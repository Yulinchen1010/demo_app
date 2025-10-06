

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final granted = await _ensurePermissions();
    if (!granted) {
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

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final scanStatus = await Permission.bluetoothScan.request();
    final connectStatus = await Permission.bluetoothConnect.request();

    if (scanStatus.isGranted && connectStatus.isGranted) {
      return true;
    }

    final locationStatuses = await [
      Permission.locationWhenInUse,
      Permission.location,
    ].request();

    if (locationStatuses.values.any((s) => !s.isGranted)) {
      return false;
    }

    final retryScan = await Permission.bluetoothScan.request();
    final retryConnect = await Permission.bluetoothConnect.request();
    return retryScan.isGranted && retryConnect.isGranted;
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
        final parts = line.split(',');
        if (parts.length >= 2) {
          final ts = double.tryParse(parts[0]) ?? (_lastX + 1);
          final emgRms = double.tryParse(parts[1]) ?? 0.0;
          setState(() {
            _spots.add(FlSpot(ts, emgRms));
            _lastX = ts;
            if (_spots.length > 500) _spots.removeAt(0);
          });
          _uploadToCloud(ts, emgRms);
        }
      });
    } catch (e) {
      debugPrint('❌ Bluetooth connect error: $e');
    }
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
      child: RegressionChart(series: Series(_spots), title: '即時 EMG RMS'),
    );
  }

  @override
  void dispose() {
    esp32.dispose();
    super.dispose();
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
