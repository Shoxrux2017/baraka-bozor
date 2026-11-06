import 'package:flutter/material.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import 'rate_rise.dart';

/// What the rating screen's button is doing (`DL-134`).
enum RateFooterMode {
  /// The form is open: the button says send, send again or shorten.
  form,

  /// A rating is on its way.
  sending,

  /// The answer came: a check, for a moment, before the screen goes.
  sent,

  /// The window is closed: the button leads back to the order.
  closed,
}

/// The footer pinned under the rating screen (`DL-134`): the failure notes and
/// the one big button. The notes sit in a short scroll of their own, so at
/// large text with the keyboard up the button never leaves the screen.
/// [onPressed] is the button's action in the [mode]; `null` when it is off.
class RateOrderFooter extends StatelessWidget {
  const RateOrderFooter({
    required this.mode,
    required this.locked,
    required this.tooLong,
    required this.unsent,
    required this.refusal,
    required this.onPressed,
    required this.onRetry,
    super.key,
  });

  final RateFooterMode mode;

  /// A send's answer was lost: the next send repeats it as it was.
  final bool locked;

  final bool tooLong;

  /// A send failed for sure before it left the phone: the red strip.
  final bool unsent;

  /// The words of a sure refusal, shown as a red line.
  final String? refusal;

  final VoidCallback? onPressed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double bottom = MediaQuery.paddingOf(context).bottom;
    final bool notes = mode == RateFooterMode.form;
    final String? line = notes ? refusal : null;
    // «Повторить» sends nothing while the comment is too long, so the strip
    // waits until it is shortened.
    final bool strip = unsent && !locked && !tooLong;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KitColors.line)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, -6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (notes && (line != null || strip || locked))
              Flexible(
                child: SingleChildScrollView(
                  // Not the body's controller: the notes scroll on their own.
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (line != null)
                        Padding(
                          key: const ValueKey<String>('rate-failure'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: KitColors.danger,
                              ),
                            ),
                          ),
                        ),
                      if (strip)
                        RateRise(
                          child: _Strip(onRetry: onRetry, l10n: l10n),
                        ),
                      if (locked) RateRise(child: _LostAnswerNote(l10n: l10n)),
                    ],
                  ),
                ),
              ),
            _SendButton(
              mode: mode,
              locked: locked,
              tooLong: tooLong,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing was sent: the words and «Повторить». Above 1.3 at 13 px the button
/// goes under the words at full width.
class _Strip extends StatelessWidget {
  const _Strip({required this.onRetry, required this.l10n});

  final VoidCallback onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final Widget words = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        l10n.rateUnsent,
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: KitColors.ink2,
        ),
      ),
    );
    final Widget retry = _RetryButton(label: l10n.retryButton, onTap: onRetry);
    const Widget icon = Icon(Icons.wifi_off, size: 20, color: KitColors.danger);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        key: const ValueKey<String>('rate-strip'),
        decoration: BoxDecoration(
          color: KitColors.dangerWash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: large
              ? const EdgeInsets.fromLTRB(12, 6, 12, 6)
              : const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        icon,
                        const SizedBox(width: 10),
                        Expanded(child: words),
                      ],
                    ),
                    retry,
                  ],
                )
              : Row(
                  children: <Widget>[
                    icon,
                    const SizedBox(width: 10),
                    Expanded(child: words),
                    const SizedBox(width: 10),
                    retry,
                  ],
                ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('rate-retry'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KitColors.danger,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The answer was lost: the rating may have been saved, so the form is frozen
/// and the next send repeats it exactly.
class _LostAnswerNote extends StatelessWidget {
  const _LostAnswerNote({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        key: const ValueKey<String>('rate-unsure'),
        decoration: BoxDecoration(
          color: KitColors.warningWash,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.sync_problem,
                  size: 18,
                  color: KitColors.warningDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.rateUnsure,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: KitColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big green button: full width, at least 54 high, scaling to 0.98 under a
/// finger, changing colour over 250 ms.
class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.mode,
    required this.locked,
    required this.tooLong,
    required this.onPressed,
  });

  final RateFooterMode mode;
  final bool locked;
  final bool tooLong;
  final VoidCallback? onPressed;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  String _label(AppLocalizations l10n) => switch (widget.mode) {
    RateFooterMode.sending => l10n.rateSending,
    RateFooterMode.sent => l10n.rateSent,
    RateFooterMode.closed => l10n.rateBackToOrder,
    RateFooterMode.form =>
      widget.locked
          ? l10n.rateSendAgain
          : widget.tooLong
          ? l10n.rateShorten
          : l10n.rateSend,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final bool busy =
        widget.mode == RateFooterMode.sending ||
        widget.mode == RateFooterMode.sent;
    final bool active = widget.onPressed != null;
    final Widget label = Flexible(
      child: Text(
        _label(l10n),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Listener(
      onPointerDown: (_) => _press(true),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedScale(
        scale: _pressed && active && !reduced ? 0.98 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 100),
        child: FilledButton(
          key: const ValueKey<String>('rate-send'),
          style: FilledButton.styleFrom(
            animationDuration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 250),
            backgroundColor: KitColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: busy
                ? KitColors.primary
                : KitColors.buttonOff,
            disabledForegroundColor: busy ? Colors.white : KitColors.muted,
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: widget.onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.mode == RateFooterMode.sending) ...<Widget>[
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.mode == RateFooterMode.sent) ...<Widget>[
                _Check(reduced: reduced),
                const SizedBox(width: 8),
              ],
              label,
            ],
          ),
        ),
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
