import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

enum StreamStatus { idle, connecting, connected, reconnecting, error, closed }

class TelemetrySample {
  final DateTime ts;
  final double emgRms;
  final RulaScore? rula;
  TelemetrySample(this.ts, this.emgRms, this.rula);
}

/// Reads real-time telemetry from a WebSocket and exposes typed streams.
class StreamingService {
  final String? url;
  final Duration _pingInterval = const Duration(seconds: 20);
  final Duration _initialBackoff = const Duration(seconds: 1);
  final Duration _maxBackoff = const Duration(seconds: 15);

  WebSocket? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(seconds: 1);

  final _statusCtrl = StreamController<StreamStatus>.broadcast();
  final _emgCtrl = StreamController<EmgPoint>.broadcast();
  final _rulaCtrl = StreamController<RulaScore>.broadcast();
  final _sampleCtrl = StreamController<TelemetrySample>.broadcast();

  StreamingService({this.url});

  Stream<StreamStatus> get status => _statusCtrl.stream;
  Stream<EmgPoint> get emg => _emgCtrl.stream;
  Stream<RulaScore> get rula => _rulaCtrl.stream;
  Stream<TelemetrySample> get samples => _sampleCtrl.stream;

  static const String kStreamUrl = String.fromEnvironment('STREAM_URL', defaultValue: '');
  static bool get hasConfiguredUrl => kStreamUrl.isNotEmpty;

  Future<void> start() async {
    final target = url ?? kStreamUrl;
    if (target.isEmpty) {
      _statusCtrl.add(StreamStatus.idle);
      return;
    }
    _connect(target);
  }

  void _connect(String target) async {
    _statusCtrl.add(StreamStatus.connecting);
    try {
      _ws = await WebSocket.connect(target);
      _statusCtrl.add(StreamStatus.connected);
      _backoff = _initialBackoff;
      // Configure ping on the socket after connect (Dart IO)
      try { _ws!.pingInterval = _pingInterval; } catch (_) {}
      _wsSub = _ws!.listen(
        _handleMessage,
        onDone: _scheduleReconnect,
        onError: (e, st) {
          _statusCtrl.add(StreamStatus.error);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _statusCtrl.add(StreamStatus.error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.close();
    _ws = null;
    _statusCtrl.add(StreamStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff, () {
      final target = url ?? kStreamUrl;
      if (target.isEmpty) return;
      _connect(target);
    });
    // exponential backoff with cap
    _backoff = _backoff * 2;
    if (_backoff > _maxBackoff) _backoff = _maxBackoff;
  }

  void _handleMessage(dynamic data) {
    try {
      final obj = data is String ? jsonDecode(data) : data;
      if (obj is! Map) return;
      final map = obj.map((k, v) => MapEntry(k.toString(), v));
      final tsMs = _asInt(map['ts_ms']) ?? _asInt(map['timestamp']) ?? DateTime.now().millisecondsSinceEpoch;
      final ts = DateTime.fromMillisecondsSinceEpoch(tsMs);
      final emg = (map['emg_rms'] is num) ? (map['emg_rms'] as num).toDouble() : _asNum(map['emg'])?.toDouble() ?? 0.0;
      RulaScore? rula;
      final r = map['rula'];
      if (r is Map) {
        final score = _asInt(r['score']);
        final label = r['risk_label']?.toString();
        if (score != null) rula = RulaScore(score, riskLabel: label);
      }

      final point = EmgPoint(ts, emg);
      _emgCtrl.add(point);
      if (rula != null) _rulaCtrl.add(rula);
      _sampleCtrl.add(TelemetrySample(ts, emg, rula));
    } catch (_) {
      // ignore malformed frames
    }
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _wsSub?.cancel();
    try {
      await _ws?.close();
    } catch (_) {}
    await _statusCtrl.close();
    await _emgCtrl.close();
    await _rulaCtrl.close();
    await _sampleCtrl.close();
  }
}
