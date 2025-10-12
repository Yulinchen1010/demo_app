import 'dart:async';



import 'package:flutter/material.dart';



import 'widgets/realtime_emg_chart.dart';

import 'widgets/rula_badge.dart';

import 'widgets/demo_emg_stream.dart';

import 'widgets/cloud_status_banner.dart';

import 'widgets/fatigue_light.dart';

import '../data/models.dart';

import '../data/streaming_service.dart';

import '../data/bluetooth_streaming_service.dart';

import '../data/cloud_api.dart';

import '../data/cloud_subscriber.dart';

import '../system/status_aggregator.dart';

import '../widgets/breath_indicator.dart';



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

  StreamSubscription<EmgPoint>? _emgSub;

  StreamSubscription<CloudEvent>? _cloudSubEvents;

  RulaScore? _rula;

  DateTime? _lastTs;

  StreamStatus _status = StreamStatus.idle;

  DataSource _source = DataSource.bluetooth;

  final _cloudSub = CloudStatusSubscriber();



  // Status aggregation

  final _agg = SystemStatusAggregator();

  Timer? _tick;



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



    // Cloud API event wiring for pings and uploads

    _cloudSubEvents = CloudApi.events.listen((e) {

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

    });



    // Periodic UI tick to keep breathing and timing fresh

    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {

      if (!mounted) return;

      setState(() {});

    });

  }



  @override

  void dispose() {

    _rulaSub?.cancel();

    _statusSub?.cancel();

    _emgSub?.cancel();

    _cloudSubEvents?.cancel();

    _tick?.cancel();

    _ws?.dispose();

    _bt?.stop();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text('\u75b2\u52de\u6a39'),

        actions: [

          IconButton(

            onPressed: _openCloudDialog,

            icon: const Icon(Icons.cloud),

            tooltip: '\u96f2\u7aef\u8a2d\u5b9a',

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

                        value: DataSource.websocket, child: Text('\u7db2\u8def\u4e32\u6d41')),

                    DropdownMenuItem(

                        value: DataSource.bluetooth, child: Text('\u85cd\u7259')),

                    DropdownMenuItem(value: DataSource.demo, child: Text('\u793a\u7bc4')),

                  ],

                ),

                const Spacer(),

                IconButton(

                  tooltip: '\u91cd\u65b0\u9023\u7dda',

                  onPressed: _reconnect,

                  icon: const Icon(Icons.sync),

                ),

              ],

            ),

            // \u8b93\u75b2\u52de\u71c8\u865f\u6210\u70ba\u4e3b\u8996\u89ba\uff1a\u5148\u986f\u793a\u71c8\u865f\uff0c\u518d\u986f\u793a\u96f2\u7aef\u72c0\u614b

            FatigueLight(subscriber: _cloudSub),

            const SizedBox(height: 8),

            const CloudStatusBanner(),

          const SizedBox(height: 12),

          // Aggregated system indicators

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

            decoration: BoxDecoration(

              color: const Color(0xFF0B1220), // \u4e0d\u900f\u660e\u6df1\u5e95\uff0c\u907f\u514d\u8272\u504f

              borderRadius: BorderRadius.circular(14),

              border: Border.all(color: Colors.white.withOpacity(.08)),

            ),

            child: Row(

              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [

                BreathIndicator(color: _agg.mcu, label: 'MCU \u9023\u7dda'),

                BreathIndicator(color: _agg.cloud, label: '\u96f2\u7aef\u72c0\u614b'),

                BreathIndicator(color: _agg.upload, label: '\u4e0a\u50b3\u72c0\u614b'),

              ],

            ),

          ),

          const SizedBox(height: 6),

          Builder(builder: (context) {

            // Debug line (kDebugMode-like behavior without import); always show lightly here

            final now = DateTime.now();

            String fmtAgo(DateTime? t) {

              if (t == null) return '-';

              return '${now.difference(t).inSeconds}s';

            }

            final btConnected = _status == StreamStatus.connected;

            final btConnecting = _status == StreamStatus.connecting || _status == StreamStatus.reconnecting;

            final btScanning = false;

            final cloudConfigured = CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty;

            final cloudPaused = false;

            return Text(

              'BT: connected=' + btConnected.toString() + ' connecting=' + btConnecting.toString() + ' scanning=' + btScanning.toString() +

              ' | Cloud: cfg=' + cloudConfigured.toString() + ' paused=' + cloudPaused.toString() +

              ' lastOk=' + fmtAgo(_agg.lastCloudPingOk) +

              ' | Upload: lastOk=' + fmtAgo(_agg.lastUploadOkAt) +

              ' lastPkt=' + fmtAgo(_agg.lastPacketAt) +

              ' lastErr=' + fmtAgo(_agg.lastUploadErrorAt),

              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),

            );

          }),

          const SizedBox(height: 12),

          RulaBadge(score: _rula, updatedAt: _lastTs),

          const SizedBox(height: 6),

          Text(

            _statusLabel2(_status),

            style: Theme.of(context).textTheme.labelSmall,

            ),

            const SizedBox(height: 16),

            Text('\u5373\u6642 30 \u79d2', style: Theme.of(context).textTheme.labelSmall),

            const SizedBox(height: 6),

            Expanded(

              child: RealtimeEmgChart(

                stream: _emg ?? const Stream<EmgPoint>.empty(),

                initialWindow: TimeWindow.s30,

                title: '\u808c\u96fb\u5f37\u5ea6\uff08\u5373\u6642\uff09',

              ),

            ),

          ],

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

                      labelText: '\u4f3a\u670d\u5668\u4f4d\u5740\uff08\u4f8b\uff1ahttps://api.example.com\uff09',

                    ),

                  ),

                  const SizedBox(height: 8),

                  TextField(

                    controller: workerCtrl,

                    decoration: const InputDecoration(

                      labelText: '\u4f7f\u7528\u8005\u7de8\u865f\uff08worker_id\uff09',

                    ),

                  ),

                ],

              ),

            ),

            actions: [

              TextButton(

                onPressed: busy ? null : () => Navigator.of(ctx).pop(),

                child: const Text('\u95dc\u9589'),

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

                        if (CloudApi.baseUrl.isNotEmpty &&

                            CloudApi.workerId.isNotEmpty &&

                            !_cloudSub.isRunning) {

                          _cloudSub.start();

                        }

                        ScaffoldMessenger.of(context).showSnackBar(

                          const SnackBar(content: Text('\u5df2\u5132\u5b58\u8a2d\u5b9a')),

                        );

                      },

                child: const Text('\u5132\u5b58'),

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

                          _agg.set(

                            cloudConfigured: CloudApi.baseUrl.isNotEmpty && CloudApi.workerId.isNotEmpty,

                          );

                          await CloudApi.health();

                          if (!_cloudSub.isRunning) {

                            _cloudSub.start();

                          }

                          if (context.mounted) {

                            ScaffoldMessenger.of(context).showSnackBar(

                              const SnackBar(content: Text('\u5065\u5eb7\u6aa2\u67e5\u6210\u529f')),

                            );

                          }

                        } catch (e) {

                          if (context.mounted) {

                            ScaffoldMessenger.of(context).showSnackBar(

                              SnackBar(content: Text('\u5065\u5eb7\u6aa2\u67e5\u5931\u6557\uff1a$e')),

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



  String _statusLabel2(StreamStatus s) {

    switch (s) {

      case StreamStatus.idle:

        return '\u7b49\u5f85\u8cc7\u6599...';

      case StreamStatus.connecting:

        return '\u9023\u7dda\u4e2d...';

      case StreamStatus.connected:

        return '\u5df2\u9023\u7dda';

      case StreamStatus.reconnecting:

        return '\u91cd\u65b0\u9023\u7dda\u4e2d...';

      case StreamStatus.error:

        return '\u932f\u8aa4 - \u91cd\u8a66\u4e2d';

      case StreamStatus.closed:

        return '\u5df2\u95dc\u9589';

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

    _emgSub?.cancel();

    _emgSub = _emg!.listen((e) => _agg.set(lastPacketAt: DateTime.now()));

    _rulaSub = _ws!.rula.listen((s) => setState(() {

          _rula = s;

          _lastTs = DateTime.now();

        }));

    _statusSub = _ws!.status.listen((st) {

      setState(() => _status = st);

      _agg.set(

        btConnected: st == StreamStatus.connected,

        btConnecting: st == StreamStatus.connecting || st == StreamStatus.reconnecting,

        btScanning: false,

      );

    });

    _ws!.start();

  }



  void _useBluetooth() {

    _bt = BluetoothStreamingService();

    _emg = _bt!.emg;

    _emgSub?.cancel();

    _emgSub = _emg!.listen((e) => _agg.set(lastPacketAt: DateTime.now()));

    _statusSub = _bt!.status.listen((st) {

      setState(() => _status = st);

      _agg.set(

        btConnected: st == StreamStatus.connected,

        btConnecting: st == StreamStatus.connecting || st == StreamStatus.reconnecting,

        btScanning: false,

      );

    });

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

