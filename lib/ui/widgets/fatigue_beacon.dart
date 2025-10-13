import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/risk_level.dart';

class FatigueBeaconSection extends StatefulWidget {
  const FatigueBeaconSection({
    super.key,
    required this.level,
    required this.hasData,
    required this.onTap,
    required this.onExplainTap,
    this.alertCooldown = const Duration(seconds: 60),
  });

  final RiskLevel? level;
  final bool hasData;
  final VoidCallback onTap;
  final VoidCallback onExplainTap;
  final Duration alertCooldown;

  @override
  State<FatigueBeaconSection> createState() => _FatigueBeaconSectionState();
}

class _FatigueBeaconSectionState extends State<FatigueBeaconSection>
    with SingleTickerProviderStateMixin {
  static const Color _neutral = Color(0xFF6E7891);
  late final AnimationController _controller;
  late final Animation<double> _breath;
  final AudioPlayer _player = AudioPlayer();
  DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _breath = Tween(begin: 0.94, end: 1.06)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant FatigueBeaconSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAlert(oldWidget.level, widget.level);
  }

  Future<void> _maybeAlert(RiskLevel? previous, RiskLevel? current) async {
    if (!widget.hasData || current != RiskLevel.critical) return;
    if (previous == RiskLevel.critical) return;
    final DateTime now = DateTime.now();
    if (now.difference(_lastAlert) < widget.alertCooldown) return;
    _lastAlert = now;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    await HapticFeedback.heavyImpact();
    unawaited(_player.play(AssetSource('audio/beep.wav')));
  }

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  String _suggestionFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return '\u4fdd\u6301\u653e\u9b06';
      case RiskLevel.medium:
        return '\u6ce8\u610f\u59ff\u52e2';
      case RiskLevel.high:
        return '\u8acb\u77ed\u66ab\u4f11\u606f';
      case RiskLevel.critical:
        return '\u7acb\u5373\u505c\u6b62\u4f5c\u696d';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.hasData && widget.level != null;
    final RiskLevel? level = widget.level;
    final Color color = active ? RiskTheme.color(level!) : _neutral;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: GestureDetector(
            onTap: widget.onExplainTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Text(
                  '\u75b2\u52de\u6307\u793a\u71c8',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fatigue Indicator',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: widget.onTap,
            child: ScaleTransition(
              scale: _breath,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _halo(color, dim: !active),
                  Container(
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                      color: active
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.04),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: active
                            ? Text(
                                RiskTheme.label(level!),
                                key: ValueKey<RiskLevel>(level),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              )
                            : Column(
                                key: const ValueKey('waiting'),
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(height: 2),
                                  Text(
                                    '\u7b49\u5f85\u8cc7\u6599',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFE2E8F0),
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (active)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Text(
                _suggestionFor(level!),
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _halo(Color color, {required bool dim}) {
    final double outerOpacity = dim ? 0.78 : 0.98;
    final double midOpacity = dim ? 0.38 : 0.66;
    final double innerOpacity = dim ? 0.16 : 0.34;
    final double shadowOpacity = dim ? 0.34 : 0.55;
    return Container(
      width: 168,
      height: 168,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(outerOpacity),
            color.withOpacity(midOpacity),
            color.withOpacity(innerOpacity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 0.82, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(shadowOpacity),
            blurRadius: 54,
            spreadRadius: 15,
          ),
        ],
      ),
    );
  }
}

Future<void> showFatigueBeaconHelp(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E252C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '\u75b2\u52de\u6307\u793a\u71c8\u8aaa\u660e',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '\u75b2\u52de\u6307\u793a\u71c8\u6839\u64da\u808c\u96fb(%MVC)\u8207\u59ff\u52e2\u98a8\u96aa(RULA)\u81ea\u52d5\u5206\u7d1a\u3002'
            '\u5206\u70ba\u56db\u7a2e\u72c0\u614b\uff0c\u7528\u65bc\u5373\u6642\u986f\u793a\u4f7f\u7528\u8005\u7684\u808c\u8089\u8ca0\u8377\u8207\u75b2\u52de\u98a8\u96aa\uff1a',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFAAB2BD),
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '\u98a8\u96aa\u7b49\u7d1a\u8aaa\u660e\uff1a',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '\ud83d\udfe2 \u4f4e  \u2014 \u808c\u8089\u653e\u9b06\uff0c\u72c0\u614b\u7a69\u5b9a\n'
            '\ud83d\udfe1 \u4e2d  \u2014 \u8f15\u5ea6\u8ca0\u8377\uff0c\u6ce8\u610f\u59ff\u52e2\n'
            '\ud83d\udfe0 \u8f03\u9ad8 \u2014 \u5efa\u8b70\u77ed\u66ab\u4f11\u606f\n'
            '\ud83d\udd34 \u9ad8  \u2014 \u904e\u5ea6\u75b2\u52de\uff0c\u8acb\u7acb\u5373\u505c\u6b62\u4f5c\u696d',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFAAB2BD),
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
