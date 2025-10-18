import 'package:flutter/material.dart';

Future<void> showRulaInfoDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('RULA\u59ff\u52e2\u98a8\u96aa\u5206\u6578\u8aaa\u660e'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('RULA \u7528\u65bc\u8a55\u4f30\u4e0a\u80a2\u76f8\u95dc\u7684\u59ff\u52e2\u98a8\u96aa\uff0c\u5206\u6578\u8d8a\u9ad8\u4ee3\u8868\u8d8a\u7acb\u5373\u7684\u6539\u5584\u9700\u6c42\u3002\u672c\u7cfb\u7d71\u65bc\u524d\u7aef\u4ee5\u300c\u5de6\u80a9\u3001\u53f3\u80a9\u3001\u8ec0\u5e79\u300d\u4e09\u8655\u89d2\u5ea6\u9032\u884c\u7c21\u5316\u8a08\u5206\u5f8c\u518d\u4e0a\u50b3\u81f3\u5f8c\u7aef\u5132\u5b58\u3002'),
              SizedBox(height: 10),
              Text('\u5206\u6578\u69cb\u6210\u8207\u52a0\u7e3d\u65b9\u5f0f\uff08\u524d\u7aef\u5be6\u4f5c\uff09'),
              Text('\u2022 \u50c5\u7528 3 \u500b\u89d2\u5ea6\uff1a\u5de6\u80a9\u3001\u53f3\u80a9\u3001\u8ec0\u5e79\uff1b\u5176\u9918\u90e8\u4f4d\uff08\u524d\u81c2\u3001\u624b\u8155\u3001\u9838\u90e8\u3001\u4e0b\u80a2\uff09\u8996\u70ba\u4e2d\u6027'),
              Text('\u2022 A \u7d44\u8fd1\u4f3c\uff1amax(\u5de6\u4e0a\u81c2\u5206\u6578, \u53f3\u4e0a\u81c2\u5206\u6578) + \u524d\u81c21 + \u624b\u81551\uff08\u4e0a\u9650 7\uff09'),
              Text('\u2022 B \u7d44\u8fd1\u4f3c\uff1a\u8ec0\u5e79\u5206\u6578 + \u9838\u90e81 + \u4e0b\u80a21\uff08\u4e0a\u9650 7\uff09'),
              Text('\u2022 \u6700\u7d42\u5206\u6578\uff1a\u4ee5 (A+B) \u6620\u5c04\u5230 1\u20137 \u7b49\u7d1a\uff0c\u7528\u65bc\u5373\u6642\u63d0\u793a\uff08\u7c21\u5316\u5c0d\u7167\uff09'),
              SizedBox(height: 10),
              Text('\u5206\u6578\u89e3\u8b80\uff08\u672c\u7cfb\u7d71\u986f\u793a\uff09'),
              Text('• 1–2：低   • 3–4：中   • 5–6：較高   • 7：高'),
              Text('• 顏色對應：綠（≤2）、黃（3–4）、橙（5–6）、紅（7）'),

              SizedBox(height: 10),
              Text('\u5099\u8a3b\uff1a\u82e5\u5f8c\u7e8c\u63d0\u4f9b\u5404\u89d2\u5ea6\u9580\u6abb\u6216\u4fee\u6b63\u503c\uff08\u4f8b\u5982\u8ca0\u8f09\u81e8\u754c\u6216\u975c\u614b/\u91cd\u8907\u689d\u4ef6\uff09\uff0c\u53ef\u4e00\u4f75\u66f4\u65b0\u6b64\u8aaa\u660e\u4ee5\u7dad\u6301\u8207\u5be6\u52d9\u898f\u5247\u4e00\u81f4\u3002'),
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

