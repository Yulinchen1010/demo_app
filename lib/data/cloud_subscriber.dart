import 'dart:async';
import 'package:flutter/foundation.dart';
import 'cloud_api.dart';
import 'status_mapper.dart';

class CloudStatusData {
  final String workerId;
  final String label;
  final int riskLevel;    // 1:低 2:中 3:高 4:嚴重（若後端有）
  final String riskColor; // hex
  final DateTime ts;

  CloudStatusData({
    required this.workerId,
    required this.label,
    required this.riskLevel,
    required this.riskColor,
    required this.ts,
  });
}

/// 採樣自 BLE/MCU 的 %MVC（本地已算好），做 1 分鐘平均，上傳後端。
/// 同時以 /process 作為 heartbeat 拉回雲端狀態供 UI 顯示。
class CloudStatusSubscriber {
  CloudStatusSubscriber({this.interval = const Duration(seconds: 5)});

  /// 輪詢雲端狀態的間隔（heartbeat）
  final Duration interval;

  final _ctrl = StreamController<CloudStatusData>.broadcast();
  Stream<CloudStatusData> get stream => _ctrl.stream;

  Timer? _pollTimer;
  Timer? _uploadTimer;
  bool _running = false;

  // 最近 1 分鐘的 %MVC
  final List<double> _mvcBuffer = <double>[];

  // 採樣限制與有效範圍
  static const int _maxSamplesPerMinute = 600; // 10Hz × 60s，可依實際頻率調整
  static const double _minMvc = 0.0;
  static const double _maxMvc = 100.0;

  // 併發保護旗標
  bool _polling = false;
  bool _uploading = false;

  bool get isRunning => _running;

  /// 外部主動推送雲端狀態（例如 BT 端解析到伺服器回應）
  void addStatus(CloudStatusData data) {
    if (!_ctrl.isClosed) _ctrl.add(data);
  }

  /// 由 BLE/MCU 層把「本地已算好」的 %MVC 丟進來（單位：百分比 0–100）
  void pushLocalMvc(double mvc) {
    if (!mvc.isFinite) return;
    if (mvc < _minMvc || mvc > _maxMvc) return; // 超出 0–100 視為無效
    _mvcBuffer.add(mvc);
    // 保留最近 1 分鐘容量，避免高頻塞爆記憶體
    if (_mvcBuffer.length > _maxSamplesPerMinute) {
      _mvcBuffer.removeRange(0, _mvcBuffer.length - _maxSamplesPerMinute);
    }
  }

  /// 啟動：固定輪詢雲端狀態 + 每分鐘上傳一次平均值
  void start({String? workerId}) {
    if (_running) return;
    _running = true;

    // 先做一次 heartbeat
    _tick(workerId: workerId);

    // 固定輪詢雲端狀態
    _pollTimer = Timer.periodic(interval, (_) => _tick(workerId: workerId));

    // 每分鐘上傳一次平均值
    _uploadTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _uploadAverage(workerId: workerId),
    );
  }

  /// 停止所有計時器
  Future<void> stop() async {
    _pollTimer?.cancel();
    _uploadTimer?.cancel();
    _pollTimer = null;
    _uploadTimer = null;
    _running = false;
  }

  /// Flutter 的 State.dispose() 不能 async/await，所以做成同步即可
  void dispose() {
    stop();
    _ctrl.close();
  }

  /// 每次輪詢雲端：用 /process 當 heartbeat（不收集資料）
  Future<void> _tick({String? workerId}) async {
    if (_polling) return; // 併發保護
    _polling = true;

    try {
      final id = (workerId ?? CloudApi.workerId).trim();
      if (CloudApi.baseUrl.isEmpty || id.isEmpty) return;

      final res = await CloudApi.process(
        workerId: id,
        percentMvc: 0,      // 這裡不傳本地值，只當心跳
        augmentHigh: true,
      );

      // 後端會直接給 level；統一交給 mapper
      final rv = StatusMapper.fromResponse(res);

      final data = CloudStatusData(
        workerId: id,
        label: rv.label,
        riskLevel: rv.level,
        riskColor: rv.colorHex,
        ts: DateTime.now(),
      );

      if (_running && !_ctrl.isClosed) {
        _ctrl.add(data);
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Cloud poll error: $e');
      }
    } finally {
      _polling = false;
    }
  }

  /// 每分鐘把 buffer 取平均，上傳到 /process_json
  Future<void> _uploadAverage({String? workerId}) async {
    if (_uploading) return;     // 併發保護
    if (_mvcBuffer.isEmpty) return;

    _uploading = true;
    try {
      // 計算平均並清空
      final sum = _mvcBuffer.fold<double>(0.0, (a, b) => a + b);
      final avgMvc = sum / _mvcBuffer.length;
      _mvcBuffer.clear();

      if (!avgMvc.isFinite) return;

      final id = (workerId ?? CloudApi.workerId).trim();
      if (id.isEmpty) return;

      final rows = <Map<String, dynamic>>[
        {
          'worker_id': id,
          'type': 'mvc_avg_1min', // ← 加上標記，與即時 mvc 資料區分
          'percent_mvc': avgMvc,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      ];

      if (kDebugMode) {
        // ignore: avoid_print
        print('⬆️ 上傳 rows=$rows');
      }

      await CloudApi.uploadJson(rows, augmentHigh: true);

      if (kDebugMode) {
        // ignore: avoid_print
        print('✅ 每分鐘平均上傳成功：worker=$id avgMVC=${avgMvc.toStringAsFixed(2)}');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('⚠️ 平均上傳失敗: $e');
      }
    } finally {
      _uploading = false;
    }
  }
}
