// lib/data/models.dart（只示意 EmgPoint 這段）
class EmgPoint {
  final DateTime ts;
  final double rms; // 你原本的欄位名稱如果不是 rms，請對應調整
  EmgPoint(this.ts, this.rms);

  // 讓 UI 可用 point.value 取得 RMS
  double get value => rms;
}




class RulaScore {

  final int score; // 0\u20137

  final String? riskLabel;

  const RulaScore(this.score, {this.riskLabel});

}



