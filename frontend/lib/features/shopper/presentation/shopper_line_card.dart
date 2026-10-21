import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../domain/shopper_orders.dart';
import 'shopper_line_actions.dart';

/// One line of the order with what the Shopper needs to buy it and what
/// became of it.
class ShopperLineCard extends StatelessWidget {
  const ShopperLineCard({required this.order, required this.line, super.key});

  final ShopperOrder order;
  final ShopperLine line;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = interfaceLanguage(context);
    String name(String uz, String ru) => language == AppLanguage.ru ? ru : uz;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    String money(int amount) => MoneyFormat.uzs(amount, language);
    String amount(String quantity) =>
        '${QuantityRules.display(quantity)} $unit';
    final bool removed = line.status == OrderItemStatus.removed;
    final String? cap = line.approvedQuantityCap;
    final PriceBound? bound = line.bound;
    final ShopperReplacement? replacement = line.replacement;
    final int? replacementPrice = replacement?.marketPriceUzs;
    final ShopperPurchase? purchase = line.purchase;
    final int? paid = purchase?.actualMarketPriceUzs;
    final OpenQuestion? question = line.openQuestion;

    return Card(
      key: ValueKey<String>('shopper-line-${line.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${name(line.nameUz, line.nameRu)} · ${amount(line.quantity)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                decoration: removed ? TextDecoration.lineThrough : null,
              ),
            ),
            if (cap != null) Text(l10n.shopperLineCap(amount(cap))),
            Text(
              removed
                  ? l10n.itemRemovedBecause(
                      OrderLabels.removedReason(l10n, line.removedReason!),
                    )
                  : OrderLabels.itemStatus(l10n, line.status),
              key: ValueKey<String>('shopper-line-status-${line.id}'),
            ),
            Text(l10n.itemMarketPrice(money(line.marketPriceUzs))),
            if (bound != null)
              Text(
                l10n.shopperPriceLimit(money(bound.marketPriceUzs)),
                key: ValueKey<String>('shopper-line-limit-${line.id}'),
              ),
            Text(OrderLabels.substitution(l10n, line.substitutionPolicy)),
            if (line.customerNote != null)
              Text(l10n.itemNote(line.customerNote!)),
            if (replacement != null) ...<Widget>[
              Text(
                <String>[
                  l10n.itemReplacedWith(
                    name(replacement.nameUz, replacement.nameRu),
                  ),
                  OrderLabels.substitutionResolution(
                    l10n,
                    replacement.resolution,
                  ),
                  if (replacementPrice != null)
                    l10n.itemMarketPrice(money(replacementPrice)),
                ].join(', '),
                key: ValueKey<String>('shopper-line-replacement-${line.id}'),
              ),
              Text(
                l10n.shopperPriceLimit(money(replacement.bound.marketPriceUzs)),
              ),
            ],
            if (purchase != null)
              Text(
                l10n.itemBought(amount(purchase.purchasedQuantity)),
                key: ValueKey<String>('shopper-line-bought-${line.id}'),
              ),
            if (paid != null) Text(l10n.itemPricePaid(money(paid))),
            if (question != null)
              Text(
                l10n.shopperQuestion(
                  OrderLabels.approvalType(l10n, question.type),
                  TashkentTime.format(question.expiresAt),
                ),
                key: ValueKey<String>('shopper-line-question-${line.id}'),
              ),
            // At the market: an open line can be bought, replaced or said
            // not to be found; a line waiting for the Customer cannot.
            if (order.status == OrderStatus.shopping &&
                line.status == OrderItemStatus.pending)
              ShopperLineActions(order: order, line: line),
          ],
        ),
      ),
    );
  }
}
