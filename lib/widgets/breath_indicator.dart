import 'package:flutter/material.dart';
import '../system/status_aggregator.dart';

class BreathIndicator extends StatefulWidget {
  final IndicatorColor color;
  final String label;

  const BreathIndicator({super.key, required this.color, required this.label});

  @override
  State<BreathIndicator> createState() => _BreathIndicatorState();
}

class _BreathIndicatorState extends State<BreathIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _breath;

  static const _green = Color(0xFF22C55E);
  static const _yellow = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _grey = Color(0xFF6B7280);

  Color get _baseColor {
    switch (widget.color) {
      case IndicatorColor.green:
        return _green;
      case IndicatorColor.yellow:
        return _yellow;
      case IndicatorColor.red:
        return _red;
      case IndicatorColor.grey:
        return _grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _breath = Tween(begin: .85, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _baseColor;
    final glow = color.withOpacity(.25);
    const double size = 18; // 16\u201318px
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _breath,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color, // \u5be6\u5fc3\u8272\uff0c\u907f\u514d\u758a\u8272\u504f\u6697
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glow,
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xD9FFFFFF), // \u767d 85%
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

