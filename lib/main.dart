

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  bool _connecting = true;
  String? _error;
  double? _startTimestamp;
  double? _latestPct;

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
      _spots.clear();
      _lastX = 0;
      _startTimestamp = null;
      _latestPct = null;
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

    setState(() {
      double x;
      if (rawTs != null) {
        _startTimestamp ??= rawTs;
        x = (rawTs - _startTimestamp!) / 1000.0;
      } else {
        x = _lastX + 1;
      }
      _spots.add(FlSpot(x, emgRms));
      _lastX = x;
      _latestPct = pct;
      if (_spots.length > 500) {
        _spots.removeAt(0);
      }
    });

    _uploadToCloud(rawTs, emgRms, pct);
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('連線失敗：\n$_error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _connectAndListen,
              child: const Text('重新嘗試'),
            ),
          ],
        ),
      );
    }

    if (!_connected) {
      return const Center(child: Text('尚未連線到裝置'));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_spots.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('等待裝置資料中…'),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '最新 EMG RMS：${_spots.last.y.toStringAsFixed(2)}' +
                    (_latestPct != null
                        ? ' (${_latestPct!.toStringAsFixed(1)}%)'
                        : ''),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Expanded(
            child:
                RegressionChart(series: Series(_spots), title: '即時 EMG RMS'),
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
