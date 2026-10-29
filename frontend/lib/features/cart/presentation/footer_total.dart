import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/soft_change.dart';

/// "Итого" and the total over the button. They stand in one row when the
/// total and the label's longest word fit it; otherwise the total goes under
/// the label, end-aligned, and shrinks only when it alone is wider than the
/// row, so it never breaks inside a word (`DL-119`, shared by the checkout in `DL-121`).
class FooterTotal extends StatelessWidget {
  const FooterTotal({
    required this.label,
    required this.value,
    required this.waiting,
    required this.width,
    super.key,
  });

  final String label;
  final String value;
  final bool waiting;
  final double width;

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 14,
    color: KitColors.ink2,
  );
  static const TextStyle _valueStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: KitColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final Widget amount = SoftChange(
      value: value,
      waiting: waiting,
      child: Text(
        value,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.end,
        style: _valueStyle,
      ),
    );
    final double valueWidth = textWidth(context, value, _valueStyle);
    final double longestWord = label
        .split(RegExp(r'\s+'))
        .map((String word) => textWidth(context, word, _labelStyle))
        .fold<double>(0, math.max);
    if (valueWidth + 12 + longestWord <= width) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(child: Text(label, style: _labelStyle)),
          const SizedBox(width: 12),
          amount,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: _labelStyle),
        Align(
          alignment: Alignment.centerRight,
          child: FittedBox(fit: BoxFit.scaleDown, child: amount),
        ),
      ],
    );
  }
}
