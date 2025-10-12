import 'package:flutter/material.dart';
import '../../design/tokens.dart';

class BreathingLight extends StatefulWidget {
  final HealthLevel level;
  final String label;
  final Duration period; // \u9810\u8a2d 3s \u8ff4\u5708
  final bool glow; // \u662f\u5426\u958b\u555f\u5916\u5708\u767c\u5149
  final double size; // \u76f4\u5f91

  const BreathingLight({
    super.key,
    required this.level,
    required this.label,
    this.period = const Duration(seconds: 3),
    this.glow = true,
    this.size = 20,
  });

  @override
  State<BreathingLight> createState() => _BreathingLightState();
}

class _BreathingLightState extends State<BreathingLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _breath;

  Color get color {
    switch (widget.level) {
      case HealthLevel.ok:
        return HealthColors.ok;
      case HealthLevel.warning:
        return HealthColors.warning;
      case HealthLevel.error:
        return HealthColors.error;
    }
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
    _breath = Tween(begin: 0.85, end: 1.0).animate(
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
    final diameter = widget.size;
    final glowColor = color.withOpacity(0.55);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _breath,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(.95), color.withOpacity(.7)],
                radius: .8,
              ),
              boxShadow: widget.glow
                  ? [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 18,
                        spreadRadius: 1.5,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 0),
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 11,
            color: HealthColors.label, // 0.7 \u900f\u660e\u5ea6
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

