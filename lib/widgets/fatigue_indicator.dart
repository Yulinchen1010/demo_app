import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FatigueLevel { low, mid, highish, high }

FatigueLevel computeLevel(double? rula, double? mvc) {
  if (rula == null || mvc == null) return FatigueLevel.low;
  if (rula >= 7 || mvc >= 70) return FatigueLevel.high;
  if ((rula >= 5 && rula <= 6) || (mvc >= 50 && mvc < 70)) {
    return FatigueLevel.highish;
  }
  if ((rula >= 3 && rula <= 4) || (mvc >= 30 && mvc < 50)) {
    return FatigueLevel.mid;
  }
  return FatigueLevel.low;
}

Color levelColor(FatigueLevel level) {
  switch (level) {
    case FatigueLevel.low:
      return const Color(0xFF22C55E);
    case FatigueLevel.mid:
      return const Color(0xFFF59E0B);
    case FatigueLevel.highish:
      return const Color(0xFFF97316);
    case FatigueLevel.high:
      return const Color(0xFFEF4444);
  }
}

class FatigueIndicator extends StatefulWidget {
  const FatigueIndicator({
    super.key,
    this.rula,
    this.mvc,
    this.size = 400,
    this.isActive = false,
  });

  final double? rula;
  final double? mvc;
  final double size;
  final bool isActive;

  @override
  State<FatigueIndicator> createState() => _FatigueIndicatorState();
}

class _FatigueIndicatorState extends State<FatigueIndicator> {
  FatigueLevel? _lastLevel;
  late final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _lastLevel = computeLevel(widget.rula, widget.mvc);
    if (widget.isActive && _lastLevel == FatigueLevel.high) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerAlert();
      });
    }
  }

  @override
  void didUpdateWidget(covariant FatigueIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final FatigueLevel level = computeLevel(widget.rula, widget.mvc);
    final bool escalatedToHigh = widget.isActive &&
        level == FatigueLevel.high &&
        (_lastLevel != FatigueLevel.high || !oldWidget.isActive);

    if (escalatedToHigh) {
      _triggerAlert();
    }

    _lastLevel = level;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _triggerAlert() async {
    if (!mounted || !widget.isActive) return;

    await _triggerHaptics();

    try {
      await _player.stop();
      await _player.play(AssetSource('audio/alert.wav'));
    } catch (_) {
      // Ignore audio playback failures.
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '[警示] 疲勞風險過高，請立即休息！',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          duration: Duration(seconds: 3),
        ),
      );
  }

  Future<void> _triggerHaptics() async {
    try {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 160));
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Ignore haptic failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final FatigueLevel level = computeLevel(widget.rula, widget.mvc);
    final bool active = widget.isActive;
    final Color coreColor =
        active ? levelColor(level) : const Color(0xFF94A3B8);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _EnergyRipples(
            color: coreColor,
            size: widget.size,
            mvc: widget.mvc,
            active: active,
          ),
          _CoreSphere(
            color: coreColor,
            size: widget.size * 0.62,
            active: active,
          ),
        ],
      ),
    );
  }
}

class _CoreSphere extends StatefulWidget {
  const _CoreSphere({
    required this.color,
    required this.size,
    required this.active,
  });

  final Color color;
  final double size;
  final bool active;

  @override
  State<_CoreSphere> createState() => _CoreSphereState();
}

class _CoreSphereState extends State<_CoreSphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final bool active = widget.active;
        final double factor = lerpDouble(
          active ? 0.9 : 0.85,
          active ? 1.0 : 0.9,
          _controller.value,
        )!;
        final Color baseColor =
            active ? widget.color : const Color(0xFFCBD5F5).withOpacity(0.4);
        final int dots = active
            ? 0
            : (((_controller.lastElapsedDuration?.inMilliseconds ?? 0) ~/ 350) %
                    3) +
                1;
        final String label = active
            ? _labelByColor(widget.color)
            : '等待資料${List.filled(dots, '.').join()}';
        return Container(
          width: widget.size * factor,
          height: widget.size * factor,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                baseColor.withOpacity(0.95),
                baseColor.withOpacity(0.0),
              ],
              stops: const [0.35, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: active ? 24 : 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF1E293B).withOpacity(0.65),
              letterSpacing: active ? 0 : 0.35,
              shadows: [
                Shadow(
                  blurRadius: active ? 8 : 5,
                  color: baseColor.withOpacity(active ? 0.7 : 0.28),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelByColor(Color color) {
    if (color == const Color(0xFF22C55E)) return '低';
    if (color == const Color(0xFFF59E0B)) return '中';
    if (color == const Color(0xFFF97316)) return '較高';
    return '高';
  }
}

class _EnergyRipples extends StatefulWidget {
  const _EnergyRipples({
    required this.color,
    required this.size,
    required this.mvc,
    required this.active,
  });

  final Color color;
  final double size;
  final double? mvc;
  final bool active;

  @override
  State<_EnergyRipples> createState() => _EnergyRipplesState();
}

class _EnergyRipplesState extends State<_EnergyRipples>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFromMvc(widget.mvc),
    )..repeat();
    if (!widget.active) {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _EnergyRipples oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Duration nextDuration = _durationFromMvc(widget.mvc);
    if (_controller.duration != nextDuration) {
      _controller.duration = nextDuration;
      if (_controller.isAnimating) {
        _controller
          ..reset()
          ..repeat();
      }
    }

    if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    } else if (widget.active && !_controller.isAnimating) {
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RipplesPainter(
          color: widget.color.withOpacity(0.35),
          progress: _controller.value,
        ),
      ),
    );
  }

  Duration _durationFromMvc(double? mvc) {
    final double intensity = (mvc ?? 0).clamp(0, 100);
    final double milliseconds = lerpDouble(1800, 700, intensity / 100)!;
    return Duration(milliseconds: max(300, milliseconds.round()));
  }
}

class _RipplesPainter extends CustomPainter {
  const _RipplesPainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.width / 2 * 0.95;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      final double p = (progress + i / 3) % 1.0;
      final double radius = maxRadius * p;
      paint.color = color.withOpacity((1 - p) * 0.35);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
