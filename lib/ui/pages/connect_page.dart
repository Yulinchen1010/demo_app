import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';

import '../../data/cloud_api.dart';
import '../../data/cloud_subscriber.dart';
import '../../data/app_bus.dart';
import '../../data/data_source.dart';
import '../widgets/cloud_status_banner.dart';
import '../widgets/bluetooth_status_banner.dart';
import '../../system/status_aggregator.dart';
import '../../widgets/breath_indicator.dart';
import '../../data/streaming_service.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _cloudSub = CloudStatusSubscriber();
  bool _busyScan = false;
  final _agg = SystemStatusAggregator();
  Timer? _tick;
  StreamSubscription<StreamStatus>? _btSub;
  StreamSubscription<CloudEvent>? _cloudEventsSub;

  @override
  void initState() {
    super.initState();
    if (CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty && !_cloudSub.isRunning) {
      _cloudSub.start();
    }
    _btSub = AppBus.instance.onBtStatus.listen((s) {
      _agg.set(
        btConnected: s == StreamStatus.connected,
        btConnecting: s == StreamStatus.connecting || s == StreamStatus.reconnecting,
      );
      if (mounted) setState(() {});
    });
    _cloudEventsSub = CloudApi.events.listen((e) {
      final now = DateTime.now();
      switch (e.op) {
        case 'health':
        case 'status':
          _agg.set(
            cloudConfigured: CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty,
            lastCloudPingOk: e.ok ? now : null,
            lastCloudPingFail: e.ok ? null : now,
          );
          break;
        case 'upload':
        case 'upload_rula':
        case 'upload_batch':
          _agg.set(
            lastUploadOkAt: e.ok ? now : null,
            lastUploadErrorAt: e.ok ? null : now,
          );
          break;
        default:
          break;
      }
      if (mounted) setState(() {});
    });
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _btSub?.cancel();
    _cloudEventsSub?.cancel();
    _cloudSub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _openCloudDialog,
                  icon: const Icon(Icons.cloud),
                  label: const Text('雲端設定'),
                ),
                const SizedBox(width: 8),
                const Expanded(child: CloudStatusBanner()),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busyScan ? null : _openBtPicker,
                  icon: const Icon(Icons.bluetooth),
                  label: Text(_busyScan ? '掃描中...' : '藍牙連線'),
                ),
                const SizedBox(width: 8),
                const Expanded(child: BluetoothStatusBanner()),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BreathIndicator(color: _agg.mcu, label: 'MCU 連線'),
                  BreathIndicator(color: _agg.cloud, label: '雲端狀態'),
                  BreathIndicator(color: _agg.upload, label: '上傳狀態'),
                ],
              ),
            ),
          ],
        ),
      ),
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
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        CloudApi.setBaseUrl(urlCtrl.text.trim());
                        CloudApi.setWorkerId(workerCtrl.text.trim());
                        _agg.set(
                          cloudConfigured: CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty,
                        );
                        if (CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty && !_cloudSub.isRunning) {
                          _cloudSub.start();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已儲存設定')),
                          );
                        }
                      },
                child: const Text('儲存'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          if (urlCtrl.text.trim().isNotEmpty) CloudApi.setBaseUrl(urlCtrl.text.trim());
                          if (workerCtrl.text.trim().isNotEmpty) CloudApi.setWorkerId(workerCtrl.text.trim());
                          _agg.set(
                            cloudConfigured: CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty,
                          );
                          await CloudApi.health();
                          if (!_cloudSub.isRunning) _cloudSub.start();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('健康檢查成功')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('健康檢查失敗: $e')),
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

  /* unused: String _labelFor(DataSource s) {
    switch (s) {
      case DataSource.websocket:
        return '網路串流';
      case DataSource.bluetooth:
        return '藍牙';
      case DataSource.demo:
        return '示範模式';
    }
  } */

  Future<void> _openBtPicker() async {
    setState(() => _busyScan = true);
    try {
      await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
      final bt = classic.FlutterBluetoothSerial.instance;
      final bonded = await bt.getBondedDevices();
      final found = <String, classic.BluetoothDiscoveryResult>{};
      final discovery = bt.startDiscovery();
      _agg.set(btScanning: true);

      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setState) {
            discovery.listen((r) => setState(() => found[r.device.address] = r));
            final discovered = found.values
                .map((e) => e.device)
                .where((d) => (d.name ?? '').isNotEmpty)
                .toList();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [const Icon(Icons.bluetooth, size: 20), const SizedBox(width: 8), Text('選擇藍牙裝置', style: Theme.of(context).textTheme.titleMedium)]),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 360,
                      child: ListView(children: [
                        if (bonded.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('已配對', style: Theme.of(context).textTheme.labelLarge)),
                        ...bonded.map((d) => ListTile(
                              leading: const Icon(Icons.devices_other),
                              title: Text(d.name ?? d.address),
                              subtitle: Text(d.address),
                              onTap: () {
                                AppBus.instance.setBtName(d.name ?? d.address);
                                _agg.set(btConnecting: true, btScanning: false);
                                AppBus.instance.setSource(DataSource.bluetooth);
                                AppBus.instance.reconnect();
                                Navigator.of(ctx).pop();
                              },
                            )),
                        if (discovered.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('附近裝置', style: Theme.of(context).textTheme.labelLarge)),
                        ...discovered.map((d) => ListTile(
                              leading: const Icon(Icons.bluetooth_searching),
                              title: Text(d.name ?? d.address),
                              subtitle: Text(d.address),
                              onTap: () {
                                AppBus.instance.setBtName(d.name ?? d.address);
                                _agg.set(btConnecting: true, btScanning: false);
                                AppBus.instance.setSource(DataSource.bluetooth);
                                AppBus.instance.reconnect();
                                Navigator.of(ctx).pop();
                              },
                            )),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('關閉'))),
                  ],
                ),
              ),
            );
          });
        },
      );
    } finally {
      _agg.set(btScanning: false);
      if (mounted) setState(() => _busyScan = false);
    }
  }
}
