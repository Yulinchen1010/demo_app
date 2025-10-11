import 'models.dart';

/// Simplified RULA scoring using only left/right shoulder and trunk angles (degrees).
/// Missing parts (forearm, wrist, neck, legs) are assumed neutral per your spec.
class RulaCalculator {
  static RulaScore fromAngles({double? leftShoulderDeg, double? rightShoulderDeg, double? trunkDeg}) {
    final upperL = _scoreUpperArm(leftShoulderDeg ?? 0.0);
    final upperR = _scoreUpperArm(rightShoulderDeg ?? 0.0);
    final upper = upperL > upperR ? upperL : upperR;

    // Assume neutral for missing parts per requirement
    const forearm = 1;
    const wrist = 1;
    final A = (upper + forearm + wrist).clamp(0, 7);

    final trunk = _scoreTrunk(trunkDeg ?? 0.0);
    const neck = 1;
    const legs = 1;
    final B = (trunk + neck + legs).clamp(0, 7);

    final total = A + B;
    final C = _mapABToFinal(total);
    final label = _labelFor(C);
    return RulaScore(C, riskLabel: label);
  }

  static int _scoreUpperArm(double deg) {
    final a = (deg).abs();
    if (a <= 20) return 1;
    if (a <= 45) return 2;
    if (a <= 90) return 3;
    return 4;
  }

  static int _scoreTrunk(double deg) {
    final a = (deg).abs();
    if (a <= 5) return 1;
    if (a <= 20) return 2;
    if (a <= 60) return 3;
    return 4;
  }

  static int _mapABToFinal(int total) {
    if (total <= 2) return 1;
    if (total <= 4) return 2;
    if (total <= 6) return 3;
    if (total <= 8) return 4;
    if (total <= 10) return 5;
    if (total <= 12) return 6;
    return 7;
  }

  static String _labelFor(int score) {
    if (score <= 2) return '低';
    if (score <= 4) return '中';
    if (score <= 6) return '較高';
    return '高';
  }
}

