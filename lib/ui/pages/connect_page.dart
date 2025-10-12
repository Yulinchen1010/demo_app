import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as classic;

import 'package:permission_handler/permission_handler.dart';

import '../../data/cloud_api.dart';

import '../../data/cloud_subscriber.dart';

import '../../data/app_bus.dart';

import '../../data/data_source.dart';

import '../../system/status_aggregator.dart';

import '../../data/streaming_service.dart';

import '../../design/tokens.dart';
import '../widgets/system_status_bar.dart';

enum BleState { idle, scanning, connecting, connected, error }

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

    if (CloudApi.baseUrl.isNotEmpty &&
        CloudApi.workerId.isNotEmpty &&
        !_cloudSub.isRunning) {
      _cloudSub.start();
    }

    _btSub = AppBus.instance.onBtStatus.listen((s) {
      _agg.set(
        btConnected: s == StreamStatus.connected,
        btConnecting:
            s == StreamStatus.connecting || s == StreamStatus.reconnecting,
      );

      if (mounted) setState(() {});
    });

    _cloudEventsSub = CloudApi.events.listen((e) {
      final now = DateTime.now();

      switch (e.op) {
        case 'health':
        case 'status':
          _agg.set(
            cloudConfigured:
                CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty,
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

  HealthLevel _asHealth(IndicatorColor color) {
    switch (color) {
      case IndicatorColor.green:
        return HealthLevel.ok;
      case IndicatorColor.yellow:
        return HealthLevel.warning;
      case IndicatorColor.red:
        return HealthLevel.error;
      case IndicatorColor.grey:
      default:
        return HealthLevel.warning;
    }
  }

  BleState _bleState(StreamStatus? status) {
    if (_agg.btScanning || _busyScan) return BleState.scanning;
    if (_agg.btConnecting) return BleState.connecting;
    if (_agg.btConnected) return BleState.connected;
    switch (status) {
      case StreamStatus.error:
      case StreamStatus.closed:
        return BleState.error;
      case StreamStatus.connecting:
      case StreamStatus.reconnecting:
        return BleState.connecting;
      case StreamStatus.connected:
        return BleState.connected;
      case StreamStatus.idle:
      case null:
        return BleState.idle;
    }
  }

  bool get _cloudActive =>
      _agg.cloudConfigured &&
      _agg.within(_agg.lastCloudPingOk, const Duration(seconds: 15));

  bool get _cloudError =>
      _agg.cloudConfigured &&
      _agg.within(_agg.lastCloudPingFail, const Duration(seconds: 10));

  bool get _uploadRecently =>
      _agg.within(_agg.lastPacketAt, const Duration(seconds: 4));

  bool get _uploadFailedRecently =>
      _agg.within(_agg.lastUploadErrorAt, const Duration(seconds: 6));

  String get _cloudStatusLabel {
    if (!_agg.cloudConfigured) return '\u672a\u8a2d\u5b9a';
    if (_agg.cloudPaused) return '\u5df2\u66ab\u505c';
    if (_cloudError) return '\u932f\u8aa4';
    if (_cloudActive) return '\u6d3b\u8e8d';
    return '\u5f85\u547c';
  }

  @override
  Widget build(BuildContext context) {
    final StreamStatus? status = AppBus.instance.lastBtStatus;
    final String? deviceName =
        AppBus.instance.lastBtDeviceName ?? AppBus.instance.selectedBtName;
    final BleState bleState = _bleState(status);

    return Scaffold(
      backgroundColor: const Color(0xFF0F141A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CloudBar(
                status: _cloudStatusLabel,
                onEdit: _openCloudDialog,
              ),
              const SizedBox(height: 12),
              _BleBar(
                state: bleState,
                deviceName: deviceName,
                busy: _busyScan || _agg.btScanning,
                onTap: _busyScan ? null : _openBtPicker,
              ),
              const SizedBox(height: 12),
              _SystemSummaryCard(
                bleState: bleState,
                mcuConnected: _agg.btConnected,
                uploadRecently: _uploadRecently,
                uploadFailed: _uploadFailedRecently,
                cloudActive: _cloudActive,
                cloudConfigured: _agg.cloudConfigured,
                cloudPaused: _agg.cloudPaused,
                cloudError: _cloudError,
                latencyText: '--',
                deviceName: deviceName ?? '\u2014',
              ),
              const SizedBox(height: 12),
              _FooterStatusBar(
                mcu: _asHealth(_agg.mcu),
                cloud: _asHealth(_agg.cloud),
                uplink: _asHealth(_agg.upload),
                showHint: bleState == BleState.error,
                hint: '\u9023\u7dda\u5931\u6557\uff0c\u8acb\u91cd\u8a66',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCloudDialog() async {
    final urlCtrl = TextEditingController(text: CloudApi.baseUrl);

    final workerCtrl = TextEditingController(
        text: CloudApi.workerId.isEmpty ? 'worker_1' : CloudApi.workerId);

    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('\u96f2\u7aef\u8a2d\u5b9a'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          '\u4f3a\u670d\u5668\u4f4d\u5740\uff08\u4f8b\uff1ahttps://api.example.com\uff09',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: workerCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          '\u4f7f\u7528\u8005\u7de8\u865f\uff08worker_id\uff09',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('\u53d6\u6d88'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        CloudApi.setBaseUrl(urlCtrl.text.trim());

                        CloudApi.setWorkerId(workerCtrl.text.trim());

                        _agg.set(
                          cloudConfigured: CloudApi.baseUrl.isNotEmpty &&
                              CloudApi.workerId.isNotEmpty,
                        );

                        if (CloudApi.baseUrl.isNotEmpty &&
                            CloudApi.workerId.isNotEmpty &&
                            !_cloudSub.isRunning) {
                          _cloudSub.start();
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('\u5df2\u5132\u5b58\u8a2d\u5b9a')),
                          );
                        }
                      },
                child: const Text('\u5132\u5b58'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);

                        try {
                          if (urlCtrl.text.trim().isNotEmpty)
                            CloudApi.setBaseUrl(urlCtrl.text.trim());

                          if (workerCtrl.text.trim().isNotEmpty)
                            CloudApi.setWorkerId(workerCtrl.text.trim());

                          _agg.set(
                            cloudConfigured: CloudApi.baseUrl.isNotEmpty &&
                                CloudApi.workerId.isNotEmpty,
                          );

                          await CloudApi.health();

                          if (!_cloudSub.isRunning) _cloudSub.start();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      '\u5065\u5eb7\u6aa2\u67e5\u6210\u529f')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '\u5065\u5eb7\u6aa2\u67e5\u5931\u6557: $e')),
                            );
                          }
                        } finally {
                          setState(() => busy = false);
                        }
                      },
                child: const Text('\u5065\u5eb7\u6aa2\u67e5'),
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

        return '\u7db2\u8def\u4e32\u6d41';

      case DataSource.bluetooth:

        return '\u85cd\u7259';

      case DataSource.demo:

        return '\u793a\u7bc4\u6a21\u5f0f';

    }

  } */

  Future<void> _openBtPicker() async {
    setState(() => _busyScan = true);

    StreamSubscription<classic.BluetoothDiscoveryResult>? discoverySub;

    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse
      ].request();

      final bt = classic.FlutterBluetoothSerial.instance;

      final bonded = await bt.getBondedDevices();

      final found = <String, classic.BluetoothDiscoveryResult>{};

      final discovery = bt.startDiscovery().asBroadcastStream();

      _agg.set(btScanning: true);

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          String? errorText;

          return StatefulBuilder(builder: (ctx, setState) {
            discoverySub ??= discovery.listen(
              (r) => setState(() => found[r.device.address] = r),
              onError: (err, __) {
                errorText = err.toString();

                setState(() {});

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('\u85cd\u7259\u6383\u63cf\u5931\u6557: $err')),
                  );
                }
              },
            );

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
                    Row(children: [
                      const Icon(Icons.bluetooth, size: 20),
                      const SizedBox(width: 8),
                      Text('\u9078\u64c7\u85cd\u7259\u88dd\u7f6e',
                          style: Theme.of(context).textTheme.titleMedium)
                    ]),
                    const SizedBox(height: 8),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    SizedBox(
                      height: 360,
                      child: ListView(children: [
                        if (bonded.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('\u5df2\u914d\u5c0d',
                                  style:
                                      Theme.of(context).textTheme.labelLarge)),
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
                        if (discovered.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('\u9644\u8fd1\u88dd\u7f6e',
                                  style:
                                      Theme.of(context).textTheme.labelLarge)),
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
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('\u95dc\u9589'))),
                  ],
                ),
              ),
            );
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u85cd\u7259\u9023\u7dda\u932f\u8aa4: $e')),
        );
      }
    } finally {
      _agg.set(btScanning: false);

      await discoverySub?.cancel();

      await classic.FlutterBluetoothSerial.instance
          .cancelDiscovery()
          .catchError((_) {});

      if (mounted) setState(() => _busyScan = false);
    }
  }
}

