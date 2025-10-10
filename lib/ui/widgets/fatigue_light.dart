import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/cloud_subscriber.dart';

class FatigueLight extends StatefulWidget {
  final CloudStatusSubscriber subscriber;
  const FatigueLight({super.key, required this.subscriber});

  @override
  State<FatigueLight> createState() => _FatigueLightState();
}

class _FatigueLightState extends State<FatigueLight> {
  CloudStatusData? _last;
  StreamSubscription<CloudStatusData>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.subscriber.stream.listen((e) => setState(() => _last = e));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final risk = _last?.riskLevel ?? 0;
    final label = _last?.label ?? '尚未訂閱';
    final ts = _last?.ts;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _lightCircle(Colors.red, active: risk >= 3),
              const SizedBox(width: 8),
              _lightCircle(Colors.orange, active: risk == 2),
              const SizedBox(width: 8),
              _lightCircle(Colors.green, active: risk == 1),
              const Spacer(),
              Text(
                _statusText(risk, label),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          if (ts != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '雲端更新：${_hhmmss(ts)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _lightCircle(Color color, {required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: active ? color : color.withOpacity(0.2),
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }

  String _statusText(int risk, String label) {
    switch (risk) {
      case 3:
        return '高風險（紅燈）· $label';
      case 2:
        return '中風險（黃燈）· $label';
      case 1:
        return '低風險（綠燈）· $label';
      default:
        return '未取得雲端狀態';
    }
  }

  String _hhmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

