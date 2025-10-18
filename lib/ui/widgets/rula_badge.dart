import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../widgets/info_sheets.dart'; // ← 確保這行指到正確位置

class RulaBadge extends StatelessWidget {
  final RulaScore? score;
  final DateTime? updatedAt;
  const RulaBadge({super.key, required this.score, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final s = score;
    final bg = _bgColorFor(s?.score ?? 0);
    final label = s == null
        ? '姿勢風險分數（RULA）：--'
        : '姿勢風險分數（RULA）：${s.score}${s.riskLabel != null ? '（${s.riskLabel}）' : ''}';

    final ts = updatedAt;
    final when = ts == null ? '更新時間：--:--:--' : '更新時間：${_hhmmss(ts)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showRulaInfo(context), // ← 點擊開說明
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
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
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

 Color _bgColorFor(int score) {
  if (score <= 2) return const Color(0xFF43A047); // 綠 - 低風險
  if (score <= 4) return const Color(0xFFFBC02D); // 黃 - 中風險
  if (score <= 6) return const Color(0xFFFF9800); // 橙 - 較高風險
  return const Color(0xFFE53935); // 紅 (score == 7) - 高風險
}

  }

  String _hhmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
