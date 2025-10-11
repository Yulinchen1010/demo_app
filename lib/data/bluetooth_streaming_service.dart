import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as classic;
import 'package:permission_handler/permission_handler.dart';

import 'models.dart';
import 'mvc.dart';
import 'streaming_service.dart' show StreamStatus; // reuse status enum
import 'cloud_api.dart';
import 'rula.dart';

/// Reads CSV lines from an ESP32 over Bluetooth Classic (SPP) and exposes
/// EMG points aligned to the device timestamp (ms).
class BluetoothStreamingService {
  final String deviceName;
  BluetoothStreamingService({this.deviceName = 'ESP32_EMG_IMU'});

  final _statusCtrl = StreamController<StreamStatus>.broadcast();
  final _emgCtrl = StreamController<EmgPoint>.broadcast();
  final _mvcCtrl = StreamController<MvcPoint>.broadcast();
  final _rulaCtrl = StreamController<RulaScore>.broadcast();

  classic.FlutterBluetoothSerial get _bluetooth =>
      classic.FlutterBluetoothSerial.instance;
  classic.BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _sub;
  DateTime? _lastRulaUploadAt;
  int? _lastUploadedRulaScore;
  DateTime? _lastMvcUploadAt;
  int? _lastUploadedMvcRounded;

  Stream<StreamStatus> get status => _statusCtrl.stream;
  Stream<EmgPoint> get emg => _emgCtrl.stream;
  Stream<MvcPoint> get mvc => _mvcCtrl.stream;
  Stream<RulaScore> get rula => _rulaCtrl.stream;

  Future<void> start() async {
    if (kIsWeb) {
      _statusCtrl.add(StreamStatus.error);
      return;
    }
    _statusCtrl.add(StreamStatus.connecting);
    try {
      final ok = await _ensurePermissions();
      if (!ok) {
        _statusCtrl.add(StreamStatus.error);
        return;
      }
      await _bluetooth.cancelDiscovery().catchError((_) {});
      final dev = await _findDevice(deviceName);
      if (dev == null) {
        _statusCtrl.add(StreamStatus.error);
        return;
      }
      _conn = await classic.BluetoothConnection.toAddress(dev.address);
      _statusCtrl.add(StreamStatus.connected);
      _listen();
    } catch (_) {
      _statusCtrl.add(StreamStatus.error);
      await stop();
    }
  }

  void _listen() {
    final input = _conn?.input;
    if (input == null) {
      _statusCtrl.add(StreamStatus.error);
      return;
    }
    final buffer = StringBuffer();
    _sub = input.listen((data) {
      buffer.write(utf8.decode(data, allowMalformed: true));
      while (true) {
        final s = buffer.toString();
        final idx = s.indexOf('\n');
        if (idx < 0) break;
        final line = s.substring(0, idx).trim();
        buffer
          ..clear()
          ..write(idx + 1 < s.length ? s.substring(idx + 1) : '');
        if (line.isNotEmpty) _handleLine(line);
      }
    }, onDone: () => _statusCtrl.add(StreamStatus.closed),
        onError: (_) => _statusCtrl.add(StreamStatus.error),
        cancelOnError: false);
  }

  void _handleLine(String line) {
    // Flexible CSV parser.
    // Preferred layout: ts_ms, emg_rms, percent_mvc, left_shoulder_deg, right_shoulder_deg, trunk_deg
    final parts = line.split(',');
    if (parts.length < 2) return;
    final tsMs = int.tryParse(parts[0]);
    final rms = double.tryParse(parts[1]);
    if (tsMs == null || rms == null) return;
    _emgCtrl.add(EmgPoint(DateTime.fromMillisecondsSinceEpoch(tsMs), rms));

    // Optional %MVC as third column
    if (parts.length >= 3) {
      final mvc = double.tryParse(parts[2]);
      if (mvc != null) {
        final pct = mvc.clamp(0, 100).toDouble();
        final ts = DateTime.fromMillisecondsSinceEpoch(tsMs);
        if (!_mvcCtrl.isClosed) {
          _mvcCtrl.add(MvcPoint(ts, pct));
        }
        _maybeUploadMvc(pct, ts);
      }
    }

    // Try parse optional angles if provided
    double? leftShoulder;
    double? rightShoulder;
    double? trunk;
    if (parts.length >= 4) leftShoulder = double.tryParse(parts[3]);
    if (parts.length >= 5) rightShoulder = double.tryParse(parts[4]);
    if (parts.length >= 6) trunk = double.tryParse(parts[5]);
    if (leftShoulder != null || rightShoulder != null || trunk != null) {
      final score = RulaCalculator.fromAngles(
        leftShoulderDeg: leftShoulder,
        rightShoulderDeg: rightShoulder,
        trunkDeg: trunk,
      );
      if (!_rulaCtrl.isClosed) _rulaCtrl.add(score);
      _maybeUploadRula(score);
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _conn?.close();
    } catch (_) {}
    _conn = null;
    // Do not close controllers (reusable service), just leave streams open
  }

  Future<classic.BluetoothDevice?> _findDevice(String name) async {
    final bonded = await _bluetooth.getBondedDevices();
    for (final d in bonded) {
      if ((d.name ?? '').trim() == name) return d;
    }
    // fallback to discovery (requires location/scan permission)
    classic.BluetoothDiscoveryResult? hit;
    final stream = _bluetooth.startDiscovery();
    try {
      await for (final r in stream) {
        if ((r.device.name ?? '').trim() == name) {
          hit = r;
          break;
        }
      }
    } finally {
      await _bluetooth.cancelDiscovery().catchError((_) {});
    }
    return hit?.device;
  }

  Future<bool> _ensurePermissions() async {
    // Android 12+
    final req = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final ok = (req[Permission.bluetoothScan]?.isGranted ?? false) &&
        (req[Permission.bluetoothConnect]?.isGranted ?? false);
    if (ok) return true;
    // Older fallback
    return (await Permission.bluetooth.request().isGranted) ||
        (await Permission.locationWhenInUse.request().isGranted);
  }

  Future<void> _maybeUploadRula(RulaScore s) async {
    try {
      if (CloudApi.baseUrl.isEmpty || CloudApi.workerId.isEmpty) return;
      final now = DateTime.now();
      final lastScore = _lastUploadedRulaScore;
      final shouldByScore = lastScore == null || lastScore != s.score;
      final shouldByTime = _lastRulaUploadAt == null || now.difference(_lastRulaUploadAt!).inSeconds >= 30;
      if (!shouldByScore && !shouldByTime) return;
      _lastUploadedRulaScore = s.score;
      _lastRulaUploadAt = now;
      await CloudApi.uploadRula(
        workerId: CloudApi.workerId,
        score: s.score,
        riskLabel: s.riskLabel,
        timestamp: now,
      );
    } catch (_) {
      // ignore upload errors
    }
  }

  Future<void> _maybeUploadMvc(double percentMvc, DateTime ts) async {
    try {
      if (CloudApi.baseUrl.isEmpty || CloudApi.workerId.isEmpty) return;
      final now = DateTime.now();
      final rounded = percentMvc.round();
      final byValue = _lastUploadedMvcRounded == null || _lastUploadedMvcRounded != rounded;
      final byTime = _lastMvcUploadAt == null || now.difference(_lastMvcUploadAt!).inSeconds >= 10;
      if (!byValue && !byTime) return;
      _lastUploadedMvcRounded = rounded;
      _lastMvcUploadAt = now;
      await CloudApi.upload(
        workerId: CloudApi.workerId,
        percentMvc: percentMvc,
        timestamp: ts,
      );
    } catch (_) {
      // ignore upload errors
    }
  }
}
