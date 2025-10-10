import 'dart:async';
import 'package:flutter/foundation.dart';

import 'cloud_api.dart';

class CloudStatusData {
  final String workerId;
  final String label; // 低度/中度/高度 or server label
  final int riskLevel; // 1=綠,2=黃,3=紅
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
      final res = await CloudApi.status(id);
      final data = CloudStatusData(
        workerId: id,
        label: (res['fatigue_risk']?.toString() ?? '').isNotEmpty
            ? res['fatigue_risk'].toString()
            : '未知',
        riskLevel: (res['risk_level'] is num) ? (res['risk_level'] as num).toInt() : 0,
        riskColor: res['risk_color']?.toString() ?? '#27ae60',
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

