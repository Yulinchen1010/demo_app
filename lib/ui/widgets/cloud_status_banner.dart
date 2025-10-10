import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/cloud_api.dart';

class CloudStatusBanner extends StatefulWidget {
  const CloudStatusBanner({super.key});

  @override
  State<CloudStatusBanner> createState() => _CloudStatusBannerState();
}

class _CloudStatusBannerState extends State<CloudStatusBanner> {
  CloudEvent? _last;
  StreamSubscription<CloudEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = CloudApi.events.listen((e) => setState(() => _last = e));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = CloudApi.baseUrl.isEmpty ? '(未設定)' : CloudApi.baseUrl;
    final has = _last != null;
    final color = !has
        ? Colors.blueGrey
        : _last!.ok
            ? Colors.green
            : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(has ? (_last!.ok ? Icons.cloud_done : Icons.cloud_off) : Icons.cloud,
              color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('雲端：$base',
                    style: Theme.of(context).textTheme.labelMedium),
                Text(
                  has
                      ? '最近 ${_last!.op} • ${_last!.ok ? '成功' : '失敗'} • ${_last!.message}'
                      : '尚無雲端活動',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
