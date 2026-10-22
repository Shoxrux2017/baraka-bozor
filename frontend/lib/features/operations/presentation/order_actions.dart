import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/session/staff_account.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_dialog.dart';
import '../../../core/widgets/kit/kit_fields.dart';
import '../../admin/presentation/catalog_form_rules.dart';
import '../../auth/domain/app_user.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_widgets.dart';

/// The longest note or reason the server keeps on an action (`docs/09`
/// sections 40, 41 and 45).
const int _noteMax = 300;

/// A question put to the Customer, with its proposal, its timers and how it
/// ended, and the way to remove its line once it expired unanswered while
/// the order is still shopped (`BR-APP-007`, `DL-68`).
class ApprovalTile extends ConsumerWidget {
  const ApprovalTile({required this.order, required this.approval, super.key});

  final BoardOrder order;
  final BoardApproval approval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final BoardApproval approval = this.approval;
    final BoardItem item = order.item(approval.itemId)!;
    final String name = _name(language, item.nameUz, item.nameRu);
    final NamedProduct? replacement = approval.replacement;
    final int? price = approval.proposedCustomerUnitPriceUzs;
    final String? quantity = approval.proposedQuantity;
    final DateTime? resolvedAt = approval.resolvedAt;
    final PersonRef? resolvedBy = approval.resolvedBy;
    final bool removable =
        approval.awaitsRemoval && order.status == OrderStatus.shopping;

    final bool pending = approval.status == ApprovalStatus.pending;
    final Color ground = approval.awaitsRemoval
        ? KitColors.dangerWash
        : pending
        ? KitColors.warningWash
        : Colors.white;
    final Color outline = approval.awaitsRemoval
        ? KitColors.danger
        : pending
        ? KitColors.warning
        : KitColors.line;
    final (Color tagGround, Color tagText) = switch (approval.status) {
      ApprovalStatus.pending => (KitColors.warningSoft, KitColors.warningDark),
      ApprovalStatus.approved => (KitColors.primaryWash, KitColors.primaryDark),
      ApprovalStatus.expired => (KitColors.dangerWash, KitColors.dangerDark),
      ApprovalStatus.rejected ||
      ApprovalStatus.cancelled => (KitColors.line, KitColors.ink2),
    };
    const TextStyle body = TextStyle(fontSize: 13, color: KitColors.ink);
    const TextStyle small = TextStyle(fontSize: 12, color: KitColors.muted);

