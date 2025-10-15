import 'dart:convert';

import 'package:dio/dio.dart';
import 'dart:async';

class CloudApi {
  CloudApi._();

  static String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static String _workerId = '';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  static String get baseUrl => _baseUrl;
  static String get workerId => _workerId;

  static void setBaseUrl(String url) {
    _baseUrl = url.trim();
    _dio.options.baseUrl = _baseUrl;
  }

  static void setWorkerId(String id) {
    _workerId = id.trim();
  }

  static Future<Map<String, dynamic>> process({
    required String workerId,
    required double percentMvc,
    bool augmentHigh = true,
    DateTime? timestamp,
  }) async {
    final formData = FormData.fromMap({
      'worker_id': workerId,
      'augment_high': augmentHigh,
      if (timestamp != null) 'timestamp': timestamp.toUtc().toIso8601String(),
    });
    try {
      final res = await _dio.post('/process', data: formData);
      _emit(CloudEvent('process', true, 'worker=$workerId mvc=$percentMvc'));
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      _emit(CloudEvent('process', false, e.toString()));
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> train({
    required String workerId,
    required double percentMvc,
    bool augmentHigh = true,
    DateTime? timestamp,
  }) async {
    final formData = FormData.fromMap({
      'worker_id': workerId,
      'augment_high': augmentHigh,
      if (timestamp != null) 'timestamp': timestamp.toUtc().toIso8601String(),
    });
    try {
      final res = await _dio.post('/train', data: formData);
      _emit(CloudEvent('train', true, 'worker=$workerId mvc=$percentMvc'));
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      _emit(CloudEvent('train', false, e.toString()));
      rethrow;
    }
  }

  // 移除 status、predict 和 workers endpoints，因為新的 FastAPI 服務不支援這些功能

  // Events
  static final _eventsCtrl = StreamController<CloudEvent>.broadcast();
  static Stream<CloudEvent> get events => _eventsCtrl.stream;
  static void _emit(CloudEvent e) {
    if (!_eventsCtrl.isClosed) {
      _eventsCtrl.add(e);
    }
  }

  static Future<Map<String, dynamic>> health() async {
    try {
      final res = await _dio.get('/healthz');
      _emit(CloudEvent('health', true, 'ok'));
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      _emit(CloudEvent('health', false, e.toString()));
      rethrow;
    }
  }

  // 在此處新增靜態成員與方法，用於上傳 RULA 與 MVC 資料
  static Future<void> uploadRula({
    required String workerId,
    required int score,
    required String riskLabel,
    required DateTime timestamp,
  }) async {
    // TODO: 實作上傳 RULA 資料的邏輯
    return;
  }

  static Future<void> upload({
    required String workerId,
    required double percentMvc,
    required DateTime timestamp,
  }) async {
    // TODO: 實作上傳 MVC 資料的邏輯
    return;
  }
}

class CloudEvent {
  final String op; // upload/status/predict/workers
  final bool ok;
  final String message;
  final DateTime ts;
  CloudEvent(this.op, this.ok, this.message) : ts = DateTime.now();
}
