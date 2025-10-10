import 'dart:math' as math;
import 'package:flutter/material.dart';

class NeuralTree extends StatelessWidget {
  final List<double?> mvc; // up to 6 values (0-100). null → greyed node
  const NeuralTree({super.key, required this.mvc});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CustomPaint(
        painter: _TreePainter(mvc),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  final List<double?> mvc;
  _TreePainter(this.mvc);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6);
    final trunkTop = Offset(size.width / 2, size.height * 0.25);

    final trunkPaint = Paint()
      ..color = const Color(0xFF1D2733)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    // Trunk
    canvas.drawLine(center, trunkTop, trunkPaint);

    // Shoulders (branches)
    final leftShoulder = Offset(size.width * 0.35, size.height * 0.35);
    final rightShoulder = Offset(size.width * 0.65, size.height * 0.35);
    canvas.drawLine(trunkTop, leftShoulder, trunkPaint);
    canvas.drawLine(trunkTop, rightShoulder, trunkPaint);

    // Leaves layout: 3 per side within ±60° sector
    final leftNodes = _fanPositions(leftShoulder, radius: size.shortestSide * 0.18, startDeg: 200, endDeg: 260, count: 3);
    final rightNodes = _fanPositions(rightShoulder, radius: size.shortestSide * 0.18, startDeg: -80, endDeg: -20, count: 3);

    final nodes = [...leftNodes, ...rightNodes];
    for (int i = 0; i < nodes.length; i++) {
      final v = i < mvc.length ? mvc[i] : null;
      _drawNode(canvas, nodes[i], v);
    }
  }

  void _drawNode(Canvas canvas, Offset p, double? v) {
    final value = (v ?? 0).clamp(0, 100);
    final color = v == null ? const Color(0xFF455A64) : _colorForMvc(value);
    final radius = 8 + 10 * (value / 100);

    // Glow
    final glow = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(p, radius, glow);

    final fill = Paint()..color = color;
    canvas.drawCircle(p, radius, fill);
  }

  List<Offset> _fanPositions(Offset origin, {required double radius, required double startDeg, required double endDeg, required int count}) {
    final res = <Offset>[];
    for (int i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      final deg = startDeg + (endDeg - startDeg) * t;
      final rad = deg * math.pi / 180;
      res.add(Offset(origin.dx + radius * math.cos(rad), origin.dy + radius * math.sin(rad)));
    }
    return res;
  }

  Color _colorForMvc(double v) {
    if (v <= 20) return const Color(0xFF00E5FF); // cyan
    if (v <= 60) return const Color(0xFF76FF03); // green
    return const Color(0xFFFF3B30); // red
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) => oldDelegate.mvc != mvc;
}

