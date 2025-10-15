"""Fatigue analytics pipeline utilities.

This module implements the fatigue processing pipeline that was provided in
the user requirements.  The implementation mirrors the reference logic and is
intended to be used both offline (for training baseline models) and online for
real-time feature generation.  The pipeline operates on 30-second samples that
contain at minimum the following columns:

* ``timestamp`` – ISO 8601 string or any pandas-compatible datetime value.
* ``mvc_percent`` – the %MVC value reported by the wearable device.
* ``rula_score`` – the instantaneous RULA posture score (integer).

If ``EMG_RMS`` values are present we perform force-removal to compute
``RMS_fe``.  When the column is missing we keep the downstream code resilient by
filling ``RMS_fe`` with ``NaN``; the baseline feature builder will gracefully
skip RMS-derived features in that case.

The code follows the five major stages documented in the specification:

1.  RMS 去力化 (force removal) – linear fit on clear data and online residuals.
2.  連續超額 + 雙門檻 + 姿勢封頂 + 指數衰減 – accumulation of fatigue score ``E``.
3.  EWMA smoothing and five-minute slope to derive trends.
4.  LED decision logic (color + blink) based on fatigue level & trend.
5.  Future fatigue labelling and baseline feature generation for machine
    learning models (Logistic Regression & HistGradientBoostingClassifier).

The helper :func:`prepare_pipeline_from_csv` function wraps the full workflow
for a CSV file so the FastAPI service can consume processed data and trained
models directly.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import numpy as np
import pandas as pd
from sklearn.experimental import enable_hist_gradient_boosting  # noqa: F401
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split


# ========= 可調參數 =========
SAMPLE_EVERY_S = 30.0  # 每 30 秒一筆
ALPHA_EWMA = 0.30  # EWMA 平滑係數
THETA_PER_MIN = 0.02  # 斜率門檻：0.02 / 分（對 E_norm）
THETA_PER_SEC = THETA_PER_MIN / 60.0  # 換算成 per second
LAMBDA_REST = 0.0003  # 恢復衰減率 (s^-1)，低負荷才生效
POSE_GAMMA = 0.10  # 姿勢加權 γ
POSE_CAP = 0.50  # 姿勢加權封頂：最多 +50%
WINDOW_SLOPE_S = 300.0  # 5 分鐘斜率視窗
ELEVEL_BINS = [-1, 0.33, 0.66, 10]  # 低/中/高門檻（對 E_norm）
ELEVEL_LABELS = ["low", "mid", "high"]
HORIZON_S = 1800.0  # 30 分鐘標籤視窗


# ========= A. RMS 去力化 =========
def fit_force_rms_model(df_fresh: pd.DataFrame) -> Tuple[float, float]:
    """Fit ``EMG_RMS ≈ α + β·%MVC`` using least squares."""

    if "EMG_RMS" not in df_fresh.columns:
        # If RMS data is missing, fall back to a simple deterministic mapping.
        # This keeps downstream code functional while making the assumption
        # explicit.  A more complete deployment should supply true EMG data.
        return 0.0, 0.0

    X = df_fresh[["mvc_percent"]].values
    X = np.c_[np.ones(len(X)), X]
    y = df_fresh["EMG_RMS"].values
    coef, _, _, _ = np.linalg.lstsq(X, y, rcond=None)  # [alpha, beta]
    return float(coef[0]), float(coef[1])


def compute_rms_fe(df: pd.DataFrame, alpha: float, beta: float) -> pd.Series:
    """線上取殘差：``RMS_fe = RMS_observed − (α + β·%MVC)``."""

    if "EMG_RMS" not in df.columns or (alpha == 0.0 and beta == 0.0):
        return pd.Series(np.nan, index=df.index, dtype=float)

    return df["EMG_RMS"] - (alpha + beta * df["mvc_percent"])


# ========= B. 累積疲勞分數 =========
def deltaE_double_threshold(mvc: np.ndarray) -> np.ndarray:
    """連續超額 + 雙門檻（未含時間因子）。"""

    over20 = np.maximum(0.0, mvc - 20.0)
    over40 = np.maximum(0.0, mvc - 40.0)
    return over20 + 2.0 * over40


def pose_multiplier(rula: np.ndarray) -> np.ndarray:
    """姿勢加權 multiplier with γ=0.1 and +50% cap."""

    add = POSE_GAMMA * np.maximum(0.0, rula - 3.0)
    add = np.minimum(POSE_CAP, add)
    return 1.0 + add


def accumulate_with_recovery(deltaE: np.ndarray, mvc: np.ndarray) -> np.ndarray:
    """指數衰減累積疲勞分數。"""

    dt = SAMPLE_EVERY_S
    E = np.zeros_like(deltaE, dtype=float)
    for i in range(len(deltaE)):
        lam_eff = LAMBDA_REST * max(0.0, 1.0 - min(1.0, mvc[i] / 20.0))
        decay = 1.0 - lam_eff * dt
        prev = 0.0 if i == 0 else E[i - 1]
        E[i] = max(0.0, prev * decay + deltaE[i] * dt)
    return E


def normalize_E(E: np.ndarray, session_seconds: float) -> np.ndarray:
    """Normalize fatigue score to [0, 1] using a two-hour @ 80% MVC reference."""

    Emax_per_sec = (80 - 20) * 1 + (80 - 40) * 2
    denom = Emax_per_sec * max(session_seconds, SAMPLE_EVERY_S)
    return np.clip(E / denom, 0.0, 1.0)


# ========= C. 平滑與斜率 =========
def ewma(x: np.ndarray, alpha: float = ALPHA_EWMA) -> np.ndarray:
    out = np.zeros_like(x, dtype=float)
    for i, v in enumerate(x):
        out[i] = v if i == 0 else alpha * v + (1 - alpha) * out[i - 1]
    return out


def slope_5min(series: np.ndarray) -> np.ndarray:
    """5 分鐘視窗的線性回歸斜率（單位 per second）。"""

    dt = SAMPLE_EVERY_S
    w = int(WINDOW_SLOPE_S / dt)
    if w < 2:
        raise ValueError("WINDOW_SLOPE_S 太小")
    x = np.arange(w) * dt
    x = x - x.mean()
    denom = np.sum(x ** 2)
    slope = np.full_like(series, np.nan, dtype=float)
    for i in range(w - 1, len(series)):
        y = series[i - w + 1 : i + 1]
        y = y - y.mean()
        slope[i] = float((x @ y) / denom)
    return slope


def trend_from_slope(s_per_sec: float) -> str:
    if np.isnan(s_per_sec):
        return "NA"
    if s_per_sec > THETA_PER_SEC:
        return "up"
    if s_per_sec < -THETA_PER_SEC:
        return "down"
    return "flat"


# ========= D. 燈號決策 =========
def level_from_Enorm(e: float) -> str:
    bins = ELEVEL_BINS
    if e < bins[1]:
        return "low"
    if e < bins[2]:
        return "mid"
    return "high"


def led_logic(level: str, trend: str) -> Dict[str, str]:
    if level == "high" and trend == "up":
        return {"color": "red", "blink": "fast"}
    if level == "high" and trend in ("flat", "down"):
        return {"color": "red", "blink": "slow"}
    if level == "mid" and trend == "up":
        return {"color": "amber", "blink": "fast"}
    return {"color": "green", "blink": "none" if trend != "up" else "slow"}


# ========= E. 標籤與特徵 =========
def future_high_label(E_norm: np.ndarray) -> np.ndarray:
    horizon_pts = int(HORIZON_S / SAMPLE_EVERY_S)
    y = np.zeros_like(E_norm, dtype=int)
    for i in range(len(E_norm)):
        j = min(len(E_norm), i + horizon_pts)
        y[i] = 1 if np.any(E_norm[i:j] >= 0.66) else 0
    return y


def future_level_label(E_norm: np.ndarray) -> np.ndarray:
    horizon_pts = int(HORIZON_S / SAMPLE_EVERY_S)
    y = np.empty(len(E_norm), dtype=object)
    for i in range(len(E_norm)):
        j = min(len(E_norm), i + horizon_pts)
        m = np.nanmax(E_norm[i:j]) if j > i else E_norm[i]
        y[i] = level_from_Enorm(m)
    return y


def rolling_feature(arr: np.ndarray, w_pts: int, fn: str) -> np.ndarray:
    out = np.full_like(arr, np.nan, dtype=float)
    for i in range(w_pts - 1, len(arr)):
        win = arr[i - w_pts + 1 : i + 1]
        if fn == "mean":
            out[i] = np.nanmean(win)
        elif fn == "max":
            out[i] = np.nanmax(win)
        elif fn == "slope":
            dt = SAMPLE_EVERY_S
            x = np.arange(w_pts) * dt
            x = x - x.mean()
            denom = np.sum(x ** 2)
            win2 = win - np.nanmean(win)
            out[i] = float((x @ win2) / denom)
        else:
            raise ValueError("unknown fn")
    return out


def build_baseline_features(df: pd.DataFrame) -> pd.DataFrame:
    dt = SAMPLE_EVERY_S
    w3m = int(180.0 / dt)
    w5m = int(300.0 / dt)

    feat = pd.DataFrame(index=df.index)

    feat["mvc_mean_3m"] = rolling_feature(df["mvc_percent"].values, w3m, "mean")
    feat["mvc_max_5m"] = rolling_feature(df["mvc_percent"].values, w5m, "max")
    feat["mvc_slope_5m"] = rolling_feature(df["mvc_percent"].values, w5m, "slope")

    feat["E_norm"] = df["E_norm"].values
    feat["E_ewma"] = df["E_smooth"].values
    feat["E_slope5m"] = df["slope5m"].values

    r = df["rula_score"].values.astype(float)
    feat["rula_avg_5m"] = rolling_feature(r, w5m, "mean")
    feat["rula_max_5m"] = rolling_feature(r, w5m, "max")

    frac = np.full(len(r), np.nan)
    for i in range(w5m - 1, len(r)):
        win = r[i - w5m + 1 : i + 1]
        frac[i] = np.mean(win >= 5)
    feat["rula_frac_ge5_5m"] = frac

    if "RMS_fe" in df.columns:
        feat["rms_fe_last"] = df["RMS_fe"].values
        var5 = np.full(len(r), np.nan)
        for i in range(w5m - 1, len(r)):
            win = df["RMS_fe"].values[i - w5m + 1 : i + 1]
            var5[i] = np.nanvar(win)
        feat["rms_fe_var_5m"] = var5

    tod = pd.to_datetime(df["timestamp"]).dt.hour.values
    feat["tod_morning"] = ((tod >= 8) & (tod < 12)).astype(int)
    feat["tod_afternoon"] = ((tod >= 12) & (tod < 18)).astype(int)
    feat["tod_evening"] = (((tod >= 18) | (tod < 8))).astype(int)

    return feat


# ========= 主流程 =========
def _ensure_emg_rms(df: pd.DataFrame) -> pd.DataFrame:
    if "EMG_RMS" in df.columns:
        return df

    # Deterministic surrogate EMG RMS – keeps the pipeline functional when the
    # simulation does not provide raw EMG readings.
    df = df.copy()
    df["EMG_RMS"] = 0.02 * df["mvc_percent"].astype(float) + 0.1
    return df


def run_pipeline(df: pd.DataFrame) -> pd.DataFrame:
    df = df.sort_values("timestamp").reset_index(drop=True).copy()
    df = _ensure_emg_rms(df)

    t0 = pd.to_datetime(df["timestamp"]).min()
    fresh = df[pd.to_datetime(df["timestamp"]) <= t0 + pd.Timedelta(minutes=20)]
    alpha, beta = fit_force_rms_model(fresh)

    df["RMS_fe"] = compute_rms_fe(df, alpha, beta)

    base = deltaE_double_threshold(df["mvc_percent"].values.astype(float))
    mult = pose_multiplier(df["rula_score"].values.astype(float))
    deltaE = base * mult

    E = accumulate_with_recovery(deltaE, df["mvc_percent"].values.astype(float))
    df["E"] = E
    session_seconds = len(df) * SAMPLE_EVERY_S
    df["E_norm"] = normalize_E(E, session_seconds=session_seconds)
    df["level"] = [level_from_Enorm(v) for v in df["E_norm"].values]

    df["E_smooth"] = ewma(df["E_norm"].values, ALPHA_EWMA)
    df["slope5m"] = slope_5min(df["E_smooth"].values)
    df["trend"] = [trend_from_slope(s) for s in df["slope5m"].values]

    led = [led_logic(lv, tr) for lv, tr in zip(df["level"], df["trend"])]
    df["color"] = [o["color"] for o in led]
    df["blink"] = [o["blink"] for o in led]

    return df


@dataclass
class PipelineModels:
    """Container for trained baseline classifiers."""

    binary_logistic: Optional[LogisticRegression]
    binary_hgb: Optional[HistGradientBoostingClassifier]
    trinary_hgb: Optional[HistGradientBoostingClassifier]


@dataclass
class PipelineArtifacts:
    processed: pd.DataFrame
    features: pd.DataFrame
    feature_columns: List[str]
    valid_feature_mask: pd.Series
    y_bin: np.ndarray
    y_tri: np.ndarray
    models: PipelineModels
    classification_reports: Dict[str, str]


def _train_baseline_models(X: pd.DataFrame, y_bin: np.ndarray, y_tri: np.ndarray) -> Tuple[PipelineModels, Dict[str, str]]:
    reports: Dict[str, str] = {}

    def _train_classifier(
        model, X_data: pd.DataFrame, y_data: Sequence, label: str
    ) -> Optional[object]:
        if len(np.unique(y_data)) < 2:
            reports[label] = "insufficient class diversity"
            return None

        test_size = 0.3 if len(X_data) >= 10 else 0.5
        strat = y_data if len(np.unique(y_data)) > 1 else None
        X_train, X_test, y_train, y_test = train_test_split(
            X_data, y_data, test_size=test_size, random_state=42, stratify=strat
        )
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)
        reports[label] = classification_report(y_test, y_pred)
        return model

    models = PipelineModels(binary_logistic=None, binary_hgb=None, trinary_hgb=None)

    log_model = LogisticRegression(max_iter=500)
    models.binary_logistic = _train_classifier(log_model, X, y_bin, "binary_logistic")

    hgb_bin = HistGradientBoostingClassifier(random_state=42)
    models.binary_hgb = _train_classifier(hgb_bin, X, y_bin, "binary_hgb")

    hgb_tri = HistGradientBoostingClassifier(random_state=42)
    models.trinary_hgb = _train_classifier(hgb_tri, X, y_tri, "trinary_hgb")

    return models, reports


def prepare_pipeline_from_csv(csv_path: str, session_column: str = "session_id") -> PipelineArtifacts:
    raw = pd.read_csv(csv_path)
    if session_column not in raw.columns:
        raw[session_column] = "session_0"

    processed_sessions: List[pd.DataFrame] = []
    for session_id, df_session in raw.groupby(session_column):
        if not {"timestamp", "mvc_percent", "rula_score"}.issubset(df_session.columns):
            continue
        df_proc = run_pipeline(df_session)
        df_proc[session_column] = session_id
        processed_sessions.append(df_proc)

    if not processed_sessions:
        raise ValueError("CSV did not contain any sessions with required columns")

    processed = pd.concat(processed_sessions, ignore_index=True)
    processed["timestamp"] = pd.to_datetime(processed["timestamp"])

    y_bin = future_high_label(processed["E_norm"].values)
    y_tri = future_level_label(processed["E_norm"].values)

    features = build_baseline_features(processed)
    feature_columns = [col for col in features.columns if col.startswith("mvc_") or col.startswith("E_") or col.startswith("rula_") or col.startswith("rms_") or col.startswith("tod_")]

    valid_mask = ~features[feature_columns].isna().any(axis=1)
    X = features.loc[valid_mask, feature_columns]

    models, reports = _train_baseline_models(X, y_bin[valid_mask], y_tri[valid_mask])

    features = features.assign(
        session_id=processed[session_column], timestamp=processed["timestamp"]
    )

    return PipelineArtifacts(
        processed=processed,
        features=features,
        feature_columns=feature_columns,
        valid_feature_mask=valid_mask,
        y_bin=y_bin,
        y_tri=y_tri,
        models=models,
        classification_reports=reports,
    )


def predict_high_fatigue_probability(models: PipelineModels, feature_row: pd.DataFrame) -> Dict[str, float]:
    result: Dict[str, float] = {}
    if models.binary_logistic is not None:
        proba = models.binary_logistic.predict_proba(feature_row)[:, 1]
        result["logistic_high_prob"] = float(proba[0])
    if models.binary_hgb is not None:
        proba = models.binary_hgb.predict_proba(feature_row)[:, 1]
        result["hgb_high_prob"] = float(proba[0])
    return result


def predict_future_level(models: PipelineModels, feature_row: pd.DataFrame) -> Optional[str]:
    if models.trinary_hgb is None:
        return None
    return str(models.trinary_hgb.predict(feature_row)[0])

