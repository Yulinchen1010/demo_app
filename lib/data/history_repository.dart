import 'dart:async';

import 'package:flutter/material.dart';

class DayStats {
  const DayStats({
    required this.avgRula,
    required this.avgMvc,
    required this.peakRula,
    required this.peakMvc,
    required this.highMinutes,
    required this.uploadRate,
  });

  final double? avgRula;
  final double? avgMvc;
  final double? peakRula;
  final double? peakMvc;
  final int highMinutes;
  final double? uploadRate;
}

class HistoryRepository {
  Future<DayStats?> fetchDay(DateTime date) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (date.isAfter(DateTime.now())) return null;
    return const DayStats(
      avgRula: 4.2,
      avgMvc: 35.4,
      peakRula: 6.1,
      peakMvc: 78,
      highMinutes: 12,
      uploadRate: 0.92,
    );
  }
}

class HistoryProvider extends ChangeNotifier {
  HistoryProvider(this.repo);

  final HistoryRepository repo;

  Future<DayStats?> load(DateTime day) => repo.fetchDay(day);
}
