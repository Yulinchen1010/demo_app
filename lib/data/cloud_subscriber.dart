import 'dart:async';

import 'package:flutter/foundation.dart';



import 'cloud_api.dart';



class CloudStatusData {

  final String workerId;

  final String label; // \u4f4e\u5ea6/\u4e2d\u5ea6/\u9ad8\u5ea6 or server label

  final int riskLevel; // 1=\u7da0,2=\u9ec3,3=\u7d05

  final String riskColor; // hex like #e74c3c

  final DateTime ts;

  CloudStatusData({

    required this.workerId,

    required this.label,

    required this.riskLevel,

    required this.riskColor,

    required this.ts,

  });

}



/// Periodically polls CloudApi.status(workerId) and emits CloudStatusData.

class CloudStatusSubscriber {

  final Duration interval;

  Timer? _timer;

  bool _running = false;

  final _ctrl = StreamController<CloudStatusData>.broadcast();



  CloudStatusSubscriber({this.interval = const Duration(seconds: 5)});



  Stream<CloudStatusData> get stream => _ctrl.stream;



  bool get isRunning => _running;



  void start({String? workerId}) {

    if (_running) return;

    _running = true;

    _tick(workerId: workerId);

    _timer = Timer.periodic(interval, (_) => _tick(workerId: workerId));

  }



  Future<void> _tick({String? workerId}) async {

    final id = (workerId ?? CloudApi.workerId).trim();

    if (CloudApi.baseUrl.isEmpty || id.isEmpty) return;

    try {

      // 直接使用 process API，同時獲取處理結果
      final res = await CloudApi.process(

        workerId: id,

        percentMvc: 0, // 用 0 表示只取狀態不上傳數據

        augmentHigh: true,

      );

      // 解析回傳的風險資訊

      final data = CloudStatusData(

        workerId: id,

        label: res['status']?.toString() ?? '\u672a\u77e5',

        riskLevel: 1, // 簡化風險等級（1=綠）

        riskColor: '#27ae60', // 預設綠色

        ts: DateTime.now(),

      );

      if (!_ctrl.isClosed) _ctrl.add(data);

    } catch (e) {

      if (kDebugMode) {

        // Silent in release; log in debug.

        // ignore: avoid_print

        print('Cloud poll error: $e');

      }

    }

  }



  Future<void> stop() async {

    _timer?.cancel();

    _timer = null;

    _running = false;

  }



  Future<void> dispose() async {

    await stop();

    await _ctrl.close();

  }

}



