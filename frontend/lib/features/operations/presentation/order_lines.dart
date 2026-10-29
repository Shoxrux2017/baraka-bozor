import 'package:flutter/material.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../domain/board.dart';
import 'order_actions.dart';

const Map<int, TableColumnWidth> _columns = <int, TableColumnWidth>{
  0: FlexColumnWidth(3),
  1: FlexColumnWidth(2),
  2: FlexColumnWidth(2.4),
  3: FlexColumnWidth(1.6),
};

const TextStyle _text = TextStyle(fontSize: 13, color: KitColors.ink);
const TextStyle _strong = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);
const TextStyle _small = TextStyle(fontSize: 12, color: KitColors.muted);

/// The order's lines as a table (`DL-100` (5)): the product with its status
/// beside its name, the quantity with what was bought and billed, the
/// Customer's price with the price paid or the market price under it, and
/// the total. The markup is said once, in the header, when every line
/// shares it, and per line when they differ.
class OrderLines extends StatelessWidget {
  const OrderLines({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Set<String> markups = <String>{
      for (final BoardItem item in order.items) item.markupPercent,
    };
    final bool shared = markups.length == 1;
    const BorderSide line = BorderSide(color: KitColors.line);

    Widget header(
      int index,
      String text, {
      TextAlign align = TextAlign.start,
    }) => Padding(
      padding: _cellPadding(index, vertical: 10),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: KitColors.muted,
        ),
      ),
    );

    return PanelCard(
      flush: true,
      title: l10n.orderSectionItems,
      count: '${order.items.length}',
      trailing: shared
          ? Flexible(
              child: Text(
                l10n.itemMarkup(QuantityRules.display(markups.single)),
                textAlign: TextAlign.end,
                style: _small,
              ),
            )
          : null,
      children: <Widget>[
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: KitColors.card,
            border: Border.symmetric(horizontal: line),
          ),
          child: Table(
            columnWidths: _columns,
            children: <TableRow>[
              TableRow(
                children: <Widget>[
                  header(0, l10n.itemColumnProduct),
                  header(1, l10n.itemColumnQuantity),
                  header(2, l10n.itemColumnPrice, align: TextAlign.end),
                  header(3, l10n.itemColumnTotal, align: TextAlign.end),
                ],
              ),
            ],
          ),
        ),
        for (final BoardItem item in order.items)
          _Line(order: order, item: item, markupPerLine: !shared),
      ],
    );
  }
}

/// A cell's padding: the first and the last column keep the card's 20 px
/// side padding.
EdgeInsets _cellPadding(int index, {double vertical = 14}) =>
    EdgeInsets.fromLTRB(
      index == 0 ? 20 : 8,
      vertical,
      index == 3 ? 20 : 8,
      vertical,
    );

class _Line extends StatelessWidget {
  const _Line({
    required this.order,
    required this.item,
    required this.markupPerLine,
  });

  final BoardOrder order;
  final BoardItem item;
  final bool markupPerLine;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final bool removed = item.status == OrderItemStatus.removed;
    final bool purchased = item.status == OrderItemStatus.purchased;
    final bool waiting = item.status == OrderItemStatus.awaitingCustomer;
    final String unit = CatalogLabels.unit(l10n, item.unit);
    final int? paid = item.actualMarketPriceUzs;
    final int? billedPrice = item.billableUnitPriceUzs;
    final String? bought = item.purchasedQuantity;
    final String? billed = item.billableQuantity;
    final bool estimate = item.priceMode == PriceMode.estimate;
    String money(int amount) => MoneyFormat.uzs(amount, language);

    final Widget quantity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${QuantityRules.display(item.quantity)} $unit', style: _text),
        if (purchased && bought != null)
          Text(
            l10n.itemBought('${QuantityRules.display(bought)} $unit'),
            key: ValueKey<String>('order-item-bought-${item.id}'),
            style: _small,
          ),
        if (purchased && billed != null)
          Text(
            l10n.itemBilled('${QuantityRules.display(billed)} $unit'),
            style: _small,
          ),
      ],
    );

    final Widget price = removed
        ? const Text('—', textAlign: TextAlign.end, style: _small)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (purchased) ...<Widget>[
                if (billedPrice != null)
                  Text(
                    l10n.itemBilledPrice(money(billedPrice)),
                    textAlign: TextAlign.end,
                    style: _text,
                  ),
                if (paid != null)
                  Text(
                    l10n.itemPricePaid(money(paid)),
                    key: ValueKey<String>('order-item-paid-${item.id}'),
                    textAlign: TextAlign.end,
                    style: _small,
                  ),
                if (estimate)
                  Text(
                    l10n.itemWasEstimate(
                      '${money(item.customerUnitPriceUzs)}/$unit',
                    ),
                    key: ValueKey<String>('order-item-was-${item.id}'),
                    textAlign: TextAlign.end,
                    style: _small,
                  ),
              ] else ...<Widget>[
                Text(
                  '${estimate ? '≈ ' : ''}'
                  '${money(item.customerUnitPriceUzs)}/$unit',
                  textAlign: TextAlign.end,
                  style: _text,
                ),
                Text(
                  l10n.itemMarketPrice(money(item.marketPriceUzs)),
                  textAlign: TextAlign.end,
                  style: _small,
                ),
              ],
              PriceCorrectionButton(order: order, item: item),
              if (markupPerLine)
                Text(
                  l10n.itemMarkup(QuantityRules.display(item.markupPercent)),
                  textAlign: TextAlign.end,
                  style: _small,
                ),
            ],
          );

    final Widget total = removed
        ? const Text('—', textAlign: TextAlign.end, style: _small)
        : Text(
            '${purchased || !estimate ? '' : '≈ '}${money(item.lineTotalUzs)}',
            textAlign: TextAlign.end,
            style: _strong,
          );

    return DecoratedBox(
      key: ValueKey<String>('order-line-${item.id}'),
      decoration: BoxDecoration(
        color: waiting ? KitColors.warningWash : Colors.white,
        border: const Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: Table(
        columnWidths: _columns,
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              Padding(
                padding: _cellPadding(0),
                child: _Product(order: order, item: item),
              ),
              Padding(padding: _cellPadding(1), child: quantity),
              Padding(padding: _cellPadding(2), child: price),
              Padding(padding: _cellPadding(3), child: total),
            ],
          ),
        ],
      ),
    );
  }
}

