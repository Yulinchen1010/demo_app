import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/streaming_service.dart';
import '../../data/bluetooth_streaming_service.dart';
import '../../data/mvc.dart';
import '../../data/cloud_subscriber.dart';
import '../../data/app_bus.dart';
import '../../data/data_source.dart';
import '../widgets/rula_badge.dart';
import '../widgets/mvc_badge.dart';
import '../widgets/realtime_emg_chart.dart';
import '../widgets/demo_emg_stream.dart';
import '../widgets/fatigue_light.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({super.key});

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

class _RealtimePageState extends State<RealtimePage> {
  final _cloudSub = CloudStatusSubscriber();
  Stream<EmgPoint>? _emg;
  StreamingService? _ws;
  BluetoothStreamingService? _bt;
  StreamSubscription<RulaScore>? _rulaSub;
  StreamSubscription<MvcPoint>? _mvcSub;
  StreamSubscription<StreamStatus>? _statusSub;
  StreamSubscription<DataSource>? _busSourceSub;
  StreamSubscription<void>? _busReconnectSub;
  RulaScore? _rula;
  DateTime? _lastTs;
  double? _mvcPct;
  DateTime? _mvcTs;
  StreamStatus _status = StreamStatus.idle;
  DataSource _source = DataSource.bluetooth;

  @override
  void initState() {
    super.initState();
    if (StreamingService.hasConfiguredUrl) {
      _source = DataSource.websocket;
      _useWebSocket();
    } else {
      _source = DataSource.bluetooth;
      _useBluetooth();
    }
    _busSourceSub = AppBus.instance.onSource.listen((s) => _switchSource(s));
    _busReconnectSub = AppBus.instance.onReconnect.listen((_) => _reconnect());
  }

  @override
  void dispose() {
    _rulaSub?.cancel();
    _mvcSub?.cancel();
    _statusSub?.cancel();
    _busSourceSub?.cancel();
    _busReconnectSub?.cancel();
    _ws?.dispose();
    _bt?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          RulaBadge(score: _rula, updatedAt: _lastTs),
          const SizedBox(height: 14),
          MvcBadge(percent: _mvcPct, updatedAt: _mvcTs),
          const SizedBox(height: 14),
          Text(_statusLabel2(_status), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 18),
          RealtimeEmgChart(
            stream: _emg ?? const Stream<EmgPoint>.empty(),
            initialWindow: TimeWindow.s30,
            title: 'EMG',
            height: 220,
            compact: true,
          ),
          const SizedBox(height: 48),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2A36),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text('疲勞警示'),
            ),
          ),
          const SizedBox(height: 28),
          Center(child: FatigueLight(subscriber: _cloudSub, size: 64)),
        ],
      ),
    );
  }

  String _statusLabel2(StreamStatus s) {
    switch (s) {
      case StreamStatus.idle:
        return '等待資料...';
      case StreamStatus.connecting:
        return '連線中...';
      case StreamStatus.connected:
        return '已連線';
      case StreamStatus.reconnecting:
        return '重新連線中...';
      case StreamStatus.error:
        return '錯誤 - 重試中';
      case StreamStatus.closed:
        return '已關閉';
    }
  }

  Future<void> _switchSource(DataSource next) async {
    setState(() {
      _status = StreamStatus.connecting;
      _rula = null;
      _lastTs = null;
      _source = next;
    });
    await _ws?.dispose();
    await _bt?.stop();
    _rulaSub?.cancel();
    _statusSub?.cancel();

    switch (next) {
      case DataSource.websocket:
        _useWebSocket();
        break;
      case DataSource.bluetooth:
        _useBluetooth();
        break;
      case DataSource.demo:
        _useDemo();
        break;
    }
  }

  void _useWebSocket() {
    _ws = StreamingService();
    _emg = _ws!.emg;
    _rulaSub = _ws!.rula.listen((s) => setState(() {
          _rula = s;
          _lastTs = DateTime.now();
        }));
    _mvcSub = _ws!.mvc.listen((m) => setState(() {
          _mvcPct = m.percent;
          _mvcTs = m.ts;
        }));
    _statusSub = _ws!.status.listen((st) => setState(() => _status = st));
    _ws!.start();
  }

  void _useBluetooth() {
    final name = AppBus.instance.selectedBtName;
    _bt = BluetoothStreamingService(deviceName: (name == null || name.isEmpty) ? 'ESP32_EMG_IMU' : name);
    _emg = _bt!.emg;
    _statusSub = _bt!.status.listen((st) => setState(() {
          _status = st;
          AppBus.instance.setBtStatus(st, deviceName: _bt?.deviceName);
        }));
    _rulaSub = _bt!.rula.listen((s) => setState(() {
          _rula = s;
          _lastTs = DateTime.now();
        }));
    _mvcSub = _bt!.mvc.listen((m) => setState(() {
          _mvcPct = m.percent;
          _mvcTs = m.ts;
        }));
    _bt!.start();
  }

  void _useDemo() {
    _emg = demoEmgStream();
    setState(() => _status = StreamStatus.idle);
  }

  Future<void> _reconnect() async {
    switch (_source) {
      case DataSource.websocket:
        await _ws?.dispose();
        _useWebSocket();
        break;
      case DataSource.bluetooth:
        await _bt?.stop();
        _useBluetooth();
        break;
      case DataSource.demo:
        _useDemo();
        break;
    }
  }
}
