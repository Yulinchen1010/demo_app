import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

enum LinkState { scanning, connecting, connected, error }

enum CloudState { idle, paused, active, error }

enum UploadState { idle, uploading, success, failed }

class SystemPulsePanel extends StatefulWidget {
  const SystemPulsePanel({
    super.key,
    required this.linkState,
    required this.cloudState,
    required this.uploadState,
    required this.mcuConnected,
    required this.uploadPercent,
    required this.latencyMs,
    required this.deviceName,
    this.showTreeEnergy = true,
  });

  final LinkState linkState;
  final CloudState cloudState;
  final UploadState uploadState;
  final bool mcuConnected;
  final int? uploadPercent;
  final int? latencyMs;
  final String? deviceName;
  final bool showTreeEnergy;

  @override
  State<SystemPulsePanel> createState() => _SystemPulsePanelState();
}

class _SystemPulsePanelState extends State<SystemPulsePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Future<bool>? _hasTreeAsset;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _prepareAssetFuture();
  }

  void _prepareAssetFuture() {
    if (widget.showTreeEnergy) {
      _hasTreeAsset = _loadTreeAssetFlag();
    } else {
      _hasTreeAsset = Future<bool>.value(false);
    }
  }

  Future<bool> _loadTreeAssetFlag() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);
      return manifest.keys.contains('assets/anim/tree_energy.json');
    } catch (_) {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant SystemPulsePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showTreeEnergy != oldWidget.showTreeEnergy) {
      _prepareAssetFuture();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool tickerEnabled = TickerMode.of(context);
    if (tickerEnabled && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!tickerEnabled && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showTreeEnergy)
            Positioned.fill(
              child: FutureBuilder<bool>(
                future: _hasTreeAsset,
                initialData: false,
                builder: (context, snapshot) {
                  final bool hasAsset = snapshot.data ?? false;
                  if (hasAsset) {
                    return IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: 0.85,
                          child: Lottie.asset(
                            'assets/anim/tree_energy.json',
                            frameRate: FrameRate.max,
                            repeat: true,
                            reverse: false,
                            fit: BoxFit.contain,
                            width: 260,
                            height: 260,
                          ),
                        ),
                      ),
                    );
                  }
                  return IgnorePointer(
                    child: _GlowFallback(animation: _pulseController),
                  );
                },
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnimatedStatusBar(
                animation: _pulseController,
                state: widget.linkState,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _SystemSummaryCard(
                    mcuConnected: widget.mcuConnected,
                    uploadState: widget.uploadState,
                    uploadPercent: widget.uploadPercent,
                    cloudState: widget.cloudState,
                    latencyMs: widget.latencyMs,
                    deviceName: widget.deviceName,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatusBar extends StatelessWidget {
  const _AnimatedStatusBar({
    required this.animation,
    required this.state,
  });

  final Animation<double> animation;
  final LinkState state;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.78,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final double t =
                (math.sin(animation.value * 2 * math.pi) + 1) * 0.5;
            final _BarPalette palette = _BarPalette.forState(state, t);
            return Container(
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: palette.colors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: palette.stops,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withOpacity(palette.shadowOpacity),
                    blurRadius: palette.blurRadius,
                    spreadRadius: palette.spreadRadius,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarPalette {
  _BarPalette({
    required this.colors,
    required this.shadow,
    required this.shadowOpacity,
    required this.blurRadius,
    required this.spreadRadius,
    this.stops,
  });

  final List<Color> colors;
  final Color shadow;
  final double shadowOpacity;
  final double blurRadius;
  final double spreadRadius;
  final List<double>? stops;

  factory _BarPalette.forState(LinkState state, double phase) {
    switch (state) {
      case LinkState.scanning:
        final Color start =
            Color.lerp(const Color(0xFFF59E0B), Colors.white, 0.08 * phase)!;
        final Color end = Color.lerp(
          const Color(0xFFFCD34D),
          Colors.white,
          0.12 + phase * 0.18,
        )!;
        return _BarPalette(
          colors: [start, end],
          shadow: const Color(0xFFF59E0B),
          shadowOpacity: 0.32 + phase * 0.18,
          blurRadius: 22 + phase * 16,
          spreadRadius: 1.2 + phase * 2.4,
        );
      case LinkState.connecting:
        final Color start =
            Color.lerp(const Color(0xFF14B8A6), const Color(0xFF22D3EE), phase)!;
        final Color end =
            Color.lerp(const Color(0xFF2563EB), const Color(0xFF60A5FA), 1 - phase)!;
        final List<double> stops = [
          0,
          (0.35 + phase * 0.45).clamp(0.4, 0.88),
        ];
        return _BarPalette(
          colors: [start, end],
          shadow: const Color(0xFF2563EB),
          shadowOpacity: 0.38 + phase * 0.2,
          blurRadius: 26 + phase * 18,
          spreadRadius: 1.4 + phase * 2.6,
          stops: stops,
        );
      case LinkState.connected:
        final Color start =
            Color.lerp(const Color(0xFF10B981), const Color(0xFF34D399), phase * 0.4)!;
        final Color end =
            Color.lerp(const Color(0xFF22C55E), const Color(0xFF86EFAC), phase * 0.3)!;
        return _BarPalette(
          colors: [start, end],
          shadow: const Color(0xFF16A34A),
          shadowOpacity: 0.26 + phase * 0.12,
          blurRadius: 20 + phase * 12,
          spreadRadius: 1 + phase * 2,
        );
      case LinkState.error:
        final double burst = phase < 0.35
            ? (0.35 - phase) * 2.1
            : (phase - 0.35).clamp(0, 0.4);
        final Color start =
            Color.lerp(const Color(0xFFEF4444), const Color(0xFFF97316), burst)!;
        final Color end =
            Color.lerp(const Color(0xFFDC2626), const Color(0xFFFB7185), phase * 0.2)!;
        return _BarPalette(
          colors: [start, end],
          shadow: const Color(0xFFEF4444),
          shadowOpacity: 0.34 + burst * 0.25,
          blurRadius: 24 + burst * 18,
          spreadRadius: 1.6 + burst * 3.2,
        );
    }
  }
}

class _SystemSummaryCard extends StatelessWidget {
  const _SystemSummaryCard({
    required this.mcuConnected,
    required this.uploadState,
    required this.uploadPercent,
    required this.cloudState,
    required this.latencyMs,
    required this.deviceName,
  });

  final bool mcuConnected;
  final UploadState uploadState;
  final int? uploadPercent;
  final CloudState cloudState;
  final int? latencyMs;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Colors.white.withOpacity(0.78);
    final Color hintColor = Colors.white.withOpacity(0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x190B1726),
            blurRadius: 26,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(
            leadingIcon: Icons.memory,
            leadingText: mcuConnected ? 'MCU 已連線' : 'MCU 未連線',
            leadingColor: textColor,
            trailingIcon: Icons.upload,
            trailingText: _uploadText(),
            trailingColor: textColor,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            leadingIcon: Icons.cloud_outlined,
            leadingText: _cloudText(),
            leadingColor: textColor,
            trailingIcon: Icons.timelapse,
            trailingText: '延遲：${latencyMs != null ? '$latencyMs ms' : '\u2014'}',
            trailingColor: hintColor,
          ),
          if (deviceName != null && deviceName!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.devices_other,
                    size: 16, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '裝置：${deviceName!}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _uploadText() {
    switch (uploadState) {
      case UploadState.idle:
        return '上傳：待命';
      case UploadState.uploading:
        final pct = uploadPercent;
        return pct != null ? '上傳中 $pct%' : '上傳中…';
      case UploadState.success:
        return '上傳：完成';
      case UploadState.failed:
        return '上傳：失敗';
    }
  }

  String _cloudText() {
    switch (cloudState) {
      case CloudState.idle:
        return '雲端：待命';
      case CloudState.paused:
        return '雲端：已暫停';
      case CloudState.active:
        return '雲端：活躍';
      case CloudState.error:
        return '雲端：錯誤';
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.leadingIcon,
    required this.leadingText,
    required this.leadingColor,
    required this.trailingIcon,
    required this.trailingText,
    required this.trailingColor,
  });

  final IconData leadingIcon;
  final String leadingText;
  final Color leadingColor;
  final IconData trailingIcon;
  final String trailingText;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            icon: leadingIcon,
            text: leadingText,
            color: leadingColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryItem(
            icon: trailingIcon,
            text: trailingText,
            color: trailingColor,
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.85)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: color, height: 1.25),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GlowFallback extends StatelessWidget {
  const _GlowFallback({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double t = (math.sin(animation.value * 2 * math.pi) + 1) * 0.5;
        final Color primary =
            Color.lerp(const Color(0xFF22D3EE), const Color(0xFF6366F1), t)!;
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: 280,
            height: 220,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  primary.withOpacity(0.24 + t * 0.12),
                  primary.withOpacity(0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
