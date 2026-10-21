import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/map_links.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_call_card.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_empty_state.dart';
import '../../../core/widgets/kit/kit_footer.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../application/courier_orders_controllers.dart';
import '../domain/courier_orders.dart';
import 'courier_outcome_sheets.dart';
import 'courier_stage.dart';
import 'courier_status_card.dart';

/// Whether a screen's load has settled on data, so its periodic refresh
/// may run (`DL-54` (15)).
bool _settled(AsyncValue<Object?> value) =>
    value.hasValue && !value.hasError && !value.isLoading;

/// One of the Courier's deliveries (`docs/09` sections 36 and 37, `DL-99`):
/// the status card of its stage, where the package is picked up, the calls,
/// the address with the route, and the payment; and under it the next step —
/// accept, set off, or the outcome. It keeps current while shown (`DL-54`
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
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: shown == null
            ? l10n.shellCourier
            : l10n.customerOrderTitle(shown.orderNumber),
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
                  data: (CourierOrder order) =>
                      _DeliveryView(order: order, unanswered: unanswered),
                  error: (Object error, StackTrace _) {
                    // A handover whose answer was lost may have gone
                    // through, and the delivery with it; it is sent again
                    // under its key, which answers the completed order.
                    final bool gone =
                        error is ApiRefusal && error.status == 404;
                    if (gone && !unanswered) {
                      return const _Gone();
                    }
                    return Column(
                      children: <Widget>[
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: <Widget>[
                              if (unanswered) ...<Widget>[
                                const _UnconfirmedNote(),
                                _UnansweredFailure(orderId: orderId),
                              ],
                              if (!gone)
                                LoadFailure(
                                  error: error,
                                  onRetry: () => ref.invalidate(
                                    courierOrderProvider(orderId),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (unanswered) _UnansweredFooter(orderId: orderId),
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
  const _DeliveryView({required this.order, required this.unanswered});

  final CourierOrder order;
  final bool unanswered;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final Recipient? recipient = order.recipient;
    final DeliveryAddress? address = order.address;
    final String? shopper = order.shopperPhone;
    final int? amount = order.amountToCollectUzs;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            key: const ValueKey<String>('courier-order'),
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              CourierStatusCard(order: order),
              if (order.status == OrderStatus.deliveryAssigned) ...<Widget>[
                const SizedBox(height: 16),
                if (order.handoffPoint)
                  KitNote(
                    icon: Icons.inventory_2_outlined,
                    text: Text(
                      l10n.courierPickupAtPoint('${order.orderNumber}'),
                      key: const ValueKey<String>('courier-pickup-at-point'),
                    ),
                  )
                else
                  KitNote(
                    icon: Icons.storefront_outlined,
                    tone: KitTone.amber,
                    text: Text(
                      l10n.courierPickupFromShopper,
                      key: const ValueKey<String>(
                        'courier-pickup-from-shopper',
                      ),
                    ),
                  ),
              ],
              if (shopper != null) ...<Widget>[
                const SizedBox(height: 12),
                KitCallCard(
                  key: const ValueKey<String>('call-shopper'),
                  title: l10n.courierCallShopper,
                  phone: shopper,
                  icon: Icons.shopping_basket_outlined,
                  tone: KitTone.amber,
                ),
              ],
              if (unanswered) ...<Widget>[
                const SizedBox(height: 16),
                const _UnconfirmedNote(),
              ],
              if (recipient != null) ...<Widget>[
                _Heading(l10n.courierRecipientTitle),
                KitCallCard(
                  key: const ValueKey<String>('call-recipient'),
                  title: recipient.fullName,
                  phone: recipient.phone,
                ),
              ],
              if (address != null) ...<Widget>[
                _Heading(l10n.courierAddressTitle),
                _AddressCard(address: address, note: order.deliveryNote),
              ],
              _Heading(l10n.courierPaymentTitle),
              _PaymentBox(amount: amount, language: language),
            ],
          ),
        ),
        _Footer(order: order),
      ],
    );
  }
}

/// A section heading: 16 bold, with 22 above and 12 below.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
      ),
    );
  }
}

/// A handover sent without a sure answer, as a grey note.
class _UnconfirmedNote extends StatelessWidget {
  const _UnconfirmedNote();

