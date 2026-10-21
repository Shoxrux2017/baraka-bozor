import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_empty_state.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit/kit_sheet.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../application/shopper_orders_controllers.dart';
import '../domain/shopper_orders.dart';
import 'shopper_line_card.dart';
import 'shopper_status_card.dart';

/// Whether a screen's load has settled on data, so its periodic refresh
/// may run (`DL-54` (15)).
bool _settled(AsyncValue<Object?> value) =>
    value.hasValue && !value.hasError && !value.isLoading;

/// One of the Shopper's orders (`docs/09` sections 28 and 29, `DL-98`): the
/// status card of its stage, the call to the Customer while the server
/// gives the phone, every line, and a footer with the next step — accept,
/// start, or complete. It keeps current while shown (`DL-54` (15)).
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
    final DateTime now = ref.watch(clockProvider)();
    // Watched here, so the requests without a sure answer last while the
    // order is shown, and a completion in flight holds the refresh, which
    // could otherwise find its order gone before the answer (`DL-70` (5)).
    final bool completionUnanswered =
        ref.watch(unansweredRequestsProvider(orderId)).completion != null;
    final bool completing = ref.watch(shopperCompleteProvider(orderId)).isBusy;

    return Scaffold(
      backgroundColor: Colors.white,
      // The page holds no text field; its sheets pad themselves for the
      // keyboard, so the page behind must not shrink under them.
      resizeToAvoidBottomInset: false,
      appBar: kitAppBar(
        title: shown == null
            ? l10n.shellShopper
            : l10n.boardOrderNumber('${shown.orderNumber}'),
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
                  data: (ShopperOrder order) =>
                      _OrderView(order: order, now: now),
                  error: (Object error, StackTrace _) {
                    // A completion whose answer was lost may have gone
                    // through, and the order with it; it is sent again under
                    // its key, which answers the completed order.
                    final bool gone =
                        error is ApiRefusal && error.status == 404;
                    if (gone && !completionUnanswered) {
                      return const _Gone();
                    }
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: <Widget>[
                        if (completionUnanswered)
                          _UnansweredCompletion(orderId: orderId),
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
  const _OrderView({required this.order, required this.now});

  final ShopperOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperStage stage = shopperStage(order);
    final bool shopping = stage == ShopperStage.shopping;
    final String? phone = order.customerPhone;
    final String? wish = order.deliveryTimeNote;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            key: const ValueKey<String>('shopper-order'),
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              ShopperStatusCard(order: order, now: now),
              if (wish != null) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.schedule, size: 17, color: KitColors.ink2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.shopperDeliveryWish(wish),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (phone != null) ...<Widget>[
                const SizedBox(height: 16),
                _CallCard(phone: phone),
              ],
              if (!shopping) ...<Widget>[
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.checkoutItems(order.items.length),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                for (final ShopperLine line in order.items)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ShopperLineRow(
                      key: ValueKey<String>('shopper-line-${line.id}'),
                      line: line,
                    ),
                  ),
              ] else ...<Widget>[
                _LineGroup(
                  groupKey: 'shopper-group-buy',
                  title: l10n.shopperGroupToBuy,
                  tone: KitTone.green,
                  order: order,
                  lines: <ShopperLine>[
                    for (final ShopperLine line in order.items)
                      if (line.status == OrderItemStatus.pending) line,
                  ],
                ),
                _LineGroup(
                  groupKey: 'shopper-group-waiting',
                  title: l10n.shopperGroupWaiting,
                  tone: KitTone.amber,
                  order: order,
                  lines: <ShopperLine>[
                    for (final ShopperLine line in order.items)
                      if (line.status == OrderItemStatus.awaitingCustomer) line,
                  ],
                ),
                _LineGroup(
                  groupKey: 'shopper-group-done',
                  title: l10n.shopperGroupDone,
                  tone: KitTone.grey,
                  order: order,
                  lines: <ShopperLine>[
                    for (final ShopperLine line in order.items)
                      if (line.status == OrderItemStatus.purchased ||
                          line.status == OrderItemStatus.removed)
                        line,
                  ],
                ),
              ],
              if (stage == ShopperStage.assigned ||
                  stage == ShopperStage.accepted) ...<Widget>[
                const SizedBox(height: 16),
                KitNote(
                  icon: Icons.info_outline,
                  text: Text(l10n.shopperPhoneLater),
                ),
              ],
            ],
          ),
        ),
        if (stage != ShopperStage.other) _Footer(order: order, stage: stage),
      ],
    );
  }
}

