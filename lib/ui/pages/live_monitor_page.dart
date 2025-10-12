import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_bus.dart';
import '../../data/ble_connection_service.dart';
import '../../data/bluetooth_streaming_service.dart';
import '../../data/data_source.dart';
import '../../data/models.dart';
import '../../data/mvc.dart';
import '../../data/streaming_service.dart';
import '../../data/telemetry_service.dart';
import '../../domain/risk_level.dart';
import '../../nav/bottom_nav_controller.dart';
import '../widgets/demo_emg_stream.dart';
import '../widgets/fatigue_beacon.dart';
import '../widgets/info_sheets.dart';
import '../widgets/realtime_emg_chart.dart';
import 'fatigue_detail_page.dart';

class LiveMonitorPage extends StatefulWidget {
  const LiveMonitorPage({super.key});

  @override
  State<LiveMonitorPage> createState() => _LiveMonitorPageState();
}

class _LiveMonitorPageState extends State<LiveMonitorPage> {
  Stream<EmgPoint>? _emg;
  StreamingService? _ws;
  BluetoothStreamingService? _bt;
  StreamSubscription<RulaScore>? _rulaSub;
  StreamSubscription<MvcPoint>? _mvcSub;
  StreamSubscription<EmgPoint>? _emgSub;
  StreamSubscription<StreamStatus>? _statusSub;
  StreamSubscription<DataSource>? _busSourceSub;
  StreamSubscription<void>? _busReconnectSub;

  double? _rulaScore;
  double? _mvcPercent;
  DateTime? _lastSampleAt;
  DataSource _source = DataSource.bluetooth;

  RiskLevel _riskLevel = RiskLevel.low;
  DateTime? _criticalStart;
  Duration _overThreshold = Duration.zero;

  static const Duration _criticalHold = Duration(seconds: 5);
  late final TelemetryService _telemetry;

  @override
  void initState() {
    super.initState();
    _telemetry = Provider.of<TelemetryService>(context, listen: false);
    if (StreamingService.hasConfiguredUrl) {
      _source = DataSource.websocket;
      _useWebSocket();
    } else {
      _source = DataSource.bluetooth;
      _useBluetooth();
    }
    _busSourceSub = AppBus.instance.onSource.listen(_switchSource);
    _busReconnectSub = AppBus.instance.onReconnect.listen((_) => _reconnect());
  }

