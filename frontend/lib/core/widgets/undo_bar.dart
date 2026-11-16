import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/kit_colors.dart';

/// How long the undo bar stays (`DL-119`). With a screen reader on it does not
/// leave on its own, see [showUndoBar].
const Duration undoBarDuration = Duration(seconds: 4);

/// Shows a floating bar with [text] and an [actionLabel] that runs [onUndo]
/// and closes the bar. It hides the current snack bar first. It leaves after
/// [undoBarDuration]; with a screen reader on it stays until its action, a
/// swipe or the next bar, so the person can reach the action (`DL-119`).
/// [duration] and [margin] default to the usual bar; the search screen gives a
/// longer one that sits above its cart bar (`DL-128`). [onVisible] runs once
/// the bar has come in; before then it is queued or still entering and cannot
/// be closed through its controller.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoBar(
  ScaffoldMessengerState messenger, {
  required String text,
  required String actionLabel,
  required VoidCallback onUndo,
  Duration duration = undoBarDuration,
  EdgeInsetsGeometry? margin,
  VoidCallback? onVisible,
}) {
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KitColors.undoBar,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: duration,
      margin: margin,
      onVisible: onVisible,
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

const Cubic _inlineCurve = Cubic(0.2, 0.8, 0.2, 1);
const Duration _inlineIn = Duration(milliseconds: 250);
const Duration _inlineOut = Duration(milliseconds: 200);

/// The undo bar drawn inside a surface that lies over the screen's snack bar,
/// such as a bottom sheet (`DL-137`). It comes in by opacity and a 16 px rise,
/// stays [duration] (until its action with a screen reader on, as
/// [showUndoBar] does), leaves by opacity, and then calls [onEnded] — once,
/// however it ended: its time, «Вернуть» (after [onUndo]) or its removal from
/// the tree. The owner takes it out of the tree on [onEnded].
class InlineUndoBar extends StatefulWidget {
  const InlineUndoBar({
    required this.text,
    required this.actionLabel,
    required this.onUndo,
    required this.onEnded,
    required this.duration,
    super.key,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onUndo;
  final VoidCallback onEnded;
  final Duration duration;

  @override
  State<InlineUndoBar> createState() => _InlineUndoBarState();
}

class _InlineUndoBarState extends State<InlineUndoBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _inlineIn,
    reverseDuration: _inlineOut,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: _inlineCurve,
    reverseCurve: Curves.easeIn,
  );
  Timer? _timer;
  bool _leaving = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(_startTimer);
  }

  /// The time runs from when the bar has come in; a screen reader's bar has
  /// none.
  void _startTimer() {
    if (!mounted || _leaving || MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _timer = Timer(widget.duration, _leave);
  }

  void _leave() {
    if (_leaving || !mounted) {
      return;
    }
    _leaving = true;
    _timer?.cancel();
    _controller.reverse().whenComplete(_end);
  }

  void _end() {
    if (_ended) {
      return;
    }
    _ended = true;
    widget.onEnded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curved.dispose();
    _controller.dispose();
    // Removed before it ended: the owner still hears of it, once.
    _end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _curved,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: _curved.value,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : 16 * (1 - _curved.value)),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.undoBar,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: _UndoContent(
            text: widget.text,
            actionLabel: widget.actionLabel,
            onPressed: () {
              if (_leaving) {
                return;
              }
              widget.onUndo();
              _leave();
            },
          ),
        ),
      ),
    );
  }
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
