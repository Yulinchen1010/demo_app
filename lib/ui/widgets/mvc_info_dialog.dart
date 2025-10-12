import 'package:flutter/material.dart';

Future<void> showMvcInfoDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('%MVC\u8aaa\u660e'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('\u4ec0\u9ebc\u662f %MVC\uff1f'),
              Text('%MVC\uff08Percent MVC\uff09\u4ee3\u8868\u76ee\u524d\u808c\u96fb\u6d3b\u52d5\u5f37\u5ea6\u76f8\u5c0d\u65bc\u53c3\u8003\u6700\u5927\u81ea\u4e3b\u6536\u7e2e\uff08MVC\uff09\u4e4b\u767e\u5206\u6bd4\u3002\u6578\u503c\u8d8a\u9ad8\uff0c\u4ee3\u8868\u7528\u529b\u7a0b\u5ea6\u8d8a\u5927\uff1b\u63a5\u8fd1\u6216\u8d85\u904e 100% \u8868\u793a\u5df2\u63a5\u8fd1\u500b\u4eba\u6700\u5927\u7528\u529b\u3002'),
              SizedBox(height: 10),
              Text('\u8cc7\u6599\u4f86\u6e90\u8207\u904b\u7b97\uff08\u88dd\u7f6e\u7aef MCU\uff09'),
              Text('\u2022 EMG \u53d6\u6a23 EMG_FS=1000Hz\uff0c\u5c07\u6bcf\u79d2\u53d6\u6a23\u503c\u5e73\u65b9\u5e73\u5747\u5f8c\u958b\u6839\u865f\u5f97\u5230 emg_rms\uff08RMS\uff09'),
              Text('\u2022 \u4ee5 MVC_RMS_DEFAULT=3000.0 \u70ba\u57fa\u6e96\uff1apercent_mvc = (emg_rms / MVC_RMS_DEFAULT) \u00d7 100%'),
              Text('\u2022 \u6bcf\u79d2\u5c01\u5305\u5305\u542b timestamp\u3001emg_rms\u3001percent_mvc \u8207 6 \u7d44 IMU \u503c\uff0c\u7d93\u85cd\u7259\u9001\u81f3 App'),
              SizedBox(height: 10),
              Text('App \u8207\u96f2\u7aef'),
              Text('\u2022 App \u4f7f\u7528 MCU \u63d0\u4f9b\u7684 percent_mvc \u986f\u793a\u4e26\u4e0a\u50b3\u81f3 /upload\uff08\u5df2\u505a\u7bc0\u6d41\uff09'),
              Text('\u2022 \u96f2\u7aef\u50c5\u5132\u5b58 %MVC\uff0c\u4e0d\u91cd\u65b0\u8a08\u7b97\uff1b\u82e5\u9700\u500b\u4eba\u5316 MVC \u6821\u6b63\u503c\uff0c\u53ef\u7531\u96f2\u7aef\u4e0b\u767c\u6216\u65bc MCU \u7aef\u8abf\u6574\u57fa\u6e96'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('\u95dc\u9589'),
          ),
        ],
      );
    },
  );
}

