import 'package:flutter/material.dart';
import 'dart:async';

import 'widgets/realtime_emg_chart.dart';
import 'widgets/rula_badge.dart';
import 'widgets/demo_emg_stream.dart';
import 'widgets/cloud_status_banner.dart';
import '../data/models.dart';
import '../data/streaming_service.dart';
import '../data/bluetooth_streaming_service.dart';
import '../data/cloud_api.dart';
import '../data/cloud_subscriber.dart';
import 'widgets/fatigue_light.dart';
// 蝘駁?函??脩垢???寧敶閮剖?閬?

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
  final _cloudSub = CloudStatusSubscriber();

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

        title: const Text('疲勞樹'),

        actions: [
          IconButton(
            onPressed: _openCloudDialog,
            icon: const Icon(Icons.cloud),
            tooltip: '重新連線',
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

                    DropdownMenuItem(value: DataSource.websocket, child: Text('網路串流')))),
                    DropdownMenuItem(value: DataSource.bluetooth, child: Text('藍牙')))),

                    DropdownMenuItem(value: DataSource.demo, child: Text('示範')))),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: '重新連線',
                  onPressed: _reconnect,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const CloudStatusBanner(),
            const SizedBox(height: 8),
            FatigueLight(subscriber: _cloudSub),
            const SizedBox(height: 12),
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

                  title: '肌電強度（即時）'),
          ],
        ),
      ),
    );
  }

  Future<void> _openCloudDialog() async {
    final urlCtrl = TextEditingController(text: CloudApi.baseUrl);
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('疲勞樹'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: '隡箸??其??嚗?嚗ttps://api.example.com嚗?,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('??'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        CloudApi.setBaseUrl(urlCtrl.text);
                        if (CloudApi.workerId.isEmpty) { CloudApi.setWorkerId('worker_1'); }
                        if (!_cloudSub.isRunning) { _cloudSub.start(); }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('撌脣摮撩?雿?')),
                        );
                      },
                child: const Text('?脣?'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          if (urlCtrl.text.trim().isNotEmpty) {
                            CloudApi.setBaseUrl(urlCtrl.text.trim());
                          }
                          await CloudApi.health();
                          if (!_cloudSub.isRunning) { _cloudSub.start(); }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('?亙熒瑼Ｘ??')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('?亙熒瑼Ｘ憭望?嚗?e')),
                            );
                          }
                        } finally {
                          setState(() => busy = false);
                        }
                      },
                child: const Text('?亙熒瑼Ｘ'),
              ),
            ],
          );
        });
      },
    );
  }

  
  String _statusLabel2(StreamStatus s) {
    switch (s) {
      case StreamStatus.idle:
        return '蝑?鞈?...';
      case StreamStatus.connecting:
        return '???銝?..';
      case StreamStatus.connected:
        return '撌脤??';
      case StreamStatus.reconnecting:
        return '????銝?..';
      case StreamStatus.error:
        return '?航炊 - ?岫銝?;
      case StreamStatus.closed:
        return '撌脤???;
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







