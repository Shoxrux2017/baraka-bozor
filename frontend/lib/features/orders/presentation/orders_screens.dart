import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
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
import 'order_cards.dart';

/// A total with its kind (`DL-37` (10)), or that nothing is due.
String orderTotalText(
  AppLocalizations l10n,
  AppLanguage language,
  int? totalUzs,
  TotalKind kind,
) => switch (kind) {
  TotalKind.none => l10n.totalNothingDue,
  TotalKind.estimate =>
    '${MoneyFormat.uzs(totalUzs ?? 0, language)} · ${l10n.totalKindEstimate}',
  TotalKind.finalTotal =>
    '${MoneyFormat.uzs(totalUzs ?? 0, language)} · ${l10n.totalKindFinal}',
};

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

/// One of the Customer's orders (`docs/09` section 20): where it stands, its
/// lines with what was bought or replaced, the questions waiting for their
/// answer, the totals and their kind, the payment, the address and the wish;
/// and, while the server allows it, the way to edit it, to cancel it, or to
/// ask an Operator to cancel it. An open order is kept current while shown
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
    required bool request,
  }) async {
    final OrderCancelController cancelling = ref.read(
      orderCancelProvider(orderId).notifier,
    );
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _CancelDialog(
        request: request,
        unconfirmed: cancelling.unconfirmed,
        reason: cancelling.unconfirmedReason,
      ),
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
      appBar: AppBar(
        title: Text(
          order.value == null
              ? ''
              : l10n.orderTitle('${order.value!.orderNumber}'),
        ),
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
                  data: (CustomerOrder order) => _Order(
                    order: order,
                    cancelling: cancelling,
                    onEdit: () =>
                        context.push(AppPaths.customerOrderEdit(order.id)),
                    onCancel: () => _cancel(context, ref, request: false),
                    onRequestCancel: () => _cancel(context, ref, request: true),
                  ),
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

class _Order extends StatelessWidget {
  const _Order({
    required this.order,
    required this.cancelling,
    required this.onEdit,
    required this.onCancel,
    required this.onRequestCancel,
  });

  final CustomerOrder order;
  final MutationState cancelling;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onRequestCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final OrderAddress address = order.address;
    final CancellationReason? reason = order.cancellationReason;
    final CustomerCancellationRequest? request = order.cancellationRequest;
    final CustomerPayment? payment = order.payment;

    Widget amount(String label, int? value, {bool strong = false}) {
      final TextStyle? style = strong
          ? const TextStyle(fontWeight: FontWeight.bold)
          : null;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              strong
                  ? orderTotalText(l10n, language, value, order.totalKind)
                  : MoneyFormat.uzs(value ?? 0, language),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      );
    }

    Widget spinnerOr(IconData icon) => cancelling.isBusy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: l10n.orderCancelling,
            ),
          )
        : Icon(icon);

    return ListView(
      key: const ValueKey<String>('order'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          OrderLabels.customerStatus(l10n, order.status),
          key: const ValueKey<String>('order-status'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(l10n.orderPlacedAt(TashkentTime.format(order.createdAt))),
        Text(OrderLabels.paymentMethod(l10n, order.paymentMethod)),
        if (reason != null) Text(OrderLabels.cancellationReason(l10n, reason)),
        if (request != null) _Request(request: request),
        const SizedBox(height: 16),
        for (final CustomerOrderLine line in order.lines)
          // The Customer's own removals are gone from what they order.
          if (line.removedReason != ItemRemovedReason.customerRemoved)
            _Line(orderId: order.id, line: line, language: language),
        const Divider(),
        if (order.totalKind != TotalKind.none) ...<Widget>[
          amount(l10n.totalsMerchandise, order.merchandiseSubtotalUzs),
          amount(l10n.totalsServiceFee, order.serviceFeeUzs),
          amount(l10n.totalsDeliveryFee, order.deliveryFeeUzs),
        ],
        amount(l10n.totalsTotal, order.totalUzs, strong: true),
        if (order.totalKind == TotalKind.estimate)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.checkoutEstimateExplain),
          ),
        if (payment != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              payment.paidAt == null
                  ? '${OrderLabels.paymentMethod(l10n, payment.method)} · '
                        '${OrderLabels.paymentStatus(l10n, payment.status)} · '
                        '${MoneyFormat.uzs(payment.amountUzs, language)}'
                  : l10n.orderPaid(
                      MoneyFormat.uzs(payment.amountUzs, language),
                      TashkentTime.format(payment.paidAt!),
                    ),
              key: const ValueKey<String>('order-payment'),
            ),
          ),
        const Divider(),
        Text(
          '${l10n.checkoutAddress}: ${address.street}, ${address.house}'
          '${address.apartment == null ? '' : ', ${address.apartment}'}',
        ),
        if (order.deliveryTimeNote != null)
          Text('${l10n.orderSectionDeliveryWish}: ${order.deliveryTimeNote}'),
        const SizedBox(height: 16),
        if (order.canEdit)
          OutlinedButton.icon(
            key: const ValueKey<String>('order-edit'),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.orderEdit),
            onPressed: cancelling.isBusy ? null : onEdit,
          ),
        if (order.canCancelDirectly)
          TextButton.icon(
            key: const ValueKey<String>('order-cancel'),
            icon: spinnerOr(Icons.cancel_outlined),
            label: Text(l10n.orderCancel),
            onPressed: cancelling.isBusy ? null : onCancel,
          ),
        if (order.canRequestCancellation)
          TextButton.icon(
            key: const ValueKey<String>('order-request-cancel'),
            icon: spinnerOr(Icons.cancel_outlined),
            label: Text(l10n.orderRequestCancel),
            onPressed: cancelling.isBusy ? null : onRequestCancel,
          ),
        if (_needsReason(cancelling.failure))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.orderCancellationNeedsReason,
              key: const ValueKey<String>('order-cancel-needs-reason'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          )
        else
          FailureMessage(
            // A request filed meanwhile, from another device: the order
            // loaded again shows it, and its words are the Operator's.
            _alreadyRequested(cancelling.failure) ? null : cancelling.failure,
          ),
      ],
    );
  }

  /// Shopping began since the order was shown: the cancel now asks an
  /// Operator, and a request needs its reason (`DL-65` (1)).
  static bool _needsReason(ApiFailure? failure) =>
      failure is ApiRefusal &&
      failure.status == 422 &&
      failure.error.errors.containsKey('reason');

  static bool _alreadyRequested(ApiFailure? failure) =>
      failure is ApiRefusal && failure.code == 'cancellation_already_pending';
}

