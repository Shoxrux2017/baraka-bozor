import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/language_menu.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/map_links.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../../shells/presentation/staff_area_menu.dart';
import '../application/courier_orders_controllers.dart';
import '../domain/courier_orders.dart';
import 'courier_outcome_dialogs.dart';

/// Whether a screen's load has settled on data, so its periodic refresh
/// may run (`DL-54` (15)).
bool _settled(AsyncValue<Object?> value) =>
    value.hasValue && !value.hasError && !value.isLoading;

/// The address as one line: the street, the house and the apartment.
String addressLine(DeliveryAddress address) =>
    '${address.street}, ${address.house}'
    '${address.apartment == null ? '' : ', ${address.apartment}'}';

/// The Courier's area: their current deliveries, the longest-waiting first,
/// kept current while shown (`docs/09` section 36, `DL-72`). Its app bar
/// holds the language and one menu, as the Shopper's does (`DL-69` (5)).
class CourierOrdersScreen extends ConsumerWidget {
  const CourierOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Paged<CourierOrder>> page = ref.watch(
      courierOrdersProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shellCourier),
        actions: const <Widget>[LanguageMenuButton(), StaffAreaMenu()],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                active: _settled(page),
                onRefresh: () => ref.invalidate(courierOrdersProvider),
                child: page.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: !page.hasError,
                  data: (Paged<CourierOrder> page) =>
                      page.items.isEmpty && !page.hasPrevious
                      ? Center(
                          key: const ValueKey<String>('courier-orders-empty'),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.courierOrdersEmpty,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          key: const ValueKey<String>('courier-orders'),
                          padding: const EdgeInsets.all(16),
                          children: <Widget>[
                            // A page a refresh emptied, past the last one.
                            if (page.items.isEmpty)
                              Text(
                                l10n.courierPageEmpty,
                                key: const ValueKey<String>(
                                  'courier-page-empty',
                                ),
                              ),
                            for (final CourierOrder order in page.items)
                              _Row(order: order),
                            PaginationBar(
                              page: page,
                              onPage: ref
                                  .read(courierOrdersPageProvider.notifier)
                                  .goToPage,
                            ),
                          ],
                        ),
                  error: (Object error, StackTrace _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: LoadFailure(
                      error: error,
                      onRetry: () => ref.invalidate(courierOrdersProvider),
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

/// What to collect, or that nothing is.
String _collect(AppLocalizations l10n, AppLanguage language, CourierOrder o) {
  final int? amount = o.amountToCollectUzs;
  return amount == null
      ? l10n.courierPaidOnline
      : l10n.courierCollect(MoneyFormat.uzs(amount, language));
}

class _Row extends StatelessWidget {
  const _Row({required this.order});

  final CourierOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final bool accepted = order.assignment.acceptedAt != null;
    final Recipient? recipient = order.recipient;
    final DeliveryAddress? address = order.address;

    return Card(
      child: ListTile(
        key: ValueKey<String>('courier-order-${order.id}'),
        title: Text(
          '${l10n.boardOrderNumber('${order.orderNumber}')} · '
          '${OrderLabels.status(l10n, order.status)}',
        ),
        subtitle: Text(
          <String>[
            if (recipient != null) l10n.courierRecipient(recipient.fullName),
            if (address != null) l10n.courierAddress(addressLine(address)),
            if (order.deliveryTimeNote != null)
              '${l10n.orderSectionDeliveryWish}: ${order.deliveryTimeNote}',
            _collect(l10n, language, order),
            if (order.cancellationRequestPending) l10n.courierRequestPending,
            if (accepted)
              l10n.courierAssignedAt(
                TashkentTime.format(order.assignment.assignedAt),
              )
            else
              l10n.courierNotAccepted,
          ].join('\n'),
        ),
        trailing: accepted ? null : const Icon(Icons.fiber_new_outlined),
        onTap: () => context.push(AppPaths.courierOrder(order.id)),
      ),
    );
  }
}

/// One of the Courier's deliveries (`docs/09` sections 36 and 37): who
/// receives it and where, the wishes, the cash to collect, the calls and
/// the point in the map app; the acceptance, the start, and the outcome
/// while the server allows them. It keeps current while shown (`DL-54`
/// (15)).
class CourierOrderScreen extends ConsumerWidget {
  const CourierOrderScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CourierOrder> order = ref.watch(
      courierOrderProvider(orderId),
    );
    final CourierOrder? shown = order.value;
    // Watched here, so a handover without a sure answer lasts while the
    // delivery is shown (`DL-72`). An outcome is sent from a dialog, which
    // covers the page, so the refresh waits for it anyway.
    final bool unanswered =
        ref.watch(unansweredHandoverProvider(orderId)) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          shown == null
              ? l10n.shellCourier
              : l10n.boardOrderNumber('${shown.orderNumber}'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                active: _settled(order),
                onRefresh: () => ref.invalidate(courierOrderProvider(orderId)),
                child: order.when(
                  skipLoadingOnRefresh: !order.hasError,
                  data: (CourierOrder order) => _DeliveryView(order: order),
                  error: (Object error, StackTrace _) {
                    // A handover whose answer was lost may have gone
                    // through, and the delivery with it; it is sent again
                    // under its key, which answers the completed order.
                    final bool gone =
                        error is ApiRefusal && error.status == 404;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        if (unanswered)
                          _UnansweredHandover(orderId: orderId)
                        else if (gone)
                          const _Gone(),
                        if (!gone)
                          LoadFailure(
                            error: error,
                            onRetry: () =>
                                ref.invalidate(courierOrderProvider(orderId)),
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

class _DeliveryView extends StatelessWidget {
  const _DeliveryView({required this.order});

  final CourierOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CourierAssignment assignment = order.assignment;
    final DateTime? acceptedAt = assignment.acceptedAt;
    final DateTime? startedAt = assignment.deliveryStartedAt;
    final DateTime? delayAt = assignment.delayAt;
    final Recipient? recipient = order.recipient;
    final DeliveryAddress? address = order.address;
    final String? landmark = address?.landmark;
    final String? note = order.deliveryNote;

    return ListView(
      key: const ValueKey<String>('courier-order'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Chip(
            key: const ValueKey<String>('courier-order-status'),
            label: Text(OrderLabels.status(l10n, order.status)),
          ),
        ),
        if (order.cancellationRequestPending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              key: const ValueKey<String>('courier-request-pending'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.warning_amber_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.courierRequestPending,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (recipient != null) Text(l10n.courierRecipient(recipient.fullName)),
        if (address != null)
          Text(
            l10n.courierAddress(addressLine(address)),
            key: const ValueKey<String>('courier-address'),
          ),
        if (landmark != null) Text(l10n.courierLandmark(landmark)),
        if (note != null) Text(l10n.courierDeliveryNote(note)),
        Text(
          '${l10n.orderSectionDeliveryWish}: '
          '${order.deliveryTimeNote ?? l10n.orderNoDeliveryWish}',
        ),
        const SizedBox(height: 8),
        Text(
          _collect(l10n, language, order),
          key: const ValueKey<String>('courier-amount'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.courierAssignedAt(TashkentTime.format(assignment.assignedAt)),
        ),
        if (acceptedAt != null)
          Text(l10n.courierAcceptedAt(TashkentTime.format(acceptedAt))),
        if (startedAt != null)
          Text(l10n.courierStartedAt(TashkentTime.format(startedAt))),
        if (delayAt != null)
          Text(
            l10n.courierDueBy(TashkentTime.format(delayAt)),
            key: const ValueKey<String>('courier-due-by'),
          ),
        const SizedBox(height: 16),
        _Contacts(order: order),
        const SizedBox(height: 16),
        _Actions(order: order),
        if (order.status == OrderStatus.onTheWay && startedAt != null)
          _Outcome(order: order),
      ],
    );
  }
}

/// The calls and the map: the recipient, the point in the phone's own map
/// app, and — without a handoff point — the Shopper who has the order
/// (`DL-54` (16), `BR-DEL-006`).
class _Contacts extends ConsumerWidget {
  const _Contacts({required this.order});

  final CourierOrder order;

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

  Future<void> _openMap(
    BuildContext context,
    WidgetRef ref,
    DeliveryAddress address,
  ) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool opened = await ref
        .read(mapLinksProvider)
        .open(address.latitude, address.longitude);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.courierMapFailed(addressLine(address)))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Recipient? recipient = order.recipient;
    final DeliveryAddress? address = order.address;
    final String? shopper = order.shopperPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: <Widget>[
            if (recipient != null)
              OutlinedButton.icon(
                key: const ValueKey<String>('call-recipient'),
                icon: const Icon(Icons.call_outlined),
                label: Text(l10n.callRecipient(formatPhone(recipient.phone))),
                onPressed: () => _call(context, ref, recipient.phone),
              ),
            if (address != null)
              OutlinedButton.icon(
                key: const ValueKey<String>('courier-open-map'),
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.courierOpenMap),
                onPressed: () => _openMap(context, ref, address),
              ),
          ],
        ),
        if (shopper != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(l10n.courierPickupFromShopper),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('call-shopper'),
            icon: const Icon(Icons.call_outlined),
            label: Text(l10n.callShopper(formatPhone(shopper))),
            onPressed: () => _call(context, ref, shopper),
          ),
        ],
      ],
    );
  }
}

/// The acceptance and the start while the server offers them, and what the
/// last attempt answered. A start refused because a cancellation request
/// now waits loads the order again, which then says so.
class _Actions extends ConsumerWidget {
  const _Actions({required this.order});

