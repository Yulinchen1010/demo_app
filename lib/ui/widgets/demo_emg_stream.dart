import 'dart:async';
import 'dart:math' as math;

import '../../data/models.dart';

/// Simple demo stream that emits EMG-like values around a baseline.
Stream<EmgPoint> demoEmgStream({Duration period = const Duration(milliseconds: 20)}) {
  final rnd = math.Random();
  double t = 0.0;
  return Stream.periodic(period, (_) {
    t += period.inMilliseconds / 1000.0;
    final noise = (rnd.nextDouble() - 0.5) * 0.1;
    final wave = 0.4 + 0.3 * math.sin(t * 2 * math.pi * 0.2) + noise;
    final value = wave.clamp(0.0, 1.2);
    return EmgPoint(DateTime.now(), value);
  });
}
