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

            stateText = '\u5df2\u9023\u7dda';

            break;

          case StreamStatus.connecting:

            stateText = '\u9023\u7dda\u4e2d...';

            break;

          case StreamStatus.reconnecting:

            stateText = '\u91cd\u65b0\u9023\u7dda\u4e2d...';

            break;

          case StreamStatus.closed:

            stateText = '\u5df2\u95dc\u9589';

            break;

          case StreamStatus.error:

            stateText = '\u9023\u7dda\u932f\u8aa4';

            break;

          case StreamStatus.idle:

          default:

            stateText = '\u5c1a\u672a\u9023\u7dda';

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

                    Text('\u85cd\u7259\u88dd\u7f6e', style: theme.textTheme.labelMedium),

                    Text(

                      '$dev \u00b7 $stateText',

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