/// The order's latest cancellation request: the Customer's reason and where
/// it stands (`DL-65` (5)).
class _Request extends StatelessWidget {
  const _Request({required this.request});

  final CustomerCancellationRequest request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool pending = request.status == CancellationRequestStatus.pending;

    return Padding(
      key: const ValueKey<String>('order-cancellation-request'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.requestYours(request.reason)),
          Text(
            switch (request.status) {
              CancellationRequestStatus.pending =>
                l10n.orderCancellationRequested,
              CancellationRequestStatus.approved => l10n.requestStateApproved,
              CancellationRequestStatus.rejected => l10n.requestStateRejected,
              CancellationRequestStatus.closed => l10n.requestStateClosed,
            },
            key: ValueKey<String>(
              pending
                  ? 'order-cancellation-requested'
                  : 'order-cancellation-request-${request.status.code}',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// A line: what was ordered; once bought, the quantity and the price billed
/// (`BR-PRICE-001`) and what replaced it; its question waiting for the
/// Customer, or that its time ran out; and a refusal of their answer.
class _Line extends ConsumerWidget {
  const _Line({
    required this.orderId,
    required this.line,
    required this.language,
  });

  final String orderId;
  final CustomerOrderLine line;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final ItemRemovedReason? removed = line.removedReason;
    final int? billed = line.billableUnitPriceUzs;
    final ProductNames? replacement = line.replacement;
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

    return Column(
      key: ValueKey<String>('order-line-${line.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${line.name(language)} · ${QuantityRules.display(line.quantity)} $unit',
            style: removed != null
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                removed != null
                    ? l10n.orderLineRemoved(
                        OrderLabels.customerRemovedReason(l10n, removed),
                      )
                    : billed != null
                    ? l10n.orderLineBought(
                        '${QuantityRules.display(line.billableQuantity!)} $unit',
                        l10n.catalogPricePerUnit(
                          MoneyFormat.uzs(billed, language),
                          unit,
                        ),
                        MoneyFormat.uzs(line.lineTotalUzs, language),
                      )
                    : '${l10n.catalogPricePerUnit(MoneyFormat.uzs(line.customerUnitPriceUzs, language), unit)}'
                          ' · ${line.priceMode == PriceMode.estimate ? l10n.cartLineEstimate(MoneyFormat.uzs(line.lineTotalUzs, language)) : MoneyFormat.uzs(line.lineTotalUzs, language)}',
              ),
              if (replacement != null)
                Text(
                  l10n.itemReplacedWith(replacement.name(language)),
                  key: ValueKey<String>('order-line-replacement-${line.id}'),
                ),
            ],
          ),
        ),
        if (question != null)
          _Question(
            orderId: orderId,
            line: line,
            question: question,
            deciding: deciding,
            language: language,
          )
        else if (line.questionExpired)
          Text(
            l10n.questionExpired,
            key: ValueKey<String>('question-expired-${line.id}'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        // A refusal belongs to the question it answered: it is said while
        // that question, or none, is on the line, and not under a question
        // asked since.
        FailureMessage(
          question == null || question.id == answered ? deciding.failure : null,
        ),
      ],
    );
  }
}

/// A question about a line in the Customer's words, with its answers
/// (`docs/09` section 23). After an answer that did not say what it did, it
/// offers only to send the same decision again, under the same key.
class _Question extends ConsumerWidget {
  const _Question({
    required this.orderId,
    required this.line,
    required this.question,
    required this.deciding,
    required this.language,
  });