    return Container(
      key: ValueKey<String>('approval-${approval.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: outline,
          width: pending || approval.awaitsRemoval ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  '${OrderLabels.approvalType(l10n, approval.type)} · $name',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tagGround,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Text(
                      OrderLabels.approvalStatus(l10n, approval.status),
                      key: ValueKey<String>('approval-status-${approval.id}'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tagText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (replacement != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.approvalReplacement(
                  _name(language, replacement.nameUz, replacement.nameRu),
                ),
                style: body,
              ),
            ),
          if (price != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.approvalProposedPrice(
                  MoneyFormat.uzs(price, language),
                  MoneyFormat.uzs(
                    approval.proposedActualMarketPriceUzs!,
                    language,
                  ),
                ),
                key: ValueKey<String>('approval-proposal-${approval.id}'),
                style: body,
              ),
            ),
          if (quantity != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.approvalProposedQuantity(
                  '${QuantityRules.display(quantity)} ${CatalogLabels.unit(l10n, item.unit)}',
                ),
                key: ValueKey<String>('approval-proposal-${approval.id}'),
                style: body,
              ),
            ),
          if (approval.requestNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.itemNote(approval.requestNote!), style: body),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              children: <Widget>[
                Text(
                  l10n.approvalAskedBy(
                    nameOf(l10n, approval.requestedBy),
                    TashkentTime.format(approval.createdAt),
                  ),
                  style: small,
                ),
                Text(
                  l10n.approvalTimers(
                    TashkentTime.format(approval.attentionAt),
                    TashkentTime.format(approval.expiresAt),
                  ),
                  key: ValueKey<String>('approval-timers-${approval.id}'),
                  style: small,
                ),
              ],
            ),
          ),
          if (resolvedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                resolvedBy == null
                    ? l10n.approvalClosedAt(TashkentTime.format(resolvedAt))
                    : l10n.approvalResolvedBy(
                        nameOf(l10n, resolvedBy),
                        TashkentTime.format(resolvedAt),
                      ),
                style: small,
              ),
            ),
          if (approval.resolution == ApprovalResolution.removeItem)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l10n.approvalLineRemoved, style: small),
            ),
          if (removable)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  key: ValueKey<String>('remove-expired-${approval.id}'),
                  style: kitFilled(
                    color: KitColors.danger,
                    height: 36,
                  ).copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon: const Icon(
                    Icons.remove_shopping_cart_outlined,
                    size: 18,
                  ),
                  label: Text(l10n.removeExpiredLine),
                  onPressed: _reloading(ref, order)
                      ? null
                      : () => OrderActionDialog.show(
                          context,
                          title: l10n.removeExpiredTitle(name),
                          subtitle: orderDialogLine(l10n, order),
                          orderId: order.id,
                          explanation: l10n.removeExpiredExplained,
                          confirm: l10n.removeExpiredLine,
                          confirmIcon: Icons.remove_shopping_cart,
                          destructive: true,
                          act: (OrderActionController actions, String? note) =>
                              actions.removeExpiredLine(approval.id, note),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A request to cancel the order, and for a pending one the Operator's or
/// the Admin's decision (`docs/09` section 40, `DL-68`).
class CancellationRequestTile extends ConsumerWidget {
  const CancellationRequestTile({
    required this.order,
    required this.request,
    super.key,
  });

  final BoardOrder order;
  final BoardCancellationRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardCancellationRequest request = this.request;
    final DateTime? resolvedAt = request.resolvedAt;
    final PersonRef? resolvedBy = request.resolvedBy;
    final bool reloading = _reloading(ref, order);

    void decide(CancellationDecision decision) {
      final bool approve = decision == CancellationDecision.approve;
      OrderActionDialog.show(
        context,
        title: approve ? l10n.approveRequestTitle : l10n.rejectRequestTitle,
        subtitle: orderDialogLine(l10n, order),
        orderId: order.id,
        quote: request.reason == null
            ? null
            : l10n.requestCustomerReason(request.reason!),
        explanation: approve
            ? l10n.approveRequestExplained
            : l10n.rejectRequestExplained,
        confirm: approve ? l10n.approveRequest : l10n.rejectRequest,
        destructive: approve,
        act: (OrderActionController actions, String? note) =>
            actions.decide(request.id, decision, note),
      );
    }

    final bool pending = request.status == CancellationRequestStatus.pending;
    const TextStyle line = TextStyle(fontSize: 13, color: KitColors.ink2);

    return Column(
      key: ValueKey<String>('request-${request.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              OrderLabels.requestOrigin(l10n, request.origin),
              style: line.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('·', style: line),
            Text(
              l10n.requestFiledBy(
                nameOf(l10n, request.requestedBy),
                TashkentTime.format(request.createdAt),
              ),
              style: line,
            ),
            const SizedBox(width: 2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: switch (request.status) {
                  CancellationRequestStatus.pending => KitColors.warningWash,
                  CancellationRequestStatus.approved => KitColors.primaryWash,
                  _ => KitColors.field,
                },
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  OrderLabels.requestStatus(l10n, request.status),
                  key: ValueKey<String>('request-status-${request.id}'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: switch (request.status) {
                      CancellationRequestStatus.pending =>
                        KitColors.warningDark,
                      CancellationRequestStatus.approved =>
                        KitColors.primaryDark,
                      _ => KitColors.muted,
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          request.reason == null
              ? l10n.orderCustomerErased
              : l10n.requestReason(request.reason!),
          style: line,
        ),
        if (resolvedAt != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            resolvedBy == null
                ? l10n.requestClosedAt(TashkentTime.format(resolvedAt))
                : l10n.requestDecidedBy(
                    nameOf(l10n, resolvedBy),
                    TashkentTime.format(resolvedAt),
                  ),
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
        ],
        if (request.resolutionNote != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            l10n.itemNote(request.resolutionNote!),
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
        ],
        if (pending)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ButtonPair(
              first: OutlinedButton(
                key: ValueKey<String>('reject-request-${request.id}'),
                style: kitOutlined(height: 40)
                    .copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: reloading
                    ? null
                    : () => decide(CancellationDecision.reject),
                child: Text(l10n.rejectRequest),
              ),
              second: FilledButton(
                key: ValueKey<String>('approve-request-${request.id}'),
                style: kitFilled(
                  color: KitColors.danger,
                  height: 40,
                ).copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: reloading
                    ? null
                    : () => decide(CancellationDecision.approve),
                child: Text(l10n.approveRequest),
              ),
            ),
          ),
      ],
    );
  }
}

/// Two buttons side by side, each half the width; past large text, stacked
/// with the second first.
class _ButtonPair extends StatelessWidget {
  const _ButtonPair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (kitLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[second, const SizedBox(height: 10), first],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }
}

/// The way to cancel an order its latest delivery failed, while no request
/// asks for the same (`docs/09` section 41, `DL-68`).
class FailedDeliveryCancel extends ConsumerWidget {
  const FailedDeliveryCancel({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!order.cancellableAfterFailedDelivery) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      key: const ValueKey<String>('cancel-failed-delivery'),
      style: kitOutlined(foreground: KitColors.dangerDark, height: 44).copyWith(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: KitColors.danger),
        ),
      ),
      icon: const Icon(Icons.cancel_outlined, size: 20),
      label: Text(l10n.cancelFailedDelivery),
      onPressed: _reloading(ref, order)
          ? null
          : () => OrderActionDialog.show(
              context,
              title: l10n.cancelFailedDeliveryTitle,
              subtitle: orderDialogLine(l10n, order),
              orderId: order.id,
              explanation: l10n.cancelFailedDeliveryExplained,
              confirm: l10n.cancelFailedDelivery,
              destructive: true,
              act: (OrderActionController actions, String? note) =>
                  actions.cancelAfterFailedDelivery(note),
            ),
    );
  }
}

