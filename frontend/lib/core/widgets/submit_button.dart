import 'package:flutter/material.dart';

import '../theme/kit_colors.dart';

/// What a [SubmitButton] is doing (`DL-135`).
enum SubmitFace {
  /// Pressable, green.
  ready,

  /// Not pressable yet: grey with muted words.
  off,

  /// A request is on its way: green with a spinner, not pressable.
  busy,

  /// The answer came: green with a check, not pressable.
  done,
}

/// The big green button at the foot of a form: full width, at least 54 high,
/// scaling to 0.98 under a finger when [face] is [SubmitFace.ready], changing
/// colour over 250 ms. It taps only in `ready`; `busy` and `done` keep the
/// green fill though disabled. A reader hears `off` as «{label}, недоступна»
/// from the button's own disabled state, then [offHint] (`DL-135`).
/// [buttonKey] sits on the inner [FilledButton].
class SubmitButton extends StatefulWidget {
  const SubmitButton({
    required this.face,
    required this.label,
    required this.onPressed,
    this.offHint,
    this.buttonKey,
    super.key,
  });

  final SubmitFace face;
  final String label;
  final VoidCallback? onPressed;

  /// What a reader hears after «недоступна» while the button is off.
  final String? offHint;

  final Key? buttonKey;

  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final bool ready = widget.face == SubmitFace.ready;
    final bool filled =
        widget.face == SubmitFace.busy || widget.face == SubmitFace.done;
    final Widget button = FilledButton(
      key: widget.buttonKey,
      style: FilledButton.styleFrom(
        animationDuration: reduced
            ? Duration.zero
            : const Duration(milliseconds: 250),
        backgroundColor: KitColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: filled
            ? KitColors.primary
            : KitColors.buttonOff,
        disabledForegroundColor: filled ? Colors.white : KitColors.muted,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: ready ? widget.onPressed : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (widget.face == SubmitFace.busy) ...<Widget>[
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.face == SubmitFace.done) ...<Widget>[
            _Check(reduced: reduced),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Listener(
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedScale(
        scale: _pressed && ready && !reduced ? 0.98 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 100),
        child: widget.face == SubmitFace.off && widget.offHint != null
            ? MergeSemantics(
                child: Semantics(hint: widget.offHint, child: button),
              )
            : button,
      ),
    );
  }
}

/// The ✓ popping 1 → 1.18 → 0.97 → 1 in 380 ms; still with reduced motion.
class _Check extends StatelessWidget {
  const _Check({required this.reduced});

  final bool reduced;

  @override
  Widget build(BuildContext context) {
    const Widget icon = Icon(Icons.check, size: 20);
    if (reduced) {
      return icon;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      builder: (BuildContext context, double t, Widget? child) =>
          Transform.scale(scale: _pop(t), child: child),
      child: icon,
    );
  }

  static double _pop(double t) {
    final (double from, double to, double a, double b) = t < 0.35
        ? (1, 1.18, 0, 0.35)
        : t < 0.7
        ? (1.18, 0.97, 0.35, 0.7)
        : (0.97, 1, 0.7, 1);
    return from + (to - from) * Curves.easeOut.transform((t - a) / (b - a));
  }
}
