import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';

// 型別一律走 models.dart 的版本
import 'models.dart' as m;                 // m.EmgPoint, m.RulaScore
import 'mvc.dart';                         // MvcPoint
import 'streaming_service.dart' show StreamStatus;
import 'cloud_api.dart';
import 'rula.dart' as r;                   // 只用演算法 RulaCalculator

/// 透過藍牙（SPP）讀 CSV，輸出 EMG/MVC/RULA，並節流上傳到雲端。
class BluetoothStreamingService {
  final String deviceName;
  BluetoothStreamingService({this.deviceName = 'ESP32_EMG_IMU'});

  // ── Streams ────────────────────────────────────────────────────────────────
  final _statusCtrl = StreamController<StreamStatus>.broadcast();
  final _emgCtrl = StreamController<m.EmgPoint>.broadcast(); // EMG 走 EmgPoint
  final _mvcCtrl = StreamController<MvcPoint>.broadcast();
  final _rulaCtrl = StreamController<m.RulaScore>.broadcast();
  final _serverCtrl = StreamController<Map<String, dynamic>>.broadcast(); // 後端回應

  Stream<StreamStatus> get status => _statusCtrl.stream;
  Stream<m.EmgPoint> get emg => _emgCtrl.stream;
  Stream<MvcPoint> get mvc => _mvcCtrl.stream;
  Stream<m.RulaScore> get rula => _rulaCtrl.stream;
  Stream<Map<String, dynamic>> get serverResponses => _serverCtrl.stream;

  // ── BT 連線 ────────────────────────────────────────────────────────────────
  classic.FlutterBluetoothSerial get _bluetooth => classic.FlutterBluetoothSerial.instance;
  classic.BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _sub;

  // ── 節流上傳用 ──────────────────────────────────────────────────────────────
  DateTime? _lastRulaUploadAt;
  int? _lastUploadedRulaScore;

  DateTime? _lastMvcUploadAt;
  int? _lastUploadedMvcRounded;

  // ★ EMG RMS 上傳節流
  DateTime? _lastEmgUploadAt;
  double? _lastUploadedEmgRounded; // 取小數兩位做變化門檻

  // ── Lifecycle ─────────────────────────────────────────────────────────────
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

      // 避免使用退役 API；優先關掉舊連線
      try {
        if (_conn?.isConnected ?? false) {
          await _conn!.close();
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      } catch (_) {}

      _conn = await classic.BluetoothConnection.toAddress(dev.address);
      _statusCtrl.add(StreamStatus.connected);
      _listen();
    } catch (_) {
      _statusCtrl.add(StreamStatus.error);
      await stop();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _conn?.close();
    } catch (_) {}
    _conn = null;

