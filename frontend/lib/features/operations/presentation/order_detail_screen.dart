import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/localization/role_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_widgets.dart';

/// One order as the Operator and the Admin see it (`docs/09` section 38):
/// the Customer and the address, the delivery wish, every line with the
/// prices it was placed at — the market price and markup among them — the
/// totals and their kind, every Shopper assignment with its self-order mark,
/// and the whole history.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BoardOrder> order = ref.watch(boardOrderProvider(orderId));

    return ListView(
      key: const ValueKey<String>('order-detail'),
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey<String>('order-back'),
              tooltip: l10n.orderBackToBoard,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(AppPaths.operations),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.value == null
                    ? ''
                    : l10n.orderTitle('${order.value!.orderNumber}'),
                style: Theme.of(context).textTheme.headlineSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const ValueKey<String>('order-refresh'),
              tooltip: l10n.boardRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(boardOrderProvider(orderId)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        order.when(
          skipLoadingOnRefresh: !order.hasError,
          data: (BoardOrder order) => _Order(order: order),
          error: (Object error, StackTrace _) => LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(boardOrderProvider(orderId)),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _Order extends StatelessWidget {
  const _Order({required this.order});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final BoardAddress address = order.address;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OrderStatusChip(order.status),
            Text(OrderLabels.paymentMethod(l10n, order.paymentMethod)),
            Text(l10n.orderPlacedAt(TashkentTime.format(order.createdAt))),
            if (order.completedAt != null)
              Text(
                l10n.orderCompletedAt(TashkentTime.format(order.completedAt!)),
              ),
            if (order.cancelledAt != null)
              Text(
                l10n.orderCancelledAt(TashkentTime.format(order.cancelledAt!)),
              ),
            if (order.cancellationReason != null)
              Text(
                OrderLabels.cancellationReason(l10n, order.cancellationReason!),
              ),
          ],
        ),
        _Section(
          title: l10n.orderSectionCustomer,
          children: <Widget>[
            Text(order.customer.fullName),
            Text(formatPhone(order.customer.phone)),
          ],
        ),
        _Section(
          title: l10n.orderSectionAddress,
          children: <Widget>[
            Text('${l10n.addressStreet}: ${address.street}'),
            Text('${l10n.addressHouse}: ${address.house}'),
            if (address.apartment != null)
              Text('${l10n.addressApartment}: ${address.apartment}'),
            if (address.landmark != null)
              Text('${l10n.addressLandmark}: ${address.landmark}'),
            if (address.deliveryNote != null)
              Text('${l10n.addressDeliveryNote}: ${address.deliveryNote}'),
            Text(l10n.orderCoordinates(address.latitude, address.longitude)),
          ],
        ),
        _Section(
          title: l10n.orderSectionDeliveryWish,
          children: <Widget>[
            Text(order.deliveryTimeNote ?? l10n.orderNoDeliveryWish),
          ],
        ),
        _Section(
          title: l10n.orderSectionItems,
          children: <Widget>[
            for (final BoardItem item in order.items)
              _Item(item: item, language: language),
          ],
        ),
        _Section(
          title: l10n.orderSectionTotals,
          children: <Widget>[_Totals(totals: order.totals, language: language)],
        ),
        _Section(
          title: l10n.orderSectionShoppers,
          children: <Widget>[
            _AssignmentActions(order: order),
            if (order.shopperAssignments.isEmpty) Text(l10n.assignmentsNone),
            for (final ShopperAssignment assignment
                in order.shopperAssignments.reversed)
              _Assignment(assignment: assignment),
          ],
        ),
        _Section(
          title: l10n.orderSectionHistory,
          children: <Widget>[
            if (order.history.isEmpty) Text(l10n.historyNone),
            for (final HistoryEntry entry in order.history.reversed)
              _History(entry: entry, order: order),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.language});

  final BoardItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool removed = item.status == OrderItemStatus.removed;
    final String name = language == AppLanguage.ru ? item.nameRu : item.nameUz;

    return ListTile(
      key: ValueKey<String>('order-item-${item.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$name · ${item.quantity} ${CatalogLabels.unit(l10n, item.unit)}',
        style: removed
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: <Widget>[
          Text(
            removed
                ? l10n.itemRemovedBecause(
                    OrderLabels.removedReason(l10n, item.removedReason!),
                  )
                : OrderLabels.itemStatus(l10n, item.status),
          ),
          Text(CatalogLabels.priceMode(l10n, item.priceMode)),
          Text(
            l10n.itemMarketPrice(
              MoneyFormat.uzs(item.marketPriceUzs, language),
            ),
          ),
          Text(
            l10n.itemCustomerPrice(
              MoneyFormat.uzs(item.customerUnitPriceUzs, language),
            ),
          ),
          Text(l10n.itemMarkup(item.markupPercent)),
          Text(
            l10n.itemLineTotal(MoneyFormat.uzs(item.lineTotalUzs, language)),
          ),
          Text(OrderLabels.substitution(l10n, item.substitutionPolicy)),
          if (item.customerNote != null)
            Text(l10n.itemNote(item.customerNote!)),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals, required this.language});

  final BoardTotals totals;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (totals.kind == TotalKind.none) {
      return Text(l10n.totalNothingDue, key: const ValueKey<String>('totals'));
    }

    Widget line(String label, String amount, {TextStyle? style}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(amount, style: style, textAlign: TextAlign.end),
        ),
      ],
    );

    return Column(
      key: const ValueKey<String>('totals'),
      children: <Widget>[
        line(
          l10n.totalsMerchandise,
          MoneyFormat.uzs(totals.merchandiseSubtotalUzs!, language),
        ),
        line(
          l10n.totalsServiceFee,
          MoneyFormat.uzs(totals.serviceFeeUzs!, language),
        ),
        line(
          l10n.totalsDeliveryFee,
          MoneyFormat.uzs(totals.deliveryFeeUzs!, language),
        ),
        const Divider(),
        line(
          l10n.totalsTotal,
          totalText(context, l10n, totals.totalUzs, totals.kind),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _Assignment extends StatelessWidget {
  const _Assignment({required this.assignment});

  final ShopperAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? endedAt = assignment.endedAt;

    return ListTile(
      key: ValueKey<String>('assignment-${assignment.id}'),
      contentPadding: EdgeInsets.zero,
      title: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(nameOf(l10n, assignment.shopper)),
          Text(formatPhone(assignment.shopperPhone)),
          if (endedAt == null)
            Chip(
              label: Text(l10n.assignmentCurrent),
              visualDensity: VisualDensity.compact,
            ),
          if (assignment.isSelfOrder) const SelfOrderMark(),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.assignmentAssignedBy(
              nameOf(l10n, assignment.assignedBy),
              TashkentTime.format(assignment.assignedAt),
            ),
          ),
          if (assignment.acceptedAt != null)
            Text(
              l10n.assignmentAccepted(
                TashkentTime.format(assignment.acceptedAt!),
              ),
            ),
          if (assignment.startedAt != null)
            Text(
              l10n.assignmentStarted(
                TashkentTime.format(assignment.startedAt!),
              ),
            ),
          if (endedAt != null)
            Text(
              l10n.assignmentEnded(
                TashkentTime.format(endedAt),
                _endReason(l10n, assignment.endedReason!),
              ),
            ),
        ],
      ),
    );
  }

  static String _endReason(AppLocalizations l10n, AssignmentEndReason reason) =>
      switch (reason) {
        AssignmentEndReason.completed => l10n.assignmentEndCompleted,
        AssignmentEndReason.reassigned => l10n.assignmentEndReassigned,
        AssignmentEndReason.orderCancelled => l10n.assignmentEndOrderCancelled,
      };
}

