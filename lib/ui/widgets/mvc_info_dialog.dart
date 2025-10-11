import 'package:flutter/material.dart';

Future<void> showMvcInfoDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('%MVC說明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('什麼是 %MVC？'),
              Text('%MVC（Percent MVC）代表目前肌電活動強度相對於參考最大自主收縮（MVC）之百分比。數值越高，代表用力程度越大；接近或超過 100% 表示已接近個人最大用力。'),
              SizedBox(height: 10),
              Text('資料來源與運算（裝置端 MCU）'),
              Text('• EMG 取樣 EMG_FS=1000Hz，將每秒取樣值平方平均後開根號得到 emg_rms（RMS）'),
              Text('• 以 MVC_RMS_DEFAULT=3000.0 為基準：percent_mvc = (emg_rms / MVC_RMS_DEFAULT) × 100%'),
              Text('• 每秒封包包含 timestamp、emg_rms、percent_mvc 與 6 組 IMU 值，經藍牙送至 App'),
              SizedBox(height: 10),
              Text('App 與雲端'),
              Text('• App 使用 MCU 提供的 percent_mvc 顯示並上傳至 /upload（已做節流）'),
              Text('• 雲端僅儲存 %MVC，不重新計算；若需個人化 MVC 校正值，可由雲端下發或於 MCU 端調整基準'),
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

