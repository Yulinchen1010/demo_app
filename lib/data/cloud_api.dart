import 'dart:convert';

import 'package:dio/dio.dart';
import 'dart:async';

class CloudApi {
  CloudApi._();

  static String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.trim();
    _dio.options.baseUrl = _baseUrl;
  }

  static Future<Map<String, dynamic>> upload({
    required String workerId,
    required double percentMvc,
    DateTime? timestamp,
  }) async {
    final body = {
      'worker_id': workerId,
      'percent_mvc': percentMvc,
      if (timestamp != null) 'timestamp': timestamp.toUtc().toIso8601String(),
    };
    try {
      final res = await _dio.post('/upload', data: jsonEncode(body));
      _emit(CloudEvent('upload', true, 'worker=$workerId mvc=$percentMvc'));
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      _emit(CloudEvent('upload', false, e.toString()));
      rethrow;
    }
  }

  static Future<int> uploadBatch(List<Map<String, dynamic>> items) async {
    final body = {'data': items};
    try {
      final res = await _dio.post('/upload_batch', data: jsonEncode(body));
      final map = Map<String, dynamic>.from(res.data as Map);
      final n = (map['uploaded'] as num?)?.toInt() ?? 0;
      _emit(CloudEvent('upload_batch', true, 'uploaded=$n'));
      return n;
    } catch (e) {
      _emit(CloudEvent('upload_batch', false, e.toString()));
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> status(String workerId) async {
    try {
      final res = await _dio.get('/status/$workerId');
      _emit(CloudEvent('status', true, 'worker=$workerId'));
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      _emit(CloudEvent('status', false, e.toString()));
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> predict(String workerId,
      {int horizon = 120}) async {
    try {
      final res = await _dio.get('/predict/$workerId',
          queryParameters: {'horizon': horizon});
      _emit(CloudEvent('predict', true, 'worker=$workerId horizon=$horizon'));
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      _emit(CloudEvent('predict', false, e.toString()));
      rethrow;
    }
  }

  static Future<List<String>> workers() async {
    try {
      final res = await _dio.get('/workers');
      final list = (res.data as List).cast<dynamic>();
      _emit(CloudEvent('workers', true, 'count=${list.length}'));
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      _emit(CloudEvent('workers', false, e.toString()));
      rethrow;
    }
  }

  // Events
  static final _eventsCtrl = StreamController<CloudEvent>.broadcast();
  static Stream<CloudEvent> get events => _eventsCtrl.stream;
  static void _emit(CloudEvent e) {
    if (!_eventsCtrl.isClosed) {
      _eventsCtrl.add(e);
    }
  }
}

class CloudEvent {
  final String op; // upload/status/predict/workers
  final bool ok;
  final String message;
  final DateTime ts;
  CloudEvent(this.op, this.ok, this.message) : ts = DateTime.now();
}
