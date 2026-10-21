import 'package:flutter/material.dart';

import '../../../core/formatting/order_dates.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
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

/// A bar of [segments], one box each: 4 high, round, with a gap of 4 up to
/// twelve segments and 2 above.
class SegmentBar extends StatelessWidget {
  const SegmentBar({required this.segments, super.key});

  final List<Color> segments;

  @override
  Widget build(BuildContext context) {
    final double gap = segments.length <= 12 ? 4 : 2;

    return Row(
      children: <Widget>[
        for (int index = 0; index < segments.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: gap),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: segments[index],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
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

    final Color wash;
    final Color circle;
    final Color iconColor;
    final IconData icon;
    final String title;
    final String? hint;
    Widget? progress;
    if (stage == ShopperStage.assigned || stage == ShopperStage.accepted) {
      final bool assigned = stage == ShopperStage.assigned;
      wash = KitColors.primaryWash;
      circle = KitColors.primarySoft;
      iconColor = KitColors.primaryDark;
      icon = assigned
          ? Icons.assignment_outlined
          : Icons.assignment_turned_in_outlined;
      title = assigned ? l10n.shopperStatusNew : l10n.shopperStatusAccepted;
      hint = assigned ? l10n.shopperStatusNewHint : l10n.shopperStartAtMarket;
      progress = _Steps(order: order, reached: assigned ? 1 : 2);
    } else if (stage == ShopperStage.shopping && open > 0) {
      wash = KitColors.warningWash;
      circle = Colors.white;
      iconColor = KitColors.warning;
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
      wash = KitColors.primaryWash;
      circle = KitColors.primarySoft;
      iconColor = KitColors.primaryDark;
      icon = Icons.task_alt;
      title = l10n.shopperStatusResolved;
      hint = l10n.shopperResolvedHint(counts.bought, counts.removed);
      progress = SegmentBar(
        segments: List<Color>.filled(order.items.length, KitColors.primary),
      );
    } else {
      wash = KitColors.field;
      circle = Colors.white;
      iconColor = KitColors.muted;
      icon = Icons.assignment_outlined;
      title = OrderLabels.status(l10n, order.status);
      hint = null;
    }

    return DecoratedBox(
      key: const ValueKey<String>('shopper-order-status'),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circle,
                  ),
                  child: Icon(icon, size: 26, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      if (hint != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: const TextStyle(
                            fontSize: 13,
                            color: KitColors.ink2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: 14),
              progress,
            ],
          ],
        ),
      ),
    );
  }
}

/// The four steps of an assignment: [reached] of them green, each named, with
/// the time when the server knows it.
class _Steps extends StatelessWidget {
  const _Steps({required this.order, required this.reached});

  final ShopperOrder order;
  final int reached;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperAssignment? assignment = order.assignment;
    final List<(String, DateTime?)> steps = <(String, DateTime?)>[
      (l10n.shopperStepAssigned, assignment?.assignedAt),
      (l10n.shopperStepAccepted, assignment?.acceptedAt),
      (l10n.shopperStepShopping, assignment?.startedAt),
      (l10n.shopperStepDone, null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentBar(
          segments: <Color>[
            for (int index = 0; index < steps.length; index++)
              index < reached ? KitColors.primary : KitColors.primarySoft,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < steps.length; index++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        steps[index].$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: index < reached
                              ? KitColors.primaryDark
                              : KitColors.muted,
                        ),
                      ),
                      if (steps[index].$2 != null)
                        Text(
                          TashkentTime.time(steps[index].$2!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: KitColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KitColors.warningDark,
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
