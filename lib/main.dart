

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Base URL for your cloud API. Replace with your own endpoint.
const kBaseUrl = 'https://api.your-cloud.com';
/// API key for authenticating against the cloud API. Replace with your own key.
const kApiKey = 'your_api_key';

/// Global Dio client configured with sensible defaults.
final _dio = Dio(
  BaseOptions(
    baseUrl: kBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Authorization': 'Bearer $kApiKey',
    },
  ),
);

/// Represents a time series of points to plot on a chart.
class Series {
  final List<FlSpot> spots;
  Series(this.spots);

  /// Constructs a [Series] from a JSON array of pairs.
  factory Series.fromJson(List data) {
    return Series(
      data
          .map<FlSpot>((e) => FlSpot(
                (e[0] as num).toDouble(),
                (e[1] as num).toDouble(),
              ))
          .toList(),
    );
  }
}

/// Simple 3D vector utility to work with IMU acceleration data.
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  static const Vector3 zero = Vector3(0, 0, 0);

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  bool get isValid => magnitude > 1e-9 && x.isFinite && y.isFinite && z.isFinite;

  Vector3 normalized() {
    final mag = magnitude;
    if (mag < 1e-9 || !mag.isFinite) {
      return zero;
    }
    return Vector3(x / mag, y / mag, z / mag);
  }

  double dot(Vector3 other) => x * other.x + y * other.y + z * other.z;

  Vector3 cross(Vector3 other) => Vector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  Vector3 orthogonal() {
    // Pick the smallest component to avoid degeneracy.
    if (x.abs() < y.abs() && x.abs() < z.abs()) {
      return Vector3(0, -z, y).normalized();
    } else if (y.abs() < z.abs()) {
      return Vector3(-z, 0, x).normalized();
    } else {
      return Vector3(-y, x, 0).normalized();
    }
  }

  static double angleBetween(Vector3 a, Vector3 b) {
    if (!a.isValid || !b.isValid) {
      return double.nan;
    }
    final na = a.normalized();
    final nb = b.normalized();
    final dot = na.dot(nb).clamp(-1.0, 1.0).toDouble();
    final angle = math.acos(dot);
    return angle * 180 / math.pi;
  }
}

/// Represents a quaternion for IMU orientation calculations.
class Quaternion {
  final double w;
  final double x;
  final double y;
  final double z;

  const Quaternion(this.w, this.x, this.y, this.z);

  static const Quaternion identity = Quaternion(1, 0, 0, 0);

  Quaternion normalized() {
    final n = math.sqrt(w * w + x * x + y * y + z * z);
    if (n < 1e-9 || !n.isFinite) {
      return identity;
    }
    return Quaternion(w / n, x / n, y / n, z / n);
  }

  Quaternion conjugate() => Quaternion(w, -x, -y, -z);

  Quaternion operator *(Quaternion other) => Quaternion(
        w * other.w - x * other.x - y * other.y - z * other.z,
        w * other.x + x * other.w + y * other.z - z * other.y,
        w * other.y - x * other.z + y * other.w + z * other.x,
        w * other.z + x * other.y - y * other.x + z * other.w,
      );

  Quaternion relativeTo(Quaternion other) => conjugate() * other;

  double get angleRadians {
    final clampedW = w.clamp(-1.0, 1.0).toDouble();
    return 2 * math.acos(clampedW);
  }

  double get principalAngleDegrees {
    final rad = angleRadians;
    final normalizedRad = rad > math.pi ? (2 * math.pi - rad) : rad;
    return normalizedRad * 180 / math.pi;
  }

  static Quaternion fromTwoVectors(Vector3 from, Vector3 to) {
    if (!from.isValid || !to.isValid) {
      return identity;
    }
    final f = from.normalized();
    final t = to.normalized();
    final dot = f.dot(t);
    final cross = f.cross(t);
    var w = 1 + dot;
    Vector3 xyz = cross;
    if (w < 1e-9) {
      // 180-degree rotation, choose an orthogonal axis.
      final axis = f.orthogonal();
      return Quaternion(0, axis.x, axis.y, axis.z).normalized();
    }
    final q = Quaternion(w, xyz.x, xyz.y, xyz.z);
    return q.normalized();
  }

