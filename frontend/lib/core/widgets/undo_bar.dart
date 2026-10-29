import 'package:flutter/material.dart';

import '../theme/kit_colors.dart';

/// How long the undo bar stays (`DL-119`). With a screen reader on it does not
/// leave on its own, see [showUndoBar].
const Duration undoBarDuration = Duration(seconds: 4);

/// Shows a floating bar with [text] and an [actionLabel] that runs [onUndo]
/// and closes the bar. It hides the current snack bar first. It leaves after
/// [undoBarDuration]; with a screen reader on it stays until its action, a
/// swipe or the next bar, so the person can reach the action (`DL-119`).
void showUndoBar(
  ScaffoldMessengerState messenger, {
  required String text,
  required String actionLabel,
  required VoidCallback onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: KitColors.undoBar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: undoBarDuration,
        persist: MediaQuery.accessibleNavigationOf(messenger.context),
        content: _UndoContent(
          text: text,
          actionLabel: actionLabel,
          onPressed: () {
            onUndo();
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
}

const TextStyle _textStyle = TextStyle(color: Colors.white, fontSize: 14);
const TextStyle _actionStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: KitColors.undoAction,
);

/// The bar's text and action: one row when they fit, otherwise the action
/// under the text at the end, so large text never overflows (`DL-119`).
class _UndoContent extends StatelessWidget {
  const _UndoContent({
    required this.text,
    required this.actionLabel,
    required this.onPressed,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onPressed;

  double _width(BuildContext context, String value, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
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

  @override
  Widget build(BuildContext context) {
    final Widget action = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: KitColors.undoAction,
      ),
      child: Text(actionLabel, style: _actionStyle),
    );
    final Widget label = Text(text, style: _textStyle);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The button's own padding is 12 on each side.
        final double needed =
            _width(context, text, _textStyle) +
            _width(context, actionLabel, _actionStyle) +
            24;
        if (needed <= constraints.maxWidth) {
          return Row(
            children: <Widget>[
              Expanded(child: label),
              action,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            label,
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        );
      },
    );
  }
}