/// A group of lines under its heading with the count in a pill; nothing
/// at all when the group is empty.
class _LineGroup extends StatelessWidget {
  const _LineGroup({
    required this.groupKey,
    required this.title,
    required this.tone,
    required this.order,
    required this.lines,
  });

  final String groupKey;
  final String title;
  final KitTone tone;
  final ShopperOrder order;
  final List<ShopperLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    final ({Color wash, Color text}) pill = switch (tone) {
      KitTone.green => (
        wash: KitColors.primaryWash,
        text: KitColors.primaryDark,
      ),
      KitTone.amber => (
        wash: KitColors.warningWash,
        text: KitColors.warningDark,
      ),
      _ => (wash: KitColors.field, text: KitColors.muted),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Row(
              key: ValueKey<String>(groupKey),
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: pill.wash,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(
                      '${lines.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pill.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final ShopperLine line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: switch (line.status) {
                OrderItemStatus.pending || OrderItemStatus.awaitingCustomer =>
                  ShopperLineCard(order: order, line: line),
                _ => ShopperLineRow(
                  key: ValueKey<String>('shopper-line-${line.id}'),
                  line: line,
                ),
              },
            ),
        ],
      ),
    );
  }
}

/// The Customer's phone as a card that dials it.
class _CallCard extends ConsumerWidget {
  const _CallCard({required this.phone});

  final String phone;

