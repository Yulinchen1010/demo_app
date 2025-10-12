import 'package:flutter/material.dart';

class FatigueDetailPage extends StatelessWidget {
  const FatigueDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('\u75b2\u52de\u8a73\u7d30')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '\u5957\u7528\u8a73\u7d30\u9801\u9762\u5c1a\u672a\u5b8c\u6210\uff0c\u53ef\u4ee5\u986f\u793a\u6700\u8fd1\u8b66\u793a\u4e8b\u4ef6\u3001\u8da8\u52e2\u5716\u8207\u5efa\u8b70\u3002',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
