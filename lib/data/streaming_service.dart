// ============================== StreamingService =============================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

// RulaScore 統一用 models.dart 的版本
import 'models.dart' as m;
import 'mvc.dart';
import 'rula.dart' as ralgo;
import 'cloud_api.dart';

enum StreamStatus { idle, connecting, connected, reconnecting, error, closed }

class TelemetrySample {
  final DateTime ts;
  final double emgRms;
  final m.RulaScore? rula;
  TelemetrySample(this.ts, this.emgRms, this.rula);
}

/// Reads real-time telemetry from a WebSocket and exposes typed streams.
class StreamingService {
  final String? url;
  final Duration _pingInterval = const Duration(seconds: 20);
  final Duration _initialBackoff = const Duration(seconds: 1);
  final Duration _maxBackoff = const Duration(seconds: 15);

  WebSocket? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(seconds: 1);
  DateTime? _lastRulaUploadAt;
  int? _lastUploadedRulaScore;

  final _statusCtrl = StreamController<StreamStatus>.broadcast();
  // ↓↓↓ EmgPoint 來自 models.dart，要加 m. 前綴
  final _emgCtrl = StreamController<m.EmgPoint>.broadcast();
  final _mvcCtrl = StreamController<MvcPoint>.broadcast();
  final _rulaCtrl = StreamController<m.RulaScore>.broadcast();
  final _sampleCtrl = StreamController<TelemetrySample>.broadcast();

  StreamingService({this.url});

  Stream<StreamStatus> get status => _statusCtrl.stream;
  // ↓↓↓ 回傳型別一併修正
  Stream<m.EmgPoint> get emg => _emgCtrl.stream;
  Stream<MvcPoint> get mvc => _mvcCtrl.stream;
  Stream<m.RulaScore> get rula => _rulaCtrl.stream;
  Stream<TelemetrySample> get samples => _sampleCtrl.stream;

  static const String kStreamUrl =
      String.fromEnvironment('STREAM_URL', defaultValue: '');
  static bool get hasConfiguredUrl => kStreamUrl.isNotEmpty;

  Future<void> start() async {
    final target = url ?? kStreamUrl;
    if (target.isEmpty) {
      _statusCtrl.add(StreamStatus.idle);
      return;
    }
    _connect(target);
  }

  void _connect(String target) async {
    _statusCtrl.add(StreamStatus.connecting);
    try {
      _ws = await WebSocket.connect(target);
      _statusCtrl.add(StreamStatus.connected);
      _backoff = _initialBackoff;
      try {
        _ws!.pingInterval = _pingInterval;
      } catch (_) {}
      _wsSub = _ws!.listen(
        _handleMessage,
        onDone: _scheduleReconnect,
        onError: (e, st) {
          _statusCtrl.add(StreamStatus.error);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _statusCtrl.add(StreamStatus.error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.close();
    _ws = null;
    _statusCtrl.add(StreamStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff, () {
      final target = url ?? kStreamUrl;
      if (target.isEmpty) return;
      _connect(target);
    });
    _backoff = _backoff * 2;
    if (_backoff > _maxBackoff) _backoff = _maxBackoff;
  }

  void _handleMessage(dynamic data) {
    try {
      final obj = data is String ? jsonDecode(data) : data;
      if (obj is! Map) return;
      final map = obj.map((k, v) => MapEntry(k.toString(), v));

      final tsMs = _asInt(map['ts_ms']) ??
          _asInt(map['timestamp']) ??
          DateTime.now().millisecondsSinceEpoch;
      final ts = DateTime.fromMillisecondsSinceEpoch(tsMs);

      final emg = (map['emg_rms'] is num)
          ? (map['emg_rms'] as num).toDouble()
          : _asNum(map['emg'])?.toDouble() ?? 0.0;

      final mvcPct = _asNum(map['percent_mvc'])?.toDouble() ??
          _asNum(map['emg_pct'])?.toDouble();

      m.RulaScore? rulaScore;

      // 1) 直接吃伺服器已算好的 rula
      final r = map['rula'];
      if (r is Map) {
        final score = _asInt(r['score']);
        final label = r['risk_label']?.toString();
        if (score != null) {
          rulaScore = m.RulaScore(score, riskLabel: label);
        }
      }

      // 2) 沒給 rula 就本地計算（angles）
      if (rulaScore == null) {
        Map<String, dynamic> angles;
        final a = map['angles'];
        if (a is Map) {
          angles = a.map((k, v) => MapEntry(k.toString(), v));
        } else {
          angles = map;
        }
        final ls = _asNum(angles['left_shoulder'])?.toDouble();
        final rs = _asNum(angles['right_shoulder'])?.toDouble();
        final tk = _asNum(angles['trunk'])?.toDouble();
        if (ls != null || rs != null || tk != null) {
          // 注意：這裡用 ralgo，避免被 class 的 getter rula 遮蔽
          final raw = ralgo.RulaCalculator.fromAngles(
            leftShoulderDeg: ls,
            rightShoulderDeg: rs,
            trunkDeg: tk,
          );
          // 轉成 models 版 RulaScore
          final computed = m.RulaScore(raw.score, riskLabel: raw.riskLabel);
          rulaScore = computed;
          _maybeUploadRula(computed);
        }
      }

      // 發佈資料（m.EmgPoint）
      final point = m.EmgPoint(ts, emg);
      _emgCtrl.add(point);

      if (mvcPct != null) {
        _mvcCtrl.add(MvcPoint(ts, mvcPct.clamp(0, 100).toDouble()));
      }
      if (rulaScore != null) _rulaCtrl.add(rulaScore);

      _sampleCtrl.add(TelemetrySample(ts, emg, rulaScore));
    } catch (_) {
      // ignore malformed frames
    }
  }

  Future<void> _maybeUploadRula(m.RulaScore s) async {
    try {
      if (CloudApi.baseUrl.isEmpty || CloudApi.workerId.isEmpty) return;
      final now = DateTime.now();
      final lastScore = _lastUploadedRulaScore;
      final shouldByScore = lastScore == null || lastScore != s.score;
      final shouldByTime =
          _lastRulaUploadAt == null || now.difference(_lastRulaUploadAt!).inSeconds >= 30;
      if (!shouldByScore && !shouldByTime) return;
      _lastUploadedRulaScore = s.score;
      _lastRulaUploadAt = now;
      // 需要時可改成 uploadJson 上傳
      // await CloudApi.uploadJson([...]);
    } catch (_) {}
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _wsSub?.cancel();
    try {
      await _ws?.close();
    } catch (_) {}
    await _statusCtrl.close();
    await _emgCtrl.close();
    await _mvcCtrl.close();
    await _rulaCtrl.close();
    await _sampleCtrl.close();
  }
}