  Future<void> _call(BuildContext context, WidgetRef ref) async {
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

    return InkWell(
      key: const ValueKey<String>('call-customer'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _call(context, ref),
      child: KitCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: KitColors.primarySoft,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 26,
                color: KitColors.primaryDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.shopperCallCustomer,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                  Text(
                    formatPhone(phone),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: KitColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: KitColors.primary,
              ),
              child: const Icon(Icons.call, size: 24, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// The step the server offers, pinned under the list: the acceptance, the
/// start, or the completion of the shopping.
class _Footer extends ConsumerWidget {
  const _Footer({required this.order, required this.stage});

  final ShopperOrder order;
  final ShopperStage stage;

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

    final Widget button;
    if (stage == ShopperStage.assigned) {
      button = _FooterButton(
        buttonKey: 'shopper-accept',
        icon: Icons.check,
        label: l10n.shopperAccept,
        busy: busy,
        onPressed: busy ? null : actions.accept,
      );
    } else if (stage == ShopperStage.accepted) {
      button = _FooterButton(
        buttonKey: 'shopper-start',
        icon: Icons.shopping_cart_outlined,
        label: l10n.shopperStart,
        busy: busy,
        onPressed: busy ? null : actions.start,
      );
    } else {
      button = _Complete(order: order);
    }

    return DecoratedBox(
      key: const ValueKey<String>('shopper-order-footer'),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[FailureMessage(state.failure), button],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String buttonKey;
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: ValueKey<String>(buttonKey),
      style: kitFilled(),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KitColors.muted,
              ),
            )
          : Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

/// Sends [orderId]'s completion. With [confirmFor], the order is shown in a
/// sheet first with what was bought and removed. Once done, the closing
/// screen replaces the order's page, whatever became of the widget that
/// asked (`DL-70` (8)).
Future<void> _sendCompletion(
  BuildContext context,
  WidgetRef ref,
  String orderId, {
  ShopperOrder? confirmFor,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final GoRouter router = GoRouter.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ShopperCompleteController completing = ref.read(
    shopperCompleteProvider(orderId).notifier,
  );
  if (confirmFor != null) {
    final bool? sure = await showKitSheet<bool>(
      context,
      title: l10n.completeTitle,
      sheetKey: 'complete-sheet',
      builder: (BuildContext sheet) => _CompleteSheet(order: confirmFor),
    );
    if (sure != true) {
      return;
    }
  }
  final ShopperOrder? done = await completing.complete();
  if (done == null) {
    return;
  }
  // A Shopper who left the order meanwhile is not pulled back to it; they
  // are told it is done (`frontend/AGENTS.md` section 6).
  if (router.state.uri.path == AppPaths.shopperOrder(orderId)) {
    router.go(AppPaths.shopperDone(done.orderNumber));
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.doneTitle('${done.orderNumber}'))),
    );
  }
}

/// What the completion sheet says: what was bought and what was removed, and
/// that the order leaves the Shopper's list.
class _CompleteSheet extends StatelessWidget {
  const _CompleteSheet({required this.order});

  final ShopperOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ({int toBuy, int waiting, int done, int bought, int removed}) counts =
        shopperCounts(order.items);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CountRow(
            label: l10n.shopperCompleteBought,
            value: l10n.orderItemCount(counts.bought),
          ),
          _CountRow(
            label: l10n.shopperCompleteRemoved,
            value: l10n.orderItemCount(counts.removed),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.completeExplained,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: KitColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          KitActionPair(
            secondary: OutlinedButton(
              key: const ValueKey<String>('complete-cancel'),
              style: kitOutlined(),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancelButton),
            ),
            primary: FilledButton(
              key: const ValueKey<String>('complete-confirm'),
              style: kitFilled(),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.completeConfirm),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: KitColors.ink2),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.completeUnconfirmed),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('complete-again'),
          style: kitFilled(),
          icon: const Icon(Icons.done_all),
          label: Text(l10n.completeShopping),
          onPressed: state.isBusy
              ? null
              : () => _sendCompletion(context, ref, orderId),
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

    return KitEmptyState(
      key: const ValueKey<String>('shopper-order-gone'),
      icon: Icons.assignment_return_outlined,
      title: l10n.shopperOrderGone,
      text: l10n.shopperOrderGoneHint,
      actionLabel: l10n.doneBack,
      actionKey: const ValueKey<String>('shopper-order-gone-back'),
      onAction: () => context.go(AppPaths.shopper),
    );
  }
}

/// The completion of the shopping (`docs/09` section 35), held while lines
/// are open and confirmed in a sheet first. Once done the order is no longer
/// the Shopper's, and the screen that follows tells them what to do with the
/// package. A refusal because lines are still open names them (for a page
/// older than the server).
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
    final ({int toBuy, int waiting, int done, int bought, int removed}) counts =
        shopperCounts(order.items);
    final int open = counts.toBuy + counts.waiting;
    final ApiFailure? failure = state.failure;
    final Object? openIds =
        failure is ApiRefusal && failure.code == 'shopping_incomplete'
        ? failure.error.details['item_ids']
        : null;
    final List<String> openNames = <String>[
      if (openIds is List<Object?>)
        for (final ShopperLine line in order.items)
          if (openIds.contains(line.id))
            language == AppLanguage.ru ? line.nameRu : line.nameUz,
    ];
    final bool enabled = !state.isBusy && (open == 0 || unconfirmed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (open > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.shopperResolveFirst(open),
              style: const TextStyle(fontSize: 12, color: KitColors.muted),
            ),
          ),
        if (unconfirmed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.completeUnconfirmed,
              key: const ValueKey<String>('complete-unconfirmed'),
              style: const TextStyle(fontSize: 13, color: KitColors.ink2),
            ),
          ),
        if (openNames.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.completeIncomplete(openNames.join(', ')),
              key: const ValueKey<String>('complete-open-lines'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          )
        else
          FailureMessage(failure),
        FilledButton.icon(
          key: const ValueKey<String>('shopper-complete'),
          style: kitFilled(),
          icon: state.isBusy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KitColors.muted,
                  ),
                )
              : const Icon(Icons.done_all),
          label: Text(l10n.completeShopping),
          onPressed: enabled
              ? () => _sendCompletion(
                  context,
                  ref,
                  order.id,
                  confirmFor: unconfirmed ? null : order,
                )
              : null,
        ),
      ],
    );
  }
}
