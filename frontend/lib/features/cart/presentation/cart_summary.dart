import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/cart.dart';

/// The amounts of the cart (drawing 19): the goods, the delivery and the
/// service fee when the server has them, and the total. Every figure is the
/// server's; nothing is added here (`DL-37` (19)).
class CartSummary extends StatelessWidget {
  const CartSummary({required this.cart, super.key});

  final Cart cart;

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
            _AmountRow(
              valueKey: 'cart-subtotal',
              label: l10n.cartGoods(cart.availableCount),
              value: estimate(cart.estimatedSubtotalUzs),
            ),
            if (delivery != null)
              _AmountRow(
                valueKey: 'cart-delivery',
                label: l10n.cartDelivery,
                value: sum(delivery),
              ),
            if (fee != null)
              _AmountRow(
                valueKey: 'cart-service-fee',
                label: l10n.cartServiceFee,
                value: cart.serviceFeeIsEstimate ? estimate(fee) : sum(fee),
              ),
            if (total != null) ...<Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, thickness: 1, color: KitColors.line),
              ),
              _AmountRow(
                valueKey: 'cart-total',
                label: l10n.cartTotal,
                value: estimate(total),
                emphasised: true,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              key: const ValueKey<String>('cart-estimate-note'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: KitColors.muted,
                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.valueKey,
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String valueKey;
  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = emphasised
        ? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          )
        : const TextStyle(fontSize: 14, color: KitColors.ink2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              key: ValueKey<String>(valueKey),
              textAlign: TextAlign.end,
              style: style.copyWith(
                color: KitColors.ink,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
