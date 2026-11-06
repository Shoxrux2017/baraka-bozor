import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/retry_strip.dart';
import '../../../core/widgets/submit_button.dart';
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

  String _label(AppLocalizations l10n) => switch (mode) {
    RateFooterMode.sending => l10n.rateSending,
    RateFooterMode.sent => l10n.rateSent,
    RateFooterMode.closed => l10n.rateBackToOrder,
    RateFooterMode.form =>
      locked
          ? l10n.rateSendAgain
          : tooLong
          ? l10n.rateShorten
          : l10n.rateSend,
  };

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
                        RetryStrip(
                          stripKey: const ValueKey<String>('rate-strip'),
                          retryKey: const ValueKey<String>('rate-retry'),
                          message: l10n.rateUnsent,
                          onRetry: onRetry,
                        ),
                      if (locked) RateRise(child: _LostAnswerNote(l10n: l10n)),
                    ],
                  ),
                ),
              ),
            SubmitButton(
              buttonKey: const ValueKey<String>('rate-send'),
              face: switch (mode) {
                RateFooterMode.sending => SubmitFace.busy,
                RateFooterMode.sent => SubmitFace.done,
                _ => onPressed == null ? SubmitFace.off : SubmitFace.ready,
              },
              label: _label(l10n),
              onPressed: onPressed,
            ),
          ],
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
