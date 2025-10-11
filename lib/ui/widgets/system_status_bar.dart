import 'package:flutter/material.dart';
import '../../design/tokens.dart';
import 'breathing_light.dart';

class SystemStatusBar extends StatelessWidget {
  final HealthLevel mcu;
  final HealthLevel cloud;
  final HealthLevel uplink;

  const SystemStatusBar({
    super.key,
    required this.mcu,
    required this.cloud,
    required this.uplink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: HealthColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          BreathingLight(level: mcu, label: 'MCU 連線'),
          BreathingLight(level: cloud, label: '雲端暫停'),
          BreathingLight(level: uplink, label: '上傳狀態'),
        ],
      ),
    );
  }
}