  static Quaternion fromAccelerometer(Vector3 accel) {
    // Assume the reference IMU frame has -Z pointing along gravity.
    const reference = Vector3(0, 0, -1);
    return fromTwoVectors(reference, accel);
  }
}

/// IMU sample containing acceleration vector and derived quaternion.
class ImuSample {
  final int index;
  final Vector3 acceleration;
  final Quaternion orientation;

  ImuSample({required this.index, required this.acceleration, required this.orientation});

  factory ImuSample.fromAcceleration({required int index, required Vector3 acceleration}) {
    final quat = Quaternion.fromAccelerometer(acceleration);
    return ImuSample(index: index, acceleration: acceleration, orientation: quat);
  }
}

class ImuPacket {
  final double timestamp;
  final double? emgRms;
  final Map<int, ImuSample> samples;

  ImuPacket({required this.timestamp, required this.emgRms, required this.samples});

  ImuSample? sampleAt(int index) => samples[index];

  static const int _imuCount = 6;

  static ImuPacket? tryParse(String line) {
    final values = _extractNumbers(line);
    if (values.isEmpty) {
      return null;
    }
    final ts = values[0];
    if (!ts.isFinite) {
      return null;
    }

    if (values.length == 2) {
      // Backward compatible with original EMG-only payload.
      return ImuPacket(
        timestamp: ts,
        emgRms: values[1],
        samples: const <int, ImuSample>{},
      );
    }

    const minPerImu = 3; // ax, ay, az
    final minValues = minPerImu * _imuCount;

    if (values.length < 1 + minValues) {
      // Not enough values to cover six IMUs.
      return null;
    }

    double? emg;
    var offset = 1;
    var available = values.length - offset;
    final perImuCandidate = (available / _imuCount).floor();

    if (values.length >= 2) {
      final availableWithEmg = values.length - 2;
      final perImuWithEmg = (availableWithEmg / _imuCount).floor();
      final alignsWithoutEmg = available % _imuCount == 0;
      final alignsWithEmg = availableWithEmg % _imuCount == 0;
      final betterWithEmg =
          perImuWithEmg >= minPerImu && perImuWithEmg > perImuCandidate;

      if ((alignsWithEmg && !alignsWithoutEmg) || betterWithEmg) {
        emg = values[1];
        offset = 2;
        available = availableWithEmg;
      }
    }

    final perImu = (available / _imuCount).floor();
    if (perImu < minPerImu) {
      return null;
    }

    final samples = <int, ImuSample>{};
    for (var i = 0; i < _imuCount; i++) {
      final base = offset + i * perImu;
      if (base + 2 >= values.length) {
        return null;
      }
      final accel = Vector3(values[base], values[base + 1], values[base + 2]);
      samples[i] = ImuSample.fromAcceleration(index: i, acceleration: accel);
    }

    return ImuPacket(timestamp: ts, emgRms: emg, samples: samples);
  }

  static List<double> _extractNumbers(String source) {
    final matches = RegExp(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?').allMatches(source);
    return [
      for (final m in matches)
        double.tryParse(m.group(0) ?? '')
    ].whereType<double>().toList();
  }
}

class JointAngleResult {
  final String label;
  final double vectorAngleDeg;
  final double quaternionAngleDeg;

