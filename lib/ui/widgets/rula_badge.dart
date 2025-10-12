import 'package:flutter/material.dart';
import '../../data/models.dart';
import 'info_sheets.dart';

class RulaBadge extends StatelessWidget {
  final RulaScore? score;
  final DateTime? updatedAt;
  const RulaBadge({super.key, required this.score, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final s = score;
    final bg = _bgColorFor(s?.score ?? 0);
    final label = s == null
        ? '\u59ff\u52e2\u98a8\u96aa\u5206\u6578\uff08RULA\uff09\uff1a--'
        : '\u59ff\u52e2\u98a8\u96aa\u5206\u6578\uff08RULA\uff09\uff1a${s.score}${s.riskLabel != null ? '\uff08${s.riskLabel}\uff09' : ''}';

    final ts = updatedAt;
    final when = ts == null
        ? '\u66f4\u65b0\u6642\u9593\uff1a--:--:--'
        : '\u66f4\u65b0\u6642\u9593\uff1a${_hhmmss(ts)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(onTap: () => showRulaInfo(context), child: AnimatedContainer(
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

  Color _bgColorFor(int score) {
    if (score <= 2) return const Color(0xFF43A047); // green
    if (score <= 4) return const Color(0xFFFB8C00); // orange
    return const Color(0xFFE53935); // red
  }

  String _hhmmss(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

