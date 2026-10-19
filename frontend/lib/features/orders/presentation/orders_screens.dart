import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';
import 'cancel_sheet.dart';
import 'order_cards.dart';
import 'order_questions.dart';
import 'order_rating_card.dart';
import 'order_sections.dart';

/// The Customer's orders, newest first, in two tabs: the ones in hand and the
/// ones that ended (`docs/09` section 20, `DL-92` item 3). An order with a
/// question waiting for their answer says so, and the tab in hand is kept
/// current while shown.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrdersTab _tab = OrdersTab.current;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Paged<OrderSummary>> page = ref.watch(
      customerOrdersProvider(_tab),
    );
    final bool refreshing =
        _tab == OrdersTab.current &&
        page.hasValue &&
        !page.hasError &&
        !page.isLoading;

    return CustomerTabScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(
          title: l10n.myOrders,
          automaticallyImplyLeading: false,
        ),
        bottomNavigationBar: const CustomerTabBar(current: CustomerTab.orders),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _TabSwitch(
                  tab: _tab,
                  onTab: (OrdersTab tab) => setState(() => _tab = tab),
                ),
              ),
              Expanded(
                child: PeriodicRefresh(
                  interval: const Duration(seconds: 30),
                  active: refreshing,
                  onRefresh: () =>
                      ref.invalidate(customerOrdersProvider(OrdersTab.current)),
                  child: page.when(
                    skipLoadingOnReload: false,
                    skipLoadingOnRefresh: !page.hasError,
                    data: (Paged<OrderSummary> page) => page.items.isEmpty
                        ? _Empty(tab: _tab)
                        : ListView(
                            key: const ValueKey<String>('orders-list'),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            children: <Widget>[
                              for (final OrderSummary order in page.items)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _tab == OrdersTab.current
                                      ? CurrentOrderCard(order: order)
                                      : PastOrderCard(order: order),
                                ),
                              PaginationBar(
                                page: page,
                                onPage: ref
                                    .read(ordersPageProvider(_tab).notifier)
                                    .goToPage,
                              ),
                            ],
                          ),
                    error: (Object error, StackTrace _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: LoadFailure(
                        error: error,
                        onRetry: () =>
                            ref.invalidate(customerOrdersProvider(_tab)),
                      ),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two tabs as one segmented control; the chosen one is green.
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.tab, required this.onTab});

  final OrdersTab tab;
  final ValueChanged<OrdersTab> onTab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    Widget segment(OrdersTab value, String key, String label) {
      final bool chosen = tab == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: chosen,
          excludeSemantics: true,
          label: label,
          child: Material(
            key: ValueKey<String>(key),
            color: chosen ? KitColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onTab(value),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: chosen ? Colors.white : KitColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: <Widget>[
              segment(
                OrdersTab.current,
                'orders-tab-current',
                l10n.ordersTabCurrent,
              ),
              const SizedBox(width: 4),
              segment(OrdersTab.past, 'orders-tab-past', l10n.ordersTabPast),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab with no orders: the way to the first one, or what will be here.
class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final OrdersTab tab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool current = tab == OrdersTab.current;

    return Center(
      key: const ValueKey<String>('orders-empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.primaryWash,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 96,
                child: Icon(
                  Icons.receipt_long,
                  size: 44,
                  color: KitColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              current ? l10n.myOrdersEmpty : l10n.ordersPastEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            if (current) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l10n.ordersEmptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: KitColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('orders-empty-shop'),
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.go(AppPaths.customer),
                child: Text(
                  l10n.ordersEmptyAction,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One of the Customer's orders (`docs/09` section 20, drawings 29 to 29з):
/// where it stands, the questions waiting for their answer, the lines with
/// what was bought or replaced, the amounts and their kind, the payment, the
/// address and the wish, the Courier once it is on the way; and, while the
/// server allows it, the way to edit the order, to cancel it, or to ask an
/// Operator to cancel it. An open order is kept current while shown
/// (`DL-54` (15)).
class OrderScreen extends ConsumerWidget {
  const OrderScreen({required this.orderId, super.key});

  final String orderId;

  static const Set<OrderStatus> _ended = <OrderStatus>{
    OrderStatus.completed,
    OrderStatus.cancelled,
  };

  /// A shown order still open, with no load running and none failed.
  static bool _refreshing(AsyncValue<CustomerOrder> order) =>
      order.hasValue &&
      !order.hasError &&
      !order.isLoading &&
      !_ended.contains(order.value!.status);

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref, {
    required int orderNumber,
    required bool request,
  }) async {
    final OrderCancelController cancelling = ref.read(
      orderCancelProvider(orderId).notifier,
    );
    final String? reason = await showCancelSheet(
      context,
      orderNumber: orderNumber,
      request: request,
      unconfirmed: cancelling.unconfirmed,
      reason: cancelling.unconfirmedReason,
    );
    if (reason == null || !context.mounted) {
      return;
    }
    final String trimmed = trimLikeServer(reason);
    await cancelling.cancel(trimmed.isEmpty ? null : trimmed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerOrder> order = ref.watch(
      customerOrderProvider(orderId),
    );
    final MutationState cancelling = ref.watch(orderCancelProvider(orderId));
    // The decisions sent without a sure answer last while the order is shown.
    ref.watch(unansweredDecisionsProvider(orderId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: order.value == null
            ? ''
            : l10n.customerOrderTitle(order.value!.orderNumber),
      ),
      bottomNavigationBar: order.when<Widget?>(
        skipLoadingOnRefresh: !order.hasError,
        data: (CustomerOrder order) => OrderFooter.shows(order, cancelling)
            ? OrderFooter(
                order: order,
                cancelling: cancelling,
                onEdit: () =>
                    context.push(AppPaths.customerOrderEdit(order.id)),
                onCancel: () => _cancel(
                  context,
                  ref,
                  orderNumber: order.orderNumber,
                  request: false,
                ),
                onRequestCancel: () => _cancel(
                  context,
                  ref,
                  orderNumber: order.orderNumber,
                  request: true,
                ),
              )
            : null,
        error: (Object error, StackTrace _) => null,
        loading: () => null,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                interval: const Duration(seconds: 15),
                active: _refreshing(order),
                // The list loads again too, so it is current on the way back.
                onRefresh: () => ref
                  ..invalidate(customerOrderProvider(orderId))
                  ..invalidate(customerOrdersProvider),
                child: order.when(
                  skipLoadingOnRefresh: !order.hasError,
                  data: (CustomerOrder order) => _Order(order: order),
                  error: (Object error, StackTrace _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: LoadFailure(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(customerOrderProvider(orderId)),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The order in the kit's order: the status, the request, the Courier, the
/// questions, the lines, the amounts and the facts. While the Courier is on
/// the way the facts come right after them, for the payment due and the
/// address to hand.
class _Order extends ConsumerWidget {
  const _Order({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DateTime now = ref.watch(clockProvider)();
    final CustomerCancellationRequest? request = order.cancellationRequest;
    final OrderCourier? courier = order.courier;
    final List<CustomerOrderLine> lines = shownLines(order);
    final Widget info = OrderInfoSection(order: order, now: now);
    final bool onTheWay = order.status == OrderStatus.onTheWay;

    return ListView(
      key: const ValueKey<String>('order'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        OrderStatusCard(order: order, now: now),
        if (request != null) ...<Widget>[
          const SizedBox(height: 16),
          CancellationRequestCard(request: request),
        ],
        if (courier != null) ...<Widget>[
          const SizedBox(height: 16),
          CourierCard(courier: courier),
        ],
        if (order.canRate) ...<Widget>[
          const SizedBox(height: 16),
          RateOrderCard(order: order),
        ] else if (order.rating != null) ...<Widget>[
          const SizedBox(height: 16),
          RatedOrderCard(rating: order.rating!),
        ],
        if (onTheWay) ...<Widget>[const SizedBox(height: 16), info],
        for (final CustomerOrderLine line in lines)
          _QuestionBlock(orderId: order.id, line: line, language: language),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            l10n.checkoutItems(lines.length),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final CustomerOrderLine line in lines)
          OrderLineRow(line: line, orderStatus: order.status),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: KitColors.line),
        const SizedBox(height: 12),
        OrderAmounts(order: order),
        if (!onTheWay) ...<Widget>[const SizedBox(height: 20), info],
      ],
    );
  }
}

/// A line's question waiting for the Customer, or that its time ran out; and
/// a refusal of their answer. The refusal belongs to the question it
/// answered: it is said while that question, or none, is on the line, and
/// not under a question asked since.
class _QuestionBlock extends ConsumerWidget {
  const _QuestionBlock({
    required this.orderId,
    required this.line,
    required this.language,
  });

  final String orderId;
  final CustomerOrderLine line;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CustomerQuestion? question = line.question;
    final MutationState deciding = ref.watch(
      approvalDecisionProvider((orderId: orderId, lineId: line.id)),
    );
    final String? answered = ref
        .read(
          approvalDecisionProvider((orderId: orderId, lineId: line.id))
              .notifier,
        )
        .approvalId;

    // A refusal stays under the line it answered after the question is gone.
    final ApiFailure? refusal = question == null || question.id == answered
        ? deciding.failure
        : null;
    if (question == null && !line.questionExpired && refusal == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (question != null)
            OrderQuestionCard(
              orderId: orderId,
              line: line,
              question: question,
              deciding: deciding,
              language: language,
            )
          else if (line.questionExpired)
            OrderQuestionExpired(line: line)
          else if (refusal != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line.name(language),
                key: ValueKey<String>('question-refusal-name-${line.id}'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KitColors.ink2,
                ),
              ),
            ),
          FailureMessage(refusal),
        ],
      ),
    );
  }
}