/// The Admin's way to correct the price paid for a bought line billed from
/// it; the Operator is not offered it (`docs/09` section 45, `DL-66`).
class PriceCorrectionButton extends ConsumerWidget {
  const PriceCorrectionButton({
    required this.order,
    required this.item,
    super.key,
  });

  final BoardOrder order;
  final BoardItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (ref.watch(staffRoleProvider) != UserRole.admin ||
        !order.pricesCorrectable ||
        !item.billedFromPricePaid) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton.icon(
        key: ValueKey<String>('correct-price-${item.id}'),
        style: TextButton.styleFrom(
          foregroundColor: KitColors.primaryDark,
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.edit, size: 14),
        label: Text(l10n.correctPrice),
        onPressed: _reloading(ref, order)
            ? null
            : () => PriceCorrectionDialog.show(context, order, item),
      ),
    );
  }
}

/// The order's payment: how much, when and whom it was paid to, or that
/// none is recorded yet.
class PaymentDetails extends StatelessWidget {
  const PaymentDetails({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final BoardPayment? payment = order.payment;
    if (payment == null) {
      return Text(
        l10n.paymentNone,
        key: const ValueKey<String>('payment'),
        style: const TextStyle(fontSize: 13, color: KitColors.muted),
      );
    }
    final DateTime? paidAt = payment.paidAt;
    final PersonRef? recordedBy = payment.recordedBy;

    /// A row of the card: the text as the arb words it, `label: value`, the
    /// label muted and the value heavier.
    Widget row(String text) {
      final int split = text.indexOf(': ');
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: split < 0 ? text : text.substring(0, split + 2),
                style: const TextStyle(color: KitColors.ink2),
              ),
              if (split >= 0)
                TextSpan(
                  text: text.substring(split + 2),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 13, color: KitColors.ink),
        ),
      );
    }

    return Column(
      key: const ValueKey<String>('payment'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        row(l10n.paymentAmount(MoneyFormat.uzs(payment.amountUzs, language))),
        if (paidAt != null)
          row(l10n.paymentPaidAt(TashkentTime.format(paidAt))),
        if (recordedBy != null)
          row(l10n.paymentRecordedBy(nameOf(l10n, recordedBy))),
      ],
    );
  }
}

/// The line under a window's title: the order's number and its Customer's
/// name, the number alone once the Customer is erased.
String orderDialogLine(AppLocalizations l10n, BoardOrder order) {
  final String? name = order.customerErased ? null : order.customer.fullName;
  final String number = '${order.orderNumber}';

  return name == null
      ? l10n.orderTitle(number)
      : l10n.dialogOrderLine(number, name);
}

