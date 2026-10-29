import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/soft_change.dart';
import '../domain/cart.dart';

/// The amounts of the cart (drawing 19): the goods, the delivery and the
/// service fee when the server has them, and the total. Every figure is the
/// server's; nothing is added here (`DL-37` (19)).
///
/// With [waiting] the amounts are dimmed: a quantity change is on its way and
/// they are the last ones the server gave (`DL-119`).
class CartSummary extends StatelessWidget {
  const CartSummary({required this.cart, this.waiting = false, super.key});

  final Cart cart;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    String sum(int amount) => MoneyFormat.uzs(amount, language);
    String estimate(int amount) => l10n.cartLineEstimate(sum(amount));

    // With nothing left to buy, the fees alone are not an amount to pay.
    final bool anySold = cart.availableCount > 0;
    final int? delivery = anySold ? cart.deliveryFeeUzs : null;
    final int? fee = anySold ? cart.serviceFeeUzs : null;
    final int? total = anySold ? cart.estimatedTotalUzs : null;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SummaryAmountRow(
              valueKey: 'cart-subtotal',
              waiting: waiting,
              label: l10n.cartGoods(cart.availableCount),
              value: estimate(cart.estimatedSubtotalUzs),
            ),
            if (delivery != null)
              SummaryAmountRow(
                valueKey: 'cart-delivery',
                waiting: waiting,
                label: l10n.cartDelivery,
                value: sum(delivery),
              ),
            if (fee != null)
              SummaryAmountRow(
                valueKey: 'cart-service-fee',
                waiting: waiting,
                label: l10n.cartServiceFee,
                value: cart.serviceFeeIsEstimate ? estimate(fee) : sum(fee),
              ),
            if (total != null) ...<Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, thickness: 1, color: KitColors.line),
              ),
              SummaryAmountRow(
                valueKey: 'cart-total',
                label: l10n.cartTotal,
                value: estimate(total),
                emphasised: true,
                waiting: waiting,
              ),
            ],
            const SizedBox(height: 8),
            const EstimateNote(key: ValueKey<String>('cart-estimate-note')),
          ],
        ),
      ),
    );
  }
}

/// "The sum is an estimate" with its info icon, under the amounts.
class EstimateNote extends StatelessWidget {
  const EstimateNote({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline, size: 16, color: KitColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l10n.cartEstimateNote,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: KitColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of amounts: a label and a figure. [replaced] is an earlier
/// figure shown struck through before the current one. A changed [value]
/// rises softly and, while [waiting], is dimmed (`DL-119`).
///
/// An amount never breaks inside a word: with room the label and the figure
/// share a row; without it the figure stands under the label, end-aligned; and
/// only when the figure alone is wider than the row is it scaled down.
class SummaryAmountRow extends StatelessWidget {
  const SummaryAmountRow({
    required this.valueKey,
    required this.label,
    required this.value,
    this.emphasised = false,
    this.replaced,
    this.waiting = false,
    super.key,
  });

  final String valueKey;
  final String label;
  final String value;
  final bool emphasised;
  final String? replaced;
  final bool waiting;

  static const TextStyle _replacedStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: KitColors.muted,
    decoration: TextDecoration.lineThrough,
  );

  @override
  Widget build(BuildContext context) {
    final TextStyle style = emphasised
        ? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          )
        : const TextStyle(fontSize: 14, color: KitColors.ink2);
    final TextStyle valueStyle = style.copyWith(
      color: KitColors.ink,
      fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
    );
    final Widget valueText = SoftChange(
      value: value,
      waiting: waiting,
      child: Text(
        value,
        key: ValueKey<String>(valueKey),
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.end,
        style: valueStyle,
      ),
    );
    final String? earlier = replaced;
    final Widget block = earlier == null
        ? valueText
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                earlier,
                maxLines: 1,
                softWrap: false,
                style: _replacedStyle,
              ),
              const SizedBox(width: 8),
              valueText,
            ],
          );
    final double blockWidth =
        textWidth(context, value, valueStyle) +
        (earlier == null ? 0 : textWidth(context, earlier, _replacedStyle) + 8);
    final double longestWord = label
        .split(RegExp(r'\s+'))
        .map((String word) => textWidth(context, word, style))
        .fold<double>(0, math.max);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (blockWidth + 12 + longestWord <= constraints.maxWidth) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Text(label, style: style)),
                const SizedBox(width: 12),
                block,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(label, style: style),
              Align(
                alignment: Alignment.centerRight,
                child: FittedBox(fit: BoxFit.scaleDown, child: block),
              ),
            ],
          );
        },
      ),
    );
  }
}