  const JointAngleResult({
    required this.label,
    required this.vectorAngleDeg,
    required this.quaternionAngleDeg,
  });
}

/// Represents a single history record returned by the cloud API.
class HistoryItem {
  final String id;
  final DateTime date;
  HistoryItem({required this.id, required this.date});
  factory HistoryItem.fromJson(Map<String, dynamic> j) =>
      HistoryItem(id: j['id'], date: DateTime.parse(j['date']));
}

/// Encapsulates calls to the cloud API.
class CloudApi {
  /// Fetches the latest prediction series.
  static Future<Series> fetchLatest() async {
    final res = await _dio.get('/predict/latest');
    return Series.fromJson(res.data['series']);
  }

  /// Fetches a list of historic prediction items ordered by most recent.
  static Future<List<HistoryItem>> fetchHistoryIndex() async {
    final res = await _dio.get('/predict/history');
    final list = (res.data as List)
        .map((e) => HistoryItem.fromJson(e))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Fetches a historic prediction series by ID.
  static Future<Series> fetchHistoryById(String id) async {
    final res = await _dio.get('/predict/history/$id');
    return Series.fromJson(res.data['series']);
  }
}

/// Service that handles Bluetooth Low Energy (BLE) ingestion from an ESP32 device.
///
/// The service exposes separate [connect] and [listen] methods so you can
/// control when the connection is established and when data is consumed.
class BleIngestService {
  BluetoothDevice? _dev;
  BluetoothCharacteristic? _notify;
  StreamSubscription<List<int>>? _sub;

  /// Name of the target ESP32 device in advertisement packets.
  static const String kDeviceName = 'ESP32_SIM_EMG_IMU';
  /// UUID of the BLE service to look for on the device.
  static final Guid kServiceUuid = Guid('0000abcd-0000-1000-8000-00805f9b34fb');
  /// UUID of the characteristic to subscribe to for notifications.
  static final Guid kNotifyUuid = Guid('0000dcba-0000-1000-8000-00805f9b34fb');

  /// Connects to a BLE device whose advertised name matches [deviceName] or
  /// whose advertised service UUID matches [kServiceUuid]. This method
  /// requests the necessary permissions, scans for a matching device, and
  /// discovers the notify characteristic. Throws if no device is found.
  Future<void> connect(String deviceName) async {
    // 1. Request permissions on Android. If denied, bail out.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      throw Exception('藍牙/定位權限未允許');
    }

    // 2. Start scanning for up to 8 seconds using the static API.
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    ScanResult? hit;
    final subScan = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        final svcs = r.advertisementData.serviceUuids;
        if (name == deviceName || svcs.contains(kServiceUuid)) {
          hit = r;
          break;
        }
      }
    });

    final start = DateTime.now();
    while (hit == null && DateTime.now().difference(start).inSeconds < 8) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await subScan.cancel();
    await FlutterBluePlus.stopScan();

    if (hit == null) {
      throw Exception('找不到目標裝置：$deviceName');
    }

    // 3. Connect to the discovered device.
    _dev = hit!.device;
    await _dev!.connect(timeout: const Duration(seconds: 10));

    // 4. Discover services and locate the notify characteristic.
    final services = await _dev!.discoverServices();
    final svc = services.firstWhere((s) => s.uuid == kServiceUuid,
        orElse: () =>
            throw Exception('找不到服務 $kServiceUuid on device ${_dev!.platformName}'));
    _notify = svc.characteristics.firstWhere((c) => c.uuid == kNotifyUuid,
        orElse: () => throw Exception('找不到特徵 $kNotifyUuid'));
  }

  /// Begins listening for newline-delimited strings from the device. Each
  /// complete line is delivered to [onLine]. Call only after [connect].
  void listen(void Function(String line) onLine) {
    if (_notify == null) {
      throw StateError('尚未連線或找不到通知特徵');
    }
    _notify!.setNotifyValue(true);
    final buffer = StringBuffer();
    _sub = _notify!.lastValueStream.listen((bytes) {
      buffer.write(String.fromCharCodes(bytes));
      while (true) {
        final text = buffer.toString();
        final i = text.indexOf('\n');
        if (i < 0) break;
        final line = text.substring(0, i).trim();
        if (line.isNotEmpty) onLine(line);
        buffer.clear();
        if (i + 1 < text.length) buffer.write(text.substring(i + 1));
      }
    });
  }

  /// Releases resources and disconnects from the BLE device.
  Future<void> dispose() async {
    await _sub?.cancel();
    if (_dev != null) {
      try {
        await _dev!.disconnect();
      } catch (_) {
        // ignore disconnect exceptions
      }
    }
  }
}

