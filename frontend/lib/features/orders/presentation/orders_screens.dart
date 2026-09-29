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
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

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

/// The Customer's orders, newest first (`docs/09` section 20).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final AsyncValue<Paged<OrderSummary>> page = ref.watch(
      customerOrdersProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myOrders)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: page.when(
                skipLoadingOnReload: false,
                skipLoadingOnRefresh: !page.hasError,
                data: (Paged<OrderSummary> page) => page.items.isEmpty
                    ? Center(
                        key: const ValueKey<String>('orders-empty'),
                        child: Text(l10n.myOrdersEmpty),
                      )
                    : ListView(
                        key: const ValueKey<String>('orders-list'),
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          for (final OrderSummary order in page.items)
                            Card(
                              child: ListTile(
                                key: ValueKey<String>('order-${order.id}'),
                                title: Text(
                                  '${l10n.boardOrderNumber('${order.orderNumber}')} · '
                                  '${OrderLabels.customerStatus(l10n, order.status)}',
                                ),
                                subtitle: Text(
                                  '${TashkentTime.format(order.createdAt)}\n'
                                  '${orderTotalText(l10n, language, order.totalUzs, order.totalKind)} · '
                                  '${l10n.boardItemCount(order.itemCount)}',
                                ),
                                onTap: () => context.push(
                                  AppPaths.customerOrder(order.id),
                                ),
                              ),
                            ),
                          PaginationBar(
                            page: page,
                            onPage: ref
                                .read(ordersPageProvider.notifier)
                                .goToPage,
                          ),
                        ],
                      ),
                error: (Object error, StackTrace _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadFailure(
                    error: error,
                    onRetry: () => ref.invalidate(customerOrdersProvider),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the Customer's orders (`docs/09` section 20): where it stands, its
/// lines at the prices it was placed at, the totals and their kind, the
/// address and the wish; and, while the server allows it, the way to edit it
/// and to cancel it.
class OrderScreen extends ConsumerWidget {
  const OrderScreen({required this.orderId, super.key});

  final String orderId;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final OrderCancelController cancelling = ref.read(
      orderCancelProvider(orderId).notifier,
    );
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _CancelDialog(
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
              child: order.when(
                skipLoadingOnRefresh: !order.hasError,
                data: (CustomerOrder order) => _Order(
                  order: order,
                  cancelling: cancelling,
                  onEdit: () =>
                      context.push(AppPaths.customerOrderEdit(order.id)),
                  onCancel: () => _cancel(context, ref),
                ),
                error: (Object error, StackTrace _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadFailure(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(customerOrderProvider(orderId)),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
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
  });

  final CustomerOrder order;
  final MutationState cancelling;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final OrderAddress address = order.address;
    final CancellationReason? reason = order.cancellationReason;

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
        if (order.cancellationRequest == CancellationRequestStatus.pending)
          Text(
            l10n.orderCancellationRequested,
            key: const ValueKey<String>('order-cancellation-requested'),
          ),
        const SizedBox(height: 16),
        for (final CustomerOrderLine line in order.lines)
          // The Customer's own removals are gone from what they order.
          if (line.removedReason != ItemRemovedReason.customerRemoved)
            _Line(line: line, language: language),
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
            icon: cancelling.isBusy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.orderCancelling,
                    ),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(l10n.orderCancel),
            onPressed: cancelling.isBusy ? null : onCancel,
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
          FailureMessage(cancelling.failure),
      ],
    );
  }

  /// Shopping began since the order was shown: the cancel now asks an
  /// Operator, and a request needs its reason (`DL-65` (1)).
  static bool _needsReason(ApiFailure? failure) =>
      failure is ApiRefusal &&
      failure.status == 422 &&
      failure.error.errors.containsKey('reason');
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.language});

  final CustomerOrderLine line;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final ItemRemovedReason? removed = line.removedReason;

    return ListTile(
      key: ValueKey<String>('order-line-${line.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${line.name(language)} · ${QuantityRules.display(line.quantity)} $unit',
        style: removed != null
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        removed != null
            ? l10n.orderLineRemoved(OrderLabels.removedReason(l10n, removed))
            : '${l10n.catalogPricePerUnit(MoneyFormat.uzs(line.customerUnitPriceUzs, language), unit)}'
                  ' · ${line.priceMode == PriceMode.estimate ? l10n.cartLineEstimate(MoneyFormat.uzs(line.lineTotalUzs, language)) : MoneyFormat.uzs(line.lineTotalUzs, language)}',
      ),
    );
  }
}

/// Asks before cancelling, with an optional reason of up to 300
/// characters; answers the reason, or `null` when the Customer keeps the
/// order. After a cancel whose outcome is unknown it shows that cancel's
/// reason, which a retry sends again unchanged.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.unconfirmed, required this.reason});

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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.orderCancelConfirm),
      content: Form(
        key: _form,
        child: TextFormField(
          key: const ValueKey<String>('cancel-reason'),
          controller: _reason,
          readOnly: widget.unconfirmed,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.orderCancelReason,
            helperText: widget.unconfirmed ? l10n.orderCancelRepeating : null,
            helperMaxLines: 3,
          ),
          validator: (String? text) =>
              trimLikeServer(text ?? '').runes.length > 300
              ? l10n.fieldTooLong(300)
              : null,
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
          child: Text(l10n.orderCancel),
        ),
      ],
    );
  }
}
