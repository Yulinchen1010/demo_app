import 'dart:async';

import 'dart:math' as math;



import 'package:fl_chart/fl_chart.dart';

import 'package:flutter/material.dart';

import '../../data/models.dart';



/// Fixed\u2011capacity ring buffer (overwrite when full).

class RingBuffer<T> {

  final int capacity;

  final List<T?> _buf;

  int _head = 0; // next write index

  int _len = 0;



  RingBuffer(this.capacity) : _buf = List<T?>.filled(capacity, null, growable: false);



  int get length => _len;

  bool get isEmpty => _len == 0;



  void add(T value) {

    _buf[_head] = value;

    _head = (_head + 1) % capacity;

    if (_len < capacity) _len++;

  }



  Iterable<T> items() sync* {

    if (_len == 0) return;

    final start = (_head - _len + capacity) % capacity;

    for (int i = 0; i < _len; i++) {

      final idx = (start + i) % capacity;

      final v = _buf[idx];

      if (v != null) yield v;

    }

  }



  void clear() {

    for (int i = 0; i < capacity; i++) {

      _buf[i] = null;

    }

    _head = 0;

    _len = 0;

  }

}



/// Time windows available for the chart.

enum TimeWindow { s30, s60, m5 }



extension TimeWindowX on TimeWindow {

  Duration get duration => switch (this) {

        TimeWindow.s30 => const Duration(seconds: 30),

        TimeWindow.s60 => const Duration(seconds: 60),

        TimeWindow.m5 => const Duration(minutes: 5),

      };



  String get label => switch (this) {

        TimeWindow.s30 => '30\u79d2',

        TimeWindow.s60 => '60\u79d2',

        TimeWindow.m5 => '5\u5206',

      };

}



/// Real\u2011time EMG chart with a wall\u2011clock aligned, sliding time window.

/// - Keeps a ring buffer sized to `windowSeconds * 10Hz`.

/// - Resamples input to 10Hz via fixed 100ms bins (mean of bin).

/// - Repaints up to 60 FPS, but coalesces frames when idle.

class RealtimeEmgChart extends StatefulWidget {

  final Stream<EmgPoint> stream;

  final TimeWindow initialWindow;

  final double? minY;

  final double? maxY;

  final String title;

  final double height;

  final bool compact;



  const RealtimeEmgChart({

    super.key,

    required this.stream,

    this.initialWindow = TimeWindow.s60,

    this.minY,

    this.maxY,

    this.title = 'EMG RMS',

    this.height = 220,

    this.compact = false,

  });



  @override

  State<RealtimeEmgChart> createState() => _RealtimeEmgChartState();

}



class _RealtimeEmgChartState extends State<RealtimeEmgChart> {

  late TimeWindow _windowSel;

  late RingBuffer<EmgPoint> _rb;

  StreamSubscription<EmgPoint>? _sub;

  Timer? _ticker;



  // Resampling bin

  static const _bin = Duration(milliseconds: 100); // 10Hz bins

  DateTime? _binStart;

  double _binSum = 0.0;

  int _binCount = 0;



  @override

