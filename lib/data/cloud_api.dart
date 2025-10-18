import 'dart:async';
import 'package:dio/dio.dart';

class CloudApi {
  CloudApi._();

  // Render base URL
  static String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ai-predictor-emg-imu.onrender.com',
  );
  static String _workerId = '';

  // 內部狀態
  static Timer? _autoTimer;
  static Duration _interval = const Duration(minutes: 1);
  static bool _autoRunning = false;

  // ★ 防重入：避免 _autoTick 併發
  static bool _tickBusy = false;

  // 可選：由外部提供資料的 callback（若給了就用它；否則送 heartbeat）
  static List<Map<String, dynamic>> Function()? _rowsProvider;
  static double Function()? _percentMvcProvider;

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Accept': 'application/json'}, // 確保回傳 JSON
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        // ignore: avoid_print
        print('[REQ] ${o.method} ${o.baseUrl}${o.path} '
            'ct=${o.headers['content-type']} qp=${o.queryParameters}');
        h.next(o);
      },
      onResponse: (r, h) {
        // ignore: avoid_print
        final s = r.data?.toString();
        if (s != null) {
          final head = s.length > 200 ? '${s.substring(0, 200)}...' : s;
          print('[RES] ${r.requestOptions.path} -> ${r.statusCode} body=$head');
        } else {
          print('[RES] ${r.requestOptions.path} -> ${r.statusCode} (no body)');
        }
        h.next(r);
      },
      onError: (e, h) {
        // ignore: avoid_print
        print('[ERR] ${e.requestOptions.path} -> '
            '${e.response?.statusCode} ${e.response?.data}');
        h.next(e);
      },
    ));

  static String get baseUrl => _baseUrl;
  static String get workerId => _workerId;
  static bool get autoRunning => _autoRunning;
  static Duration get interval => _interval;

  static void setBaseUrl(String url) {
    _baseUrl = url.trim();
    _dio.options.baseUrl = _baseUrl;
  }

  static void setWorkerId(String id) {
    _workerId = id.trim();
  }

  /// 設定自動上傳的資料來源（兩者擇一）：
  /// - rowsProvider：回傳要上傳的 JSON 陣列（任何鍵名皆可，會自動正規化）
  /// - percentMvcProvider：只有一個數值，用 heartbeat 形式上傳
  static void setProviders({
    List<Map<String, dynamic>> Function()? rowsProvider,
    double Function()? percentMvcProvider,
  }) {
    _rowsProvider = rowsProvider;
    _percentMvcProvider = percentMvcProvider;
  }

  /// 調整自動上傳週期（預設 1 分鐘）
  static void setInterval(Duration d) {
    _interval = d;
    if (_autoRunning) {
      stopAutoUpload();
      startAutoUpload(workerId: _workerId);
    }
  }

  // ---------- 健康檢查：/healthz ----------
  static Future<Map<String, dynamic>> health() async {
    try {
      final res = await _dio.get(
        '/healthz',
        options: Options(responseType: ResponseType.json),
      );
      _emit(CloudEvent('health', true, 'ok'));
      return _asMap(res.data);
    } on DioException catch (e) {
      final msg =
          'health failed: ${e.response?.statusCode} ${e.response?.data ?? e.message}';
      _emit(CloudEvent('health', false, msg));
      rethrow;
    }
  }

  // ---------- 上傳 JSON 陣列到 /process_json ----------
  // 如果 rows 本身就是 {worker_id, percent_mvc, timestamp} 三欄，則「直通」不上濾。
  // 其餘情境（例如送 MVC/RMS/ts 等），才會做 normalize。
  static Future<Map<String, dynamic>?> uploadJson(
    dynamic rows, {
    bool augmentHigh = false,
  }) async {
    final payload = _ensureJsonArray(rows);

    // 三欄直通
    if (_looksLikePlainAvg(payload)) {
      try {
        _emit(CloudEvent(
            'upload_start', true, 'rows=${payload.length} (passthrough)'));
        final res = await _dio.post(
          '/process_json',
          data: payload,
          queryParameters: {'augment_high': augmentHigh},
          options: Options(
            contentType: 'application/json',
            responseType: ResponseType.json,
          ),
        );
        _emit(CloudEvent(
            'upload_json', true, 'rows=${payload.length} (passthrough)'));
        _emit(CloudEvent(
            'upload', true, 'rows=${payload.length} (passthrough)'));
        return _asMap(res.data);
      } on DioException catch (e) {
        final msg =
            'uploadJson failed: ${e.response?.statusCode} ${e.response?.data ?? e.message}';
        _emit(CloudEvent('upload_json', false, msg));
        _emit(CloudEvent('upload', false, msg));
        rethrow;
      }
    }

    // 其他格式才正規化
    final normalized = _normalizeRows(payload);
    try {
      _emit(CloudEvent(
          'upload_start', true, 'rows=${normalized.length} (normalized)'));
      final res = await _dio.post(
        '/process_json',
        data: normalized,
        queryParameters: {'augment_high': augmentHigh},
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.json,
        ),
      );
      _emit(CloudEvent(
          'upload_json', true, 'rows=${normalized.length} (normalized)'));
      _emit(CloudEvent(
          'upload', true, 'rows=${normalized.length} (normalized)'));
      return _asMap(res.data);
    } on DioException catch (e) {
      final msg =
          'uploadJson failed: ${e.response?.statusCode} ${e.response?.data ?? e.message}';
      _emit(CloudEvent('upload_json', false, msg));
      _emit(CloudEvent('upload', false, msg));
      rethrow;
    }
  }

  // ---------- 輕量單筆（heartbeat） ----------
  static Future<Map<String, dynamic>> process({
    required String workerId,
    double percentMvc = 0.0,
    bool augmentHigh = true,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;

    final rows = [
      {
        'ts': nowSec,
        'MVC': percentMvc / 100.0, // 0~1；後端也容忍 0~100
        'RMS': 0.0,
        'worker_id': workerId,
        'timestamp': nowIso,
        'type': 'heartbeat',
      }
    ];

    try {
      _emit(CloudEvent('upload_start', true, 'heartbeat'));
      final res = await _dio.post(
        '/process_json',
        data: rows,
        queryParameters: {'augment_high': augmentHigh},
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.json,
        ),
      );
      _emit(CloudEvent('process', true, 'worker=$workerId mvc=$percentMvc'));
      _emit(CloudEvent('upload', true, 'worker=$workerId mvc=$percentMvc'));
      return _asMap(res.data);
    } on DioException catch (e) {
      final msg =
          'process failed: ${e.response?.statusCode} ${e.response?.data ?? e.message}';
      _emit(CloudEvent('process', false, msg));
      _emit(CloudEvent('upload', false, msg));
      rethrow;
    }
  }

  // ---------- 查詢運算結果（風險等級/MVC 等） ----------
  static Future<Map<String, dynamic>> getStatus(String workerId) async {
    try {
      final res = await _dio.get(
        '/status/$workerId',
        options: Options(responseType: ResponseType.json),
      );
      _emit(CloudEvent('status', true, 'ok'));
      return _asMap(res.data);
    } on DioException catch (e) {
      final msg =
          'getStatus failed: ${e.response?.statusCode} ${e.response?.data ?? e.message}';
      _emit(CloudEvent('status', false, msg));
      rethrow;
    }
  }

  // ---------- 自動上傳 ----------
  static Future<void> startAutoUpload({
    required String workerId,
    bool augmentHigh = false,
  }) async {
    _workerId = workerId.trim();
    if (_autoRunning) return;

    try {
      await health();
    } catch (_) {
      return; // 健康檢查失敗不啟動
    }

    _autoRunning = true;
    _emit(CloudEvent('autostart', true, 'interval=${_interval.inSeconds}s'));

    await _autoTick(augmentHigh: augmentHigh);

    _autoTimer = Timer.periodic(_interval, (_) async {
      await _autoTick(augmentHigh: augmentHigh);
    });
  }

  static Future<void> _autoTick({required bool augmentHigh}) async {
    if (_tickBusy) {
      _emit(CloudEvent('auto_tick', false, 'busy'));
      return;
    }
    _tickBusy = true;

    try {
      if (_rowsProvider != null) {
        final rows = _rowsProvider!.call();
        await uploadJson(rows, augmentHigh: augmentHigh);
      } else {
        final mvc = _percentMvcProvider?.call() ?? 0.0;
        await process(
          workerId: _workerId,
          percentMvc: mvc,
          augmentHigh: augmentHigh,
        );
      }
      _emit(CloudEvent('auto_tick', true, 'sent'));
    } catch (e) {
      _emit(CloudEvent('auto_tick', false, e.toString()));
    } finally {
      _tickBusy = false;
    }
  }

  static void stopAutoUpload() {
    _autoTimer?.cancel();
    _autoTimer = null;
    final wasRunning = _autoRunning;
    _autoRunning = false;
    if (wasRunning) _emit(CloudEvent('autostop', true, 'stopped'));
  }

  // ---------- 事件流（給 UI 顯示 log） ----------
  static final _eventsCtrl = StreamController<CloudEvent>.broadcast();
  static Stream<CloudEvent> get events => _eventsCtrl.stream;
  static void _emit(CloudEvent e) {
    if (!_eventsCtrl.isClosed) _eventsCtrl.add(e);
  }

  // ---------- 小工具 ----------
  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data}; // 陣列/字串/數字就放在 data 裡
  }

  // 允許傳 Map 或 List<Map>；統一轉 List<Map>
  static List<Map<String, dynamic>> _ensureJsonArray(dynamic rows) {
    if (rows == null) return <Map<String, dynamic>>[];
    if (rows is List) {
      return rows
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (rows is Map) return [Map<String, dynamic>.from(rows)];
    throw ArgumentError('rows 必須是 List<Map> 或 Map 單筆');
  }

  // 檢查是否為「只包含 worker_id / percent_mvc / timestamp」的三欄平均上傳格式
  static bool _looksLikePlainAvg(List<Map<String, dynamic>> rows) {
    const allowed = {'worker_id', 'percent_mvc', 'timestamp'};
    for (final m in rows) {
      final keys = m.keys.toSet();
      if (keys.length != 3 || !allowed.containsAll(keys)) return false;

      // 型別粗檢
      final wid = m['worker_id'];
      final pmv = m['percent_mvc'];
      final ts = m['timestamp'];
      final pmvOk =
          (pmv is num) || (pmv is String && double.tryParse(pmv) != null);
      final tsOk = ts is String; // ISO-8601 字串

      if (wid == null || !pmvOk || !tsOk) return false;
    }
    return true;
  }

  /// 正規化：把任意 rows 轉成後端要的形狀，且保留其他欄位（worker_id/type…）
  static List<Map<String, dynamic>> _normalizeRows(
      List<Map<String, dynamic>> rows) {
    double _toTsSec(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt.millisecondsSinceEpoch / 1000.0;
      }
      return DateTime.now().millisecondsSinceEpoch / 1000.0;
    }

    double? _toMvc01(dynamic v) {
      if (v == null) return null;
      if (v is num) {
        final x = v.toDouble();
        return x <= 1.0 ? x : (x / 100.0);
      }
      if (v is String) {
        final n = double.tryParse(v);
        if (n != null) return n <= 1.0 ? n : (n / 100.0);
      }
      return null;
    }

    double? _toRms(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return rows.map<Map<String, dynamic>>((m) {
      final out = Map<String, dynamic>.from(m);

      // ts / timestamp
      final tsSec =
          out.containsKey('ts') ? _toTsSec(out['ts']) : _toTsSec(out['timestamp']);
      out['ts'] = tsSec;

      out['timestamp'] = out['timestamp'] ??
          DateTime.fromMillisecondsSinceEpoch((tsSec * 1000).round())
              .toUtc()
              .toIso8601String();

      // MVC: 聚合到 out['MVC']，0..1
      final mvc =
          _toMvc01(out['MVC'] ?? out['percent_mvc'] ?? out['mvc'] ?? out['emg_pct']);
      if (mvc != null) {
        out['MVC'] = mvc;
      } else {
        out.remove('MVC');
      }

      // RMS: 聚合到 out['RMS']
      final rms = _toRms(out['RMS'] ?? out['emg_rms'] ?? out['rms'] ?? out['emg']);
      if (rms != null) {
        out['RMS'] = rms;
      } else if (!out.containsKey('MVC')) {
        // 兩者都沒給的話，至少填一個 0.0，避免空 payload
        out['RMS'] = 0.0;
      }

      // 清掉別名殘件
      out.remove('percent_mvc');
      out.remove('mvc');
      out.remove('emg_pct');
      out.remove('emg_rms');
      out.remove('rms');
      out.remove('emg');

      return out;
    }).toList();
  }
}

class CloudEvent {
  // 'health' | 'upload_start' | 'upload_json' | 'process' | 'status' | 'upload' | 'autostart' | 'auto_tick' | 'autostop'
  final String op;
  final bool ok;
  final String message;
  final DateTime ts;
  CloudEvent(this.op, this.ok, this.message) : ts = DateTime.now();
}
