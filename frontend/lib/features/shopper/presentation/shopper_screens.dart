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
import '../../../core/localization/language_menu.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../../shells/presentation/staff_area_menu.dart';
import '../application/shopper_orders_controllers.dart';
import '../domain/shopper_orders.dart';
import 'shopper_line_actions.dart';

/// Whether a screen's load has settled on data, so its periodic refresh
/// may run (`DL-54` (15)).
bool _settled(AsyncValue<Object?> value) =>
    value.hasValue && !value.hasError && !value.isLoading;

/// The Shopper's area: their current orders, the longest-waiting first,
/// kept current while shown (`docs/09` section 28, `DL-69`).
class ShopperOrdersScreen extends ConsumerWidget {
  const ShopperOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Paged<ShopperOrderRow>> page = ref.watch(
      shopperOrdersProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shellShopper),
        actions: const <Widget>[LanguageMenuButton(), StaffAreaMenu()],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                active: _settled(page),
                onRefresh: () => ref.invalidate(shopperOrdersProvider),
                child: page.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: !page.hasError,
                  data: (Paged<ShopperOrderRow> page) =>
                      page.items.isEmpty && !page.hasPrevious
                      ? Center(
                          key: const ValueKey<String>('shopper-orders-empty'),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.shopperOrdersEmpty,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          key: const ValueKey<String>('shopper-orders'),
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            // A page a refresh emptied, past the last one.
                            if (page.items.isEmpty)
                              Text(
                                l10n.shopperPageEmpty,
                                key: const ValueKey<String>(
                                  'shopper-page-empty',
                                ),
                              ),
                            for (final ShopperOrderRow row in page.items)
                              _Row(row: row),
                            PaginationBar(
                              page: page,
                              onPage: ref
                                  .read(shopperOrdersPageProvider.notifier)
                                  .goToPage,
                            ),
                          ],
                        ),
                  error: (Object error, StackTrace _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: LoadFailure(
                      error: error,
                      onRetry: () => ref.invalidate(shopperOrdersProvider),
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

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final ShopperOrderRow row;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool accepted = row.assignment.acceptedAt != null;

    return Card(
      child: ListTile(
        key: ValueKey<String>('shopper-order-${row.id}'),
        title: Text(
          '${l10n.boardOrderNumber('${row.orderNumber}')} · '
          '${OrderLabels.status(l10n, row.status)}',
        ),
        subtitle: Text(
          <String>[
            l10n.shopperOpenLines(row.openItemCount, row.itemCount),
            if (row.deliveryTimeNote != null)
              '${l10n.orderSectionDeliveryWish}: ${row.deliveryTimeNote}',
            if (accepted)
              l10n.shopperAssignedAt(
                TashkentTime.format(row.assignment.assignedAt),
              )
            else
              l10n.shopperNotAccepted,
          ].join('\n'),
        ),
        trailing: accepted ? null : const Icon(Icons.fiber_new_outlined),
        onTap: () => context.push(AppPaths.shopperOrder(row.id)),
      ),
    );
  }
}

/// One of the Shopper's orders (`docs/09` sections 28 and 29): its number,
/// the delivery wish, every line with how far its price may go and what
/// became of it; the acceptance and the start while the server offers them;
/// and while shopping, the call to the Customer (interview 7.3). It keeps
/// current while shown (`DL-54` (15)).
class ShopperOrderScreen extends ConsumerWidget {
  const ShopperOrderScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ShopperOrder> order = ref.watch(
      shopperOrderProvider(orderId),
    );
    final ShopperOrder? shown = order.value;
    // Watched here, so the requests without a sure answer last while the
    // order is shown, and a completion in flight holds the refresh, which
    // could otherwise find its order gone before the answer (`DL-70` (5)).
    final bool completionUnanswered =
        ref.watch(unansweredRequestsProvider(orderId)).completion != null;
    final bool completing = ref.watch(shopperCompleteProvider(orderId)).isBusy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          shown == null
              ? l10n.shellShopper
              : l10n.boardOrderNumber('${shown.orderNumber}'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                active: _settled(order) && !completing,
                onRefresh: () => ref.invalidate(shopperOrderProvider(orderId)),
                child: order.when(
                  skipLoadingOnRefresh: !order.hasError,
                  data: (ShopperOrder order) => _OrderView(order: order),
                  error: (Object error, StackTrace _) {
                    // A completion whose answer was lost may have gone
                    // through, and the order with it; it is sent again under
                    // its key, which answers the completed order.
                    final bool gone =
                        error is ApiRefusal && error.status == 404;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        if (completionUnanswered)
                          _UnansweredCompletion(orderId: orderId)
                        else if (gone)
                          const _Gone(),
                        if (!gone)
                          LoadFailure(
                            error: error,
                            onRetry: () =>
                                ref.invalidate(shopperOrderProvider(orderId)),
                          ),
                      ],
                    );
                  },
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

class _OrderView extends StatelessWidget {
  const _OrderView({required this.order});

  final ShopperOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final ShopperAssignment? assignment = order.assignment;
    final DateTime? acceptedAt = assignment?.acceptedAt;
    final DateTime? startedAt = assignment?.startedAt;

    return ListView(
      key: const ValueKey<String>('shopper-order'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Chip(
            key: const ValueKey<String>('shopper-order-status'),
            label: Text(OrderLabels.status(l10n, order.status)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${l10n.orderSectionDeliveryWish}: '
          '${order.deliveryTimeNote ?? l10n.orderNoDeliveryWish}',
        ),
        if (assignment != null)
          Text(
            l10n.shopperAssignedAt(TashkentTime.format(assignment.assignedAt)),
          ),
        if (acceptedAt != null)
          Text(l10n.shopperAcceptedAt(TashkentTime.format(acceptedAt))),
        if (startedAt != null)
          Text(l10n.shopperStartedAt(TashkentTime.format(startedAt))),
        const SizedBox(height: 16),
        _Actions(order: order),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            l10n.orderSectionItems,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final ShopperLine line in order.items)
          _LineCard(order: order, line: line, language: language),
        if (order.status == OrderStatus.shopping) _Complete(order: order),
      ],
    );
  }
}

