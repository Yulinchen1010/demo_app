

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as classic;
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

const Color kBackgroundColor = Color(0xFF121212);
const Color kPrimaryAccent = Color(0xFF00BCD4);
const Color kEmgColor = Color(0xFFFF5252);
const Color kTrunkColor = Color(0xFF4CAF50);
const Color kLeftShoulderColor = Color(0xFFFFC107);
const Color kRightShoulderColor = Color(0xFF2196F3);
const List<Color> kRulaGaugeGradient = [Color(0xFFFF9800), Color(0xFFF44336)];

/// Represents a time series of points to plot on a chart.
class Series {
  final List<FlSpot> spots;
  Series(this.spots);

  /// Constructs a [Series] from a JSON array of pairs.
  factory Series.fromJson(dynamic data) {
    final iterable = _coerceIterable(data);
    final spots = <FlSpot>[];

    for (final entry in iterable) {
      final spot = _spotFromEntry(entry);
      if (spot != null) {
        spots.add(spot);
      }
    }

    return Series(spots);
  }

  static Iterable _coerceIterable(dynamic data) {
    if (data is Iterable) return data;
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Iterable) return decoded;
    }
    throw StateError('Series expects an iterable but received ${data.runtimeType}');
  }

  static FlSpot? _spotFromEntry(dynamic entry) {
    double? x;
    double? y;

    if (entry is List && entry.length >= 2) {
      x = _toDouble(entry[0]);
      y = _toDouble(entry[1]);
    } else if (entry is Map) {
      final map = entry.map((key, value) => MapEntry(key.toString(), value));
      x = _toDouble(map['x'] ?? map['timestamp'] ?? map['time'] ?? map['t']);
      y = _toDouble(map['y'] ?? map['value'] ?? map['emg_rms'] ?? map['rms']);
    }

    if (x == null || y == null) return null;
    return FlSpot(x, y);
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Represents a single history record returned by the cloud API.
class HistoryItem {
  final String id;
  final DateTime date;
  HistoryItem({required this.id, required this.date});
  factory HistoryItem.fromJson(dynamic json) {
    if (json is Map) {
      final map = json.map((key, value) => MapEntry(key.toString(), value));
      final id = (map['id'] ?? map['uuid'] ?? map['history_id'] ?? '').toString();
      final rawDate = map['date'] ?? map['created_at'] ?? map['timestamp'];
      final date = _parseDate(rawDate);
      if (id.isEmpty || date == null) {
        throw StateError('無法解析歷史紀錄：$map');
      }
      return HistoryItem(id: id, date: date);
    }

    if (json is List && json.length >= 2) {
      final id = json[0].toString();
      final date = _parseDate(json[1]);
      if (date == null) {
        throw StateError('無法解析歷史紀錄：$json');
      }
      return HistoryItem(id: id, date: date);
    }

    throw StateError('Unsupported history item format: ${json.runtimeType}');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is num) {
      // Assume seconds if value is reasonably small, otherwise milliseconds.
      final millis = value > 1e12 ? value.toInt() : (value * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Encapsulates calls to the cloud API.
class CloudApi {
  /// Fetches the latest prediction series.
  static Future<Series> fetchLatest() async {
    final res = await _dio.get('/predict/latest');
    final data = _normalizeResponse(res);
    final series = _extractList(data, 'latest series', ['series', 'data', 'points']);
    return Series.fromJson(series);
  }

  /// Fetches a list of historic prediction items ordered by most recent.
  static Future<List<HistoryItem>> fetchHistoryIndex() async {
    final res = await _dio.get('/predict/history');
    final data = _normalizeResponse(res);
    final rawList = _extractList(data, 'history index', ['data', 'items', 'history']);
    final list = rawList.map((e) => HistoryItem.fromJson(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Fetches a historic prediction series by ID.
  static Future<Series> fetchHistoryById(String id) async {
    final res = await _dio.get('/predict/history/$id');
    final data = _normalizeResponse(res);
    final series = _extractList(data, 'history detail', ['series', 'data', 'points']);
    return Series.fromJson(series);
  }

  static dynamic _normalizeResponse(Response res) {
    final data = res.data;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return [];
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  static List<dynamic> _extractList(
    dynamic data,
    String context,
    List<String> candidateKeys,
  ) {
    if (data is List) {
      return data;
    }

    if (data is Map) {
      final map = data.map((key, value) => MapEntry(key.toString(), value));
      for (final key in candidateKeys) {
        final value = map[key];
        if (value is List) {
          return value;
        }
      }
    }

    throw StateError('Unexpected $context response shape: ${data.runtimeType}');
  }
}

/// Simple 3D vector implementation providing the handful of operations needed
/// for IMU orientation math without pulling an external dependency.
class Vector3 {
  double x;
  double y;
  double z;

  Vector3(this.x, this.y, this.z);

  Vector3 clone() => Vector3(x, y, z);

  double get lengthSquared => x * x + y * y + z * z;

  double get length2 => lengthSquared;

  double get length => math.sqrt(lengthSquared);

  void scale(double scalar) {
    x *= scalar;
    y *= scalar;
    z *= scalar;
  }

  void normalize() {
    final len = length;
    if (len < 1e-9) {
      x = 0;
      y = 0;
      z = 0;
      return;
    }
    scale(1 / len);
  }

  double dot(Vector3 other) => x * other.x + y * other.y + z * other.z;

  Vector3 cross(Vector3 other) => Vector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );
}

class Quaternion {
  double w;
  double x;
  double y;
  double z;

  Quaternion(this.w, this.x, this.y, this.z);

  factory Quaternion.identity() => Quaternion(1, 0, 0, 0);

  factory Quaternion.axisAngle(Vector3 axis, double angle) {
    final normalizedAxis = axis.clone();
    final axisLength = normalizedAxis.length;
    if (axisLength < 1e-9) {
      return Quaternion.identity();
    }
    normalizedAxis.scale(1 / axisLength);
    final half = angle / 2;
    final sinHalf = math.sin(half);
    final q = Quaternion(
      math.cos(half),
      normalizedAxis.x * sinHalf,
      normalizedAxis.y * sinHalf,
      normalizedAxis.z * sinHalf,
    );
    q.normalize();
    return q;
  }

  Quaternion copy() => Quaternion(w, x, y, z);

  void normalize() {
    final magnitude = math.sqrt(w * w + x * x + y * y + z * z);
    if (magnitude < 1e-9) {
      w = 1;
      x = y = z = 0;
      return;
    }
    final inv = 1 / magnitude;
    w *= inv;
    x *= inv;
    y *= inv;
    z *= inv;
  }

  void conjugate() {
    x = -x;
    y = -y;
    z = -z;
  }

  void multiply(Quaternion other) {
    final nw = w * other.w - x * other.x - y * other.y - z * other.z;
    final nx = w * other.x + x * other.w + y * other.z - z * other.y;
    final ny = w * other.y - x * other.z + y * other.w + z * other.x;
    final nz = w * other.z + x * other.y - y * other.x + z * other.w;
    w = nw;
    x = nx;
    y = ny;
    z = nz;
  }
}

/// Represents the raw IMU reading for a single sensor, including derived
/// orientation expressed as a quaternion relative to the gravity vector.
class ImuReading {
  final Vector3 accel;
  final Vector3 gyro;
  final Quaternion orientation;

  ImuReading._(this.accel, this.gyro, this.orientation);

  /// Builds an [ImuReading] from six sequential values:
  /// `[ax, ay, az, gx, gy, gz]`.
  factory ImuReading.fromValues(List<double> values) {
    final accel = Vector3(values[0], values[1], values[2]);
    final gyro = Vector3(values[3], values[4], values[5]);
    final orientation = _orientationFromAcceleration(accel);
    return ImuReading._(accel, gyro, orientation);
  }

  static Quaternion _orientationFromAcceleration(Vector3 accel) {
    final norm = accel.clone();
    final magnitude = norm.length;
    if (magnitude < 1e-6) {
      return Quaternion.identity();
    }
    norm.scale(1 / magnitude);
    final reference = Vector3(0, 0, -1);
    final dot = math.max(-1.0, math.min(1.0, reference.dot(norm)));
    final axis = reference.cross(norm);
    if (axis.length2 < 1e-12) {
      if (dot >= 0) {
        return Quaternion.identity();
      }
      // Opposite direction: rotate 180° around an arbitrary axis orthogonal to
      // gravity. X-axis keeps things simple.
      final fallback = Vector3(1, 0, 0);
      return Quaternion.axisAngle(fallback, math.pi);
    }
    axis.normalize();
    final angle = math.acos(dot);
    final q = Quaternion.axisAngle(axis, angle);
    q.normalize();
    return q;
  }
}

/// Container for the calculated joint angle of a sensor pair.
class JointAngleMeasurement {
  final String label;
  final double? vectorDegrees;
  final double? quaternionDegrees;

  const JointAngleMeasurement({
    required this.label,
    required this.vectorDegrees,
    required this.quaternionDegrees,
  });
}

/// Result of mapping IMU joint angles into a simplified RULA assessment.
class RulaAssessment {
  final int trunkScore;
  final int leftScore;
  final int rightScore;
  final int finalScore;
  final String dominantSide;
  final String recommendation;

  const RulaAssessment({
    required this.trunkScore,
    required this.leftScore,
    required this.rightScore,
    required this.finalScore,
    required this.dominantSide,
    required this.recommendation,
  });
}

/// Service that handles Bluetooth Low Energy (BLE) ingestion from an ESP32 device.
///
/// The service exposes separate [connect] and [listen] methods so you can
/// control when the connection is established and when data is consumed.
class BleIngestService {
  static const String kDeviceName = 'ESP32_EMG_IMU';

  final classic.FlutterBluetoothSerial _bluetooth =
      classic.FlutterBluetoothSerial.instance;
  classic.BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _subscription;

  /// Connects to the ESP32 over classic Bluetooth (SPP).
  Future<void> connect(String deviceName) async {
    await dispose();

    final granted = await _ensurePermissions();
    if (!granted) {
      throw Exception('藍牙/定位權限未允許');
    }

    final isEnabled = await _bluetooth.isEnabled ?? false;
    if (!isEnabled) {
      final enabled = await _bluetooth.requestEnable();
      if (enabled != true) {
        throw Exception('請先開啟藍牙功能');
      }
    }

    try {
      await _bluetooth.cancelDiscovery();
    } catch (_) {
      // Ignore discovery cancellation issues when Bluetooth is off.
    }
    final device = await _findDevice(deviceName);
    if (device == null) {
      throw Exception('找不到目標裝置：$deviceName');
    }

    try {
      _connection = await classic.BluetoothConnection.toAddress(device.address)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException catch (_) {
      throw Exception('連線逾時，請確認裝置已開機且可被配對');
    }
  }

  /// Begins listening for newline-delimited packets emitted by the ESP32.
  void listen(
    void Function(String line) onLine, {
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    final conn = _connection;
    if (conn == null || !conn.isConnected) {
      throw StateError('尚未建立藍牙連線');
    }

    final input = conn.input;
    if (input == null) {
      throw StateError('此裝置沒有可讀取的資料串流');
    }

    final buffer = StringBuffer();
    _subscription = input.listen(
      (Uint8List data) {
        buffer.write(utf8.decode(data));
        while (true) {
          final current = buffer.toString();
          final idx = current.indexOf('\n');
          if (idx < 0) break;
          final line = current.substring(0, idx).trim();
          if (line.isNotEmpty) {
            onLine(line);
          }
          buffer
            ..clear()
            ..write(idx + 1 < current.length ? current.substring(idx + 1) : '');
        }
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: false,
    );
  }

  /// Releases resources and disconnects from the ESP32.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (_) {
        // Ignore errors during teardown.
      }
    }
    _connection = null;
    try {
      await _bluetooth.cancelDiscovery();
    } catch (_) {
      // ignore discovery cancellation issues
    }
  }

  Future<classic.BluetoothDevice?> _findDevice(String deviceName) async {
    final bonded = await _bluetooth.getBondedDevices();
    for (final device in bonded) {
      if ((device.name ?? '').trim() == deviceName) {
        return device;
      }
    }

    classic.BluetoothDiscoveryResult? discoveryResult;
    final stream = _bluetooth.startDiscovery();
    try {
      await for (final result in stream) {
        final name = result.device.name ?? '';
        if (name.trim() == deviceName) {
          discoveryResult = result;
          break;
        }
      }
    } finally {
      await _bluetooth.cancelDiscovery();
    }
    return discoveryResult?.device;
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final sdkInt = _androidSdkInt();
    final requested = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetooth,
      Permission.locationWhenInUse,
      Permission.location,
    ].request();

    if (sdkInt >= 31) {
      bool scanGranted = requested[Permission.bluetoothScan]?.isGranted ?? false;
      bool connectGranted =
          requested[Permission.bluetoothConnect]?.isGranted ?? false;

      if (!scanGranted) {
        scanGranted = (await Permission.bluetoothScan.request()).isGranted;
      }
      if (!connectGranted) {
        connectGranted =
            (await Permission.bluetoothConnect.request()).isGranted;
      }
      return scanGranted && connectGranted;
    }

    // Android 30 以下：授與傳統藍牙或定位權限即可運作
    if (requested[Permission.bluetooth]?.isGranted ?? false) {
      return true;
    }

    final locationGranted =
        (requested[Permission.locationWhenInUse]?.isGranted ?? false) ||
            (requested[Permission.location]?.isGranted ?? false);
    return locationGranted;
  }

  int _androidSdkInt() {
    final match = RegExp(r'SDK\s*(\d+)').firstMatch(Platform.version);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }
    return 0;
  }
}

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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryAccent,
          brightness: Brightness.dark,
        ).copyWith(background: kBackgroundColor, surface: const Color(0xFF1C1C1C)),
        scaffoldBackgroundColor: kBackgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1C1C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
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
  final _liveKey = GlobalKey<_LivePredictionPageState>();
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: IndexedStack(
        index: _idx,
        children: [
          LivePredictionPage(
            key: _liveKey,
            onHistoryTap: () => _onDestinationSelected(1),
          ),
          const HistoryPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1C1C1C),
        indicatorColor: kPrimaryAccent.withOpacity(0.2),
        selectedIndex: _idx,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_idx == 0) {
      return AppBar(
        title: const Text('Real-time Monitoring'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryAccent,
                side: BorderSide(color: kPrimaryAccent.withOpacity(0.6)),
              ),
              onPressed: () => _onDestinationSelected(1),
              icon: const Icon(Icons.history),
              label: const Text('History View'),
            ),
          ),
        ],
      );
    }
    if (_idx == 1) {
      return AppBar(
        title: const Text('History View'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryAccent,
                side: BorderSide(color: kPrimaryAccent.withOpacity(0.6)),
              ),
              onPressed: () => _onDestinationSelected(0),
              icon: const Icon(Icons.podcasts),
              label: const Text('Back to Live'),
            ),
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('Settings'),
    );
  }

  void _onDestinationSelected(int i) {
    if (_idx == i) return;
    setState(() {
      _idx = i;
    });
    _liveKey.currentState?.setActive(i == 0);
  }
}