/// The name with its status beside it, the replacement, the substitution
/// policy, the Customer's note, and why a removed line left.
class _Product extends StatelessWidget {
  const _Product({required this.order, required this.item});

  final BoardOrder order;
  final BoardItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final bool removed = item.status == OrderItemStatus.removed;
    final String name = language == AppLanguage.ru ? item.nameRu : item.nameUz;
    final NamedProduct? replacement = item.replacement;
    final SubstitutionResolution? resolution = item.replacementResolution;
    final bool expired =
        item.status == OrderItemStatus.awaitingCustomer &&
        order.approvals.any(
          (BoardApproval approval) =>
              approval.itemId == item.id && approval.awaitsRemoval,
        );

    return Column(
      key: ValueKey<String>('order-item-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: removed ? KitColors.muted : KitColors.ink,
                decoration: removed ? TextDecoration.lineThrough : null,
              ),
            ),
            _StatusChip(item: item),
          ],
        ),
        if (replacement != null)
          _Note(
            icon: Icons.autorenew,
            color: KitColors.primaryDark,
            text: <String>[
              l10n.itemReplacedWith(
                language == AppLanguage.ru
                    ? replacement.nameRu
                    : replacement.nameUz,
              ),
              if (resolution != null)
                OrderLabels.substitutionResolution(l10n, resolution),
            ].join(', '),
            textKey: ValueKey<String>('order-item-replacement-${item.id}'),
            strong: true,
          ),
        _Note(
          icon: switch (item.substitutionPolicy) {
            SubstitutionPolicy.allowSimilar => Icons.swap_horiz,
            SubstitutionPolicy.contactBefore => Icons.phone_outlined,
            SubstitutionPolicy.removeIfUnavailable =>
              Icons.remove_shopping_cart_outlined,
          },
          color: KitColors.ink2,
          text: OrderLabels.substitution(l10n, item.substitutionPolicy),
        ),
        if (item.customerNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DecoratedBox(
              key: ValueKey<String>('order-item-note-${item.id}'),
              decoration: BoxDecoration(
                color: KitColors.field,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 14,
                      color: KitColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.itemNote(item.customerNote!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (removed && item.removedReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.itemRemovedBecause(
                OrderLabels.removedReason(l10n, item.removedReason!),
              ),
              style: _small,
            ),
          ),
        if (expired)
          _Note(
            icon: Icons.timer_off_outlined,
            color: KitColors.danger,
            text: l10n.itemExpiredHint,
            strong: true,
          ),
      ],
    );
  }
}

/// A line of 12 px text with a small icon before it.
class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.color,
    required this.text,
    this.strong = false,
    this.textKey,
  });

  final Key? textKey;
  final IconData icon;
  final Color color;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              key: textKey,
              style: TextStyle(
                fontSize: 12,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line's status in a 22 px chip: bought green, waiting for the
/// Customer amber, removed red, otherwise grey.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final BoardItem item;

  @override
  Widget build(BuildContext context) {
    final (Color ground, Color text) = switch (item.status) {
      OrderItemStatus.purchased => (
        KitColors.primaryWash,
        KitColors.primaryDark,
      ),
      OrderItemStatus.awaitingCustomer => (
        KitColors.warningWash,
        KitColors.warningDark,
      ),
      OrderItemStatus.removed => (KitColors.dangerWash, KitColors.danger),
      OrderItemStatus.pending => (KitColors.line, KitColors.ink2),
    };

    return DecoratedBox(
      key: ValueKey<String>('order-item-status-${item.id}'),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Center(
            widthFactor: 1,
            child: Text(
              OrderLabels.itemStatus(AppLocalizations.of(context), item.status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The questions to the Customer, newest first (`DL-100` (5)).
class OrderQuestions extends StatelessWidget {
  const OrderQuestions({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PanelCard(
      title: l10n.orderSectionApprovals,
      count: '${order.approvals.length}',
      children: <Widget>[
        const SizedBox(height: 12),
        if (order.approvals.isEmpty) Text(l10n.approvalsNone, style: _small),
        for (
          int index = 0;
          index < order.approvals.length;
          index++
        ) ...<Widget>[
          if (index > 0) const SizedBox(height: 10),
          ApprovalTile(
            order: order,
            approval: order.approvals[order.approvals.length - 1 - index],
          ),
        ],
      ],
    );
  }
}
