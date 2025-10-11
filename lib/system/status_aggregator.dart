class SystemStatusAggregator {
  // Inputs
  bool btConnected = false;
  bool btConnecting = false;
  bool btScanning = false;

  bool cloudConfigured = false;
  bool cloudPaused = false;

  DateTime? lastCloudPingOk;
  DateTime? lastCloudPingFail;

  DateTime? lastPacketAt;
  DateTime? lastUploadOkAt;
  DateTime? lastUploadErrorAt;

  // Touch flags to keep initial state grey until we receive real input
  bool _btTouched = false;
  bool _cloudTouched = false;
  bool _uplinkTouched = false;

  // Outputs
  IndicatorColor get mcu {
    if (!_btTouched) return IndicatorColor.grey;
    if (btConnected == true) return IndicatorColor.green;
    if (btConnecting == true || btScanning == true) return IndicatorColor.yellow;
    if (!btConnected && !btConnecting && !btScanning) return IndicatorColor.red;
    return IndicatorColor.grey;
  }

  IndicatorColor get cloud {
    if (!_cloudTouched) return IndicatorColor.grey;
    if (cloudConfigured && within(lastCloudPingOk, const Duration(seconds: 10))) {
      return IndicatorColor.green;
    }
    if (!cloudConfigured || cloudPaused) {
      return IndicatorColor.yellow;
    }
    if (cloudConfigured && within(lastCloudPingFail, const Duration(seconds: 10))) {
      return IndicatorColor.red;
    }
    return IndicatorColor.grey;
  }

  IndicatorColor get upload {
    if (!_uplinkTouched) return IndicatorColor.grey;
    final ok = within(lastUploadOkAt, const Duration(seconds: 2));
    final hasRecentPkt = within(lastPacketAt, const Duration(seconds: 5));
    final hasRecentErr = within(lastUploadErrorAt, const Duration(seconds: 5));
    if (ok) return IndicatorColor.green;
    if (!ok && hasRecentPkt) return IndicatorColor.yellow;
    if (!hasRecentPkt || hasRecentErr) return IndicatorColor.red;
    return IndicatorColor.grey;
  }

  bool within(DateTime? t, Duration d) {
    if (t == null) return false;
    final now = DateTime.now();
    return now.difference(t) <= d;
  }

  void set({
    bool? btConnected,
    bool? btConnecting,
    bool? btScanning,
    bool? cloudConfigured,
    bool? cloudPaused,
    DateTime? lastCloudPingOk,
    DateTime? lastCloudPingFail,
    DateTime? lastPacketAt,
    DateTime? lastUploadOkAt,
    DateTime? lastUploadErrorAt,
  }) {
    if (btConnected != null || btConnecting != null || btScanning != null) {
      _btTouched = true;
      if (btConnected != null) this.btConnected = btConnected;
      if (btConnecting != null) this.btConnecting = btConnecting;
      if (btScanning != null) this.btScanning = btScanning;
    }
    if (cloudConfigured != null || cloudPaused != null || lastCloudPingOk != null || lastCloudPingFail != null) {
      _cloudTouched = true;
      if (cloudConfigured != null) this.cloudConfigured = cloudConfigured;
      if (cloudPaused != null) this.cloudPaused = cloudPaused;
      if (lastCloudPingOk != null) this.lastCloudPingOk = lastCloudPingOk;
      if (lastCloudPingFail != null) this.lastCloudPingFail = lastCloudPingFail;
    }
    if (lastPacketAt != null || lastUploadOkAt != null || lastUploadErrorAt != null) {
      _uplinkTouched = true;
      if (lastPacketAt != null) this.lastPacketAt = lastPacketAt;
      if (lastUploadOkAt != null) this.lastUploadOkAt = lastUploadOkAt;
      if (lastUploadErrorAt != null) this.lastUploadErrorAt = lastUploadErrorAt;
    }
  }
}

enum IndicatorColor { grey, green, yellow, red }