class _JointPair {
  final int a;
  final int b;
  final String label;
  const _JointPair(this.a, this.b, this.label);
}

const _jointPairs = <_JointPair>[
  _JointPair(0, 1, '軀幹（後頸 vs 下背）'),
  _JointPair(2, 3, '左肩（上臂 vs 肩胛）'),
  _JointPair(4, 5, '右肩（上臂 vs 肩胛）'),
];

/// A reusable widget that draws a regression line chart for a [Series].
class RegressionChart extends StatelessWidget {
  final Series series;
  final String? title;
  final double? minY, maxY;
  const RegressionChart({
    super.key,
    required this.series,
    this.title,
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final s = series.spots;
    if (s.isEmpty) return const Center(child: Text('沒有資料'));
    final minx = s.first.x, maxx = s.last.x;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minX: minx,
              maxX: maxx,
              minY: minY ?? _autoMinY(s),
              maxY: maxY ?? _autoMaxY(s),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                ),
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: true)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: s,
                  isCurved: true,
                  barWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _autoMinY(List<FlSpot> s) {
    final v = s.map((e) => e.y);
    final m = v.reduce((a, b) => a < b ? a : b);
    return m - (m.abs() * 0.1 + 0.05);
  }

  double _autoMaxY(List<FlSpot> s) {
    final v = s.map((e) => e.y);
    final m = v.reduce((a, b) => a > b ? a : b);
    return m + (m.abs() * 0.1 + 0.05);
  }
}

/// The entry point of the Flutter application. It sets up the theme and home page.
void main() => runApp(const MyApp());

/// Root widget that configures the app and hosts the [PredictionHome] page.
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '疲勞預測',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const PredictionHome(),
    );
  }
}

/// Shell widget with a bottom navigation bar to switch between real-time and history views.
class PredictionHome extends StatefulWidget {
  const PredictionHome({super.key});
  @override
  State<PredictionHome> createState() => _PredictionHomeState();
}

class _PredictionHomeState extends State<PredictionHome> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_idx == 0 ? '即時預測' : '歷史紀錄')),
      body: IndexedStack(
        index: _idx,
        children: const [
          LivePredictionPage(),
          HistoryPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart), label: '即時'),
          NavigationDestination(icon: Icon(Icons.history), label: '歷史'),
        ],
      ),
    );
  }
}

/// Page that connects to the ESP32, streams live EMG RMS values, shows them on a chart and uploads them to the cloud.
class LivePredictionPage extends StatefulWidget {
  const LivePredictionPage({super.key});
  @override
  State<LivePredictionPage> createState() => _LivePredictionPageState();
}

class _LivePredictionPageState extends State<LivePredictionPage> {
  final esp32 = BleIngestService();
  final List<FlSpot> _spots = [];
  double _lastX = 0;
  bool _connected = false;
  List<JointAngleResult> _jointAngles = const [];

  @override
  void initState() {
    super.initState();
    _connectAndListen();
  }

  Future<void> _connectAndListen() async {
    try {
      await esp32.connect('ESP32_SIM_EMG_IMU');
      setState(() => _connected = true);
      esp32.listen((line) {
        final packet = ImuPacket.tryParse(line);
        if (packet == null) {
          debugPrint('⚠️ 無法解析 IMU 資料: $line');
          return;
        }

        setState(() {
          if (packet.emgRms != null) {
            final ts = _sanitizeTimestamp(packet.timestamp);
            final emgRms = packet.emgRms ?? 0.0;
            _spots.add(FlSpot(ts, emgRms));
            _lastX = ts;
            if (_spots.length > 500) _spots.removeAt(0);
          }
          _jointAngles = _computeJointAngles(packet, _jointAngles);
        });

        if (packet.emgRms != null) {
          _uploadToCloud(packet.timestamp, packet.emgRms!);
        }
      });
    } catch (e) {
      debugPrint('❌ Bluetooth connect error: $e');
    }
  }