class _CloudBar extends StatelessWidget {
  const _CloudBar({required this.status, required this.onEdit});

  final String status;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '\u96f2\u7aef\u8a2d\u5b9a',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: const Text('\u7de8\u8f2f'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '\u96f2\u7aef\uff1a$status',
            style: const TextStyle(fontSize: 13, color: Color(0xFFAAB2BD)),
          ),
          const SizedBox(height: 6),
          const Text(
            '\u8a2d\u5b9a\u5b8c\u6210\u5f8c\u53ef\u555f\u7528\u96f2\u7aef\u4e0a\u50b3\u3002',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _BleBar extends StatelessWidget {
  const _BleBar({
    required this.state,
    required this.deviceName,
    required this.busy,
    required this.onTap,
  });

  final BleState state;
  final String? deviceName;
  final bool busy;
  final VoidCallback? onTap;

  bool get _showProgress =>
      state == BleState.connecting || state == BleState.scanning;
  bool get _showError => state == BleState.error;

  @override
  Widget build(BuildContext context) {
    final String statusLabel = switch (state) {
      BleState.connected => '\u85cd\u7259\u88dd\u7f6e \u00b7 \u5df2\u9023\u7dda',
      BleState.connecting => '\u85cd\u7259\u88dd\u7f6e \u00b7 \u9023\u7dda\u4e2d\u2026',
      BleState.scanning => '\u85cd\u7259\u88dd\u7f6e \u00b7 \u6383\u63cf\u4e2d\u2026',
      BleState.error => '\u85cd\u7259\u88dd\u7f6e \u00b7 \u9023\u7dda\u932f\u8aa4',
      BleState.idle => '\u85cd\u7259\u88dd\u7f6e \u00b7 \u672a\u9023\u7dda',
    };
    final bool scanning = state == BleState.scanning;
    final bool connecting = state == BleState.connecting;
    final bool hasError = state == BleState.error;
    final String buttonLabel = scanning
        ? '\u6383\u63cf\u4e2d...'
        : hasError
            ? '\u91cd\u65b0\u9023\u7dda'
            : '\u9023\u7dda\u88dd\u7f6e';
    final bool enableButton = !scanning && !connecting && onTap != null;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _showProgress || _showError ? (_showError ? 6 : 4) : 0,
            margin: EdgeInsets.only(bottom: _showProgress || _showError ? 10 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: _showProgress
                  ? const LinearGradient(
                      colors: [Color(0xFFFFA500), Color(0xFFFF7A59)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
              boxShadow: _showError
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.bluetooth, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: enableButton ? onTap : null,
                child: Text(buttonLabel),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (deviceName == null || deviceName!.trim().isEmpty)
                ? '\u672a\u9078\u64c7\u88dd\u7f6e'
                : deviceName!.trim(),
            style: const TextStyle(fontSize: 12, color: Color(0xFFAAB2BD)),
          ),
          const SizedBox(height: 6),
          Text(
            hasError
                ? '\u8acb\u6aa2\u67e5\u88dd\u7f6e\u96fb\u529b\u6216\u8a66\u8457\u91cd\u65b0\u914d\u5c0d\u3002'
                : '\u4e0a\u6b21\u9023\u7dda\u7684\u88dd\u7f6e\u5c07\u81ea\u52d5\u5617\u8a66\u91cd\u9023\u3002',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _SystemSummaryCard extends StatelessWidget {
  const _SystemSummaryCard({
    required this.bleState,
    required this.mcuConnected,
    required this.uploadRecently,
    required this.uploadFailed,
    required this.cloudActive,
    required this.cloudConfigured,
    required this.cloudPaused,
    required this.cloudError,
    required this.latencyText,
    required this.deviceName,
  });

  final BleState bleState;
  final bool mcuConnected;
  final bool uploadRecently;
  final bool uploadFailed;
  final bool cloudActive;
  final bool cloudConfigured;
  final bool cloudPaused;
  final bool cloudError;
  final String latencyText;
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final String mcuText = mcuConnected ? '\u5df2\u9023\u7dda' : '\u672a\u9023\u7dda';
    final String uploadText = uploadFailed
        ? '\u5931\u6557'
        : uploadRecently
            ? '\u9032\u884c\u4e2d'
            : '\u5f85\u547c';
    final String cloudText = !cloudConfigured
        ? '\u672a\u8a2d\u5b9a'
        : cloudPaused
            ? '\u5df2\u66ab\u505c'
            : cloudError
                ? '\u932f\u8aa4'
                : cloudActive
                    ? '\u6d3b\u8e8d'
                    : '\u5f85\u547c';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.memory, size: 16, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                '\u7cfb\u7d71\u6458\u8981',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SummaryEntry(label: 'MCU \u9023\u7dda', value: mcuText),
          _SummaryEntry(label: '\u4e0a\u50b3', value: uploadText),
          _SummaryEntry(label: '\u96f2\u7aef', value: cloudText),
          _SummaryEntry(label: '\u5ef6\u9072', value: latencyText),
          _SummaryEntry(label: '\u88dd\u7f6e', value: deviceName.isEmpty ? '\u2014' : deviceName),
        ],
      ),
    );
  }
}

class _SummaryEntry extends StatelessWidget {
  const _SummaryEntry({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStatusBar extends StatelessWidget {
  const _FooterStatusBar({
    required this.mcu,
    required this.cloud,
    required this.uplink,
    required this.showHint,
    required this.hint,
  });

  final HealthLevel mcu;
  final HealthLevel cloud;
  final HealthLevel uplink;
  final bool showHint;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              hint,
              style: const TextStyle(fontSize: 13, color: Color(0xFFAAB2BD)),
            ),
          ),
        _SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: SystemStatusBar(mcu: mcu, cloud: cloud, uplink: uplink),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1E252C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: child,
    );
  }
}
