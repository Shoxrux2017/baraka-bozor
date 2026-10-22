import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/localization/role_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../auth/domain/app_user.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_widgets.dart';
import 'order_actions.dart';
import 'order_path.dart';
import 'order_side.dart';
import 'order_staff.dart';

/// One order as the Operator and the Admin see it (`docs/09` section 38,
/// `DL-100` (4)): a path of five steps, then the lines, the questions to the
/// Customer and the history at the left, and at the right who and where —
/// a waiting cancellation request and a low rating on top, the Customer
/// with the address and the wish, every Shopper and Courier assignment with
/// its self-order mark, the totals and the payment — with the actions the
/// rules allow on it (`DL-68`). Below [twoColumns] it is one column.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  /// From this width of the page — its content, without the padding — the
  /// order has two columns; the side column is [sideWidth] wide, [gap] apart.
  static const double twoColumns = 1100;
  static const double sideWidth = 372;
  static const double gap = 20;

  /// From this width the Shopper and Courier cards stand side by side in the
  /// one column.
  static const double staffBeside = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BoardOrder> order = ref.watch(boardOrderProvider(orderId));
    final bool compact = MediaQuery.sizeOf(context).width < 1200;
    final EdgeInsets padding = compact
        ? const EdgeInsets.fromLTRB(24, 20, 24, 24)
        : const EdgeInsets.fromLTRB(28, 26, 28, 28);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double content = constraints.maxWidth - padding.horizontal;
        final bool labelled = content >= 560;
        final BoardOrder? loaded = order.value;

        return ListView(
          key: const ValueKey<String>('order-detail'),
          padding: padding,
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey<String>('order-back'),
                style: TextButton.styleFrom(
                  foregroundColor: KitColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.orderBackToBoard),
                onPressed: () => context.go(AppPaths.operations),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: loaded == null
                      ? const SizedBox(height: 32)
                      : _Header(order: loaded),
                ),
                const SizedBox(width: 12),
                if (labelled)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('order-refresh'),
                    style: kitOutlined(
                      height: 40,
                    ).copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(l10n.boardRefresh),
                    onPressed: () =>
                        ref.invalidate(boardOrderProvider(orderId)),
                  )
                else
                  Tooltip(
                    message: l10n.boardRefresh,
                    child: OutlinedButton(
                      key: const ValueKey<String>('order-refresh'),
                      style: kitOutlined(height: 40).copyWith(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const WidgetStatePropertyAll<Size>(
                          Size(40, 40),
                        ),
                        padding: const WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      onPressed: () =>
                          ref.invalidate(boardOrderProvider(orderId)),
                      child: const Icon(Icons.refresh, size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            order.when(
              skipLoadingOnRefresh: !order.hasError,
              data: (BoardOrder order) =>
                  _Order(order: order, twoColumns: content >= twoColumns),
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
      },
    );
  }
}

/// The order's number with its status, and when it was placed and how it is
/// paid; for a cancelled one, why.
class _Header extends StatelessWidget {
  const _Header({required this.order});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              l10n.orderTitle('${order.orderNumber}'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            OrderStatusChip(order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.orderPlacedAt(TashkentTime.format(order.createdAt))} · '
          '${OrderLabels.paymentMethod(l10n, order.paymentMethod)}',
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
        if (order.cancellationReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              OrderLabels.cancellationReason(l10n, order.cancellationReason!),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KitColors.dangerDark,
              ),
            ),
          ),
      ],
    );
  }
}

class _Order extends StatelessWidget {
  const _Order({required this.order, required this.twoColumns});

