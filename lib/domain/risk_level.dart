import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high, critical }

class RiskTheme {
  static const Color low = Color(0xFF22C55E);
  static const Color medium = Color(0xFFF59E0B);
  static const Color high = Color(0xFFF97316);
  static const Color critical = Color(0xFFEF4444);

  static Color color(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return low;
      case RiskLevel.medium:
        return medium;
      case RiskLevel.high:
        return high;
      case RiskLevel.critical:
        return critical;
    }
  }

  static String label(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return '\u4f4e';
      case RiskLevel.medium:
        return '\u4e2d';
      case RiskLevel.high:
        return '\u8f03\u9ad8';
      case RiskLevel.critical:
        return '\u9ad8';
    }
  }

  static String caption(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return '\u5b89\u5168';
      case RiskLevel.medium:
        return '\u6ce8\u610f';
      case RiskLevel.high:
        return '\u8b66\u6212';
      case RiskLevel.critical:
        return '\u5371\u96aa';
    }
  }
}

RiskLevel computeRisk({
  required double rula,
  required double mvc,
  required Duration hold,
  required Duration nowOverHold,
}) {
  final double rulaValue = rula.isNaN ? 0 : rula;
  final double mvcValue = mvc.isNaN ? 0 : mvc;
  if ((rulaValue >= 7 || mvcValue >= 70) && nowOverHold >= hold) {
    return RiskLevel.critical;
  }
  if (rulaValue >= 5 || mvcValue >= 50) {
    return RiskLevel.high;
  }
  if (rulaValue >= 3 || mvcValue >= 30) {
    return RiskLevel.medium;
  }
  return RiskLevel.low;
}