/// Page that connects to the ESP32, streams live EMG RMS values, shows them on a chart and uploads them to the cloud.
class LivePredictionPage extends StatefulWidget {
  const LivePredictionPage({super.key, this.onHistoryTap});

  final VoidCallback? onHistoryTap;
  @override
  State<LivePredictionPage> createState() => _LivePredictionPageState();
}

class _LivePredictionPageState extends State<LivePredictionPage> {
  final esp32 = BleIngestService();
  final List<FlSpot> _emgSpots = [];
  final List<FlSpot> _trunkAngleSpots = [];
  final List<FlSpot> _leftShoulderSpots = [];
  final List<FlSpot> _rightShoulderSpots = [];
  final List<FlSpot> _rulaScoreSpots = [];
  double _lastX = 0;
  bool _connected = false;
  bool _connecting = true;
  String? _error;
  double? _startTimestamp;
  double? _latestPct;
  List<JointAngleMeasurement>? _latestJointAngles;
  RulaAssessment? _latestRula;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _connectAndListen();
  }

  Future<void> _connectAndListen() async {
    setState(() {
      _connecting = true;
      _error = null;
      _connected = false;
      _emgSpots.clear();
      _trunkAngleSpots.clear();
      _leftShoulderSpots.clear();
      _rightShoulderSpots.clear();
      _rulaScoreSpots.clear();
      _lastX = 0;
      _startTimestamp = null;
      _latestPct = null;
      _latestJointAngles = null;
      _latestRula = null;
    });
    try {
      await esp32.connect(BleIngestService.kDeviceName);
      if (!mounted) return;
      setState(() {
        _connected = true;
        _connecting = false;
      });
      esp32.listen(
        _handleIncomingLine,
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = '資料串流錯誤：$error';
            _connected = false;
            _connecting = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _error = '藍牙連線已中斷';
            _connected = false;
            _connecting = false;
          });
        },
      );
    } catch (e) {
      debugPrint('❌ Bluetooth connect error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _connecting = false;
        _connected = false;
      });
    }
  }

  void _handleIncomingLine(String line) {
    final parts = line.split(',');
    if (parts.length < 2 || !mounted) {
      return;
    }

    final rawTs = double.tryParse(parts[0]);
    final emgRms = double.tryParse(parts[1]) ?? 0.0;
    final pct = parts.length >= 3 ? double.tryParse(parts[2]) : null;
    final imuReadings = _parseImuReadings(parts);
    final jointAngles = _calculateJointAngles(imuReadings);

    double x;
    if (rawTs != null) {
      _startTimestamp ??= rawTs;
      x = (rawTs - _startTimestamp!) / 1000.0;
    } else {
      x = _lastX + 1;
    }

    if (!_isActive) {
      _lastX = x;
      return;
    }

    setState(() {
      _emgSpots.add(FlSpot(x, emgRms));
      if (_emgSpots.length > 500) {
        _emgSpots.removeAt(0);
      }
      _lastX = x;
      _latestPct = pct;
      _latestJointAngles = jointAngles;
      _latestRula = _calculateRulaAssessment(jointAngles);
      if (jointAngles != null && jointAngles.length >= 3) {
        final trunk = _resolveAngle(jointAngles[0]);
        final left = _resolveAngle(jointAngles[1]);
        final right = _resolveAngle(jointAngles[2]);
        if (trunk != null) {
          _trunkAngleSpots.add(FlSpot(x, trunk));
          if (_trunkAngleSpots.length > 500) {
            _trunkAngleSpots.removeAt(0);
          }
        }
        if (left != null) {
          _leftShoulderSpots.add(FlSpot(x, left));
          if (_leftShoulderSpots.length > 500) {
            _leftShoulderSpots.removeAt(0);
          }
        }
        if (right != null) {
          _rightShoulderSpots.add(FlSpot(x, right));
          if (_rightShoulderSpots.length > 500) {
            _rightShoulderSpots.removeAt(0);
          }
        }
      }
      if (_latestRula != null) {
        _rulaScoreSpots.add(FlSpot(x, _latestRula!.finalScore.toDouble()));
        if (_rulaScoreSpots.length > 500) {
          _rulaScoreSpots.removeAt(0);
        }
      }
    });

    _uploadToCloud(rawTs, emgRms, pct);
  }

  List<ImuReading> _parseImuReadings(List<String> parts) {
    if (parts.length <= 3) {
      return const <ImuReading>[];
    }
    final values = <double>[];
    for (var i = 3; i < parts.length; i++) {
      final value = double.tryParse(parts[i].trim());
      if (value != null) {
        values.add(value);
      }
    }
    final readings = <ImuReading>[];
    for (var i = 0; i + 6 <= values.length && readings.length < 6; i += 6) {
      readings.add(ImuReading.fromValues(values.sublist(i, i + 6)));
    }
    return readings;
  }

  List<JointAngleMeasurement>? _calculateJointAngles(
      List<ImuReading> readings) {
    if (readings.length < 2) {
      return null;
    }
    const labels = [
      '軀幹（後頸 vs 下背）',
      '左肩（上臂 vs 肩胛）',
      '右肩（上臂 vs 肩胛）',
    ];
    const pairs = [
      (0, 1),
      (2, 3),
      (4, 5),
    ];
    final results = <JointAngleMeasurement>[];
    for (var i = 0; i < pairs.length; i++) {
      final (a, b) = pairs[i];
      double? vectorDeg;
      double? quaternionDeg;
      if (readings.length > a && readings.length > b) {
        final vectorRad =
            _angleBetweenVectors(readings[a].accel, readings[b].accel);
        final quaternionRad = _angleFromQuaternions(
            readings[a].orientation, readings[b].orientation);
        if (vectorRad != null) {
          vectorDeg = vectorRad * 180 / math.pi;
        }
        if (quaternionRad != null) {
          quaternionDeg = quaternionRad * 180 / math.pi;
        }
      }
      results.add(JointAngleMeasurement(
        label: labels[i],
        vectorDegrees: vectorDeg,
        quaternionDegrees: quaternionDeg,
      ));
    }
    return results;
  }

  RulaAssessment? _calculateRulaAssessment(
      List<JointAngleMeasurement>? measurements) {
    if (measurements == null || measurements.length < 3) {
      return null;
    }

    final trunkAngle = _resolveAngle(measurements[0]) ?? 0;
    final leftAngle = _resolveAngle(measurements[1]) ?? 0;
    final rightAngle = _resolveAngle(measurements[2]) ?? 0;

    final trunkScore = _trunkScore(trunkAngle);
    final leftUpperScore = _upperArmScore(leftAngle);
    final rightUpperScore = _upperArmScore(rightAngle);

    final scoreB = _scoreB(trunkScore);
    final leftScore = _scoreC(_scoreA(leftUpperScore), scoreB);
    final rightScore = _scoreC(_scoreA(rightUpperScore), scoreB);

    final dominantIsLeft = leftScore >= rightScore;
    final finalScore = dominantIsLeft ? leftScore : rightScore;
    final dominantSide = dominantIsLeft ? '左側上肢' : '右側上肢';
    final recommendation = _rulaRecommendation(finalScore);

    return RulaAssessment(
      trunkScore: scoreB,
      leftScore: leftScore,
      rightScore: rightScore,
      finalScore: finalScore,
      dominantSide: dominantSide,
      recommendation: recommendation,
    );
  }

  double? _resolveAngle(JointAngleMeasurement measurement) {
    final quat = measurement.quaternionDegrees;
    if (quat != null && quat.isFinite) {
      return quat.abs();
    }
    final vec = measurement.vectorDegrees;
    if (vec != null && vec.isFinite) {
      return vec.abs();
    }
    return null;
  }

  int _upperArmScore(double angleDegrees) {
    final angle = angleDegrees.abs();
    if (angle <= 20) return 1;
    if (angle <= 45) return 2;
    if (angle <= 90) return 3;
    return 4;
  }

  int _trunkScore(double angleDegrees) {
    final angle = angleDegrees.abs();
    if (angle <= 4) return 1;
    if (angle <= 20) return 2;
    if (angle <= 60) return 3;
    return 4;
  }

  int _scoreA(int upperArmScore) {
    const lowerArmNeutral = 1; // Assume 中性手肘
    const wristNeutral = 1; // Assume 中性手腕
    const tableA = [
      [1, 2, 2],
      [2, 2, 3],
      [3, 3, 4],
      [4, 4, 5],
      [5, 5, 6],
      [6, 6, 7],
    ];
    final upperIndex = upperArmScore.clamp(1, 6) - 1;
    final lowerIndex = lowerArmNeutral.clamp(1, 3) - 1;
    final base = tableA[upperIndex][lowerIndex];
    return (base + wristNeutral - 1).clamp(1, 7);
  }

  int _scoreB(int trunkScore) {
    const neckNeutral = 1; // Assume 中性脖子
    const legsNeutral = 1; // Assume 中性腿部支撐
    const tableB = [
      [1, 2, 3, 4, 5, 6],
      [2, 3, 4, 5, 6, 7],
      [3, 4, 5, 6, 7, 7],
      [4, 5, 6, 7, 7, 7],
      [5, 6, 7, 7, 7, 7],
      [6, 7, 7, 7, 7, 7],
    ];
    final neckIndex = neckNeutral.clamp(1, 6) - 1;
    final trunkIndex = trunkScore.clamp(1, 6) - 1;
    final base = tableB[neckIndex][trunkIndex];
    return (base + legsNeutral - 1).clamp(1, 7);
  }

  int _scoreC(int scoreA, int scoreB) {
    const tableC = [
      [1, 2, 3, 3, 4, 5, 5],
      [2, 2, 3, 4, 4, 5, 5],
      [3, 3, 4, 4, 5, 6, 6],
      [3, 3, 4, 5, 6, 7, 7],
      [4, 4, 5, 6, 7, 7, 7],
      [4, 4, 6, 6, 7, 7, 7],
      [5, 5, 6, 7, 7, 7, 7],
      [5, 5, 7, 7, 7, 7, 7],
    ];
    final aIndex = scoreA.clamp(1, 8) - 1;
    final bIndex = scoreB.clamp(1, 7) - 1;
    return tableC[aIndex][bIndex];
  }

  String _rulaRecommendation(int finalScore) {
    if (finalScore <= 2) {
      return '姿勢可接受，持續觀察';
    }
    if (finalScore <= 4) {
      return '建議進一步評估與調整';
    }
    if (finalScore <= 6) {
      return '需儘速採取改善措施';
    }
    return '需立即採取改善措施';
  }

  double? _angleBetweenVectors(Vector3 a, Vector3 b) {
    final va = a.clone();
    final vb = b.clone();
    final lenA = va.length;
    final lenB = vb.length;
    if (lenA < 1e-6 || lenB < 1e-6) {
      return null;
    }
    va.scale(1 / lenA);
    vb.scale(1 / lenB);
    final dot = math.max(-1.0, math.min(1.0, va.dot(vb)));
    return math.acos(dot);
  }

  double? _angleFromQuaternions(Quaternion a, Quaternion b) {
    final qa = a.copy()..normalize();
    final qb = b.copy()..normalize();
    qa.conjugate();
    qa.multiply(qb);
    qa.normalize();
    final w = math.max(-1.0, math.min(1.0, qa.w));
    return 2 * math.acos(w);
  }

  String _formatAngle(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return '--';
    }
    return value.toStringAsFixed(1);
  }

  Widget _buildStatusMessage(
    BuildContext context, {
    required String message,
    Widget? action,
    bool loading = false,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: kPrimaryAccent.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              CircularProgressIndicator(color: kPrimaryAccent.withOpacity(0.8)),
              const SizedBox(height: 16),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveHeader(BuildContext context) {
    final latestEmg =
        _emgSpots.isNotEmpty ? '${_emgSpots.last.y.toStringAsFixed(2)} mV' : '--';
    final latestPct =
        _latestPct != null ? '${_latestPct!.toStringAsFixed(1)} %MVC' : '--';
    final latestRula = _latestRula?.finalScore.toString() ?? '--';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildInfoPill(context, '連線狀態', '已連線', color: kPrimaryAccent),
        _buildInfoPill(context, 'EMG RMS', latestEmg, color: kEmgColor),
        _buildInfoPill(context, '百分比', latestPct, color: kPrimaryAccent),
        _buildInfoPill(context, 'RULA', latestRula, color: kRulaGaugeGradient.last),
      ],
    );
  }

  Widget _buildInfoPill(BuildContext context, String label, String value,
      {Color? color}) {
    final theme = Theme.of(context);
    final base = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: base.withOpacity(0.4)),
        gradient: LinearGradient(
          colors: [
            base.withOpacity(0.25),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmgCard(BuildContext context) {
    final pctLabel = _latestPct != null
        ? _latestPct!.toStringAsFixed(1)
        : '--';
    final emgLabel =
        _emgSpots.isNotEmpty ? '${_emgSpots.last.y.toStringAsFixed(2)} mV' : '--';

    return NeonPanel(
      title: 'EMG RMS',
      subtitle: 'Waveform (mV)',
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: buildLineChartWidget(
                    _emgSpots,
                    color: kEmgColor,
                  ),
                ),
                const SizedBox(width: 12),
                _buildValueBadge('%MVC', pctLabel),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '最新值：$emgLabel',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImuCard(BuildContext context) {
    return NeonPanel(
      title: 'IMU Joint Angles',
      subtitle: 'Trunk · Left Shoulder · Right Shoulder',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: buildMultiLineChartWidget(
              [_trunkAngleSpots, _leftShoulderSpots, _rightShoulderSpots],
              const [kTrunkColor, kLeftShoulderColor, kRightShoulderColor],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: const [
              _LegendChip(label: 'Trunk', color: kTrunkColor),
              _LegendChip(label: 'Left Shoulder', color: kLeftShoulderColor),
              _LegendChip(label: 'Right Shoulder', color: kRightShoulderColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulaCard(BuildContext context) {
    final assessment = _latestRula;
    final score = assessment?.finalScore ?? 0;
    final dominant = assessment?.dominantSide ?? '等待資料';
    final recommendation = assessment?.recommendation ?? '請保持中立姿勢';

    return NeonPanel(
      title: 'RULA Posture Score',
      subtitle: 'Updated every second',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: RulaGauge(score: score),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '主導側：$dominant',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            recommendation,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context) {
    return NeonPanel(
      title: 'Posture Trend',
      subtitle: 'RULA score over the last minute',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: buildLineChartWidget(
              _rulaScoreSpots,
              color: kPrimaryAccent,
              minY: 0,
              maxY: 7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '每秒更新一次姿勢風險趨勢',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildValueBadge(String label, String value) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F1F), Color(0xFF0F0F0F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadToCloud(
      double? rawTimestampMs, double emgRms, double? emgPct) async {
    try {
      final ts = rawTimestampMs != null
          ? rawTimestampMs.round()
          : DateTime.now().millisecondsSinceEpoch;
      await _dio.post('/predict/upload', data: {
        'timestamp': ts,
        'emg_rms': emgRms,
        if (emgPct != null) 'emg_pct': emgPct,
      });
    } catch (e) {
      debugPrint('❌ Upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return _buildStatusMessage(
        context,
        message: '連線至穿戴裝置中…',
        loading: true,
      );
    }

    if (_error != null) {
      return _buildStatusMessage(
        context,
        message: '連線失敗：\n$_error',
        action: FilledButton(
          onPressed: _connectAndListen,
          child: const Text('重新嘗試'),
        ),
      );
    }

    if (!_connected) {
      return _buildStatusMessage(
        context,
        message: '尚未連線到裝置',
        action: FilledButton(
          onPressed: _connectAndListen,
          child: const Text('立即連線'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLiveHeader(context),
          if (widget.onHistoryTap != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onHistoryTap,
                icon: const Icon(Icons.history, color: Colors.white70),
                label: const Text('Open History View'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
            children: [
              _buildEmgCard(context),
              _buildImuCard(context),
              _buildRulaCard(context),
              _buildTimelineCard(context),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    esp32.dispose();
    super.dispose();
  }

  void setActive(bool active) {
    if (_isActive == active) return;
    setState(() {
      _isActive = active;
    });
  }
}

class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
  });

  final String title;
  final String? subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F1F), Color(0xFF111111)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: kPrimaryAccent.withOpacity(0.1),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ) ??
                const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class RulaGauge extends StatelessWidget {
  const RulaGauge({super.key, required this.score, this.size = 140});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = score.clamp(0, 7) / 7.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: normalized.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    kRulaGaugeGradient.first.withOpacity(0.15),
                    kRulaGaugeGradient.last.withOpacity(0.15),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: size,
              height: size,
              child: ShaderMask(
                shaderCallback: (rect) => SweepGradient(
                  startAngle: -math.pi / 2,
                  endAngle: 3 * math.pi / 2,
                  colors: kRulaGaugeGradient,
                ).createShader(rect),
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score.toString(),
                  style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ) ??
                      const TextStyle(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'RULA',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Widget buildLineChartWidget(
  List<FlSpot> data, {
  required Color color,
  double? minY,
  double? maxY,
  String emptyLabel = '等待資料',
}) {
  if (data.length < 2) {
    return buildEmptyDataPlaceholder(emptyLabel);
  }

  final yValues = data.map((e) => e.y).toList();
  final computedMin = yValues.reduce(math.min);
  final computedMax = yValues.reduce(math.max);
  final range = (computedMax - computedMin).abs();
  final padding = range == 0 ? 5 : range * 0.15;

  final minAxis = minY ?? (computedMin - padding);
  final maxAxis = maxY ?? (computedMax + padding);

  return LineChart(
    LineChartData(
      minY: minAxis,
      maxY: maxAxis,
      backgroundColor: Colors.transparent,
      titlesData: const FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        horizontalInterval: range == 0 ? 1 : range / 4,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: Colors.white12,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: data,
          isCurved: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildMultiLineChartWidget(
  List<List<FlSpot>> dataSets,
  List<Color> colors, {
  String emptyLabel = '等待資料',
}) {
  final merged = <FlSpot>[];
  for (final set in dataSets) {
    if (set.length >= 2) {
      merged.addAll(set);
    }
  }
  if (merged.length < 2) {
    return buildEmptyDataPlaceholder(emptyLabel);
  }

  final yValues = merged.map((e) => e.y).toList();
  final minY = yValues.reduce(math.min);
  final maxY = yValues.reduce(math.max);
  final range = (maxY - minY).abs();
  final padding = range == 0 ? 5 : range * 0.2;

  return LineChart(
    LineChartData(
      minY: minY - padding,
      maxY: maxY + padding,
      backgroundColor: Colors.transparent,
      titlesData: const FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        horizontalInterval: range == 0 ? 1 : range / 4,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: Colors.white12,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        for (var i = 0; i < dataSets.length; i++)
          if (dataSets[i].length >= 2)
            LineChartBarData(
              spots: dataSets[i],
              isCurved: true,
              color: colors[i],
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
      ],
    ),
  );
}

Widget buildEmptyDataPlaceholder(String message) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.02),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.white54),
      ),
    ),
  );
}

class RulaStatistics {
  const RulaStatistics({
    required this.average,
    required this.max,
    required this.riskLevel,
  });

  final double average;
  final double max;
  final String riskLevel;
}

class HistoryDetailData {
  HistoryDetailData({
    required this.emgRms,
    required this.mvc,
    required this.jointAngles,
    required this.rula,
    required this.stats,
  });

  final Series emgRms;
  final Series mvc;
  final Map<String, Series> jointAngles;
  final Series rula;
  final RulaStatistics stats;

  factory HistoryDetailData.fromEmgSeries(Series source) {
    final emg = Series(List<FlSpot>.from(source.spots));

    double clamp(double value, double min, double max) =>
        value < min ? min : (value > max ? max : value);

    final mvcSpots = source.spots
        .map((spot) => FlSpot(spot.x, clamp(spot.y * 35, 0, 100)))
        .toList();

    final trunk = <FlSpot>[];
    final left = <FlSpot>[];
    final right = <FlSpot>[];
    final rulaSpots = <FlSpot>[];

    for (final spot in source.spots) {
      final t = spot.x;
      trunk.add(
        FlSpot(t, clamp(math.sin(t / 6) * 15 + spot.y * 0.1, -60, 60)),
      );
      left.add(
        FlSpot(t, clamp(math.cos(t / 5) * 20 + spot.y * 0.08, -80, 80)),
      );
      right.add(
        FlSpot(
          t,
          clamp(math.sin(t / 4 + 1.5) * 18 + spot.y * 0.05, -80, 80),
        ),
      );
      rulaSpots.add(
        FlSpot(
          t,
          clamp(2.5 + (spot.y / 40) + math.sin(t / 8) * 1.5, 0, 7),
        ),
      );
    }

    final avg = rulaSpots.isNotEmpty
        ? rulaSpots.map((e) => e.y).reduce((a, b) => a + b) / rulaSpots.length
        : 0.0;
    final max = rulaSpots.isNotEmpty
        ? rulaSpots.map((e) => e.y).reduce(math.max)
        : 0.0;

    final riskLevel = max >= 6
        ? 'High'
        : avg >= 4.5
            ? 'Medium'
            : 'Low';

    return HistoryDetailData(
      emgRms: emg,
      mvc: Series(mvcSpots),
      jointAngles: {
        'Trunk': Series(trunk),
        'Left': Series(left),
        'Right': Series(right),
      },
      rula: Series(rulaSpots),
      stats: RulaStatistics(average: avg, max: max, riskLevel: riskLevel),
    );
  }
}

/// Page that lists historic predictions and shows the selected record.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<void> _initialLoad;
  final Map<DateTime, List<HistoryItem>> _itemsByDate = {};
  List<HistoryItem> _items = [];
  List<int> _years = [];
  List<int> _months = [];
  List<int> _days = [];
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;
  FixedExtentScrollController? _yearController;
  FixedExtentScrollController? _monthController;
  FixedExtentScrollController? _dayController;
  HistoryDetailData? _detail;
  bool _loadingDetail = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialLoad = _loadHistoryIndex();
  }

  @override
  void dispose() {
    _yearController?.dispose();
    _monthController?.dispose();
    _dayController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialLoad,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_items.isEmpty) {
          return Center(
            child: Text(
              '尚未有歷史資料',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateSelector(context),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loadingDetail ? null : _loadDetailForSelection,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm'),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              if (_loadingDetail)
                const Center(child: CircularProgressIndicator())
              else if (_detail != null)
                _buildHistoryContent(context, _detail!)
              else
                buildEmptyDataPlaceholder('選擇日期以檢視紀錄'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadHistoryIndex() async {
    try {
      final items = await CloudApi.fetchHistoryIndex();
      if (!mounted) return;
      setState(() {
        _items = items;
        _groupItemsByDate();
        _initializeSelectors();
      });
      if (_items.isNotEmpty) {
        await _loadDetailForSelection();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '讀取歷史清單失敗：$e';
      });
    }
  }

  void _groupItemsByDate() {
    _itemsByDate.clear();
    for (final item in _items) {
      final key = DateTime(item.date.year, item.date.month, item.date.day);
      _itemsByDate.putIfAbsent(key, () => []).add(item);
    }
    _years = _itemsByDate.keys.map((e) => e.year).toSet().toList()..sort();
  }

  void _initializeSelectors() {
    if (_years.isEmpty) {
      _months = [];
      _days = [];
      return;
    }

    final year = _selectedYear != null && _years.contains(_selectedYear)
        ? _selectedYear!
        : _years.last;
    final months = _availableMonths(year);
    final month = _selectedMonth != null && months.contains(_selectedMonth)
        ? _selectedMonth!
        : months.last;
    final days = _availableDays(year, month);
    final day = _selectedDay != null && days.contains(_selectedDay)
        ? _selectedDay!
        : days.last;

    _months = months;
    _days = days;
    _selectedYear = year;
    _selectedMonth = month;
    _selectedDay = day;

    _yearController?.dispose();
    _monthController?.dispose();
    _dayController?.dispose();
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(year),
    );
    _monthController = FixedExtentScrollController(
      initialItem: months.indexOf(month),
    );
    _dayController = FixedExtentScrollController(
      initialItem: days.indexOf(day),
    );
  }

  List<int> _availableMonths(int year) {
    final months = _itemsByDate.keys
        .where((d) => d.year == year)
        .map((d) => d.month)
        .toSet()
        .toList()
      ..sort();
    return months;
  }

  List<int> _availableDays(int year, int month) {
    final days = _itemsByDate.keys
        .where((d) => d.year == year && d.month == month)
        .map((d) => d.day)
        .toSet()
        .toList()
      ..sort();
    return days;
  }

  Widget _buildDateSelector(BuildContext context) {
    if (_years.isEmpty) {
      return buildEmptyDataPlaceholder('無可用日期');
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F1F), Color(0xFF111111)],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPickerColumn(
              context,
              label: 'Year',
              values: _years,
              controller: _yearController,
              onSelected: (index) => _onYearChanged(_years[index]),
            ),
            _buildPickerColumn(
              context,
              label: 'Month',
              values: _months,
              controller: _monthController,
              onSelected: (index) => _onMonthChanged(_months[index]),
            ),
            _buildPickerColumn(
              context,
              label: 'Day',
              values: _days,
              controller: _dayController,
              onSelected: (index) => _onDayChanged(_days[index]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerColumn(
    BuildContext context, {
    required String label,
    required List<int> values,
    required FixedExtentScrollController? controller,
    required ValueChanged<int> onSelected,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
          ),
          SizedBox(
            height: 140,
            child: CupertinoPicker(
              backgroundColor: Colors.transparent,
              scrollController: controller,
              itemExtent: 36,
              squeeze: 1.1,
              looping: true,
              onSelectedItemChanged: onSelected,
              children: values
                  .map(
                    (v) => Center(
                      child: Text(
                        v.toString().padLeft(label == 'Year' ? 4 : 2, '0'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _onYearChanged(int year) {
    if (year == _selectedYear) return;
    setState(() {
      _selectedYear = year;
      _months = _availableMonths(year);
      _selectedMonth = _months.isNotEmpty ? _months.last : null;
      _days = _selectedMonth != null
          ? _availableDays(year, _selectedMonth!)
          : <int>[];
      _selectedDay = _days.isNotEmpty ? _days.last : null;
      _monthController?.dispose();
      _dayController?.dispose();
      _monthController = FixedExtentScrollController(
        initialItem: _selectedMonth != null ? _months.indexOf(_selectedMonth!) : 0,
      );
      _dayController = FixedExtentScrollController(
        initialItem: _selectedDay != null ? _days.indexOf(_selectedDay!) : 0,
      );
    });
  }

  void _onMonthChanged(int month) {
    if (month == _selectedMonth) return;
    final year = _selectedYear;
    if (year == null) return;
    setState(() {
      _selectedMonth = month;
      _days = _availableDays(year, month);
      _selectedDay = _days.isNotEmpty ? _days.last : null;
      _dayController?.dispose();
      _dayController = FixedExtentScrollController(
        initialItem: _selectedDay != null ? _days.indexOf(_selectedDay!) : 0,
      );
    });
  }

  void _onDayChanged(int day) {
    if (day == _selectedDay) return;
    setState(() {
      _selectedDay = day;
    });
  }

  Future<void> _loadDetailForSelection() async {
    final year = _selectedYear;
    final month = _selectedMonth;
    final day = _selectedDay;
    if (year == null || month == null || day == null) {
      return;
    }
    final key = DateTime(year, month, day);
    final matches = _itemsByDate[key];
    if (matches == null || matches.isEmpty) {
      setState(() {
        _detail = null;
      });
      return;
    }

    setState(() {
      _loadingDetail = true;
      _error = null;
    });

    HistoryDetailData? detail;
    String? error;
    try {
      final series = await CloudApi.fetchHistoryById(matches.first.id);
      detail = HistoryDetailData.fromEmgSeries(series);
    } catch (e) {
      error = '讀取紀錄失敗：$e';
    }

    if (!mounted) return;
    setState(() {
      _loadingDetail = false;
      _detail = detail;
      _error = error;
    });
  }

  Widget _buildHistoryContent(BuildContext context, HistoryDetailData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.05,
          children: [
            NeonPanel(
              title: 'EMG RMS',
              subtitle: 'Recorded waveform',
              body: buildLineChartWidget(
                data.emgRms.spots,
                color: kEmgColor,
              ),
            ),
            NeonPanel(
              title: '%MVC Trend',
              subtitle: 'Normalized muscle load',
              body: buildLineChartWidget(
                data.mvc.spots,
                color: kPrimaryAccent,
                minY: 0,
                maxY: 100,
              ),
            ),
            NeonPanel(
              title: 'Joint Angles',
              subtitle: 'Trunk · Left · Right',
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: buildMultiLineChartWidget(
                      [
                        data.jointAngles['Trunk']?.spots ?? const <FlSpot>[],
                        data.jointAngles['Left']?.spots ?? const <FlSpot>[],
                        data.jointAngles['Right']?.spots ?? const <FlSpot>[],
                      ],
                      const [kTrunkColor, kLeftShoulderColor, kRightShoulderColor],
                      emptyLabel: '等待關節角度資料',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: const [
                      _LegendChip(label: 'Trunk', color: kTrunkColor),
                      _LegendChip(label: 'Left Shoulder', color: kLeftShoulderColor),
                      _LegendChip(label: 'Right Shoulder', color: kRightShoulderColor),
                    ],
                  ),
                ],
              ),
            ),
            NeonPanel(
              title: 'RULA Score',
              subtitle: 'Daily posture trend',
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: buildLineChartWidget(
                      data.rula.spots,
                      color: kPrimaryAccent,
                      minY: 0,
                      maxY: 7,
                      emptyLabel: '等待 RULA 資料',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatisticsCard(context, data.stats),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsCard(BuildContext context, RulaStatistics stats) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: Colors.white.withOpacity(0.04),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatisticItem(theme, '平均分', stats.average.toStringAsFixed(1)),
          _buildStatisticItem(theme, '最高分', stats.max.toStringAsFixed(1)),
          _buildStatisticItem(theme, '風險等級', stats.riskLevel),
        ],
      ),
    );
  }

  Widget _buildStatisticItem(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _cloudSyncEnabled = true;
  String _selectedTheme = 'Aqua';
  final List<String> _themes = const ['Aqua', 'Amber', 'Violet'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            title: 'Bluetooth Device',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bluetooth_connected,
                      color: kPrimaryAccent),
                  title: const Text('ESP32_EMG_IMU'),
                  subtitle: const Text('Connected via Classic Bluetooth'),
                  trailing: FilledButton(
                    onPressed: () {},
                    child: const Text('Reconnect'),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.search, color: Colors.white70),
                  title: const Text('Scan for devices'),
                  subtitle: const Text('Tap to search nearby IMU modules'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          _buildSection(
            title: 'Cloud & Preferences',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  value: _cloudSyncEnabled,
                  onChanged: (value) => setState(() {
                    _cloudSyncEnabled = value;
                  }),
                  title: const Text('Enable cloud synchronization'),
                  subtitle:
                      const Text('Upload daily summaries to your workspace'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Theme Accent',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTheme,
                      dropdownColor: const Color(0xFF1C1C1C),
                      items: _themes
                          .map(
                            (theme) => DropdownMenuItem<String>(
                              value: theme,
                              child: Text(theme),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedTheme = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildSection(
            title: 'System Information',
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.memory, color: Colors.white70),
                  title: Text('Firmware Version'),
                  subtitle: Text('v1.3.2'),
                ),
                Divider(height: 1, color: Colors.white12),
                ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.white70),
                  title: Text('Support'),
                  subtitle: Text('support@ergomonitor.app'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F1F), Color(0xFF121212)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: kPrimaryAccent.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          child,
        ],
      ),
    );
  }
}
