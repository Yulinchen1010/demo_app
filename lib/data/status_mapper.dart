/// 統一把後端回應映射成 UI 要的 label / level / color。
/// 以後端的等級為主（支援 1/2/3/4、"low"/"medium"/"high"/"critical"）
/// 若後端沒給 label/color，才補預設。
class RiskView {
  final String label;     // 顯示字串，例如「低風險」
  final int level;        // 1=低 2=中 3=高 4=嚴重
  final String colorHex;  // UI 用色，例如 '#27ae60'

  const RiskView(this.label, this.level, this.colorHex);
}

class StatusMapper {
  /// 主入口：丟整個回傳 Map，吐出 UI 需要的三件事
  static RiskView fromResponse(Map<String, dynamic> res) {
    // 從多個常見鍵名讀「等級」
    final dynamic rawLevel = res['risk_level'] ??
        res['level'] ??
        (res['data'] is Map ? (res['data'] as Map)['risk_level'] : null) ??
        (res['data'] is Map ? (res['data'] as Map)['level'] : null);

    final int? level = _parseLevel(rawLevel);

    // 後端可能也會提供文字與顏色，若有就直用
    final String? backendLabel = _readStr(
      res['label'] ??
      res['status'] ??
      (res['data'] is Map ? (res['data'] as Map)['label'] : null),
    );

    final String? backendColor = _readStr(
      res['risk_color'] ??
      (res['data'] is Map ? (res['data'] as Map)['risk_color'] : null),
    );

    if (level != null) {
      return _withDefaults(level: level, label: backendLabel, colorHex: backendColor);
    }

    // 沒有 level 的最後保底
    return const RiskView('未知', 1, '#95a5a6');
  }

  /// 解析各種型別的風險等級
  /// 支援：1/2/3/4、"1"/"2"/"3"/"4"、"low/medium/high/critical"（大小寫皆可）
  static int? _parseLevel(dynamic v) {
    if (v == null) return null;
    if (v is int) return v.clamp(1, 4);
    if (v is num) return v.toInt().clamp(1, 4);

    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return null;

    final asInt = int.tryParse(s);
    if (asInt != null) return asInt.clamp(1, 4);

    switch (s) {
      case 'low':
      case 'l':
        return 1;
      case 'medium':
      case 'med':
      case 'm':
        return 2;
      case 'high':
      case 'h':
        return 3;
      case 'critical':
      case 'crit':
      case 'c':
        return 4;
      default:
        return null;
    }
  }

  /// 給定 level，若 label / color 缺就補預設（可改成多語系）
  static RiskView _withDefaults({required int level, String? label, String? colorHex}) {
    final clamped = level.clamp(1, 4);
    final String finalLabel = label ?? _defaultLabel(clamped);
    final String finalColor = colorHex ?? _defaultColor(clamped);
    return RiskView(finalLabel, clamped, finalColor);
  }

  static String _defaultLabel(int level) {
    switch (level) {
      case 4: return '嚴重風險';
      case 3: return '高風險';
      case 2: return '中風險';
      default: return '低風險';
    }
  }

  static String _defaultColor(int level) {
    switch (level) {
      case 4: return '#ef4444'; // critical 紅
      case 3: return '#e74c3c'; // 高紅
      case 2: return '#f39c12'; // 中橙
      default: return '#27ae60'; // 低綠
    }
  }

  // ---------- 小工具：寬鬆轉型 ----------
  static String? _readStr(dynamic v) => v == null ? null : v.toString();
}
