import 'package:flutter/material.dart';
import '../../design/t_colors.dart';
// 仍保留給舊呼叫點使用；實際轉去顯示 RMS 說明
Future<void> showMvcInfo(BuildContext context) => showRmsInfo(context);

Future<void> showRmsInfo(BuildContext context) {
  return _showInfoSheet(
    context,
    icon: Icons.show_chart,
    title: 'RMS 肌電訊號均方根值',
    summary: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'RMS（Root Mean Square）反映肌肉活化程度。在持續出力過程中，'
        'RMS 會隨疲勞出現先升後穩的變化，是評估 motor unit 去活化與神經補償的重要指標。',
        style: TextStyle(fontSize: 13, color: TColors.textSecondary, height: 1.5),
        textAlign: TextAlign.center,
      ),
    ),
    cards: const [
      _InfoCardData(
        title: '生理意義',
        gradient: [Color(0xFF0EA5E9), TColors.primary],
        paragraphLines: [
          'RMS 代表肌肉電位的平均能量大小，與活化 motor unit 數量及放電頻率有關。',
          '疲勞初期：補償招募使 RMS 上升；中後期：去活化/放電變慢，RMS 轉趨穩定。',
        ],
      ),
      _InfoCardData(
        title: '典型變化趨勢（依文獻）',
        gradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
        bulletLines: [
          '90–70%MVC：RMS 緩升（補償活化）',
          '70–60%MVC：RMS 近峰後趨穩',
          '<60%MVC：RMS 無明顯再上升、肌力下降明顯',
        ],
      ),
      _InfoCardData(
        title: '應用說明',
        gradient: [Color(0xFFF97316), Color(0xFFEA580C)],
        paragraphLines: [
          'RMS 建議與 %MVC 或姿勢指標（RULA）合併觀察，並以趨勢判讀。',
        ],
      ),
    ],
    note: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '依 “Estimating the EMG response exclusively to fatigue during sustained static MVC”，'
        'RMS 變化主要反映補償與去活化過程，應著重趨勢而非絕對值。',
        style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

// ←←← 這個函式要在檔案最外層（不要放在 class 裡）
Future<void> showRulaInfo(BuildContext context) {
  return _showInfoSheet(
    context,
    icon: Icons.accessibility_new,
    title: 'RULA 姿勢風險分數',
    summary: const Text(
      '用於評估上肢姿勢與負荷的風險，分數越高越需要調整姿勢或休息。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: TColors.textSecondary, height: 1.5),
    ),
    cards: const [
      _InfoCardData(
        title: '分數區間',
        gradient: [Color(0xFFA855F7), Color(0xFF7C3AED)],
        bulletLines: [
          '1–2：低風險，可接受',
          '3–4：中風險，建議留意',
          '5–6：較高風險，應改善',
          '≥7：高風險，需立即調整',
        ],
      ),
      _InfoCardData(
        title: '運作方式',
        gradient: [Color(0xFFF97316), Color(0xFFEA580C)],
        paragraphLines: [
          '系統依偵測角度與姿勢動作估算 RULA 分數；詳算在裝置端或後端完成。',
        ],
      ),
    ],
    note: const Text(
      '若長時間處在較高或高風險等級，建議安排休息或調整作業流程。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.4),
    ),
  );
}

Future<void> _showInfoSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget summary,
  required List<_InfoCardData> cards,
  required Widget note,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: TColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: TColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TColors.textPrimary,
                      shadows: [Shadow(blurRadius: 8, color: TColors.primary)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              summary,
              const SizedBox(height: 20),
              for (final card in cards) ...[
                _InfoCard(data: card),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.error_outline, size: 18, color: Colors.white54),
                  SizedBox(width: 6),
                  // 用 Flexible 避免溢位
                ],
              ),
              note,
              const SizedBox(height: 20),
              const _CloseButton(),
            ],
          ),
        ),
      );
    },
  );
}

class _InfoCardData {
  const _InfoCardData({
    required this.title,
    required this.gradient,
    this.bulletLines,
    this.paragraphLines,
  });

  final String title;
  final List<Color> gradient;
  final List<String>? bulletLines;
  final List<String>? paragraphLines;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.data});
  final _InfoCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: data.gradient.last.withOpacity(0.28),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (data.bulletLines != null)
            ...data.bulletLines!.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $line',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35),
                  ),
                )),
          if (data.paragraphLines != null)
            ...data.paragraphLines!.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.45),
                  ),
                )),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: TColors.primary,
        foregroundColor: TColors.primaryOn,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: () => Navigator.pop(context),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        child: Text('了解了', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