/// The acceptance and the start while the server offers them, the call to
/// the Customer while shopping, and what the last attempt answered.
class _Actions extends ConsumerWidget {
  const _Actions({required this.order});

  final ShopperOrder order;

  Future<void> _call(BuildContext context, WidgetRef ref, String phone) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool opened = await ref.read(phoneCallsProvider).call(phone);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.callFailed(formatPhone(phone)))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(shopperOrderActionProvider(order.id));
    final ShopperOrderController actions = ref.read(
      shopperOrderActionProvider(order.id).notifier,
    );
    // Only the running action holds the buttons: a tap on the order as it
    // was repeats harmlessly, and the periodic refresh never holds them.
    final bool busy = state.isBusy;
    final String? phone = order.customerPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (order.canAccept)
              FilledButton.icon(
                key: const ValueKey<String>('shopper-accept'),
                icon: const Icon(Icons.check),
                label: Text(l10n.shopperAccept),
                onPressed: busy ? null : actions.accept,
              ),
            if (order.canStart)
              FilledButton.icon(
                key: const ValueKey<String>('shopper-start'),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(l10n.shopperStart),
                onPressed: busy ? null : actions.start,
              ),
            if (phone != null)
              OutlinedButton.icon(
                key: const ValueKey<String>('call-customer'),
                icon: const Icon(Icons.call_outlined),
                label: Text(l10n.callCustomer(formatPhone(phone))),
                onPressed: () => _call(context, ref, phone),
              ),
            if (state.isBusy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        FailureMessage(state.failure),
      ],
    );
  }
}

/// Sends [orderId]'s completion, confirmed first when [confirm]. Once done,
/// the closing screen replaces the order's page, whatever became of the
/// widget that asked (`DL-70` (8)).
Future<void> _sendCompletion(
  BuildContext context,
  WidgetRef ref,
  String orderId, {
  required bool confirm,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final GoRouter router = GoRouter.of(context);
  final ShopperCompleteController completing = ref.read(
    shopperCompleteProvider(orderId).notifier,
  );
  if (confirm) {
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(l10n.completeTitle),
        content: Text(l10n.completeExplained),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('complete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('complete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.completeShopping),
          ),
        ],
      ),
    );
    if (sure != true) {
      return;
    }
  }
  final ShopperOrder? done = await completing.complete();
  if (done != null) {
    router.go(AppPaths.shopperDone(done.orderNumber));
  }
}

/// A completion whose answer was lost, when the order can no longer be
/// read: it is sent again under its key.
class _UnansweredCompletion extends ConsumerWidget {
  const _UnansweredCompletion({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(shopperCompleteProvider(orderId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.completeUnconfirmed),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('complete-again'),
          icon: const Icon(Icons.done_all),
          label: Text(l10n.completeShopping),
          onPressed: state.isBusy
              ? null
              : () => _sendCompletion(context, ref, orderId, confirm: false),
        ),
        FailureMessage(state.failure),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// An order the Shopper can no longer read: cancelled, or passed to another
/// Shopper.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey<String>('shopper-order-gone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.shopperOrderGone),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey<String>('shopper-order-gone-back'),
          onPressed: () => context.go(AppPaths.shopper),
          child: Text(l10n.doneBack),
        ),
      ],
    );
  }
}

/// The completion of the shopping (`docs/09` section 35), confirmed first
/// and keyed as a purchase is. Once done the order is no longer the
/// Shopper's, and the screen that follows tells them what to do with the
/// package. A refusal because lines are still open names them.
class _Complete extends ConsumerWidget {
  const _Complete({required this.order});

  final ShopperOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState state = ref.watch(shopperCompleteProvider(order.id));
    final bool unconfirmed =
        ref.watch(unansweredRequestsProvider(order.id)).completion != null;
    final ApiFailure? failure = state.failure;
    final Object? open =
        failure is ApiRefusal && failure.code == 'shopping_incomplete'
        ? failure.error.details['item_ids']
        : null;
    final List<String> openNames = <String>[
      if (open is List<Object?>)
        for (final ShopperLine line in order.items)
          if (open.contains(line.id))
            language == AppLanguage.ru ? line.nameRu : line.nameUz,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (unconfirmed)
            Text(
              l10n.completeUnconfirmed,
              key: const ValueKey<String>('complete-unconfirmed'),
            ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('shopper-complete'),
                icon: const Icon(Icons.done_all),
                label: Text(l10n.completeShopping),
                onPressed: state.isBusy
                    ? null
                    : () => _sendCompletion(
                        context,
                        ref,
                        order.id,
                        confirm: !unconfirmed,
                      ),
              ),
              if (state.isBusy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (openNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.completeIncomplete(openNames.join(', ')),
                key: const ValueKey<String>('complete-open-lines'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else
            FailureMessage(failure),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.order,
    required this.line,
    required this.language,
  });

  final ShopperOrder order;
  final ShopperLine line;
  final AppLanguage language;

  String _name(String uz, String ru) => language == AppLanguage.ru ? ru : uz;

  @override
  Widget build(BuildContext context) {
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
              '${_name(line.nameUz, line.nameRu)} · ${amount(line.quantity)}',
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
                    _name(replacement.nameUz, replacement.nameRu),
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
