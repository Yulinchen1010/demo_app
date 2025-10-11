import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../data/cloud_subscriber.dart';

class FatigueLight extends StatefulWidget {
  final CloudStatusSubscriber subscriber;
  final double size; // single light diameter
  const FatigueLight({super.key, required this.subscriber, this.size = 64});

  @override
  State<FatigueLight> createState() => _FatigueLightState();
}

class _FatigueLightState extends State<FatigueLight> {
  final AudioPlayer _player = AudioPlayer();
  CloudStatusData? _last;
  StreamSubscription<CloudStatusData>? _sub;
  DateTime? _lastAlert;

  @override
  void initState() {
    super.initState();
    _sub = widget.subscriber.stream.listen((e) => setState(() => _last = e));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final risk = _last?.riskLevel ?? 0;
    final ts = _last?.ts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (ctx, cons) {
              final maxW = cons.maxWidth;
              double spacing = 16;
              double d = widget.size;
              final needed = 5 * d + 4 * spacing;
              if (needed > maxW) {
                d = ((maxW - 4 * spacing) / 5).clamp(28, widget.size);
              }
              return SizedBox(
                height: d,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _buildFiveLights(risk, d, spacing),
                    ),
                    if (_riskText(risk).isNotEmpty)
                      Text(
                        _riskText(risk),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: _riskColor(risk).withOpacity(0.7),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (ts != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '最後更新: ' + _fmt(ts),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFiveLights(int risk, double diameter, double spacing) {
    // Map risk (1..3) => lights 2 / 4 / 5
    final int active = risk <= 0 ? 0 : (risk == 1 ? 2 : (risk == 2 ? 4 : 5));
    final colors = [
      const Color(0xFF4CAF50), // green
      const Color(0xFF8BC34A), // light green
      const Color(0xFFFFEB3B), // yellow
      const Color(0xFFFF9800), // orange
      const Color(0xFFFF3B30), // red
    ];
    final children = <Widget>[];
    for (int i = 0; i < 5; i++) {
      final on = i < active;
      children.add(_light(colors[i], on, diameter));
      if (i != 4) children.add(SizedBox(width: spacing));
    }
    if (active == 5) _alertOnce();
    return children;
  }

  Widget _light(Color color, bool on, double d) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: on ? color : color.withOpacity(0.2),
        shape: BoxShape.circle,
        boxShadow: on
            ? [
                BoxShadow(
                  color: color.withOpacity(0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }

  Future<void> _alertOnce() async {
    final now = DateTime.now();
    if (_lastAlert != null && now.difference(_lastAlert!).inSeconds < 10) return; // cooldown
    _lastAlert = now;
    try {
      await _player.play(AssetSource('audio/beep.wav'));
    } catch (_) {}
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 180));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _riskText(int risk) {
    if (risk <= 0) return '';
    switch (risk) {
      case 3:
        return '高風險  請暫停/改善';
      case 2:
        return '中風險  請留意';
      case 1:
        return '低風險  可持續工作';
      default:
        return '';
    }
  }

  Color _riskColor(int risk) {
    switch (risk) {
      case 3:
        return const Color(0xFFFF3B30);
      case 2:
        return const Color(0xFFFFB300);
      case 1:
        return const Color(0xFF4CAF50);
      default:
        return Colors.white70;
    }
  }
}

