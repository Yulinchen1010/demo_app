import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high, critical }

class RiskTheme {
  // 預設色票
  static const Color low = Color(0xFF22C55E);
  static const Color medium = Color(0xFFF59E0B);
  static const Color high = Color(0xFFF97316);
  static const Color critical = Color(0xFFEF4444);

  /// 從 enum 取得預設顏色
  static Color color(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return low;
      case RiskLevel.medium:
        return medium;
      case RiskLevel.high:
        return high;
      case RiskLevel.critical:
        return critical;
    }
  }

  /// 若後端有回 colorHex（例如 "#27AE60"），就優先用它
  static Color colorWithOverride(RiskLevel level, {String? colorHex}) {
    final c = _parseHexColor(colorHex);
    return c ?? color(level);
  }

  static String label(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return '低';
      case RiskLevel.medium:
        return '中';
      case RiskLevel.high:
        return '較高';
      case RiskLevel.critical:
        return '高';
    }
  }

  static String caption(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return '安全';
      case RiskLevel.medium:
        return '注意';
      case RiskLevel.high:
        return '警戒';
      case RiskLevel.critical:
        return '危險';
    }
  }

  // ---------- helpers ----------
  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var v = hex.trim();
    if (v.startsWith('#')) v = v.substring(1);
    if (v.length == 6) v = 'FF$v'; // 填滿不透明 alpha
    if (v.length != 8) return null;
    final n = int.tryParse(v, radix: 16);
    return n == null ? null : Color(n);
  }
}

/// 後端等級 → enum
/// 支援 1/2/3/4、"1"/"2"/"3"/"4"、"low/medium/high/critical"（大小寫皆可）
/// 不識別時回 null（讓上層決定 fallback）
RiskLevel? mapBackendLevel(dynamic level) {
  if (level == null) return null;

  if (level is int) {
    switch (level) {
      case 1:
        return RiskLevel.low;
      case 2:
        return RiskLevel.medium;
      case 3:
        return RiskLevel.high;
      case 4:
        return RiskLevel.critical;
    }
  }

  final s = level.toString().trim().toLowerCase();
  final asInt = int.tryParse(s);
  if (asInt != null) return mapBackendLevel(asInt);

  switch (s) {
    case 'low':
    case 'l':
      return RiskLevel.low;
    case 'medium':
    case 'med':
    case 'm':
      return RiskLevel.medium;
    case 'high':
    case 'h':
      return RiskLevel.high;
    case 'critical':
    case 'crit':
    case 'c':
      return RiskLevel.critical;
  }
  return null;
}

/// 本地 fallback：當後端沒回等級時，根據 RULA / %MVC 判斷
/// - 對 NaN/無窮與範圍做保護
/// - %MVC clamp 到 0..100
RiskLevel computeRisk({
  required double rula,
  required double mvc, // 0..100 (%)
  required Duration hold,         // 高風險需持續多久才升級 critical
  required Duration nowOverHold,  // 目前已持續多久
}) {
  final double rulaValue = (rula.isFinite ? rula : 0).clamp(0, 7).toDouble();
  final double mvcValue = (mvc.isFinite ? mvc : 0).clamp(0, 100).toDouble();

  final Duration needHold = (hold.inMilliseconds < 0)
      ? Duration.zero
      : hold;

  final bool longEnough = nowOverHold >= needHold;

  if ((rulaValue >= 7 || mvcValue >= 70) && longEnough) {
    return RiskLevel.critical;
  }
  if (rulaValue >= 5 || mvcValue >= 50) {
    return RiskLevel.high;
  }
  if (rulaValue >= 3 || mvcValue >= 30) {
    return RiskLevel.medium;
  }
  return RiskLevel.low;
}
