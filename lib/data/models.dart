class EmgPoint {
  final DateTime ts;
  final double rms;
  const EmgPoint(this.ts, this.rms);
}

class RulaScore {
  final int score; // 0–7
  final String? riskLabel;
  const RulaScore(this.score, {this.riskLabel});
}

