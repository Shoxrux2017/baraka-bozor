import 'package:flutter/material.dart';

import '../../../core/formatting/order_dates.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit/kit_status_card.dart';
import '../domain/shopper_orders.dart';

/// Where the Shopper's assignment stands, as the server offers the next step.
enum ShopperStage { assigned, accepted, shopping, other }

/// The stage of [order]: to accept, to start, being shopped, or none of these.
ShopperStage shopperStage(ShopperOrder order) {
  if (order.canAccept) {
    return ShopperStage.assigned;
  }
  if (order.canStart) {
    return ShopperStage.accepted;
  }
  if (order.status == OrderStatus.shopping) {
    return ShopperStage.shopping;
  }
  return ShopperStage.other;
}

/// How many lines are still to buy, wait for the Customer, or are done
/// (bought or removed).
({int toBuy, int waiting, int done, int bought, int removed}) shopperCounts(
  List<ShopperLine> lines,
) {
  int toBuy = 0;
  int waiting = 0;
  int bought = 0;
  int removed = 0;
  for (final ShopperLine line in lines) {
    switch (line.status) {
      case OrderItemStatus.pending:
        toBuy++;
      case OrderItemStatus.awaitingCustomer:
        waiting++;
      case OrderItemStatus.purchased:
        bought++;
      case OrderItemStatus.removed:
        removed++;
    }
  }
  return (
    toBuy: toBuy,
    waiting: waiting,
    done: bought + removed,
    bought: bought,
    removed: removed,
  );
}

/// The card on top of the order: what stage the order is at, what to do
/// next, and how far the shopping has come.
class ShopperStatusCard extends StatelessWidget {
  const ShopperStatusCard({required this.order, required this.now, super.key});

  final ShopperOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperStage stage = shopperStage(order);
    final ({int toBuy, int waiting, int done, int bought, int removed}) counts =
        shopperCounts(order.items);
    final int open = counts.toBuy + counts.waiting;
    final DateTime? startedAt = order.assignment?.startedAt;

    final IconData icon;
    final String title;
    final String? hint;
    final KitTone tone;
    Widget? progress;
    if (stage == ShopperStage.assigned || stage == ShopperStage.accepted) {
      final bool assigned = stage == ShopperStage.assigned;
      final ShopperAssignment? assignment = order.assignment;
      tone = KitTone.green;
      icon = assigned
          ? Icons.assignment_outlined
          : Icons.assignment_turned_in_outlined;
      title = assigned ? l10n.shopperStatusNew : l10n.shopperStatusAccepted;
      hint = assigned ? l10n.shopperStatusNewHint : l10n.shopperStartAtMarket;
      progress = KitSteps(
        reached: assigned ? 1 : 2,
        steps: <KitStep>[
          (label: l10n.shopperStepAssigned, at: assignment?.assignedAt),
          (label: l10n.shopperStepAccepted, at: assignment?.acceptedAt),
          (label: l10n.shopperStepShopping, at: assignment?.startedAt),
          (label: l10n.shopperStepDone, at: null),
        ],
      );
    } else if (stage == ShopperStage.shopping && open > 0) {
      tone = KitTone.amber;
      icon = Icons.shopping_basket_outlined;
      title = l10n.shopperStatusShopping;
      hint = startedAt == null
          ? null
          : l10n.shopperShoppingHint(
              orderAtLower(l10n, startedAt, now),
              open,
              order.items.length,
            );
      progress = _LineProgress(counts: counts, l10n: l10n);
    } else if (stage == ShopperStage.shopping) {
      tone = KitTone.green;
      icon = Icons.task_alt;
      title = l10n.shopperStatusResolved;
      hint = l10n.shopperResolvedHint(counts.bought, counts.removed);
      progress = SegmentBar(
        segments: List<Color>.filled(order.items.length, KitColors.primary),
      );
    } else {
      tone = KitTone.grey;
      icon = Icons.assignment_outlined;
      title = OrderLabels.status(l10n, order.status);
      hint = null;
    }

    return KitStatusCard(
      key: const ValueKey<String>('shopper-order-status'),
      icon: icon,
      title: title,
      hint: hint,
      tone: tone,
      progress: progress,
    );
  }
}

/// One segment per line, done first, then those waiting for the Customer,
/// then those still to buy, and a legend of the three counts that are not
/// zero.
class _LineProgress extends StatelessWidget {
  const _LineProgress({required this.counts, required this.l10n});

  final ({int toBuy, int waiting, int done, int bought, int removed}) counts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final List<(Color, String)> legend = <(Color, String)>[
      if (counts.done > 0)
        (KitColors.primary, l10n.shopperLegendDone(counts.done)),
      if (counts.waiting > 0)
        (KitColors.warning, l10n.shopperLegendWaiting(counts.waiting)),
      if (counts.toBuy > 0)
        (KitColors.line, l10n.shopperLegendToBuy(counts.toBuy)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentBar(
          segments: <Color>[
            for (int i = 0; i < counts.done; i++) KitColors.primary,
            for (int i = 0; i < counts.waiting; i++) KitColors.warning,
            for (int i = 0; i < counts.toBuy; i++) KitColors.line,
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: <Widget>[
            for (final (Color, String) entry in legend)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entry.$1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.$2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: KitColors.ink2,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
