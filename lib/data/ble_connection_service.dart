import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_bus.dart';
import 'streaming_service.dart';

/// Exposes a simple connection flag so UI avoids listening to the same stream multiple times.
class BleConnectionService with ChangeNotifier {
  BleConnectionService() {
    _isConnected = AppBus.instance.lastBtStatus == StreamStatus.connected;
    _subscription = AppBus.instance.onBtStatus.listen(_handleStatus);
  }

  late bool _isConnected;
  bool get isConnected => _isConnected;

  StreamSubscription<StreamStatus>? _subscription;

  void _handleStatus(StreamStatus status) {
    final next = status == StreamStatus.connected;
    if (next == _isConnected) return;
    _isConnected = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