/// The two buttons a window ends with: "Cancel" outlined and the confirming
/// button, a red one when the action [destructive]ly cancels or removes.
Widget _dialogButtons({
  required BuildContext context,
  required bool busy,
  required Key confirmKey,
  required String confirm,
  required VoidCallback submit,
  IconData? confirmIcon,
  bool destructive = false,
}) {
  final ButtonStyle style = kitFilled(
    color: destructive ? KitColors.danger : KitColors.primary,
    height: 48,
  );
  final VoidCallback? onPressed = busy ? null : submit;

  return KitActionPair(
    secondary: OutlinedButton(
      key: const ValueKey<String>('action-cancel'),
      style: kitOutlined(height: 48),
      onPressed: busy ? null : () => Navigator.of(context).pop(),
      child: Text(AppLocalizations.of(context).cancelButton),
    ),
    primary: confirmIcon == null
        ? FilledButton(
            key: confirmKey,
            style: style,
            onPressed: onPressed,
            child: Text(confirm),
          )
        : FilledButton.icon(
            key: confirmKey,
            style: style,
            onPressed: onPressed,
            icon: Icon(confirmIcon, size: 20),
            label: Text(confirm),
          ),
  );
}

/// A `field` box with rounded corners that holds a short fact of the window.
Widget _factBox(Widget child) => DecoratedBox(
  decoration: BoxDecoration(
    color: KitColors.field,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: child,
  ),
);

const TextStyle _factText = TextStyle(
  fontSize: 13,
  color: KitColors.ink,
  height: 1.5,
);

/// `label: value` as the arb words it, the label plain and the value heavier.
Widget _labelledLine(String text) {
  final int split = text.indexOf(': ');

  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: split < 0 ? text : text.substring(0, split + 2)),
        if (split >= 0)
          TextSpan(
            text: text.substring(split + 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
      ],
    ),
    style: _factText,
  );
}

/// The Customer's words with the quoted part heavier.
Widget _quoted(String text) {
  final int split = text.indexOf('«');

  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: split < 0 ? text : text.substring(0, split)),
        if (split >= 0)
          TextSpan(
            text: text.substring(split),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
      ],
    ),
    style: _factText,
  );
}

/// A confirmation of one action on an order, with an optional note the
/// server keeps (`docs/09` sections 40 and 41), in the kit's window
/// ([show]). It stays open while the action runs, says a refusal in its own
/// words, and closes once the server has done it (`DL-28` (10), `DL-68`).
class OrderActionDialog extends ConsumerStatefulWidget {
  const OrderActionDialog({
    required this.orderId,
    required this.explanation,
    required this.confirm,
    required this.act,
    this.quote,
    this.confirmIcon,
    this.destructive = false,
    super.key,
  });

  /// Opens the window: [title] with [subtitle] under it, then the body.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String orderId,
    required String explanation,
    required String confirm,
    required Future<BoardOrder?> Function(
      OrderActionController actions,
      String? note,
    )
    act,
    String? quote,
    IconData? confirmIcon,
    bool destructive = false,
  }) {
    return showKitDialog<void>(
      context: context,
      dialogKey: 'order-action',
      title: title,
      subtitle: subtitle,
      builder: (BuildContext context) => OrderActionDialog(
        orderId: orderId,
        explanation: explanation,
        confirm: confirm,
        act: act,
        quote: quote,
        confirmIcon: confirmIcon,
        destructive: destructive,
      ),
    );
  }

  final String orderId;
  final String explanation;
  final String confirm;

  /// What the Customer said, shown in a box above the explanation.
  final String? quote;
  final IconData? confirmIcon;

  /// The action cancels the order or removes a product: its button is red.
  final bool destructive;

  /// Runs the action with the note, `null` when there is none; the order
  /// the server answers, or `null` when it did not act.
  final Future<BoardOrder?> Function(
    OrderActionController actions,
    String? note,
  )
  act;

  @override
  ConsumerState<OrderActionDialog> createState() => _OrderActionDialogState();
}

