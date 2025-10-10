import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/streaming_service.dart';
import '../../data/bluetooth_streaming_service.dart';
import '../../data/cloud_api.dart';
import '../../data/cloud_subscriber.dart';
import '../widgets/fatigue_light.dart';
import '../widgets/cloud_status_banner.dart';
import '../widgets/rula_badge.dart';
import '../widgets/realtime_emg_chart.dart';
import '../widgets/demo_emg_stream.dart';

class RealtimePage extends StatefulWidget {
  const RealtimePage({super.key});

  @override
  State<RealtimePage> createState() => _RealtimePageState();
}

enum DataSource { websocket, bluetooth, demo }

class _RealtimePageState extends State<RealtimePage> {
  final _cloudSub = CloudStatusSubscriber();
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top: 雲端狀態 + 雲端設定按鈕
          Row(
            children: [
              const Expanded(child: CloudStatusBanner()),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _openCloudDialog,
                icon: const Icon(Icons.cloud),
                label: const Text('雲端設定'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RulaBadge(score: _rula, updatedAt: _lastTs),
          const SizedBox(height: 6),
          Text(_statusLabel2(_status), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          _sourceSelector(),
          const SizedBox(height: 16),
          Text('即時 30 秒', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Expanded(
            child: RealtimeEmgChart(
              stream: _emg ?? const Stream<EmgPoint>.empty(),
              initialWindow: TimeWindow.s30,
              title: '肌電強度（即時）',
            ),
          ),
          const SizedBox(height: 12),
          Text('疲勞警示', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Center(child: FatigueLight(subscriber: _cloudSub, size: 48)),
        ],
      ),
    );
  }

  Widget _sourceSelector() {
    return Row(
      children: [
        DropdownButton<DataSource>(
          value: _source,
          onChanged: (v) {
            if (v == null) return;
            _switchSource(v);
          },
          items: const [
            DropdownMenuItem(value: DataSource.websocket, child: Text('網路串流')),
            DropdownMenuItem(value: DataSource.bluetooth, child: Text('藍牙')),
            DropdownMenuItem(value: DataSource.demo, child: Text('示範')),
          ],
        ),
        const Spacer(),
        IconButton(
          tooltip: '重新連線',
          onPressed: _reconnect,
          icon: const Icon(Icons.sync),
        ),
      ],
    );
  }

  Future<void> _openCloudDialog() async {
    final urlCtrl = TextEditingController(text: CloudApi.baseUrl);
    final workerCtrl = TextEditingController(text: CloudApi.workerId.isEmpty ? 'worker_1' : CloudApi.workerId);
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('雲端設定'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: '伺服器位址（例：https://api.example.com）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: workerCtrl,
                    decoration: const InputDecoration(
                      labelText: '使用者編號（worker_id）',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('關閉'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        CloudApi.setBaseUrl(urlCtrl.text.trim());
                        CloudApi.setWorkerId(workerCtrl.text.trim());
                        if (CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty && !_cloudSub.isRunning) {
                          _cloudSub.start();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已儲存設定')),
                        );
                      },
                child: const Text('儲存'),
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
                          if (workerCtrl.text.trim().isNotEmpty) {
                            CloudApi.setWorkerId(workerCtrl.text.trim());
                          }
                          await CloudApi.health();
                          if (!mounted) return;
                          if (!_cloudSub.isRunning) {
                            _cloudSub.start();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('健康檢查成功')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('健康檢查失敗：$e')),
                            );
                          }
                        } finally {
                          setState(() => busy = false);
                        }
                      },
                child: const Text('健康檢查'),
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