class _History extends StatelessWidget {
  const _History({required this.entry, required this.order});

  final HistoryEntry entry;
  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OrderStatus? from = entry.fromStatus;
    final OrderStatus? to = entry.toStatus;
    final String? details = _details(l10n);

    return ListTile(
      key: ValueKey<String>('history-${entry.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        <String>[
          _event(l10n, entry.event),
          if (to != null)
            from == null
                ? OrderLabels.status(l10n, to)
                : '${OrderLabels.status(l10n, from)} → '
                      '${OrderLabels.status(l10n, to)}',
        ].join(' · '),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${TashkentTime.format(entry.createdAt)} · ${_actor(l10n)}'),
          if (entry.reason != null)
            Text(OrderLabels.cancellationReason(l10n, entry.reason!)),
          if (details != null)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(details),
                if (entry.details case AssignmentDetails(isSelfOrder: true))
                  const SelfOrderMark(),
              ],
            ),
          if (entry.note != null) Text(entry.note!),
        ],
      ),
    );
  }

  String _actor(AppLocalizations l10n) => switch (entry.actorType) {
    HistoryActorType.system => l10n.historySystem,
    HistoryActorType.paymentProvider => l10n.historyPaymentProvider,
    HistoryActorType.user =>
      '${entry.actor!.fullName ?? l10n.personWithoutName} '
          '(${roleLabel(l10n, entry.actor!.role)})',
  };

  /// The facts the entry carries, in words: the Shopper an assignment went
  /// to — and from, on a reassignment — and what an edit changed.
  String? _details(AppLocalizations l10n) {
    final HistoryDetails? details = entry.details;
    switch (details) {
      case AssignmentDetails():
        final String? name = _shopperName(l10n, details.assignmentId);
        final String? previousId = details.previousAssignmentId;
        final String? previous = previousId == null
            ? null
            : _shopperName(l10n, previousId);
        if (name == null) {
          return null;
        }
        return previous == null
            ? l10n.historyAssignedTo(name)
            : l10n.historyReassignedTo(previous, name);
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

  /// The name of the Shopper of the order's assignment [assignmentId].
  String? _shopperName(AppLocalizations l10n, String assignmentId) {
    for (final ShopperAssignment assignment in order.shopperAssignments) {
      if (assignment.id == assignmentId) {
        return nameOf(l10n, assignment.shopper);
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

/// The way to assign a Shopper to a `new` order, or to replace the Shopper
/// before shopping starts (`BR-ASSIGN-001`, `BR-ASSIGN-002`), and what the
/// last attempt answered. The buttons follow the order as loaded; the
/// server decides, and a conflict reloads the order and says why.
class _AssignmentActions extends ConsumerWidget {
  const _AssignmentActions({required this.order});

  final BoardOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(shopperAssignmentProvider(order.id));
    // Until the order the last change reloaded has arrived, the buttons
    // would act on the order as it was.
    final bool busy =
        state.isBusy || ref.watch(boardOrderProvider(order.id)).isLoading;
    final ShopperAssignment? current = order.currentAssignment;
    final bool assigns =
        order.status == OrderStatus.newOrder && current == null;
    final bool reassigns =
        order.status == OrderStatus.shoppingAssigned &&
        current != null &&
        current.startedAt == null;

    if (!assigns && !reassigns) {
      return FailureMessage(state.failure);
    }

    Future<void> pick() async {
      final ShopperChoice? chosen = await showDialog<ShopperChoice>(
        context: context,
        builder: (BuildContext context) =>
            _ShopperPicker(currentShopperId: current?.shopper.id),
      );
      if (chosen == null || !context.mounted) {
        return;
      }
      final ShopperAssignmentController assignment = ref.read(
        shopperAssignmentProvider(order.id).notifier,
      );
      if (current == null) {
        await assignment.assign(chosen.id);
      } else {
        await assignment.reassign(chosen.id, current.id);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (assigns)
                FilledButton.icon(
                  key: const ValueKey<String>('assign-shopper'),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(l10n.assignShopper),
                  onPressed: busy ? null : pick,
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey<String>('reassign-shopper'),
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(l10n.reassignShopper),
                  onPressed: busy ? null : pick,
                ),
              if (state.isBusy)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: l10n.assigningShopper,
                  ),
                ),
            ],
          ),
          FailureMessage(state.failure),
        ],
      ),
    );
  }
}

