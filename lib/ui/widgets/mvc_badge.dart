import 'package:flutter/material.dart';
import 'info_sheets.dart';

class MvcBadge extends StatelessWidget {
  final double? percent; // 0-100
  final DateTime? updatedAt;
  const MvcBadge({super.key, required this.percent, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final p = ((percent ?? 0) as num).clamp(0, 100).toDouble();
    final bg = _bgColorFor(p);
    final label = percent == null ? '肌力 %MVC：--' : '肌力 %MVC：${p.toStringAsFixed(1)}%';
    final ts = updatedAt;
    final when = ts == null ? '更新時間：--:--:--' : '更新時間：${_hhmmss(ts)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showMvcInfo(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          when,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Color _bgColorFor(double pct) {
    if (pct <= 30) return const Color(0xFF43A047); // green
    if (pct <= 60) return const Color(0xFFFFB300); // amber
    return const Color(0xFFE53935); // red
  }

  String _hhmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
