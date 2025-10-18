import 'package:flutter/material.dart';

Future<void> showRmsInfoDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('RMS 肌電訊號均方根值說明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('什麼是 RMS？'),
              Text(
                'RMS（Root Mean Square）代表肌肉電訊號的平均能量大小，'
                '反映出肌肉活化程度及動員的運動單元（motor units）數量。'
                '在肌肉持續出力的情況下，RMS 會隨疲勞過程出現變化：'
                '初期上升、後期趨穩或下降。',
              ),
              SizedBox(height: 10),
              Text('資料來源與運算（裝置端 MCU）'),
              Text('• EMG 取樣頻率約 1000 Hz，'
                  '每秒將取樣值平方平均後開根號，得到每秒 RMS（均方根）'),
              Text('• RMS 變化可反映出 motor unit 的補償與去活化狀況，'
                  '是評估肌肉疲勞的重要生理指標'),
              Text('• 實際上 RMS 並非直接對應用力大小，而應觀察其隨時間的趨勢變化'),
              SizedBox(height: 10),
              Text('App 與雲端'),
              Text('• App 會顯示即時 RMS 趨勢，並上傳至雲端進行疲勞分析與預測'),
              Text('• 後端模型會依 RMS 推算之%MVC下降程度，'
                  '推估肌肉疲勞層級與預警狀態'),
              SizedBox(height: 10),
              Text(
                '根據文獻 “Estimating the EMG response exclusively to fatigue during sustained static MVC”，'
                'RMS 的變化主要來自 motor unit 的動員與去活化過程，'
                '應以趨勢解讀，而非單一絕對值。',
              ),
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
