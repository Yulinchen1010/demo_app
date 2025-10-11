import 'dart:async';
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../data/app_bus.dart';
import '../../data/streaming_service.dart';
import '../../data/cloud_api.dart';
import 'system_status_bar.dart';

/// Adapter that maps live app state into the new SystemStatusBar.
class SystemHealthLights extends StatefulWidget {
  const SystemHealthLights({super.key});

  @override
  State<SystemHealthLights> createState() => _SystemHealthLightsState();
}

class _SystemHealthLightsState extends State<SystemHealthLights> {
  StreamSubscription<StreamStatus>? _btSub;
  StreamSubscription<CloudEvent>? _cloudSub;
  StreamStatus? _bt;
  bool _lastUploadOk = true;

  @override
  void initState() {
    super.initState();
    _bt = AppBus.instance.lastBtStatus;
    _btSub = AppBus.instance.onBtStatus.listen((s) => setState(() => _bt = s));
    _cloudSub = CloudApi.events.listen((e) {
      if (e.op == 'upload' || e.op == 'upload_batch' || e.op == 'upload_rula') {
        setState(() => _lastUploadOk = e.ok);
      } else {
        // Any cloud activity can re-evaluate paused state in UI
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _btSub?.cancel();
    _cloudSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mcu = (_bt == StreamStatus.connected) ? HealthLevel.ok : HealthLevel.error;
    final cloud = (CloudApi.baseUrl.isEmpty || CloudApi.workerId.isEmpty)
        ? HealthLevel.warning
        : HealthLevel.ok;
    final uplink = _lastUploadOk ? HealthLevel.ok : HealthLevel.error;

    return SystemStatusBar(mcu: mcu, cloud: cloud, uplink: uplink);
  }
}