  void initState() {

    super.initState();

    _windowSel = widget.initialWindow;

    _rb = RingBuffer<EmgPoint>(_capacityFor(_windowSel));

    _sub = widget.stream.listen(_onPoint, onError: (_) {}, onDone: () {});

    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {

      if (mounted) setState(() {}); // repaint at ~60 FPS

    });

  }



  @override

  void didUpdateWidget(covariant RealtimeEmgChart oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (oldWidget.stream != widget.stream) {

      _sub?.cancel();

      _rb.clear();

      _sub = widget.stream.listen(_onPoint, onError: (_) {}, onDone: () {});

    }

  }



  @override

  void dispose() {

    _sub?.cancel();

    _ticker?.cancel();

    super.dispose();

  }



  void _onPoint(EmgPoint p) {

    // Resample into 100ms bins

    final start = _binStart;

    if (start == null || p.ts.difference(start) >= _bin) {

      if (_binCount > 0) {

        final avg = _binSum / _binCount;

        _rb.add(EmgPoint(start ?? p.ts, avg));

      }

      _binStart = p.ts;

      _binSum = p.rms;

      _binCount = 1;

    } else {

      _binSum += p.rms;

      _binCount += 1;

    }



    // throw away anything older than the window from the front (implicit via capacity)

  }



  int _capacityFor(TimeWindow w) => (w.duration.inSeconds * 10).clamp(10, 6000);



  List<DropdownMenuItem<TimeWindow>> _windowItems() => TimeWindow.values

      .map((w) => DropdownMenuItem(value: w, child: Text(w.label)))

      .toList();



  @override

  Widget build(BuildContext context) {

    final now = DateTime.now();

    final window = _windowSel.duration;

    final minTs = now.subtract(window);



    final points = _rb

        .items()

        .where((p) => !p.ts.isBefore(minTs))

        .toList(); // growable: allow appending open bin



    // Ensure the last open bin gets flushed visually

    if (_binCount > 0 && _binStart != null && !_binStart!.isBefore(minTs)) {

      points.add(EmgPoint(_binStart!, _binSum / math.max(1, _binCount)));

    }



    final minX = minTs.millisecondsSinceEpoch.toDouble();

    final maxX = now.millisecondsSinceEpoch.toDouble();



    final minY = widget.minY ?? _autoMinY(points.map((e) => e.rms));

    final maxY = widget.maxY ?? _autoMaxY(points.map((e) => e.rms));



    final color = Theme.of(context).colorScheme.primary;

    final spots = points

        .map((e) => FlSpot(e.ts.millisecondsSinceEpoch.toDouble(), e.rms))

        .toList(growable: false);



    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        if (!widget.compact) Row(

          children: [

            Expanded(

              child: Text(

                widget.title,

                style: Theme.of(context)

                    .textTheme

                    .titleMedium

                    ?.copyWith(fontWeight: FontWeight.w600),

              ),

            ),

            DropdownButton<TimeWindow>(

              value: _windowSel,

              onChanged: (v) {

                if (v == null) return;

                setState(() {

                  _windowSel = v;

                  _rb = RingBuffer<EmgPoint>(_capacityFor(v));

                  _binStart = null;

                  _binSum = 0;

                  _binCount = 0;

                });

              },

              items: _windowItems(),

            )

          ],

        ),

        if (!widget.compact) const SizedBox(height: 8),

        if (spots.isEmpty)

          Container(

            height: widget.height,

            alignment: Alignment.center,

            decoration: BoxDecoration(

              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.2),

              borderRadius: BorderRadius.circular(8),

            ),

            child: const Text('\u7b49\u5f85\u8cc7\u6599\u2026'),

          )

        else

          SizedBox(

            height: widget.height,

            child: LineChart(

              LineChartData(

                minX: minX,

                maxX: maxX,

                minY: minY,

                maxY: maxY,

                gridData: FlGridData(show: !widget.compact),

                borderData: FlBorderData(show: true),

                titlesData: FlTitlesData(

                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                  leftTitles: AxisTitles(

                    sideTitles: SideTitles(showTitles: !widget.compact, reservedSize: !widget.compact ? 40 : 0),

                  ),

                  bottomTitles: AxisTitles(

                    sideTitles: SideTitles(

                      showTitles: !widget.compact,

                      interval: _tickInterval(window),

                      getTitlesWidget: (value, meta) => Padding(

                        padding: const EdgeInsets.only(top: 4),

                        child: Text(_fmtTs(value.toInt())),

                      ),

                    ),

                  ),

                ),

                lineBarsData: [

                  LineChartBarData(

                    isCurved: true,

                    color: color,

                    barWidth: 2,

                    dotData: const FlDotData(show: false),

                    spots: spots,

                  ),

                ],

              ),

            ),

          ),

      ],

    );

  }



  double _tickInterval(Duration window) {

    if (window <= const Duration(seconds: 30)) return 5 * 1000; // 5s

    if (window <= const Duration(minutes: 1)) return 10 * 1000; // 10s

    return 60 * 1000; // 1m

  }



  String _fmtTs(int ms) {

    final dt = DateTime.fromMillisecondsSinceEpoch(ms);

    final h = dt.hour.toString().padLeft(2, '0');

    final m = dt.minute.toString().padLeft(2, '0');

    final s = dt.second.toString().padLeft(2, '0');

    return '$h:$m:$s';

  }



  double _autoMinY(Iterable<double> values) {

    if (values.isEmpty) return 0;

    final m = values.reduce((a, b) => a < b ? a : b);

    return m - (m.abs() * 0.1 + 0.02);

  }



  double _autoMaxY(Iterable<double> values) {

    if (values.isEmpty) return 1;

    final m = values.reduce((a, b) => a > b ? a : b);

    return m + (m.abs() * 0.1 + 0.02);

  }

}

