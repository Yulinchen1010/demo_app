import 'package:flutter/material.dart';
import '../../data/models.dart';

class RulaBadge extends StatelessWidget {
  final RulaScore? score;
  final DateTime? updatedAt;
  const RulaBadge({super.key, required this.score, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final s = score;
    final bg = _bgColorFor(s?.score ?? 0);
    final label = s == null
        ? '--'
        : 'RULA: ${s.score}${s.riskLabel != null ? ' (${s.riskLabel})' : ''}';
    final ts = updatedAt;
    final when = ts == null
        ? 'Updated: --:--:--'
        : 'Updated at ${_hhmmss(ts)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
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