/// The active Shoppers to choose from, each with the orders in their hands
/// now; the current Shopper is shown but not offered.
class _ShopperPicker extends ConsumerWidget {
  const _ShopperPicker({required this.currentShopperId});

  final String? currentShopperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<ShopperChoice>> shoppers = ref.watch(
      shopperOptionsProvider,
    );

    return AlertDialog(
      title: Text(l10n.pickShopperTitle),
      content: SizedBox(
        width: 420,
        child: shoppers.when(
          skipLoadingOnRefresh: !shoppers.hasError,
          data: (List<ShopperChoice> shoppers) => shoppers.isEmpty
              ? Text(l10n.pickShopperEmpty)
              : ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final ShopperChoice shopper in shoppers)
                      ListTile(
                        key: ValueKey<String>('pick-shopper-${shopper.id}'),
                        enabled: shopper.id != currentShopperId,
                        title: Text(
                          shopper.fullName ?? formatPhone(shopper.phone),
                        ),
                        subtitle: Text(
                          '${formatPhone(shopper.phone)} · '
                          '${l10n.shopperOrdersNow(shopper.currentAssignmentCount)}',
                        ),
                        trailing: shopper.id == currentShopperId
                            ? Text(l10n.assignmentCurrent)
                            : null,
                        onTap: () => Navigator.of(context).pop(shopper),
                      ),
                  ],
                ),
          // Both keep the dialog as small as what they show.
          error: (Object error, StackTrace _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoadFailure(
                error: error,
                onRetry: () => ref.invalidate(shopperOptionsProvider),
              ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(heightFactor: 1, child: CircularProgressIndicator()),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('pick-shopper-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
      ],
    );
  }
}