  final String orderId;
  final CustomerOrderLine line;
  final CustomerQuestion question;
  final MutationState deciding;
  final AppLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final String name = line.name(language);
    final ProductNames? replacement = question.replacement;
    String perUnit(int? price) =>
        l10n.catalogPricePerUnit(MoneyFormat.uzs(price!, language), unit);
    String quantity(String? value) => '${QuantityRules.display(value!)} $unit';
    String word(ApprovalDecision decision) => switch (decision) {
      ApprovalDecision.approve => l10n.questionApprove,
      ApprovalDecision.reject => l10n.questionReject,
    };

    final String asked = switch (question.type) {
      // A price question with a replacement is about the replacement the
      // Customer authorized; without one, about the product ordered.
      ApprovalType.priceOverTolerance =>
        replacement == null
            ? l10n.questionPrice(
                name,
                perUnit(question.proposedCustomerUnitPriceUzs),
                perUnit(line.customerUnitPriceUzs),
              )
            : l10n.questionReplacementPrice(
                replacement.name(language),
                perUnit(question.proposedCustomerUnitPriceUzs),
              ),
      ApprovalType.substitution => l10n.questionSubstitution(
        name,
        replacement!.name(language),
        perUnit(question.proposedCustomerUnitPriceUzs),
      ),
      ApprovalType.reducedQuantity => l10n.questionQuantity(
        name,
        quantity(question.proposedQuantity),
        quantity(line.quantity),
      ),
    };
    final UnansweredRequest<ApprovalDecision>? unanswered = ref.watch(
      unansweredDecisionsProvider(orderId),
    )[question.id];
    final ApprovalDecisionController decisions = ref.read(
      approvalDecisionProvider((orderId: orderId, lineId: line.id)).notifier,
    );
    VoidCallback? decide(ApprovalDecision decision) =>
        deciding.isBusy ? null : () => decisions.decide(question.id, decision);
    // The decision on its way shows that it is, on its own button.
    Widget label(ApprovalDecision decision, String text) =>
        decisions.sending == decision
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: l10n.decisionSending,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(text)),
            ],
          )
        : Text(text);

    return Card(
      key: ValueKey<String>('question-${question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(asked, style: Theme.of(context).textTheme.titleSmall),
            if (question.requestNote != null)
              Text(l10n.questionNote(question.requestNote!)),
            Text(l10n.questionExpires(TashkentTime.format(question.expiresAt))),
            // Agreeing to the price of the product ordered drops the
            // replacement the line shows (`docs/09` section 23).
            if (question.type == ApprovalType.priceOverTolerance &&
                replacement == null &&
                line.replacement != null)
              Text(
                l10n.questionDropsReplacement,
                key: ValueKey<String>(
                  'question-drops-replacement-${question.id}',
                ),
              ),
            Text(l10n.questionRejectRemoves),
            const SizedBox(height: 8),
            if (unanswered != null) ...<Widget>[
              Text(
                l10n.decisionUnanswered(word(unanswered.sent)),
                key: ValueKey<String>('decision-unanswered-${question.id}'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: ValueKey<String>('decide-again-${question.id}'),
                onPressed: decide(unanswered.sent),
                child: label(unanswered.sent, l10n.sendAgain),
              ),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    key: ValueKey<String>('approve-${question.id}'),
                    onPressed: decide(ApprovalDecision.approve),
                    child: label(
                      ApprovalDecision.approve,
                      l10n.questionApprove,
                    ),
                  ),
                  OutlinedButton(
                    key: ValueKey<String>('reject-${question.id}'),
                    onPressed: decide(ApprovalDecision.reject),
                    child: label(ApprovalDecision.reject, l10n.questionReject),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks before cancelling, with a reason of up to 300 characters: optional
/// for a direct cancel, required for a request to an Operator (`DL-65` (1)).
/// Answers the reason, or `null` when the Customer keeps the order. After a
/// cancel whose outcome is unknown it shows that cancel's reason, which a
/// retry sends again unchanged — required or not, since the same request
/// goes again.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({
    required this.request,
    required this.unconfirmed,
    required this.reason,
  });

  final bool request;
  final bool unconfirmed;
  final String? reason;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _reason = TextEditingController(
    text: widget.reason ?? '',
  );

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? _check(AppLocalizations l10n, String? text) {
    final String reason = trimLikeServer(text ?? '');
    if (widget.request && !widget.unconfirmed && reason.isEmpty) {
      return l10n.fieldRequired;
    }
    return reason.runes.length > 300 ? l10n.fieldTooLong(300) : null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.request ? l10n.orderRequestCancelTitle : l10n.orderCancelConfirm,
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.request) Text(l10n.orderRequestCancelExplained),
            TextFormField(
              key: const ValueKey<String>('cancel-reason'),
              controller: _reason,
              readOnly: widget.unconfirmed,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: widget.request
                    ? l10n.orderRequestCancelReason
                    : l10n.orderCancelReason,
                helperText: widget.unconfirmed
                    ? l10n.orderCancelRepeating
                    : null,
                helperMaxLines: 3,
              ),
              validator: (String? text) => _check(l10n, text),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('cancel-keep'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.orderCancelKeep),
        ),
        FilledButton(
          key: const ValueKey<String>('cancel-confirm'),
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop(_reason.text);
            }
          },
          child: Text(
            widget.request ? l10n.orderRequestCancel : l10n.orderCancel,
          ),
        ),
      ],
    );
  }
}
