import 'package:flutter/widgets.dart';

/// The width of [text] on one line in [style] at the device's real text size
/// (`DL-119`). The style is merged over the surrounding default, as a `Text`
/// would, and scaled by the user's text scale.
double textWidth(BuildContext context, String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}
