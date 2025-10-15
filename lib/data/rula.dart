import 'models.dart';

/// Simplified RULA scoring using only left/right shoulder and trunk angles (degrees).
/// Missing parts (forearm, wrist, neck, legs) are assumed neutral per your spec.
class RulaCalculator {
  static RulaScore fromAngles({double? leftShoulderDeg, double? rightShoulderDeg, double? trunkDeg}) {
    final upperL = _scoreUpperArm(leftShoulderDeg ?? 0.0);
    final upperR = _scoreUpperArm(rightShoulderDeg ?? 0.0);
    final upper = upperL > upperR ? upperL : upperR;

    // Assume neutral for missing parts per requirement
    const forearm = 0;
    const wrist = 0;
    final A = (upper + forearm + wrist).clamp(0, 7);

    final trunk = _scoreTrunk(trunkDeg ?? 0.0);
    const neck = 0;
    const legs = 0;
    final B = (trunk + neck + legs).clamp(0, 7);

    final total = A + B;
    final C = _mapABToFinal(total);
    final label = _labelFor(C);
    return RulaScore(C, riskLabel: label);
  }

  static int _scoreUpperArm(double deg) {
    final a = deg.abs();
    if (a <= 10) return 1;
    if (a <= 30) return 2;
    if (a <= 45) return 3;
    if (a <= 60) return 4;
    if (a <= 90) return 5;
    return 6;
  }

  static int _scoreTrunk(double deg) {
    final a = deg.abs();
    if (a <= 5) return 1;
    if (a <= 15) return 2;
    if (a <= 30) return 3;
    if (a <= 45) return 4;
    if (a <= 60) return 5;
    return 6;
  }

  static int _mapABToFinal(int total) {
    if (total <= 2) return 1;
    if (total <= 4) return 2;
    if (total <= 6) return 3;
    if (total <= 7) return 4;
    if (total <= 9) return 5;
    if (total <= 11) return 6;
    return 7;
  }

  static String _labelFor(int score) {
    if (score <= 2) return '\u4f4e';
    if (score <= 4) return '\u4e2d';
    if (score <= 6) return '\u8f03\u9ad8';
    return '\u9ad8';
  }
}

