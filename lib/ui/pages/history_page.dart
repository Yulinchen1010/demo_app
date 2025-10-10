import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime _selected = DateTime.now();
  DateTime? _confirmed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selected,
              onDateTimeChanged: (d) => setState(() => _selected = d),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => setState(() => _confirmed = _selected),
            child: const Text('確定'),
          ),
          const SizedBox(height: 16),
          if (_confirmed != null)
            _DayView(date: _confirmed!)
          else
            const Center(child: Text('請選擇日期以檢視當日資料')),
        ],
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  final DateTime date;
  const _DayView({required this.date});

  @override
  Widget build(BuildContext context) {
    final ymd = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('日期：$ymd', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('當日資料尚未連接雲端 API，之後可展示摘要、趨勢或事件。'),
        ),
      ],
    );
  }
}