class _OrderActionDialogState extends ConsumerState<OrderActionDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final BoardOrder? done = await widget.act(
      ref.read(orderActionProvider(widget.orderId).notifier),
      _optional(_note.text),
    );
    if (mounted && done != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(orderActionProvider(widget.orderId));
    final String? quote = widget.quote;

    return PopScope(
      canPop: !change.isBusy,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (quote != null) ...<Widget>[
              _factBox(_quoted(quote)),
              const SizedBox(height: 14),
            ],
            Text(
              widget.explanation,
              style: const TextStyle(
                fontSize: 13,
                color: KitColors.ink2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            KitNoteField(
              fieldKey: 'action-note',
              controller: _note,
              label: l10n.actionNote,
              hint: '',
              enabled: !change.isBusy,
            ),
            FailureMessage(change.failure),
            const SizedBox(height: 20),
            _dialogButtons(
              context: context,
              busy: change.isBusy,
              confirmKey: const ValueKey<String>('action-confirm'),
              confirm: widget.confirm,
              submit: _submit,
              confirmIcon: widget.confirmIcon,
              destructive: widget.destructive,
            ),
          ],
        ),
      ),
    );
  }
}

/// The Admin's price correction of one bought line: the new price paid per
/// unit and the reason, both required. A price whose customer price would
/// pass the line's bound is refused with the bound, said in the window
/// (`docs/09` section 45, `DL-66`).
class PriceCorrectionDialog extends ConsumerStatefulWidget {
  const PriceCorrectionDialog({
    required this.order,
    required this.item,
    super.key,
  });

  /// Opens the correction window of [item].
  static Future<void> show(
    BuildContext context,
    BoardOrder order,
    BoardItem item,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final NamedProduct? replacement = item.replacement;
    final String name = replacement == null
        ? _name(language, item.nameUz, item.nameRu)
        : _name(language, replacement.nameUz, replacement.nameRu);

    return showKitDialog<void>(
      context: context,
      dialogKey: 'price-correction',
      title: l10n.correctPriceTitle(name),
      subtitle: orderDialogLine(l10n, order),
      builder: (BuildContext context) =>
          PriceCorrectionDialog(order: order, item: item),
    );
  }

  final BoardOrder order;
  final BoardItem item;

  @override
  ConsumerState<PriceCorrectionDialog> createState() =>
      _PriceCorrectionDialogState();
}

