import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/localization/role_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../auth/domain/app_user.dart';
import '../domain/board.dart';
import 'board_widgets.dart';

/// The order's history, newest first (`DL-100` (5)): a rail with a dot per
/// entry — green for a purchase or a substitution, red for an expiry, a
/// failed delivery or a cancellation — showing the newest [folded] and
/// folding the rest behind a button.
class OrderHistory extends ConsumerStatefulWidget {
  const OrderHistory({required this.order, super.key});

  final BoardOrder order;

  /// How many entries show before the rest fold.
  static const int folded = 8;

  @override
  ConsumerState<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends ConsumerState<OrderHistory> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<HistoryEntry> entries = widget.order.history.reversed.toList();
    final bool folds = entries.length > OrderHistory.folded;
    final List<HistoryEntry> shown = folds && !_all
        ? entries.take(OrderHistory.folded).toList()
        : entries;

    final DateTime now = ref.watch(clockProvider)();

    return PanelCard(
      title: l10n.orderSectionHistory,
      trailing: Flexible(
        child: Text(
          l10n.historyNewestFirst,
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
      ),
      children: <Widget>[
        const SizedBox(height: 14),
        if (entries.isEmpty)
          Text(
            l10n.historyNone,
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          )
        else
          Stack(
            children: <Widget>[
              const Positioned(
                left: 4,
                top: 6,
                bottom: 0,
                width: 2,
                child: ColoredBox(color: KitColors.line),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final HistoryEntry entry in shown)
                    _Entry(entry: entry, order: widget.order, now: now),
                ],
              ),
            ],
          ),
        if (folds)
          TextButton(
            key: const ValueKey<String>('history-fold'),
            style: TextButton.styleFrom(
              backgroundColor: KitColors.field,
              foregroundColor: KitColors.ink,
              minimumSize: const Size.fromHeight(38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => setState(() => _all = !_all),
            child: Text(
              _all
                  ? l10n.historyShowFewer
                  : l10n.historyShowAll(entries.length),
            ),
          ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry, required this.order, required this.now});

  final HistoryEntry entry;
  final BoardOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OrderStatus? from = entry.fromStatus;
    final OrderStatus? to = entry.toStatus;
    final String? details = _details(l10n, interfaceLanguage(context));
    final Color dot = _dotColor();
    final double timeWidth = MediaQuery.textScalerOf(context).scale(76);

    return Padding(
      key: ValueKey<String>('history-${entry.id}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DecoratedBox(
              key: ValueKey<String>('history-dot-${entry.id}'),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: dot, width: 2),
              ),
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: timeWidth,
            child: Text(
              panelWhen(entry.createdAt, now),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KitColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  <String>[
                    _event(l10n, entry.event),
                    if (to != null)
                      from == null
                          ? OrderLabels.status(l10n, to)
                          : '${OrderLabels.status(l10n, from)} → '
                                '${OrderLabels.status(l10n, to)}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                  ),
                ),
                Text(
                  _actor(l10n),
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
                if (entry.reason != null)
                  Text(
                    OrderLabels.cancellationReason(l10n, entry.reason!),
                    style: const TextStyle(fontSize: 12, color: KitColors.ink2),
                  ),
                if (details != null)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        details,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.ink2,
                        ),
                      ),
                      if (entry.details case AssignmentDetails(
                        isSelfOrder: true,
                      ))
                        const SelfOrderMark(),
                    ],
                  ),
                if (entry.note != null)
                  Text(
                    entry.note!,
                    style: const TextStyle(fontSize: 12, color: KitColors.ink2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor() {
    if (entry.toStatus == OrderStatus.cancelled) {
      return KitColors.danger;
    }
    return switch (entry.event) {
      OrderHistoryEvent.itemPurchased ||
      OrderHistoryEvent.itemSubstituted => KitColors.primaryDark,
      OrderHistoryEvent.approvalExpired ||
      OrderHistoryEvent.deliveryFailed => KitColors.danger,
      _ => KitColors.muted,
    };
  }

  String _actor(AppLocalizations l10n) => switch (entry.actorType) {
    HistoryActorType.system => l10n.historySystem,
    HistoryActorType.paymentProvider => l10n.historyPaymentProvider,
    HistoryActorType.user =>
      '${entry.actor!.fullName ?? l10n.personWithoutName} '
          '(${roleLabel(l10n, entry.actor!.role)})',
  };

  /// The facts the entry carries, in words: the Shopper or the Courier an
  /// assignment went to — and from, on a reassignment — and what an edit
  /// changed.
  String? _details(AppLocalizations l10n, AppLanguage language) {
    final HistoryDetails? details = entry.details;
    switch (details) {
      case AssignmentDetails():
        final bool courier = details.role == UserRole.courier;
        final String? name = _staffName(l10n, courier, details.assignmentId);
        final String? previousId = details.previousAssignmentId;
        final String? previous = previousId == null
            ? null
            : _staffName(l10n, courier, previousId);
        if (name == null) {
          return null;
        }
        if (previous == null) {
          return courier
              ? l10n.historyCourierAssignedTo(name)
              : l10n.historyAssignedTo(name);
        }
        return courier
            ? l10n.historyCourierReassignedTo(previous, name)
            : l10n.historyReassignedTo(previous, name);
      case PriceCorrectionDetails():
        final BoardItem? item = order.item(details.itemId);
        if (item == null) {
          return null;
        }
        final NamedProduct? replacement = item.replacement;
        String money(int amount) => MoneyFormat.uzs(amount, language);
        return l10n.historyPriceCorrectedDetails(
          switch ((replacement, language)) {
            (null, AppLanguage.ru) => item.nameRu,
            (null, _) => item.nameUz,
            (final NamedProduct product, AppLanguage.ru) => product.nameRu,
            (final NamedProduct product, _) => product.nameUz,
          },
          money(details.oldActualMarketPriceUzs),
          money(details.newActualMarketPriceUzs),
          money(details.oldBillableUnitPriceUzs),
          money(details.newBillableUnitPriceUzs),
        );
      case EditDetails():
        final List<String> parts = <String>[
          if (details.added > 0) l10n.historyEditAdded(details.added),
          if (details.removed > 0) l10n.historyEditRemoved(details.removed),
          if (details.changed > 0) l10n.historyEditChanged(details.changed),
          if (details.deliveryTimeNoteChanged) l10n.historyDeliveryWishChanged,
        ];
        return parts.isEmpty ? null : parts.join('; ');
      case null:
        return null;
    }
  }

  /// The name of the Shopper, or the Courier when [courier], of the order's
  /// assignment [assignmentId].
  String? _staffName(AppLocalizations l10n, bool courier, String assignmentId) {
    final Iterable<(String, PersonRef)> assignments = courier
        ? order.courierAssignments.map(
            (CourierAssignment assignment) =>
                (assignment.id, assignment.courier),
          )
        : order.shopperAssignments.map(
            (ShopperAssignment assignment) =>
                (assignment.id, assignment.shopper),
          );
    for (final (String id, PersonRef person) in assignments) {
      if (id == assignmentId) {
        return nameOf(l10n, person);
      }
    }
    return null;
  }

  static String _event(
    AppLocalizations l10n,
    OrderHistoryEvent event,
  ) => switch (event) {
    OrderHistoryEvent.statusChanged => l10n.historyEventStatusChanged,
    OrderHistoryEvent.edited => l10n.historyEventEdited,
    OrderHistoryEvent.paymentMethodSwitched =>
      l10n.historyEventPaymentMethodSwitched,
    OrderHistoryEvent.priceCorrected => l10n.historyEventPriceCorrected,
    OrderHistoryEvent.shopperAssigned => l10n.historyEventShopperAssigned,
    OrderHistoryEvent.shopperReassigned => l10n.historyEventShopperReassigned,
    OrderHistoryEvent.courierAssigned => l10n.historyEventCourierAssigned,
    OrderHistoryEvent.courierReassigned => l10n.historyEventCourierReassigned,
    OrderHistoryEvent.deliveryFailed => l10n.historyEventDeliveryFailed,
    OrderHistoryEvent.approvalRequested => l10n.historyEventApprovalRequested,
    OrderHistoryEvent.approvalDecided => l10n.historyEventApprovalDecided,
    OrderHistoryEvent.approvalExpired => l10n.historyEventApprovalExpired,
    OrderHistoryEvent.approvalResolved => l10n.historyEventApprovalResolved,
    OrderHistoryEvent.shopperAccepted => l10n.historyEventShopperAccepted,
    OrderHistoryEvent.courierAccepted => l10n.historyEventCourierAccepted,
    OrderHistoryEvent.itemPurchased => l10n.historyEventItemPurchased,
    OrderHistoryEvent.itemUnavailable => l10n.historyEventItemUnavailable,
    OrderHistoryEvent.itemSubstituted => l10n.historyEventItemSubstituted,
    OrderHistoryEvent.cancellationRequested =>
      l10n.historyEventCancellationRequested,
    OrderHistoryEvent.cancellationRequestDecided =>
      l10n.historyEventCancellationRequestDecided,
    OrderHistoryEvent.paymentRecorded => l10n.historyEventPaymentRecorded,
  };
}
