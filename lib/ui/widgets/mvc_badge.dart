import 'package:flutter/material.dart';
import 'info_sheets.dart';

class RmsBadge extends StatelessWidget {
  final double? rms; // 0–1 或 0–100 皆可，視後端輸出
  final DateTime? updatedAt;

  const RmsBadge({super.key, required this.rms, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final value = ((rms ?? 0) as num).clamp(0, 1.0).toDouble(); // 正規化到 0–1
    final bg = _bgColorFor(value);
    final label = rms == null
        ? 'RMS：--'
        : 'RMS：${(value * 100).toStringAsFixed(1)}%';
    final ts = updatedAt;
    final when = ts == null
        ? '更新時間：--:--:--'
        : '更新時間：${_hhmmss(ts)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showRmsInfo(context),
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

  // 可依 RMS 上升或疲勞等級調整顏色範圍
  Color _bgColorFor(double rms) {
    if (rms < 0.4) return const Color(0xFF43A047); // 綠：活化低
    if (rms < 0.7) return const Color(0xFFFFB300); // 黃：中度活化
    return const Color(0xFFE53935); // 紅：高活化 / 疲勞期
  }

  String _hhmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