  final CourierOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(courierOrderActionProvider(order.id));
    final CourierOrderController actions = ref.read(
      courierOrderActionProvider(order.id).notifier,
    );
    // Only the running action holds the buttons: a tap on the order as it
    // was repeats harmlessly, and the periodic refresh never holds them.
    final bool busy = state.isBusy;

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
                key: const ValueKey<String>('courier-accept'),
                icon: const Icon(Icons.check),
                label: Text(l10n.courierAccept),
                onPressed: busy ? null : actions.accept,
              ),
            if (order.canStart)
              FilledButton.icon(
                key: const ValueKey<String>('courier-start'),
                icon: const Icon(Icons.delivery_dining_outlined),
                label: Text(l10n.courierStart),
                onPressed: busy ? null : actions.start,
              ),
            if (busy)
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

/// Leaves a delivery its outcome ended: the Courier is told, and taken back
/// to the list unless they left the delivery meanwhile (`frontend/AGENTS.md`
/// section 6).
void _leave(
  GoRouter router,
  ScaffoldMessengerState messenger,
  String orderId,
  String said,
) {
  messenger.showSnackBar(SnackBar(content: Text(said)));
  if (router.state.uri.path == AppPaths.courierOrder(orderId)) {
    router.go(AppPaths.courier);
  }
}

/// Delivered and not delivered, once the Courier is on the way.
class _Outcome extends ConsumerWidget {
  const _Outcome({required this.order});