    // 不關 EMG/MVC/RULA/server 的 controller（給 UI/上層持續監聽）
    // 只變更狀態
    _statusCtrl.add(StreamStatus.closed);
  }

  /// 完整釋放（離開 App 或不用此 service 時呼叫）
  Future<void> dispose() async {
    await stop(); // 先確保連線中止
    try { await _statusCtrl.close(); } catch (_) {}
    try { await _emgCtrl.close(); } catch (_) {}
    try { await _mvcCtrl.close(); } catch (_) {}
    try { await _rulaCtrl.close(); } catch (_) {}
    try { await _serverCtrl.close(); } catch (_) {}
  }

  // ── 讀取資料流 ─────────────────────────────────────────────────────────────
  void _listen() {
    final input = _conn?.input;
    if (input == null) {
      _statusCtrl.add(StreamStatus.error);
      return;
    }

    final buffer = StringBuffer();
    _sub = input.listen(
      (data) {
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
      },
      onDone: () => _statusCtrl.add(StreamStatus.closed),
      onError: (_) => _statusCtrl.add(StreamStatus.error),
      cancelOnError: false,
    );
  }

  void _handleLine(String line) {
    // CSV: ts_ms, emg_rms, percent_mvc, left_deg, right_deg, trunk_deg
    final parts = line.split(',');
    if (parts.length < 2) return;

    final tsMs = int.tryParse(parts[0]);
    final emgRms = double.tryParse(parts[1]);
    if (tsMs == null || emgRms == null) return;

    final ts = DateTime.fromMillisecondsSinceEpoch(tsMs);

    // EMG → EmgPoint
    if (!_emgCtrl.isClosed) {
      _emgCtrl.add(m.EmgPoint(ts, emgRms));
    }
    // ★ 上傳 EMG RMS（有節流）
    _maybeUploadEmgRms(emgRms, ts);

    // 第三欄 %MVC
    if (parts.length >= 3) {
      final mvc = double.tryParse(parts[2]);
      if (mvc != null) {
        final pct = mvc.clamp(0, 100).toDouble();
        if (!_mvcCtrl.isClosed) _mvcCtrl.add(MvcPoint(ts, pct));
        _maybeUploadMvc(pct, ts);
      }
    }

    // 角度 → RULA
    double? leftShoulder, rightShoulder, trunk;
    if (parts.length >= 4) leftShoulder = double.tryParse(parts[3]);
    if (parts.length >= 5) rightShoulder = double.tryParse(parts[4]);
    if (parts.length >= 6) trunk = double.tryParse(parts[5]);

    if (leftShoulder != null || rightShoulder != null || trunk != null) {
      final m.RulaScore score = r.RulaCalculator.fromAngles(
        leftShoulderDeg: leftShoulder,
        rightShoulderDeg: rightShoulder,
        trunkDeg: trunk,
      );
      if (!_rulaCtrl.isClosed) _rulaCtrl.add(score);
      _maybeUploadRula(score);
    }
  }

  // ── 上傳（節流） ───────────────────────────────────────────────────────────
  Future<void> _maybeUploadRula(m.RulaScore s) async {
    try {
      if (CloudApi.baseUrl.isEmpty || CloudApi.workerId.isEmpty) return;

      final now = DateTime.now();
      final shouldByScore = _lastUploadedRulaScore == null || _lastUploadedRulaScore != s.score;
      final shouldByTime = _lastRulaUploadAt == null || now.difference(_lastRulaUploadAt!).inSeconds >= 30;
      if (!shouldByScore && !shouldByTime) return;

      _lastUploadedRulaScore = s.score;
      _lastRulaUploadAt = now;

      final resp = await CloudApi.uploadJson([
        {
          'worker_id': CloudApi.workerId,
          'type': 'rula',
          'score': s.score,
          'risk_label': s.riskLabel ?? '',
          'timestamp': now.toUtc().toIso8601String(),
        }
      ]);
      if (resp != null && !_serverCtrl.isClosed) _serverCtrl.add(resp);
    } catch (_) {
      // 安靜失敗
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

      final resp = await CloudApi.uploadJson([
        {
          'worker_id': CloudApi.workerId,
          'type': 'mvc',
          'percent_mvc': percentMvc,
          'timestamp': ts.toUtc().toIso8601String(),
        }
      ]);
      if (resp != null && !_serverCtrl.isClosed) _serverCtrl.add(resp);
    } catch (_) {
      // 安靜失敗
    }
  }

  // ★ 新增：EMG RMS 上傳（節流）
  Future<void> _maybeUploadEmgRms(double rms, DateTime ts) async {
    try {
      if (CloudApi.baseUrl.isEmpty || CloudApi.workerId.isEmpty) return;

      final now = DateTime.now();

      // 以兩位小數作為變化判斷，避免過度頻繁
      final rounded = double.parse(rms.toStringAsFixed(2));
      final changed = _lastUploadedEmgRounded == null || _lastUploadedEmgRounded != rounded;

      // 每 5 秒至少送一次；有明顯變化就即時送
      final byTime = _lastEmgUploadAt == null || now.difference(_lastEmgUploadAt!).inSeconds >= 5;
      if (!changed && !byTime) return;

      _lastUploadedEmgRounded = rounded;
      _lastEmgUploadAt = now;

      // CloudApi 會幫忙正規化 {timestamp → ts, RMS 保留, MVC 可省略}
      final resp = await CloudApi.uploadJson([
        {
          'worker_id': CloudApi.workerId,
          'type': 'emg',                 // 方便後端/記錄辨識
          'RMS': rms,                    // 直接丟實際值
          'timestamp': ts.toUtc().toIso8601String(),
        }
      ]);
      if (resp != null && !_serverCtrl.isClosed) _serverCtrl.add(resp);
    } catch (_) {
      // 安靜失敗
    }
  }

  // ── 服務工具方法 ───────────────────────────────────────────────────────────
  Future<classic.BluetoothDevice?> _findDevice(String name) async {
    final bonded = await _bluetooth.getBondedDevices();
    for (final d in bonded) {
      if ((d.name ?? '').trim() == name) return d;
    }
    // 掃描找不到就回 null（也可改成 discovery）
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

    // 舊版相容
    return (await Permission.bluetooth.request().isGranted) ||
        (await Permission.locationWhenInUse.request().isGranted);
  }
}
