import 'package:flutter/material.dart';

class RulaScoreBar extends StatelessWidget {
  final double? score; // 1-7+
  const RulaScoreBar({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final s = (score ?? 0).clamp(0, 9);
    final bg = _colorForScore(s);
    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(colors: _barGradient(), stops: const [0.0, .29, .57, .86, 1.0]),
      ),
      child: Stack(
        children: [
          // Marker line for current score
          Align(
            alignment: Alignment(((s - 1.0) / 8.0 * 2.0 - 1.0).clamp(-1.0, 1.0), 0),
            child: Container(width: 2, color: Colors.white),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg.withOpacity(.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'RULA 分數：${s.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _barGradient() => const [
        Color(0xFF2E7D32), // deep green
        Color(0xFF76FF03), // green
        Color(0xFFFFB300), // amber
        Color(0xFFFF7043), // orange
        Color(0xFFFF3B30), // red
      ];

  Color _colorForScore(double s) {
    if (s >= 7) return const Color(0xFFFF3B30);
    if (s >= 5) return const Color(0xFFFF7043);
    if (s >= 3) return const Color(0xFFFFB300);
    return const Color(0xFF76FF03);
  }
}