  final CourierOrder order;

  Future<void> _delivered(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CourierOrder? done = await showDialog<CourierOrder>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => DeliveredDialog(order: order),
    );
    if (done != null) {
      _leave(
        router,
        messenger,
        order.id,
        l10n.courierDeliveredDone('${done.orderNumber}'),
      );
    }
  }

  Future<void> _notDelivered(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CourierOrder? done = await showDialog<CourierOrder>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => NotDeliveredDialog(order: order),
    );
    if (done != null) {
      _leave(
        router,
        messenger,
        order.id,
        l10n.courierNotDeliveredDone('${done.orderNumber}'),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = ref.watch(courierOutcomeProvider(order.id)).isBusy;
    final bool unanswered =
        ref.watch(unansweredHandoverProvider(order.id)) != null;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (unanswered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.courierHandoverUnconfirmed,
                key: const ValueKey<String>('courier-handover-unconfirmed'),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('courier-delivered'),
                icon: const Icon(Icons.done_all),
                label: Text(l10n.courierDelivered),
                onPressed: busy ? null : () => _delivered(context),
              ),
              // After a handover without a sure answer, only the handover
              // goes: it may have completed the order.
              if (!unanswered)
                OutlinedButton.icon(
                  key: const ValueKey<String>('courier-not-delivered'),
                  icon: const Icon(Icons.report_outlined),
                  label: Text(l10n.courierNotDelivered),
                  onPressed: busy ? null : () => _notDelivered(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A handover whose answer was lost, when the delivery can no longer be
/// read: it is sent again as it was, under its key.
class _UnansweredHandover extends ConsumerWidget {
  const _UnansweredHandover({required this.orderId});

  final String orderId;

  Future<void> _again(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CourierOrder? done = await ref
        .read(courierOutcomeProvider(orderId).notifier)
        .delivered(null);
    if (done != null) {
      _leave(
        router,
        messenger,
        orderId,
        l10n.courierDeliveredDone('${done.orderNumber}'),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(courierOutcomeProvider(orderId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.courierHandoverUnconfirmed),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('courier-delivered-again'),
          icon: const Icon(Icons.done_all),
          label: Text(l10n.courierDelivered),
          onPressed: state.isBusy ? null : () => _again(context, ref),
        ),
        CashMismatchOr(failure: state.failure),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// A delivery the Courier can no longer read: delivered, failed, passed to
/// another Courier, or cancelled.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey<String>('courier-order-gone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.courierOrderGone),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey<String>('courier-order-gone-back'),
          onPressed: () => context.go(AppPaths.courier),
          child: Text(l10n.courierBack),
        ),
      ],
    );
  }
}
