import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/history_repository.dart';

enum HistoryState { idle, loading, loaded, empty }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late DateTime _selected;
  late final List<int> _years;
  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;

  int _yearIndex = 0;
  int _monthIndex = 0;
  int _dayIndex = 0;

  HistoryState _state = HistoryState.idle;
  DayStats? _stats;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _years = List<int>.generate(7, (i) => now.year - 3 + i);
    _yearIndex = _years.indexOf(_selected.year).clamp(0, _years.length - 1);
    _monthIndex = _selected.month - 1;
    _dayIndex = _selected.day - 1;
    _yearCtrl = FixedExtentScrollController(initialItem: _yearIndex);
    _monthCtrl = FixedExtentScrollController(initialItem: _monthIndex);
    _dayCtrl = FixedExtentScrollController(initialItem: _dayIndex);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  List<int> get _daysForSelection {
    final year = _years[_yearIndex];
    final month = _monthIndex + 1;
    final total = DateUtils.getDaysInMonth(year, month);
    return List<int>.generate(total, (i) => i + 1);
  }

  DateTime _dateFromWheel() {
    final year = _years[_yearIndex];
    final month = _monthIndex + 1;
    final day = _daysForSelection[_dayIndex.clamp(0, _daysForSelection.length - 1)];
    return DateTime(year, month, day);
  }

  void _updateSelected(void Function() updateIndex) {
    setState(() {
      updateIndex();
      if (_dayIndex >= _daysForSelection.length) {
        _dayIndex = _daysForSelection.length - 1;
        _dayCtrl.jumpToItem(_dayIndex);
      }
      _selected = _dateFromWheel();
    });
  }

  Future<void> _query() async {
    setState(() {
      _state = HistoryState.loading;
    });
    final repo = context.read<HistoryRepository>();
    final result = await repo.fetchDay(_selected);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _stats = null;
        _state = HistoryState.empty;
      });
    } else {
      setState(() {
        _stats = result;
        _state = HistoryState.loaded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = _state == HistoryState.loading;
    final String buttonText =
        _state == HistoryState.idle || _state == HistoryState.loading ? '\u67e5\u8a62' : '\u91cd\u65b0\u67e5\u8a62';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '\u6b77\u53f2\u8cc7\u6599',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '\u9078\u64c7\u65e5\u671f\u4ee5\u67e5\u770b\u7576\u65e5\u7684 RULA/%MVC \u8207\u4e0a\u50b3\u72c0\u614b\u3002',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAB2BD), height: 1.4),
              ),
              const SizedBox(height: 12),
              _DatePickerWheel(
                yearController: _yearCtrl,
                monthController: _monthCtrl,
                dayController: _dayCtrl,
                years: _years,
                yearIndex: _yearIndex,
                monthIndex: _monthIndex,
                dayIndex: _dayIndex,
                onYearChanged: (index) => _updateSelected(() => _yearIndex = index),
                onMonthChanged: (index) => _updateSelected(() => _monthIndex = index),
                onDayChanged: (index) => _updateSelected(() => _dayIndex = index),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _query,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('\u8f09\u5165\u4e2d\u2026'),
                          ],
                        )
                      : Text(buttonText),
                ),
              ),
              const SizedBox(height: 16),
              _SummaryCard(
                date: _selected,
                state: _state,
                stats: _stats,
              ),
              if (_state == HistoryState.loaded && _stats != null) ...[
                const SizedBox(height: 16),
                _TrendPlaceholder(stats: _stats!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerWheel extends StatelessWidget {
  const _DatePickerWheel({
    required this.yearController,
    required this.monthController,
    required this.dayController,
    required this.years,
    required this.yearIndex,
    required this.monthIndex,
    required this.dayIndex,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onDayChanged,
  });

  final FixedExtentScrollController yearController;
  final FixedExtentScrollController monthController;
  final FixedExtentScrollController dayController;
  final List<int> years;
  final int yearIndex;
  final int monthIndex;
  final int dayIndex;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onDayChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111823),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Wheel(
              controller: yearController,
              items: years.map((y) => '$y\u5e74').toList(),
              onChanged: onYearChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Wheel(
              controller: monthController,
              items: List<String>.generate(12, (i) => '${i + 1}\u6708'),
              onChanged: onMonthChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([yearController, monthController]),
              builder: (context, _) {
                final year = years[yearIndex];
                final month = monthIndex + 1;
                final total = DateUtils.getDaysInMonth(year, month);
                final labels = List<String>.generate(total, (i) => '${i + 1}\u65e5');
                return _Wheel(
                  controller: dayController,
                  items: labels,
                  onChanged: onDayChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.items,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final List<String> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 32,
        backgroundColor: const Color(0x1A172533),
        selectionOverlay: const SizedBox.shrink(),
        magnification: 1.1,
        squeeze: 1.25,
        useMagnifier: true,
        onSelectedItemChanged: onChanged,
        children: items
            .map(
              (label) => Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

enum DayConclusion { low, medium, high, critical }

DayConclusion conclude(DayStats stats) {
  final double avgRula = stats.avgRula ?? 0;
  final double avgMvc = stats.avgMvc ?? 0;
  if (stats.highMinutes >= 30 || avgRula >= 6 || avgMvc >= 60) {
    return DayConclusion.critical;
  }
  if (stats.highMinutes >= 10 || avgRula >= 5 || avgMvc >= 50) {
    return DayConclusion.high;
  }
  if (avgRula >= 3 || avgMvc >= 30) {
    return DayConclusion.medium;
  }
  return DayConclusion.low;
}

String conclusionLabel(DayConclusion c) => switch (c) {
      DayConclusion.low => '\u4f4e\u98a8\u96aa',
      DayConclusion.medium => '\u6ce8\u610f',
      DayConclusion.high => '\u8b66\u6212',
      DayConclusion.critical => '\u5371\u96aa',
    };

String conclusionHint(DayConclusion c) => switch (c) {
      DayConclusion.low =>
          '\u72c0\u614b\u7a69\u5b9a\uff0c\u7e7c\u7e8c\u7dad\u6301\u826f\u597d\u59ff\u52e2\u8207\u7bc0\u594f\u3002',
      DayConclusion.medium =>
          '\u6ce8\u610f\u59ff\u52e2\u8207\u8ca0\u8f09\uff0c\u5efa\u8b70\u6392\u5b9a\u77ed\u66ab\u4f11\u606f\u3002',
      DayConclusion.high =>
          '\u8ca0\u8377\u504f\u9ad8\uff0c\u8acb\u964d\u4f4e\u6301\u7e8c\u7528\u529b\u4e26\u589e\u52a0\u4f11\u606f\u983b\u7387\u3002',
      DayConclusion.critical =>
          '\u98a8\u96aa\u904e\u9ad8\uff0c\u8acb\u7acb\u5373\u505c\u6b62\u4f5c\u696d\u4e26\u6aa2\u8a0e\u6539\u5584\u65b9\u6cd5\u3002',
    };

Color conclusionColor(DayConclusion c) => switch (c) {
      DayConclusion.low => const Color(0xFF22C55E),
      DayConclusion.medium => const Color(0xFFF59E0B),
      DayConclusion.high => const Color(0xFFF97316),
      DayConclusion.critical => const Color(0xFFEF4444),
    };

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.date,
    required this.state,
    required this.stats,
  });

  final DateTime date;
  final HistoryState state;
  final DayStats? stats;

  @override
  Widget build(BuildContext context) {
    final String title =
        '\u7576\u65e5\u6458\u8981 \u00b7 ${_fmt(date)}';
    final bool isLoaded = state == HistoryState.loaded && stats != null;
    final bool isEmpty = state == HistoryState.empty;
    final bool isLoading = state == HistoryState.loading;
    final bool isIdle = state == HistoryState.idle;
    final DayConclusion? conclusion = isLoaded ? conclude(stats!) : null;
    final String hint = isIdle
        ? '\u8acb\u5148\u67e5\u8a62\u4ee5\u8f09\u5165\u7576\u65e5\u8cc7\u6599\u3002'
        : isLoading
            ? '\u8f09\u5165\u4e2d\u2026'
            : isEmpty
                ? '\u7576\u65e5\u7121\u8cc7\u6599\uff0c\u8acb\u78ba\u8a8d\u662f\u5426\u6709\u91cf\u6e2c\u8207\u4e0a\u50b3\u3002'
                : conclusionHint(conclusion!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E252C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (conclusion != null) _ConclusionBadge(conclusion),
              if (conclusion != null) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.65),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricCell(
                label: 'RULA \u5e73\u5747',
                value: _formatValue(stats?.avgRula, isLoaded, decimals: 1),
              ),
              _MetricCell(
                label: '%MVC \u5e73\u5747',
                value: _formatValue(stats?.avgMvc, isLoaded, decimals: 0),
              ),
              _MetricCell(
                label: '\u9ad8\u98a8\u96aa\u6642\u9577',
                value: _formatValue(stats?.highMinutes, isLoaded, suffix: '\u5206'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetricCell(
                label: '\u5cf0\u503c RULA',
                value: _formatValue(stats?.peakRula, isLoaded, decimals: 1),
              ),
              _MetricCell(
                label: '\u5cf0\u503c %MVC',
                value: _formatValue(stats?.peakMvc, isLoaded, decimals: 0),
              ),
              _MetricCell(
                label: '\u4e0a\u50b3\u6210\u529f\u7387',
                value: isLoaded && stats?.uploadRate != null
                    ? '${(stats!.uploadRate! * 100).toStringAsFixed(0)}%'
                    : '--',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(num? value, bool isLoaded,
      {int decimals = 0, String suffix = ''}) {
    if (!isLoaded || value == null) return '--';
    if (value is double) {
      return '${value.toStringAsFixed(decimals)}$suffix';
    }
    return '${value.toString()}$suffix';
  }

  String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

class _ConclusionBadge extends StatelessWidget {
  const _ConclusionBadge(this.conclusion);

  final DayConclusion conclusion;

  @override
  Widget build(BuildContext context) {
    final Color color = conclusionColor(conclusion);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        conclusionLabel(conclusion),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = value == '--';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isEmpty ? const Color(0xFF8A93A2) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPlaceholder extends StatelessWidget {
  const _TrendPlaceholder({required this.stats});

  final DayStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111823),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u7576\u65e5\u8da8\u52e2',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\u7e3d\u7d04\u9ad8\u98a8\u96aa ${stats.highMinutes}\u5206\uff0cRULA/%MVC \u4e0a\u5348\u6bd4\u4e0b\u5348\u8f03\u9ad8\u3002',
            style: const TextStyle(fontSize: 13, color: Color(0xFFAAB2BD)),
          ),
        ],
      ),
    );
  }
}