  @override
  void dispose() {
    _rulaSub?.cancel();
    _mvcSub?.cancel();
    _emgSub?.cancel();
    _statusSub?.cancel();
    _busSourceSub?.cancel();
    _busReconnectSub?.cancel();
    _ws?.dispose();
    _bt?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double? rula = _rulaScore;
    final double? mvc = _mvcPercent;
    final bool isConnected =
        context.watch<BleConnectionService>().isConnected;
    final bool hasData =
        context.select<TelemetryService, bool>((t) => t.hasFreshData);
    final Size size = MediaQuery.of(context).size;
    final double computedHeight = size.height * 0.38;
    final double chartHeight = computedHeight < 200
        ? 200
        : (computedHeight > 320 ? 320 : computedHeight);

    return Scaffold(
      backgroundColor: const Color(0xFF0F141A),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            FatigueBeaconSection(
              level: hasData ? _riskLevel : null,
              hasData: hasData,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FatigueDetailPage()),
              ),
              onExplainTap: () => showFatigueBeaconHelp(context),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetricInfoCard(
                    icon: Icons.accessibility_new,
                    title: 'RULA',
                    value: _formatRula(rula),
                    subtitle: _formatTimestamp(_lastSampleAt),
                    onInfo: () => showRulaInfo(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricInfoCard(
                    icon: Icons.monitor_heart,
                    title: '%MVC',
                    value: _formatMvc(mvc),
                    subtitle: _formatTimestamp(_mvcPoint?.ts),
                    onInfo: () => showMvcInfo(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ChartCard(
              child: SizedBox(
                height: chartHeight,
                child: RealtimeEmgChart(
                  stream: _emg ?? const Stream<EmgPoint>.empty(),
                  initialWindow: TimeWindow.s30,
                  title: 'EMG',
                  height: chartHeight,
                  compact: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!isConnected) const GoConnectBanner(),
          ],
        ),
      ),
    );
  }

  MvcPoint? _mvcPoint;

  void _handleRula(RulaScore score) {
    final DateTime now = DateTime.now();
    setState(() {
      _rulaScore = score.score.toDouble();
      _lastSampleAt = now;
      _updateRisk(now);
    });
  }

  void _handleMvc(MvcPoint point) {
    final DateTime now = DateTime.now();
    setState(() {
      _mvcPoint = point;
      _mvcPercent = point.percent;
      _lastSampleAt = now;
      _updateRisk(now);
    });
  }

  void _updateRisk(DateTime timestamp) {
    final double rulaValue = _rulaScore ?? double.nan;
    final double mvcValue = _mvcPercent ?? double.nan;
    final bool meetsCritical = (!rulaValue.isNaN && rulaValue >= 7) ||
        (!mvcValue.isNaN && mvcValue >= 70);
    if (meetsCritical) {
      _criticalStart ??= timestamp;
    } else {
      _criticalStart = null;
    }
    _overThreshold = _criticalStart == null
        ? Duration.zero
        : timestamp.difference(_criticalStart!);
    _riskLevel = computeRisk(
      rula: rulaValue,
      mvc: mvcValue,
      hold: _criticalHold,
      nowOverHold: _overThreshold,
    );
  }

  Future<void> _switchSource(DataSource next) async {
    setState(() {
      _source = next;
      _criticalStart = null;
      _overThreshold = Duration.zero;
      _rulaScore = null;
      _mvcPercent = null;
      _mvcPoint = null;
      _lastSampleAt = null;
      _riskLevel = RiskLevel.low;
    });
    await _ws?.dispose();
    await _bt?.stop();
    _emgSub?.cancel();
    _emgSub = null;
    _rulaSub?.cancel();
    _mvcSub?.cancel();
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
    _emgSub = _ws!.emg.listen((point) {
      _telemetry.onSampleArrived();
      if (mounted) {
        setState(() {
          _lastSampleAt = point.ts;
        });
      } else {
        _lastSampleAt = point.ts;
      }
    });
    _rulaSub = _ws!.rula.listen(_handleRula);
    _mvcSub = _ws!.mvc.listen(_handleMvc);
    _statusSub = _ws!.status.listen((_) {});
    _ws!.start();
  }

  void _useBluetooth() {
    final String? name = AppBus.instance.selectedBtName;
    _bt = BluetoothStreamingService(
        deviceName: (name == null || name.isEmpty) ? 'ESP32_EMG_IMU' : name);
    _emg = _bt!.emg;
    _emgSub?.cancel();
    _emgSub = _bt!.emg.listen((point) {
      _telemetry.onSampleArrived();
      if (mounted) {
        setState(() {
          _lastSampleAt = point.ts;
        });
      } else {
        _lastSampleAt = point.ts;
      }
    });
    _statusSub = _bt!.status.listen(
      (st) => AppBus.instance.setBtStatus(st, deviceName: _bt?.deviceName),
    );
    _rulaSub = _bt!.rula.listen(_handleRula);
    _mvcSub = _bt!.mvc.listen(_handleMvc);
    _bt!.start();
  }

  void _useDemo() {
    setState(() {
      _emg = demoEmgStream();
      _rulaScore = null;
      _mvcPercent = null;
      _mvcPoint = null;
      _criticalStart = null;
      _overThreshold = Duration.zero;
      _lastSampleAt = null;
      _riskLevel = RiskLevel.low;
    });
    _emgSub?.cancel();
    _emgSub = _emg!.listen((point) {
      _telemetry.onSampleArrived();
      if (mounted) {
        setState(() {
          _lastSampleAt = point.ts;
        });
      } else {
        _lastSampleAt = point.ts;
      }
    });
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

  String _formatRula(double? value) {
    if (value == null || value.isNaN) return '--';
    return value.toStringAsFixed(1);
  }

  String _formatMvc(double? value) {
    if (value == null || value.isNaN) return '--';
    return '${value.toStringAsFixed(0)}%';
  }

  String _formatTimestamp(DateTime? ts) {
    if (ts == null) return '\u672a\u63a5\u6536\u8cc7\u6599';
    final Duration diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 1) return '\u525b\u525b\u66f4\u65b0';
    if (diff.inSeconds < 60) {
      return '\u66f4\u65b0 ${diff.inSeconds}\u79d2\u524d';
    }
    if (diff.inMinutes < 60) {
      return '\u66f4\u65b0 ${diff.inMinutes}\u5206\u524d';
    }
    return '\u66f4\u65b0 ${diff.inHours}\u5c0f\u6642\u524d';
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111A23),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33111C2E),
                blurRadius: 30,
                offset: Offset(0, 24)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: child,
      ),
    );
  }
}

class GoConnectBanner extends StatelessWidget {
  const GoConnectBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.read<BottomNavController>().setIndex(0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Row(
          children: const [
            Icon(Icons.bluetooth_disabled,
                size: 18, color: Color(0xFFAAB2BD)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '\u5c1a\u672a\u9023\u7dda\uff0c\u9ede\u6b64\u524d\u5f80\u9023\u7dda\u9801',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAB2BD)),
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFFAAB2BD)),
          ],
        ),
      ),
    );
  }
}

class _MetricInfoCard extends StatelessWidget {
  const _MetricInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onInfo,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A212B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A101822), blurRadius: 24, offset: Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: onInfo,
                icon: const Icon(Icons.info_outline,
                    size: 18, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
