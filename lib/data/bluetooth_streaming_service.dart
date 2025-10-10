import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as classic;
import 'package:permission_handler/permission_handler.dart';

import 'models.dart';
import 'streaming_service.dart' show StreamStatus; // reuse status enum

/// Reads CSV lines from an ESP32 over Bluetooth Classic (SPP) and exposes
/// EMG points aligned to the device timestamp (ms).
class BluetoothStreamingService {
  final String deviceName;
  BluetoothStreamingService({this.deviceName = 'ESP32_EMG_IMU'});

  final _statusCtrl = StreamController<StreamStatus>.broadcast();
  final _emgCtrl = StreamController<EmgPoint>.broadcast();

  classic.FlutterBluetoothSerial get _bluetooth =>
      classic.FlutterBluetoothSerial.instance;
  classic.BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _sub;

  Stream<StreamStatus> get status => _statusCtrl.stream;
  Stream<EmgPoint> get emg => _emgCtrl.stream;

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
    // Expected CSV: ts_ms, emg_rms, emg_pct, imu...
    final parts = line.split(',');
    if (parts.length < 2) return;
    final tsMs = int.tryParse(parts[0]);
    final rms = double.tryParse(parts[1]);
    if (tsMs == null || rms == null) return;
    _emgCtrl.add(EmgPoint(DateTime.fromMillisecondsSinceEpoch(tsMs), rms));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _conn?.close();
    } catch (_) {}
    _conn = null;
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
}
