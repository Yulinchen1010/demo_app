import 'package:flutter/material.dart';

const _cyan = Color(0xFF00E5FF);
const _green = Color(0xFF76FF03);
const _amber = Color(0xFFFFB300);
const _orange = Color(0xFFFF7043);
const _red = Color(0xFFFF3B30);

Future<void> showMvcInfo(BuildContext context) {
  return _showCleanSheet(
    context,
    title: '％MVC 簡易說明',
    body: [
      _lead('什麼是 ％MVC？'),
      const SizedBox(height: 8),
      _para('%MVC 代表「現在用力的程度」，是和你平常的最大力量相比的百分比。數值越高，代表越吃力。'),
      const SizedBox(height: 12),
      _lead('快速判讀'),
      const SizedBox(height: 8),
      _pillRow([
        _pill('≤ 20％ 放鬆／低負荷', _cyan),
        _pill('20～60％ 一般活動', _green),
        _pill('≥ 60％ 高強度／疲勞風險', _red),
      ]),
      const SizedBox(height: 12),
      _lead('資料來源'),
      const SizedBox(height: 8),
      _bullet('感測器每秒計算肌電 RMS，換算為 ％MVC 後回傳至 App 即時顯示。'),
      _bullet('App 僅顯示 ％MVC；校正／MVC 參考值由裝置或雲端維護。'),
    ],
  );
}

Future<void> showRulaInfo(BuildContext context) {
  return _showCleanSheet(
    context,
    title: 'RULA 姿勢風險分數',
    body: [
      _lead('RULA 是什麼？'),
      const SizedBox(height: 8),
      _para('RULA 用於評估上肢相關的姿勢風險。分數越高，越需要改善姿勢。系統會根據感測到的角度／姿勢自動計算分數。'),
      const SizedBox(height: 12),
      _lead('分數區間'),
      const SizedBox(height: 8),
      _riskRow('１～２　低風險（可接受）', _green),
      const SizedBox(height: 6),
      _riskRow('３～４　中等（建議注意）', _amber),
      const SizedBox(height: 6),
      _riskRow('５～６　較高（應改善）', _orange),
      const SizedBox(height: 6),
      _riskRow('≥ 7     高（需立即調整）', _red),
      const SizedBox(height: 12),
      _note('系統僅顯示分數；詳細計算於後端或裝置端完成，以確保一致性與效能。'),
    ],
  );
}

Future<void> _showCleanSheet(
  BuildContext context, {
  required String title,
  required List<Widget> body,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.onSurface.withOpacity(.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .2),
                ),
              ),
              IconButton(
                tooltip: '關閉',
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _lead(String text) => Row(
      children: [
        const Icon(Icons.info_outline, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );

Widget _para(String text) => Text(text, style: const TextStyle(height: 1.5));

Widget _bullet(String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
      ],
    );

Widget _note(String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info, size: 18, color: Colors.white.withOpacity(.7)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.5, fontStyle: FontStyle.italic))),
      ],
    );

Widget _pill(String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(.18),
        border: Border.all(color: c.withOpacity(.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );

Widget _pillRow(List<Widget> children) => Wrap(runSpacing: 6, spacing: 6, children: children);

Widget _riskRow(String label, Color c) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.withOpacity(.22), c.withOpacity(.55)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(.7)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
