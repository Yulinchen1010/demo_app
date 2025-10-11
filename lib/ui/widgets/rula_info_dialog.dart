import 'package:flutter/material.dart';

Future<void> showRulaInfoDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('RULA姿勢風險分數說明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('RULA 用於評估上肢相關的姿勢風險，分數越高代表越立即的改善需求。本系統於前端以「左肩、右肩、軀幹」三處角度進行簡化計分後再上傳至後端儲存。'),
              SizedBox(height: 10),
              Text('分數構成與加總方式（前端實作）'),
              Text('• 僅用 3 個角度：左肩、右肩、軀幹；其餘部位（前臂、手腕、頸部、下肢）視為中性'),
              Text('• A 組近似：max(左上臂分數, 右上臂分數) + 前臂1 + 手腕1（上限 7）'),
              Text('• B 組近似：軀幹分數 + 頸部1 + 下肢1（上限 7）'),
              Text('• 最終分數：以 (A+B) 映射到 1–7 等級，用於即時提示（簡化對照）'),
              SizedBox(height: 10),
              Text('分數解讀（本系統顯示）'),
              Text('• 1–2：低   • 3–4：中   • 5–6：較高   • 7+：高'),
              Text('• 顏色對映：綠（≤2）、黃（3–4）、橘（5–6）、紅（≥7）'),
              SizedBox(height: 10),
              Text('備註：若後續提供各角度門檻或修正值（例如負載臨界或靜態/重複條件），可一併更新此說明以維持與實務規則一致。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('關閉'),
          ),
        ],
      );
    },
  );
}

