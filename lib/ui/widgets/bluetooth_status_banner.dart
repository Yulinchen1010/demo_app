import 'package:flutter/material.dart';

import '../../data/app_bus.dart';
import '../../data/streaming_service.dart';

class BluetoothStatusBanner extends StatelessWidget {
  const BluetoothStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<StreamStatus>(
      stream: AppBus.instance.onBtStatus,
      initialData: AppBus.instance.lastBtStatus,
      builder: (context, snap) {
        final st = snap.data;
        final has = st != null;
        final ok = st == StreamStatus.connected;
        final color = !has
            ? Colors.blueGrey
            : ok
                ? Colors.green
                : (st == StreamStatus.connecting || st == StreamStatus.reconnecting)
                    ? Colors.amber
                    : Colors.red;
        final dev = AppBus.instance.lastBtDeviceName ?? 'ESP32_EMG_IMU';
        String stateText;
        switch (st) {
          case StreamStatus.connected:
            stateText = '已連線';
            break;
          case StreamStatus.connecting:
            stateText = '連線中...';
            break;
          case StreamStatus.reconnecting:
            stateText = '重新連線中...';
            break;
          case StreamStatus.closed:
            stateText = '已關閉';
            break;
          case StreamStatus.error:
            stateText = '連線錯誤';
            break;
          case StreamStatus.idle:
          default:
            stateText = '尚未連線';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(
                has
                    ? (ok ? Icons.bluetooth_connected : Icons.bluetooth_disabled)
                    : Icons.bluetooth,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('藍牙裝置', style: theme.textTheme.labelMedium),
                    Text(
                      '$dev · $stateText',
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

