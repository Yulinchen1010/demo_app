import 'package:flutter/material.dart';
import 'dart:async';

import 'widgets/realtime_emg_chart.dart';
import 'widgets/rula_badge.dart';
import 'widgets/demo_emg_stream.dart';
import '../data/models.dart';
import '../data/streaming_service.dart';
import '../data/bluetooth_streaming_service.dart';
import 'cloud_page.dart';

/// Minimal Home view per spec: RULA badge + realtime EMG chart.
class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

enum DataSource { websocket, bluetooth, demo }

class _HomeScaffoldState extends State<HomeScaffold> {
  Stream<EmgPoint>? _emg;
  StreamingService? _ws;
  BluetoothStreamingService? _bt;
  StreamSubscription<RulaScore>? _rulaSub;
  StreamSubscription<StreamStatus>? _statusSub;
  RulaScore? _rula;
  DateTime? _lastTs;
  StreamStatus _status = StreamStatus.idle;
  DataSource _source = DataSource.bluetooth;

  @override
  void initState() {
    super.initState();
    // Default: prefer WebSocket if STREAM_URL defined; else Bluetooth.
    if (StreamingService.hasConfiguredUrl) {
      _source = DataSource.websocket;
      _useWebSocket();
    } else {
      _source = DataSource.bluetooth;
      _useBluetooth();
    }
  }

  @override
  void dispose() {
    _rulaSub?.cancel();
    _statusSub?.cancel();
    _ws?.dispose();
    _bt?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fatigue Tree'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CloudPage()),
              );
            },
            icon: const Icon(Icons.cloud),
            tooltip: 'Cloud API',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<DataSource>(
                  value: _source,
                  onChanged: (v) {
                    if (v == null) return;
                    _switchSource(v);
                  },
                  items: const [
                    DropdownMenuItem(
                        value: DataSource.websocket, child: Text('WebSocket')),
                    DropdownMenuItem(
                        value: DataSource.bluetooth, child: Text('Bluetooth')),
                    DropdownMenuItem(value: DataSource.demo, child: Text('Demo')),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Reconnect',
                  onPressed: _reconnect,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            RulaBadge(score: _rula, updatedAt: _lastTs),
            const SizedBox(height: 6),
            Text(
              _statusLabel2(_status),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RealtimeEmgChart(
                  stream: _emg ?? Stream<EmgPoint>.empty(),
                  initialWindow: TimeWindow.s60,
                  title: 'EMG RMS (live)'),
            ),
          ],
        ),
      ),
    );
  }

  
  String _statusLabel2(StreamStatus s) {
    switch (s) {
      case StreamStatus.idle:
        return 'Waiting for data...';
      case StreamStatus.connecting:
        return 'Connecting...';
      case StreamStatus.connected:
        return 'Connected';
      case StreamStatus.reconnecting:
        return 'Reconnecting...';
      case StreamStatus.error:
        return 'Error - retrying';
      case StreamStatus.closed:
        return 'Closed';
    }
  }

  Future<void> _switchSource(DataSource next) async {
    setState(() {
      _status = StreamStatus.connecting;
      _rula = null;
      _lastTs = null;
      _source = next;
    });
    // Tear down
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
    _statusSub = _ws!.status.listen((st) => setState(() => _status = st));
    _ws!.start();
  }

  void _useBluetooth() {
    _bt = BluetoothStreamingService();
    _emg = _bt!.emg;
    _statusSub = _bt!.status.listen((st) => setState(() => _status = st));
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