class _PriceCorrectionDialogState extends ConsumerState<PriceCorrectionDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final BoardOrder? done = await ref
        .read(orderActionProvider(widget.order.id).notifier)
        .correctPrice(
          widget.item.id,
          CatalogFormRules.marketPriceValue(_price.text),
          trimLikeServer(_reason.text),
        );
    if (mounted && done != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState change = ref.watch(
      orderActionProvider(widget.order.id),
    );
    final BoardItem item = widget.item;
    final int? paid = item.actualMarketPriceUzs;
    final InputDecoration plain = kitFieldDecoration();
    final InputDecoration priceDecoration = _ceilingOf(change.failure) != null
        ? plain.copyWith(
            enabledBorder: plain.errorBorder,
            focusedBorder: plain.errorBorder,
          )
        : plain;
    const TextStyle fieldText = TextStyle(fontSize: 15, color: KitColors.ink);

    return PopScope(
      canPop: !change.isBusy,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _factBox(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (paid != null)
                    _labelledLine(
                      l10n.itemPricePaid(MoneyFormat.uzs(paid, language)),
                    ),
                  _labelledLine(
                    l10n.itemBilledPrice(
                      MoneyFormat.uzs(item.billableUnitPriceUzs!, language),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KitLabeledField(
              label: l10n.correctPriceNew,
              field: TextFormField(
                key: const ValueKey<String>('correction-price'),
                controller: _price,
                enabled: !change.isBusy,
                keyboardType: TextInputType.number,
                style: fieldText,
                decoration: priceDecoration,
                validator: (String? text) =>
                    CatalogFormRules.marketPrice(l10n, text ?? ''),
              ),
            ),
            const SizedBox(height: 16),
            KitLabeledField(
              label: l10n.correctPriceReason,
              field: TextFormField(
                key: const ValueKey<String>('correction-reason'),
                controller: _reason,
                enabled: !change.isBusy,
                minLines: 1,
                maxLines: 3,
                style: fieldText,
                decoration: plain,
                validator: (String? text) => _optional(text ?? '') == null
                    ? l10n.fieldRequired
                    : _tooLong(l10n, text ?? ''),
              ),
            ),
            _CorrectionFailure(change.failure),
            const SizedBox(height: 20),
            _dialogButtons(
              context: context,
              busy: change.isBusy,
              confirmKey: const ValueKey<String>('correction-save'),
              confirm: l10n.saveButton,
              submit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The bound a refused correction names, `null` for any other outcome.
int? _ceilingOf(ApiFailure? failure) {
  if (failure is ApiRefusal &&
      failure.code == 'price_correction_above_ceiling') {
    final Object? ceiling =
        failure.error.details['ceiling_customer_unit_price_uzs'];
    if (ceiling is int) {
      return ceiling;
    }
  }

  return null;
}

/// A refused correction, saying the bound when the price passed it.
class _CorrectionFailure extends StatelessWidget {
  const _CorrectionFailure(this.failure);

  final ApiFailure? failure;

  @override
  Widget build(BuildContext context) {
    final int? ceiling = _ceilingOf(failure);
    if (ceiling == null) {
      return FailureMessage(failure);
    }

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error, size: 16, color: KitColors.danger),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                AppLocalizations.of(context).errorPriceAboveCeiling(
                  MoneyFormat.uzs(ceiling, interfaceLanguage(context)),
                ),
                key: const ValueKey<String>('failure-message'),
                style: const TextStyle(
                  fontSize: 12,
                  color: KitColors.danger,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether the order is being loaded again after a change; until it has
/// arrived, a button would act on the order as it was.
bool _reloading(WidgetRef ref, BoardOrder order) =>
    ref.watch(boardOrderProvider(order.id)).isLoading;

String _name(AppLanguage language, String uz, String ru) =>
    language == AppLanguage.ru ? ru : uz;

/// The text of an optional field as the server keeps it, `null` when blank.
String? _optional(String text) {
  final String value = trimLikeServer(text);
  return value.isEmpty ? null : value;
}

String? _tooLong(AppLocalizations l10n, String text) =>
    trimLikeServer(text).runes.length > _noteMax
    ? l10n.fieldTooLong(_noteMax)
    : null;

/// Only 1 to 3 stars lead to a call to the Customer (`DL-90` item 1).
const int _lowRatingMaxStars = 3;

/// Whether the order's rating waits for somebody to call the Customer: low,
/// and not yet reviewed.
bool ratingWaits(OrderRating rating) =>
    rating.stars <= _lowRatingMaxStars &&
    !(rating.reviewedAt != null && rating.reviewedBy != null);

/// The Customer's rating of the order — stars, reasons and comment — with
/// the way to mark it dealt with until somebody did, and then who did and
/// when (`docs/09` sections 59 and 60, `DL-91`).
class RatingDetails extends ConsumerWidget {
  const RatingDetails({required this.order, required this.rating, super.key});

  final BoardOrder order;
  final OrderRating rating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(orderActionProvider(order.id));
    final bool busy = change.isBusy || _reloading(ref, order);
    final DateTime? reviewedAt = rating.reviewedAt;
    final PersonRef? reviewedBy = rating.reviewedBy;
    final String? comment = rating.comment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: <Widget>[
              Semantics(
                label: l10n.ratingStars(rating.stars),
                excludeSemantics: true,
                child: Row(
                  key: const ValueKey<String>('rating-stars'),
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int star = 1; star <= 5; star++)
                      Icon(
                        Icons.star,
                        size: 22,
                        color: star <= rating.stars
                            ? KitColors.star
                            : KitColors.line,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.ratingStars(rating.stars),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (rating.reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                for (final RatingReason reason in rating.reasons)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.dangerWash,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        OrderLabels.ratingReason(l10n, reason),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: KitColors.dangerDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (comment != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.format_quote,
                      size: 16,
                      color: KitColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        comment,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (reviewedAt != null && reviewedBy != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: KitColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.ratingReviewed(
                      nameOf(l10n, reviewedBy),
                      TashkentTime.format(reviewedAt),
                    ),
                    key: const ValueKey<String>('rating-reviewed'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KitColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (rating.stars <= _lowRatingMaxStars)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton.icon(
              key: const ValueKey<String>('rating-review'),
              style: kitFilled(height: 44)
                  .copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.phone_callback_outlined, size: 20),
              label: Text(l10n.ratingReview),
              onPressed: busy
                  ? null
                  : () => ref
                        .read(orderActionProvider(order.id).notifier)
                        .reviewRating(),
            ),
          ),
        FailureMessage(change.failure),
      ],
    );
  }
}
