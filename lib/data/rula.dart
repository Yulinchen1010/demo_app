import 'models.dart';

/// Super-simplified RULA：只用左/右上臂與軀幹角度，其他部位視為「中立=1分」
/// 注意：這不是完整 RULA（少了 Table A/B/C 與負荷/肌肉使用調整），
/// 只是為了輕量顯示風險用的近似版。
class RulaCalculator {
  static RulaScore fromAngles({
    double? leftShoulderDeg,
    double? rightShoulderDeg,
    double? trunkDeg,
  }) {
    // 上臂取左右較大者（較差的一側）
    final upperL = _scoreUpperArm(leftShoulderDeg ?? 0.0); // 1..6
    final upperR = _scoreUpperArm(rightShoulderDeg ?? 0.0); // 1..6
    final upper = upperL > upperR ? upperL : upperR;       // 1..6

    // 缺少部位 → 中立 1 分（不是 0）
    const forearm = 1;
    const wrist = 1;
    final A = (upper + forearm + wrist); // 3..8

    final trunk = _scoreTrunk(trunkDeg ?? 0.0); // 1..6
    const neck = 1;
    const legs = 1;
    final B = (trunk + neck + legs); // 3..8

    // 近似 Table C：把 A+B（6..16）分箱到 1..7
    final total = A + B; // 6..16
    final C = _mapABToFinal(total);
    final label = _labelFor(C);

    return RulaScore(C, riskLabel: label);
  }

  // 上臂角度 → 1..6（越大越糟）
  static int _scoreUpperArm(double deg) {
    final a = deg.abs();
    if (a <= 10) return 1;
    if (a <= 30) return 2;
    if (a <= 45) return 3;
    if (a <= 60) return 4;
    if (a <= 90) return 5;
    return 6;
  }

  // 軀幹角度 → 1..6（越大越糟）
  static int _scoreTrunk(double deg) {
    final a = deg.abs();
    if (a <= 5) return 1;
    if (a <= 15) return 2;
    if (a <= 30) return 3;
    if (a <= 45) return 4;
    if (a <= 60) return 5;
    return 6;
  }

  // 把 A+B（6..16）映射到 RULA 最終 1..7（簡化近似）
  static int _mapABToFinal(int total) {
    // 你原本的門檻是從 0 開始，會讓中立（理論上 6 分）被錯誤落到很低層級。
    // 這裡用更合理的分箱（可以依實測再微調）：
    if (total <= 7) return 1;      // 6-7
    if (total <= 9) return 2;      // 8-9
    if (total <= 11) return 3;     // 10-11
    if (total <= 13) return 4;     // 12-13
    if (total == 14) return 5;     // 14
    if (total == 15) return 6;     // 15
    return 7;                      // 16
  }

  static String _labelFor(int score) {
    // 可自行對應到你的 UI 等級
    if (score <= 2) return '低';
    if (score <= 4) return '中';
    if (score <= 6) return '較高';
    return '高';
  }
}
