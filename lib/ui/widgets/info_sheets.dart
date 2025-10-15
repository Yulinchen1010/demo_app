import 'package:flutter/material.dart';

import '../../design/t_colors.dart';

Future<void> showMvcInfo(BuildContext context) {
  return _showInfoSheet(
    context,
    icon: Icons.monitor_heart,
    title: '\u0025MVC \u6700\u5927\u81EA\u4E3B\u6536\u7E2E\u767E\u5206\u6BD4',
    summary: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '\u5373\u6642\u986f\u793a\u808c\u96FB\u8A0A\u865F\u76F8\u5C0D\u65BC MVC \u7684\u767E\u5206\u6BD4\uFF0C\u9AD8\u65BC 60%\u610F\u5473\u8457\u808C\u8089\u8CA0\u8377\u660E\u986F\u589E\u52A0',
        style: TextStyle(fontSize: 13, color: TColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    ),
    cards: const [
      _InfoCardData(
        title: '\u5FEB\u901F\u5224\u8B80',
        gradient: [Color(0xFF0EA5E9), TColors.primary],
        bulletLines: [
          '\u2264 20%\uFF1A\u653E\u9B06\u6216\u4F4E\u8CA0\u8377',
          '20\u201360%\uFF1A\u4E00\u822C\u6D3B\u52D5',
          '\u2265 60%\uFF1A\u9AD8\u5F37\u5EA6\u6216\u75B2\u52DE\u98A8\u96AA',
        ],
      ),
      _InfoCardData(
        title: '\u8CC7\u6599\u4F86\u6E90',
        gradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
        paragraphLines: [
          '\u611F\u6E2C\u5668\u6BCF\u79D2\u8A08\u7B97\u808C\u96FB RMS \u5E76\u63DB\u7B97\u70BA %MVC \u5F8C\u56DE\u50B3\u7D66 App',
          'App \u50C5\u986F\u793A\u8207\u4E0A\u50B3\u8CC7\u6599\uFF0C\u6821\u6B63\u8207 MVC \u57FA\u6E96\u7531\u88DD\u7F6E\u7AEF\u6216\u96F2\u7AEF\u7DAD\u8B77',
        ],
      ),
    ],
    note: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '\u5EFA\u8B70\u5B9A\u671F\u6821\u6B63 MVC \u57FA\u6E96\u4EE5\u907F\u514D\u56E0\u500B\u9AD4\u5DEE\u7570\u6216\u9577\u671F\u4F7F\u7528\u9020\u6210\u5224\u8B80\u504F\u5DEE',
        style: TextStyle(fontSize: 13, color: Colors.white54),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Future<void> showRulaInfo(BuildContext context) {
  return _showInfoSheet(
    context,
    icon: Icons.accessibility_new,
    title: 'RULA \u59FF\u52E2\u98A8\u96AA\u5206\u6578',
    summary: const Text(
      '\u7528\u65BC\u8A55\u4F30\u4E0A\u80A2\u59FF\u52E2\u8207\u8CA0\u8377\u7684\u98A8\u96AA\u6307\u6A19\uFF0C\u5206\u6578\u8D8A\u9AD8\u8868\u793A\u8D8A\u9700\u8981\u8ABF\u6574\u59FF\u52E2',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: TColors.textSecondary,
        height: 1.5,
      ),
    ),
    cards: const [
      _InfoCardData(
        title: '\u5206\u6578\u5340\u9593',
        gradient: [Color(0xFFA855F7), Color(0xFF7C3AED)],
        bulletLines: [
          '1\u20132\uFF1A\u4F4E\u98A8\u96AA\uFF0C\u53EF\u63A5\u53D7',
          '3\u20134\uFF1A\u4E2D\u98A8\u96AA\uFF0C\u5EFA\u8B70\u7559\u610F',
          '5\u20136\uFF1A\u8F03\u9AD8\u98A8\u96AA\uFF0C\u61C9\u6539\u5584',
          '\u2265 7\uFF1A\u9AD8\u98A8\u96AA\uFF0C\u9700\u7ACB\u5373\u8ABF\u6574',
        ],
      ),
      _InfoCardData(
        title: '\u904B\u4F5C\u65B9\u5F0F',
        gradient: [Color(0xFFF97316), Color(0xFFEA580C)],
        paragraphLines: [
          '\u7CFB\u7D71\u6839\u64DA\u5075\u6E2C\u5230\u7684\u89D2\u5EA6\u8207\u59FF\u52E2\u52D5\u4F5C\u8A08\u7B97 RULA \u5206\u6578',
          '\u5831\u8868\u50C5\u986F\u793A\u5206\u6578\uFF0C\u7D30\u90E8\u8A08\u7B97\u65BC\u88DD\u7F6E\u7AEF\u6216\u5F8C\u7AEF\u5B8C\u6210\u4EE5\u78BA\u4FDD\u4E00\u81F4\u6027',
        ],
      ),
    ],
    note: const Text(
      '\u82E5\u5206\u6578\u9577\u6642\u9593\u8655\u65BC\u8F03\u9AD8\u6216\u9AD8\u98A8\u96AA\uFF0C\u5EFA\u8B70\u5B89\u6392\u4F11\u606F\u6216\u8ABF\u6574\u52D5\u4F5C\u6D41\u7A0B',
      style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.4),
      textAlign: TextAlign.center,
    ),
  );
}

Future<void> _showInfoSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget summary,
  required List<_InfoCardData> cards,
  required Widget note,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: TColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: TColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TColors.textPrimary,
                      shadows: [
                        Shadow(blurRadius: 8, color: TColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              summary,
              const SizedBox(height: 20),
              for (final card in cards) ...[
                _InfoCard(data: card),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: note),
                ],
              ),
              const SizedBox(height: 20),
              const _CloseButton(),
            ],
          ),
        ),
      );
    },
  );
}

class _InfoCardData {
  const _InfoCardData({
    required this.title,
    required this.gradient,
    this.bulletLines,
    this.paragraphLines,
  });

  final String title;
  final List<Color> gradient;
  final List<String>? bulletLines;
  final List<String>? paragraphLines;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.data});

  final _InfoCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: data.gradient.last.withOpacity(0.28),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (data.bulletLines != null)
            ...data.bulletLines!.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${String.fromCharCode(0x2022)} $line',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          if (data.paragraphLines != null)
            ...data.paragraphLines!.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),
        ],
      ),
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
          '\u4E86\u89E3\u4E86',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
