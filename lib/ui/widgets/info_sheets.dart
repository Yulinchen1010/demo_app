import 'package:flutter/material.dart';



const _cyan = Color(0xFF00E5FF);

const _green = Color(0xFF76FF03);

const _amber = Color(0xFFFFB300);

const _orange = Color(0xFFFF7043);

const _red = Color(0xFFFF3B30);



Future<void> showMvcInfo(BuildContext context) {

  return _showCleanSheet(

    context,

    title: '\uff05MVC \u7c21\u6613\u8aaa\u660e',

    body: [

      _lead('\u4ec0\u9ebc\u662f \uff05MVC\uff1f'),

      const SizedBox(height: 8),

      _para('%MVC \u4ee3\u8868\u300c\u73fe\u5728\u7528\u529b\u7684\u7a0b\u5ea6\u300d\uff0c\u662f\u548c\u4f60\u5e73\u5e38\u7684\u6700\u5927\u529b\u91cf\u76f8\u6bd4\u7684\u767e\u5206\u6bd4\u3002\u6578\u503c\u8d8a\u9ad8\uff0c\u4ee3\u8868\u8d8a\u5403\u529b\u3002'),

      const SizedBox(height: 12),

      _lead('\u5feb\u901f\u5224\u8b80'),

      const SizedBox(height: 8),

      _pillRow([

        _pill('\u2264 20\uff05 \u653e\u9b06\uff0f\u4f4e\u8ca0\u8377', _cyan),

        _pill('20\uff5e60\uff05 \u4e00\u822c\u6d3b\u52d5', _green),

        _pill('\u2265 60\uff05 \u9ad8\u5f37\u5ea6\uff0f\u75b2\u52de\u98a8\u96aa', _red),

      ]),

      const SizedBox(height: 12),

      _lead('\u8cc7\u6599\u4f86\u6e90'),

      const SizedBox(height: 8),

      _bullet('\u611f\u6e2c\u5668\u6bcf\u79d2\u8a08\u7b97\u808c\u96fb RMS\uff0c\u63db\u7b97\u70ba \uff05MVC \u5f8c\u56de\u50b3\u81f3 App \u5373\u6642\u986f\u793a\u3002'),

      _bullet('App \u50c5\u986f\u793a \uff05MVC\uff1b\u6821\u6b63\uff0fMVC \u53c3\u8003\u503c\u7531\u88dd\u7f6e\u6216\u96f2\u7aef\u7dad\u8b77\u3002'),

    ],

  );

}



Future<void> showRulaInfo(BuildContext context) {

  return _showCleanSheet(

    context,

    title: 'RULA \u59ff\u52e2\u98a8\u96aa\u5206\u6578',

    body: [

      _lead('RULA \u662f\u4ec0\u9ebc\uff1f'),

      const SizedBox(height: 8),

      _para('RULA \u7528\u65bc\u8a55\u4f30\u4e0a\u80a2\u76f8\u95dc\u7684\u59ff\u52e2\u98a8\u96aa\u3002\u5206\u6578\u8d8a\u9ad8\uff0c\u8d8a\u9700\u8981\u6539\u5584\u59ff\u52e2\u3002\u7cfb\u7d71\u6703\u6839\u64da\u611f\u6e2c\u5230\u7684\u89d2\u5ea6\uff0f\u59ff\u52e2\u81ea\u52d5\u8a08\u7b97\u5206\u6578\u3002'),

      const SizedBox(height: 12),

      _lead('\u5206\u6578\u5340\u9593'),

      const SizedBox(height: 8),

      _riskRow('\uff11\uff5e\uff12\u3000\u4f4e\u98a8\u96aa\uff08\u53ef\u63a5\u53d7\uff09', _green),

      const SizedBox(height: 6),

      _riskRow('\uff13\uff5e\uff14\u3000\u4e2d\u7b49\uff08\u5efa\u8b70\u6ce8\u610f\uff09', _amber),

      const SizedBox(height: 6),

      _riskRow('\uff15\uff5e\uff16\u3000\u8f03\u9ad8\uff08\u61c9\u6539\u5584\uff09', _orange),

      const SizedBox(height: 6),

      _riskRow('\u2265 7     \u9ad8\uff08\u9700\u7acb\u5373\u8abf\u6574\uff09', _red),

      const SizedBox(height: 12),

      _note('\u7cfb\u7d71\u50c5\u986f\u793a\u5206\u6578\uff1b\u8a73\u7d30\u8a08\u7b97\u65bc\u5f8c\u7aef\u6216\u88dd\u7f6e\u7aef\u5b8c\u6210\uff0c\u4ee5\u78ba\u4fdd\u4e00\u81f4\u6027\u8207\u6548\u80fd\u3002'),

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

                tooltip: '\u95dc\u9589',

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

              child: const Text('\u77e5\u9053\u4e86'),

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

