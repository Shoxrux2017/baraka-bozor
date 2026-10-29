import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/presentation/footer_total.dart';

const TextStyle _buttonText = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

/// The bar under the checkout (`DL-121`): "≈ total | Заказать". Busy, the
/// green button says what it does. A recount shows "было → стало" above it, a
/// reason line stands over the grey button, and when "total | Заказать" does not
/// fit at the device's text size the total stands over a button with «Заказать»
/// alone (`DL-119`).
class CheckoutFooter extends StatelessWidget {
  const CheckoutFooter({
    required this.totalUzs,
    required this.estimate,
    required this.busy,
    required this.busyLabel,
    required this.onOrder,
    this.recountedFromUzs,
    this.why,
    this.message,
    super.key,
  });

  final int? totalUzs;
  final bool estimate;
  final bool busy;
  final String busyLabel;
  final VoidCallback? onOrder;

  /// The total the Customer saw before a recount; shown with [totalUzs] above
  /// the button.
  final int? recountedFromUzs;

  /// Why the button is grey, when it is the missing address.
  final String? why;
  final Widget? message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? total = totalUzs;
    final int? recountedFrom = recountedFromUzs;
    final Widget? note = message;
    final String? reason = why;
    final String? totalText = total == null
        ? null
        : _amount(context, l10n, total);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // The button's padding is 18 on each side; its content is the
            // total, a 12 + 1 + 12 divider and «Заказать».
            final double needed =
                (totalText == null
                    ? 0
                    : textWidth(context, totalText, _buttonText) + 25) +
                textWidth(context, l10n.checkoutOrder, _buttonText) +
                36;
            final bool stacked =
                totalText != null && needed > constraints.maxWidth;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (note != null)
                  // A long message scrolls: the button below always stays in
                  // reach.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.25,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: note,
                      ),
                    ),
                  ),
                if (recountedFrom != null && total != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: recountedFrom == total
                        ? _RecountShell(
                            key: const ValueKey<String>('checkout-refreshed'),
                            child: Text(
                              l10n.checkoutRecounted,
                              style: _noticeText,
                            ),
                          )
                        : CheckoutRecountNotice(
                            key: const ValueKey<String>('checkout-refreshed'),
                            before: _amount(context, l10n, recountedFrom),
                            after: _amount(context, l10n, total),
                          ),
                  ),
                if (reason != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      reason,
                      key: const ValueKey<String>('checkout-why'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KitColors.muted,
                      ),
                    ),
                  ),
                if (stacked) ...<Widget>[
                  FooterTotal(
                    key: const ValueKey<String>('checkout-footer-total'),
                    label: l10n.cartTotal,
                    value: totalText,
                    waiting: false,
                    width: constraints.maxWidth,
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  key: const ValueKey<String>('checkout-confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KitColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: busy
                        ? KitColors.primary
                        : KitColors.line,
                    disabledForegroundColor: busy
                        ? Colors.white
                        : KitColors.muted,
                    minimumSize: const Size.fromHeight(54),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: busy ? null : onOrder,
                  child: busy
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const ExcludeSemantics(
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                busyLabel,
                                textAlign: TextAlign.center,
                                style: _buttonText,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (totalText != null && !stacked) ...<Widget>[
                              Text(totalText, style: _buttonText),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 1,
                                height: 22,
                                child: ColoredBox(
                                  color: onOrder != null
                                      ? Colors.white54
                                      : KitColors.muted,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: Text(
                                l10n.checkoutOrder,
                                textAlign: TextAlign.center,
                                style: _buttonText,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _amount(BuildContext context, AppLocalizations l10n, int total) {
    final String sum = MoneyFormat.uzs(total, interfaceLanguage(context));
    return estimate ? l10n.cartLineEstimate(sum) : sum;
  }
}

const TextStyle _noticeText = TextStyle(
  fontSize: 13,
  height: 1.35,
  color: KitColors.ink2,
);

/// "Сумма изменилась: было → стало" (`DL-121`): the old figure struck through
/// in grey, the new one in bold, on a wash that rises into place.
class CheckoutRecountNotice extends StatelessWidget {
  const CheckoutRecountNotice({
    required this.before,
    required this.after,
    super.key,
  });

  final String before;
  final String after;

  static const String _beforeMark = '';
  static const String _afterMark = '';

  @override
  Widget build(BuildContext context) {
    // The sentence is the localized one; the two figures are put in styled.
    final String template = AppLocalizations.of(context)
        .checkoutRecountedFromTo(_beforeMark, _afterMark);
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp mark = RegExp('[$_beforeMark$_afterMark]');
    int from = 0;
    for (final RegExpMatch match in mark.allMatches(template)) {
      if (match.start > from) {
        spans.add(TextSpan(text: template.substring(from, match.start)));
      }
      spans.add(
        match.group(0) == _beforeMark
            ? TextSpan(
                text: before,
                style: const TextStyle(
                  color: KitColors.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              )
            : TextSpan(
                text: after,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
      );
      from = match.end;
    }
    if (from < template.length) {
      spans.add(TextSpan(text: template.substring(from)));
    }
    return _RecountShell(
      child: Text.rich(TextSpan(children: spans), style: _noticeText),
    );
  }
}

/// The wash, the sync icon and the rise of the recount notice: from 12 px
/// lower and transparent in 280 ms, at once with reduced motion (`DL-121`).
class _RecountShell extends StatelessWidget {
  const _RecountShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    curve: const Cubic(0.2, 0.8, 0.2, 1),
    builder: (BuildContext context, double t, Widget? child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    ),
    child: Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.primaryWash,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.sync, size: 18, color: KitColors.primary),
              const SizedBox(width: 10),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}
