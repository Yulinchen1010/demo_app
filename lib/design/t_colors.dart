import 'package:flutter/material.dart';

/// Global color palette decoupled from fatigue-indicator state.
class TColors {
  static const bg = Color(0xFF0F141A);
  static const surface = Color(0xFF111315);
  static const textPrimary = Color(0xFFE5EAF0);
  static const textSecondary = Color(0xFFAAB2BD);

  /// App accent color (kept independent from fatigue indicator tier colors).
  static const primary = Color(0xFF38BDF8);
  static const primaryOn = Colors.white;

  /// Fatigue indicator tier colors (for visual explanation only).
  static const levelLow = Color(0xFF22C55E);
  static const levelMid = Color(0xFFF59E0B);
  static const levelHighish = Color(0xFFF97316);
  static const levelHigh = Color(0xFFEF4444);
}
