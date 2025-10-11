import 'package:flutter/material.dart';

enum HealthLevel { ok, warning, error }

class HealthColors {
  static const ok = Color(0xFF22C55E); // 🟢
  static const warning = Color(0xFFF59E0B); // 🟡
  static const error = Color(0xFFEF4444); // 🔴
  static const label = Color(0xB3E5EAF0); // 70% 透明白(#E5EAF0)
  static const surface = Color(0xFF1E252C); // 卡片底色
  static const bg = Color(0xFF0F141A); // 背景
}

