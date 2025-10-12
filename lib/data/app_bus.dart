import 'dart:async';
import 'data_source.dart';
import 'streaming_service.dart';

class AppBus {
  AppBus._();
  static final AppBus instance = AppBus._();

  final StreamController<DataSource> _sourceCtrl = StreamController.broadcast();
  final StreamController<void> _reconnectCtrl = StreamController.broadcast();
  final StreamController<StreamStatus> _btStatusCtrl = StreamController.broadcast();

  StreamStatus? _lastBtStatus;
  String? _lastBtDeviceName;
  String? _selectedBtName;

  Stream<DataSource> get onSource => _sourceCtrl.stream;
  Stream<void> get onReconnect => _reconnectCtrl.stream;
  Stream<StreamStatus> get onBtStatus => _btStatusCtrl.stream;

  StreamStatus? get lastBtStatus => _lastBtStatus;
  String? get lastBtDeviceName => _lastBtDeviceName;
  String? get selectedBtName => _selectedBtName;

  void setSource(DataSource src) => _sourceCtrl.add(src);
  void reconnect() => _reconnectCtrl.add(null);

  bool get isConnected => _lastBtStatus == StreamStatus.connected;

  void setBtStatus(StreamStatus status, {String? deviceName}) {
    _lastBtStatus = status;
    if (deviceName != null && deviceName.isNotEmpty) {
      _lastBtDeviceName = deviceName;
    }
    if (!_btStatusCtrl.isClosed) _btStatusCtrl.add(status);
  }

  void setBtName(String name) {
    _selectedBtName = name.trim();
    if ((_selectedBtName ?? '').isNotEmpty) {
      _lastBtDeviceName = _selectedBtName;
      // \u63a8\u9001\u4e00\u500b\u72c0\u614b\u4e8b\u4ef6\u8b93 UI \u7acb\u5373\u5237\u65b0\uff08\u7dad\u6301\u7576\u524d\u72c0\u614b\uff09
      if (!_btStatusCtrl.isClosed) {
        _btStatusCtrl.add(_lastBtStatus ?? StreamStatus.connecting);
      }
    }
  }
}
