import 'dart:convert';

import 'package:dio/dio.dart';

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
    final res = await _dio.post('/upload', data: jsonEncode(body));
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<int> uploadBatch(List<Map<String, dynamic>> items) async {
    final body = {'data': items};
    final res = await _dio.post('/upload_batch', data: jsonEncode(body));
    final map = Map<String, dynamic>.from(res.data as Map);
    return (map['uploaded'] as num?)?.toInt() ?? 0;
  }

  static Future<Map<String, dynamic>> status(String workerId) async {
    final res = await _dio.get('/status/$workerId');
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<Map<String, dynamic>> predict(String workerId,
      {int horizon = 120}) async {
    final res = await _dio.get('/predict/$workerId',
        queryParameters: {'horizon': horizon});
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<List<String>> workers() async {
    final res = await _dio.get('/workers');
    final list = (res.data as List).cast<dynamic>();
    return list.map((e) => e.toString()).toList();
  }
}