  final BoardOrder order;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);

    final Widget items = _Section(
      title: l10n.orderSectionItems,
      children: <Widget>[
        for (final BoardItem item in order.items)
          _Item(order: order, item: item, language: language),
      ],
    );
    final Widget questions = _Section(
      title: l10n.orderSectionApprovals,
      children: <Widget>[
        if (order.approvals.isEmpty) Text(l10n.approvalsNone),
        for (final BoardApproval approval in order.approvals.reversed)
          ApprovalTile(order: order, approval: approval),
      ],
    );
    final Widget history = _Section(
      title: l10n.orderSectionHistory,
      children: <Widget>[
        if (order.history.isEmpty) Text(l10n.historyNone),
        for (final HistoryEntry entry in order.history.reversed)
          _History(entry: entry, order: order),
      ],
    );
    final List<Widget> top = <Widget>[
      if (order.cancellationRequests.isNotEmpty) RequestsCard(order: order),
      if (order.rating != null) RatingCard(order: order, rating: order.rating!),
    ];
    final List<Widget> bottom = <Widget>[
      TotalsCard(totals: order.totals),
      PaymentCard(order: order),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OrderPath(order: order),
        const SizedBox(height: 16),
        if (twoColumns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _stack(<Widget>[items, questions, history])),
              const SizedBox(width: OrderDetailScreen.gap),
              SizedBox(
                width: OrderDetailScreen.sideWidth,
                child: _stack(<Widget>[
                  ...top,
                  ClientCard(order: order),
                  ShopperCard(order: order),
                  CourierCard(order: order),
                  ...bottom,
                ]),
              ),
            ],
          )
        else
          _stack(<Widget>[
            ...top,
            ClientCard(order: order),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  constraints.maxWidth >= OrderDetailScreen.staffBeside
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: ShopperCard(order: order)),
                        const SizedBox(width: 16),
                        Expanded(child: CourierCard(order: order)),
                      ],
                    )
                  : _stack(<Widget>[
                      ShopperCard(order: order),
                      CourierCard(order: order),
                    ]),
            ),
            items,
            questions,
            ...bottom,
            history,
          ]),
      ],
    );
  }

  /// [children] one above the other, 16 apart.
  static Widget _stack(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int index = 0; index < children.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(height: 16),
        children[index],
      ],
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
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
  const _Item({
    required this.order,
    required this.item,
    required this.language,
  });

  final BoardOrder order;
  final BoardItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool removed = item.status == OrderItemStatus.removed;
    final String name = language == AppLanguage.ru ? item.nameRu : item.nameUz;
    final String unit = CatalogLabels.unit(l10n, item.unit);
    final NamedProduct? replacement = item.replacement;
    final SubstitutionResolution? resolution = item.replacementResolution;
    final String? bought = item.purchasedQuantity;
    final String? billed = item.billableQuantity;
    final int? paid = item.actualMarketPriceUzs;
    final int? billedPrice = item.billableUnitPriceUzs;

    return ListTile(
      key: ValueKey<String>('order-item-${item.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$name · ${QuantityRules.display(item.quantity)} ${CatalogLabels.unit(l10n, item.unit)}',
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
          if (replacement != null)
            Text(
              <String>[
                l10n.itemReplacedWith(
                  language == AppLanguage.ru
                      ? replacement.nameRu
                      : replacement.nameUz,
                ),
                if (resolution != null)
                  OrderLabels.substitutionResolution(l10n, resolution),
              ].join(', '),
              key: ValueKey<String>('order-item-replacement-${item.id}'),
            ),
          if (bought != null && item.status == OrderItemStatus.purchased)
            Text(
              l10n.itemBought('${QuantityRules.display(bought)} $unit'),
              key: ValueKey<String>('order-item-bought-${item.id}'),
            ),
          if (billed != null && item.status == OrderItemStatus.purchased)
            Text(l10n.itemBilled('${QuantityRules.display(billed)} $unit')),
          if (paid != null)
            Text(
              l10n.itemPricePaid(MoneyFormat.uzs(paid, language)),
              key: ValueKey<String>('order-item-paid-${item.id}'),
            ),
          if (billedPrice != null)
            Text(l10n.itemBilledPrice(MoneyFormat.uzs(billedPrice, language))),
          PriceCorrectionButton(order: order, item: item),
        ],
      ),
    );
  }
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
    final String? details = _details(l10n, interfaceLanguage(context));

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