  @override
  Widget build(BuildContext context) {
    return KitNote(
      icon: Icons.cloud_off,
      tone: KitTone.grey,
      text: Text(
        AppLocalizations.of(context).courierHandoverUnconfirmed,
        key: const ValueKey<String>('courier-handover-unconfirmed'),
      ),
    );
  }
}

/// Where to deliver (`DL-86` (6), `DL-99`): the full line, the landmark and
/// the note under their own labels, then the route in Yandex and the line to
/// copy.
class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address, required this.note});

  final DeliveryAddress address;
  final String? note;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool opened = await ref
        .read(mapLinksProvider)
        .open(address.latitude, address.longitude);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.courierMapFailed(addressLine(l10n, address))),
        ),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: addressLine(l10n, address)));
    messenger.showSnackBar(SnackBar(content: Text(l10n.courierAddressCopied)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? landmark = address.landmark;
    final String? note = this.note;
    const ButtonStyle shrunk = ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return KitCard(
      key: const ValueKey<String>('courier-address-card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _AddressRow(
            icon: Icons.location_on_outlined,
            green: true,
            child: Text(
              addressLine(l10n, address),
              key: const ValueKey<String>('courier-address'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: KitColors.ink,
              ),
            ),
          ),
          if (landmark != null) ...<Widget>[
            const _Separator(),
            _AddressRow(
              icon: Icons.flag_outlined,
              label: l10n.courierLandmarkLabel,
              child: _Detail(landmark),
            ),
          ],
          if (note != null) ...<Widget>[
            const _Separator(),
            _AddressRow(
              icon: Icons.chat_outlined,
              label: l10n.courierNoteLabel,
              child: _Detail(note),
            ),
          ],
          const _Separator(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey<String>('courier-open-yandex'),
                    style: kitFilled(height: 44).merge(shrunk),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(
                      l10n.courierOpenYandex,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () => _open(context, ref),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 44,
                  child: Tooltip(
                    message: l10n.courierCopyAddress,
                    child: OutlinedButton(
                      key: const ValueKey<String>('courier-copy-address'),
                      style: kitOutlined(height: 44)
                          .merge(shrunk)
                          .copyWith(
                            minimumSize: const WidgetStatePropertyAll<Size>(
                              Size(44, 44),
                            ),
                            padding:
                                const WidgetStatePropertyAll<
                                  EdgeInsetsGeometry
                                >(EdgeInsets.zero),
                          ),
                      onPressed: () => _copy(context),
                      child: const Icon(Icons.content_copy_outlined, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: KitColors.line));
}

/// A line of the address card's detail: 14 `ink`.
class _Detail extends StatelessWidget {
  const _Detail(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, color: KitColors.ink),
    );
  }
}

/// One row of the address card: a 40 icon tile and the [child], over its
/// [label] when it has one.
class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.child,
    this.label,
    this.green = false,
  });

  final IconData icon;
  final Widget child;
  final String? label;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final String? label = this.label;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: green ? KitColors.primaryWash : KitColors.field,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: green ? KitColors.primaryDark : KitColors.ink2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                child,
                if (label != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What to take: the cash to collect, large, or that nothing is to be taken.
class _PaymentBox extends StatelessWidget {
  const _PaymentBox({required this.amount, required this.language});

  final int? amount;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? amount = this.amount;
    final bool cash = amount != null;

    return DecoratedBox(
      key: const ValueKey<String>('courier-amount'),
      decoration: BoxDecoration(
        color: cash ? KitColors.warningWash : KitColors.primaryWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                cash ? Icons.payments_outlined : Icons.credit_card,
                size: 26,
                color: cash ? KitColors.warning : KitColors.primaryDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    cash
                        ? l10n.courierCollectLabel
                        : l10n.courierPaidOnlineLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: KitColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cash
                        ? MoneyFormat.uzs(amount, language)
                        : l10n.courierNoCash,
                    style: TextStyle(
                      fontSize: cash ? 24 : 16,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

/// The step the delivery offers, pinned under the page: the acceptance, the
/// start, or the two outcomes. A start refused because a cancellation
/// request now waits loads the order again, which then says so.
class _Footer extends ConsumerWidget {
  const _Footer({required this.order});

  final CourierOrder order;

  Future<void> _delivered(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CourierOrder? done = await showDeliveredSheet(context, order: order);
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
    final CourierOrder? done = await showNotDeliveredSheet(
      context,
      order: order,
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
    final CourierStage stage = courierStage(order);
    final MutationState state = ref.watch(courierOrderActionProvider(order.id));
    final CourierOrderController actions = ref.read(
      courierOrderActionProvider(order.id).notifier,
    );
    final bool outcomeBusy = ref.watch(courierOutcomeProvider(order.id)).isBusy;
    final bool unanswered =
        ref.watch(unansweredHandoverProvider(order.id)) != null;
    // Only the running action holds the buttons: a tap on the order as it
    // was repeats harmlessly, and the periodic refresh never holds them.
    final bool busy = state.isBusy;
    final ApiFailure? failure = state.failure;
    // A start refused because a cancellation request now waits (`docs/09`
    // section 37) says nothing of its own: the order loaded again says so
    // while the request waits, and once an Operator has decided it, no
    // stale "do not set off" stands beside a start offered again.
    final bool heldByRequest =
        failure is ApiRefusal &&
        failure.code == 'delivery_state_conflict' &&
        failure.error.details['reason'] == 'cancellation_request_pending';

    final Widget? step;
    if (order.canAccept) {
      step = KitFooterButton(
        buttonKey: 'courier-accept',
        icon: Icons.check,
        label: l10n.courierAccept,
        busy: busy,
        onPressed: busy ? null : actions.accept,
      );
    } else if (stage == CourierStage.accepted && order.canStart) {
      step = KitFooterButton(
        buttonKey: 'courier-start',
        icon: Icons.directions_car_outlined,
        label: l10n.courierStart,
        busy: busy,
        onPressed: busy ? null : actions.start,
      );
    } else if (stage == CourierStage.accepted &&
        order.cancellationRequestPending) {
      step = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.courierWaitOperator,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: KitColors.muted),
            ),
          ),
          KitFooterButton(
            buttonKey: 'courier-start',
            icon: Icons.directions_car_outlined,
            label: l10n.courierStart,
            busy: false,
            onPressed: null,
          ),
        ],
      );
    } else if (stage == CourierStage.onTheWay &&
        order.assignment.deliveryStartedAt != null) {
      final Widget delivered = FilledButton.icon(
        key: const ValueKey<String>('courier-delivered'),
        style: kitFilled(),
        icon: Icon(unanswered ? Icons.refresh : Icons.check),
        label: Text(
          unanswered ? l10n.courierDeliveredAgain : l10n.courierDelivered,
        ),
        onPressed: outcomeBusy ? null : () => _delivered(context),
      );
      // After a handover without a sure answer, only the handover goes:
      // it may have completed the order.
      step = unanswered
          ? delivered
          : KitActionPair(
              secondary: OutlinedButton(
                key: const ValueKey<String>('courier-not-delivered'),
                style: kitOutlined(foreground: KitColors.danger),
                onPressed: outcomeBusy ? null : () => _notDelivered(context),
                child: Text(
                  l10n.courierNotDelivered,
                  textAlign: TextAlign.center,
                ),
              ),
              primary: delivered,
            );
    } else {
      step = null;
    }
    if (step == null) {
      return const SizedBox.shrink();
    }

    return KitFooter(
      key: const ValueKey<String>('courier-order-footer'),
      children: <Widget>[FailureMessage(heldByRequest ? null : failure), step],
    );
  }
}

/// What the last handover answered, when the delivery can no longer be
/// read.
class _UnansweredFailure extends ConsumerWidget {
  const _UnansweredFailure({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MutationState state = ref.watch(courierOutcomeProvider(orderId));

    return CashMismatchOr(failure: state.failure);
  }
}

/// A handover whose answer was lost, when the delivery can no longer be
/// read: it is sent again as it was, under its key.
class _UnansweredFooter extends ConsumerWidget {
  const _UnansweredFooter({required this.orderId});

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

    return KitFooter(
      key: const ValueKey<String>('courier-order-footer'),
      children: <Widget>[
        KitFooterButton(
          buttonKey: 'courier-delivered-again',
          icon: Icons.refresh,
          label: l10n.courierDeliveredAgain,
          busy: state.isBusy,
          onPressed: () => _again(context, ref),
        ),
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

    return KitEmptyState(
      key: const ValueKey<String>('courier-order-gone'),
      icon: Icons.assignment_return_outlined,
      title: l10n.courierOrderGone,
      text: l10n.courierOrderGoneHint,
      actionLabel: l10n.courierBack,
      actionKey: const ValueKey<String>('courier-order-gone-back'),
      onAction: () => context.go(AppPaths.courier),
    );
  }
}
