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

/// How much [scaler] enlarges text of [fontSize]: `scale(fontSize) / fontSize`.
/// A layout size that follows the text takes this factor at the size of the
/// text it must hold, not at its own: Android 14 and later scales large sizes
/// hardly at all and small ones fully, so `scale(88)` says nothing of a 12 px
/// name (`DL-126`).
double textScaleAt(TextScaler scaler, double fontSize) =>
    scaler.scale(fontSize) / fontSize;
