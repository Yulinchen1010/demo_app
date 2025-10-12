import 'package:flutter/foundation.dart';

/// Tracks last telemetry sample arrival to expose freshness information.
class TelemetryService with ChangeNotifier {
  DateTime? _lastSampleAt;

  DateTime? get lastSampleAt => _lastSampleAt;

  void onSampleArrived() {
    _lastSampleAt = DateTime.now();
    notifyListeners();
  }

  bool get hasFreshData {
    final last = _lastSampleAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(seconds: 3);
  }
}