  double _sanitizeTimestamp(double ts) {
    if (ts.isFinite) {
      return ts;
    }
    return _lastX + 1;
  }

  List<JointAngleResult> _computeJointAngles(
    ImuPacket packet,
    List<JointAngleResult> previous,
  ) {
    for (final pair in _jointPairs) {
      if (packet.sampleAt(pair.a) == null || packet.sampleAt(pair.b) == null) {
        return previous;
      }
    }

    final results = <JointAngleResult>[];
    for (final pair in _jointPairs) {
      final a = packet.sampleAt(pair.a)!;
      final b = packet.sampleAt(pair.b)!;
      final vectorAngle = Vector3.angleBetween(a.acceleration, b.acceleration);
      final quaternionAngle =
          a.orientation.relativeTo(b.orientation).principalAngleDegrees;
      results.add(JointAngleResult(
        label: pair.label,
        vectorAngleDeg: vectorAngle,
        quaternionAngleDeg: quaternionAngle,
      ));
    }
    return results;
  }

  Future<void> _uploadToCloud(double ts, double emgRms) async {
    try {
      await _dio.post('/predict/upload', data: {
        'timestamp': ts,
        'emg_rms': emgRms,
      });
    } catch (e) {
      debugPrint('❌ Upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RegressionChart(series: Series(_spots), title: '即時 EMG RMS'),
          const SizedBox(height: 16),
          Expanded(child: JointAngleList(angles: _jointAngles)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    esp32.dispose();
    super.dispose();
  }
}

class JointAngleList extends StatelessWidget {
  final List<JointAngleResult> angles;
  const JointAngleList({super.key, required this.angles});

  @override
  Widget build(BuildContext context) {
    if (angles.isEmpty) {
      return const Center(child: Text('等待 IMU 資料...'));
    }
    return ListView.separated(
      itemCount: angles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final angle = angles[index];
        return ListTile(
          title: Text(angle.label),
          subtitle: Text(
            '向量夾角: ${_formatAngle(angle.vectorAngleDeg)}°\n'
            '四元數差角: ${_formatAngle(angle.quaternionAngleDeg)}°',
          ),
        );
      },
    );
  }

  String _formatAngle(double value) {
    if (!value.isFinite) {
      return '--';
    }
    return value.toStringAsFixed(1);
  }
}

/// Page that lists historic predictions and shows the selected record.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<HistoryItem>> _indexFuture;
  Future<Series>? _seriesFuture;

  @override
  void initState() {
    super.initState();
    _indexFuture = CloudApi.fetchHistoryIndex();
    _indexFuture.then((list) {
      if (list.isNotEmpty) {
        _seriesFuture = CloudApi.fetchHistoryById(list.first.id);
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HistoryItem>>(
      future: _indexFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('讀取歷史清單失敗：${snap.error}'));
        }
        final items = snap.data!;
        if (items.isEmpty) return const Center(child: Text('沒有紀錄'));
        return Column(
          children: [
            Expanded(
              child: FutureBuilder<Series>(
                future: _seriesFuture,
                builder: (ctx, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError || s.data == null) {
                    return Center(child: Text('讀取該次預測失敗：${s.error}'));
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child:
                        RegressionChart(series: s.data!, title: '歷史紀錄'),
                  );
                },
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final it = items[i];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _seriesFuture = CloudApi.fetchHistoryById(it.id);
                      });
                    },
                    child: Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          it.date.toString().split(' ').first,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
