import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/t_colors.dart';
import '../../domain/risk_level.dart';
import '../../widgets/fatigue_indicator.dart';

class FatigueBeaconSection extends StatefulWidget {
  const FatigueBeaconSection({
    super.key,
    required this.level,
    required this.hasData,
    required this.onTap,
    required this.onExplainTap,
    this.rula,
    this.mvc,
    this.alertCooldown = const Duration(seconds: 60),
  });

  final RiskLevel? level;
  final bool hasData;
  final VoidCallback onTap;
  final VoidCallback onExplainTap;
  final double? rula;
  final double? mvc;
  final Duration alertCooldown;

  @override
  State<FatigueBeaconSection> createState() => _FatigueBeaconSectionState();
}

class _FatigueBeaconSectionState extends State<FatigueBeaconSection> {
  final AudioPlayer _player = AudioPlayer();
  DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: InkWell(
            onTap: widget.onExplainTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Text(
                  '\u75b2\u52de\u6307\u793a\u71c8',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fatigue Indicator',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FatigueLampBox(
          widthFactor: 0.82,
          heightFactor: 0.36,
          minDiameter: 230,
          maxDiameter: 380,
          builder: (diameter) => FatigueIndicator(
            rula: widget.rula,
            mvc: widget.mvc,
            isActive: active,
            size: diameter,
          ),
        ),
        const SizedBox(height: 12),
        if (active && level != null)
          _SuggestionChip(
            label: _suggestionFor(level),
          ),
      ],
    );
  }
}

Future<void> showFatigueBeaconHelp(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: TColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _BeaconHelpSheet(),
  );
}

class _BeaconHelpSheet extends StatelessWidget {
  const _BeaconHelpSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _HelpHeader(),
            SizedBox(height: 20),
            _RiskCard(
              title: '\u4f4e\u98a8\u96aa',
              desc:
                  'RULA 1\u20132 \u6216 %MVC < 30%\n\u72c0\u614b\u7a69\u5b9a\uff0c\u808c\u8089\u8ca0\u8377\u4f4e',
              gradient: [Color(0xFF16A34A), TColors.levelLow],
            ),
            SizedBox(height: 12),
            _RiskCard(
              title: '\u4e2d\u98a8\u96aa',
              desc:
                  'RULA 3\u20134 \u6216 %MVC 30\u201350%\n\u6ce8\u610f\u59ff\u52e2\u8207\u52d5\u4f5c\uff0c\u907f\u514d\u6301\u7e8c\u8ca0\u8377',
              gradient: [Color(0xFFFACC15), TColors.levelMid],
            ),
            SizedBox(height: 12),
            _RiskCard(
              title: '\u8f03\u9ad8\u98a8\u96aa',
              desc:
                  'RULA 5\u20136 \u6216 %MVC 50\u201370%\n\u5efa\u8b70\u8abf\u6574\u59ff\u52e2\uff0c\u9632\u6b62\u75b2\u52de\u7a4d\u7d2f',
              gradient: [TColors.levelHighish, Color(0xFFEA580C)],
            ),
            SizedBox(height: 12),
            _RiskCard(
              title: '\u9ad8\u98a8\u96aa',
              desc:
                  'RULA \u2265 7 \u6216 %MVC \u2265 70%\n\u75b2\u52de\u904e\u9ad8\uff0c\u8acb\u7acb\u5373\u4f11\u606f',
              gradient: [Color(0xFFDC2626), TColors.levelHigh],
            ),
            SizedBox(height: 16),
            _HelpFooter(),
            SizedBox(height: 20),
            _CloseButton(),
          ],
        ),
      ),
    );
  }
}

class _HelpHeader extends StatelessWidget {
  const _HelpHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, color: TColors.primary),
            SizedBox(width: 6),
            Text(
              '\u75b2\u52de\u6307\u793a\u71c8\u8aaa\u660e',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TColors.textPrimary,
                shadows: [Shadow(blurRadius: 8, color: TColors.primary)],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          '\u4f9d\u64da\u59ff\u52e2\uff08RULA\uff09\u8207\u808c\u96fb\uff08%MVC\uff09\u5373\u6642\u8a08\u7b97\u75b2\u52de\u98a8\u96aa\u7b49\u7d1a',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: TColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _HelpFooter extends StatelessWidget {
  const _HelpFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(
          Icons.error_outline,
          size: 18,
          color: Colors.white54,
        ),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            '\u82e5\u9ad8\u98a8\u96aa\u6301\u7e8c\u8d85\u904e 5 \u79d2\u7cfb\u7d71\u5c07\u89f8\u767c\u97f3\u6548\u8207\u9707\u52d5\u63d0\u9192',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: TColors.primary,
        foregroundColor: TColors.primaryOn,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      onPressed: () => Navigator.pop(context),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        child: Text(
          '\u4e86\u89e3\u4e86',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.white),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.title,
    required this.desc,
    required this.gradient,
  });

  final String title;
  final String desc;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              desc,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FatigueLampBox extends StatelessWidget {
  const FatigueLampBox({
    super.key,
    this.widthFactor = 0.95,
    this.heightFactor = 0.45,
    this.minDiameter = 320,
    this.maxDiameter = 540,
    required this.builder,
  });

  final double widthFactor;
  final double heightFactor;
  final double minDiameter;
  final double maxDiameter;
  final Widget Function(double diameter) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final Size screen = MediaQuery.of(context).size;
      final double availableWidth =
          constraints.maxWidth.isFinite ? constraints.maxWidth : screen.width;
      final double candidateByWidth = availableWidth * widthFactor;

      final double availableHeight = constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : (screen.height - kToolbarHeight - 120);
      final double candidateByHeight = availableHeight * heightFactor;

      final double diameter =
          math.min(candidateByWidth, candidateByHeight).clamp(
                minDiameter,
                maxDiameter,
              );

      return Center(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: builder(diameter),
        ),
      );
    });
  }
}
