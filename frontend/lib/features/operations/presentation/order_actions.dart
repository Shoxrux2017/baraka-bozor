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
import '../../../core/session/staff_account.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
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

    return ListTile(
      key: ValueKey<String>('approval-${approval.id}'),
      contentPadding: EdgeInsets.zero,
      title: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text('${OrderLabels.approvalType(l10n, approval.type)} · $name'),
          Text(
            OrderLabels.approvalStatus(l10n, approval.status),
            key: ValueKey<String>('approval-status-${approval.id}'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (replacement != null)
            Text(
              l10n.approvalReplacement(
                _name(language, replacement.nameUz, replacement.nameRu),
              ),
            ),
          if (price != null)
            Text(
              l10n.approvalProposedPrice(
                MoneyFormat.uzs(price, language),
                MoneyFormat.uzs(
                  approval.proposedActualMarketPriceUzs!,
                  language,
                ),
              ),
              key: ValueKey<String>('approval-proposal-${approval.id}'),
            ),
          if (quantity != null)
            Text(
              l10n.approvalProposedQuantity(
                '$quantity ${CatalogLabels.unit(l10n, item.unit)}',
              ),
              key: ValueKey<String>('approval-proposal-${approval.id}'),
            ),
          if (approval.requestNote != null)
            Text(l10n.itemNote(approval.requestNote!)),
          Text(
            l10n.approvalAskedBy(
              nameOf(l10n, approval.requestedBy),
              TashkentTime.format(approval.createdAt),
            ),
          ),
          Text(
            l10n.approvalTimers(
              TashkentTime.format(approval.attentionAt),
              TashkentTime.format(approval.expiresAt),
            ),
            key: ValueKey<String>('approval-timers-${approval.id}'),
          ),
          if (resolvedAt != null)
            Text(
              resolvedBy == null
                  ? l10n.approvalClosedAt(TashkentTime.format(resolvedAt))
                  : l10n.approvalResolvedBy(
                      nameOf(l10n, resolvedBy),
                      TashkentTime.format(resolvedAt),
                    ),
            ),
          if (approval.resolution == ApprovalResolution.removeItem)
            Text(l10n.approvalLineRemoved),
          if (removable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: ValueKey<String>('remove-expired-${approval.id}'),
                  icon: const Icon(Icons.remove_shopping_cart_outlined),
                  label: Text(l10n.removeExpiredLine),
                  onPressed: _reloading(ref, order)
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (BuildContext context) => OrderActionDialog(
                            orderId: order.id,
                            title: l10n.removeExpiredTitle(name),
                            explanation: l10n.removeExpiredExplained,
                            confirm: l10n.removeExpiredLine,
                            act: (
                              OrderActionController actions,
                              String? note,
                            ) => actions.removeExpiredLine(approval.id, note),
                          ),
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
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => OrderActionDialog(
          orderId: order.id,
          title: approve ? l10n.approveRequestTitle : l10n.rejectRequestTitle,
          explanation: approve
              ? l10n.approveRequestExplained
              : l10n.rejectRequestExplained,
          confirm: approve ? l10n.approveRequest : l10n.rejectRequest,
          act: (OrderActionController actions, String? note) =>
              actions.decide(request.id, decision, note),
        ),
      );
    }

    return ListTile(
      key: ValueKey<String>('request-${request.id}'),
      contentPadding: EdgeInsets.zero,
      title: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(OrderLabels.requestOrigin(l10n, request.origin)),
          Text(
            OrderLabels.requestStatus(l10n, request.status),
            key: ValueKey<String>('request-status-${request.id}'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.requestReason(request.reason)),
          Text(
            l10n.requestFiledBy(
              nameOf(l10n, request.requestedBy),
              TashkentTime.format(request.createdAt),
            ),
          ),
          if (resolvedAt != null)
            Text(
              resolvedBy == null
                  ? l10n.requestClosedAt(TashkentTime.format(resolvedAt))
                  : l10n.requestDecidedBy(
                      nameOf(l10n, resolvedBy),
                      TashkentTime.format(resolvedAt),
                    ),
            ),
          if (request.resolutionNote != null)
            Text(l10n.itemNote(request.resolutionNote!)),
          if (request.status == CancellationRequestStatus.pending)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton(
                    key: ValueKey<String>('approve-request-${request.id}'),
                    onPressed: reloading
                        ? null
                        : () => decide(CancellationDecision.approve),
                    child: Text(l10n.approveRequest),
                  ),
                  OutlinedButton(
                    key: ValueKey<String>('reject-request-${request.id}'),
                    onPressed: reloading
                        ? null
                        : () => decide(CancellationDecision.reject),
                    child: Text(l10n.rejectRequest),
                  ),
                ],
              ),
            ),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: const ValueKey<String>('cancel-failed-delivery'),
          icon: const Icon(Icons.cancel_outlined),
          label: Text(l10n.cancelFailedDelivery),
          onPressed: _reloading(ref, order)
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (BuildContext context) => OrderActionDialog(
                    orderId: order.id,
                    title: l10n.cancelFailedDeliveryTitle,
                    explanation: l10n.cancelFailedDeliveryExplained,
                    confirm: l10n.cancelFailedDelivery,
                    act: (OrderActionController actions, String? note) =>
                        actions.cancelAfterFailedDelivery(note),
                  ),
                ),
        ),
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
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: ValueKey<String>('correct-price-${item.id}'),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.correctPrice),
        onPressed: _reloading(ref, order)
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (BuildContext context) =>
                    PriceCorrectionDialog(order: order, item: item),
              ),
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
      return Text(l10n.paymentNone, key: const ValueKey<String>('payment'));
    }
    final DateTime? paidAt = payment.paidAt;
    final PersonRef? recordedBy = payment.recordedBy;

    return Column(
      key: const ValueKey<String>('payment'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${OrderLabels.paymentMethod(l10n, payment.method)} · '
          '${OrderLabels.paymentStatus(l10n, payment.status)}',
        ),
        Text(l10n.paymentAmount(MoneyFormat.uzs(payment.amountUzs, language))),
        if (paidAt != null)
          Text(l10n.paymentPaidAt(TashkentTime.format(paidAt))),
        if (recordedBy != null)
          Text(l10n.paymentRecordedBy(nameOf(l10n, recordedBy))),
      ],
    );
  }
}

/// A confirmation of one action on an order, with an optional note the
/// server keeps (`docs/09` sections 40 and 41). It stays open while the
/// action runs, says a refusal in its own words, and closes once the server
/// has done it (`DL-28` (13), `DL-68`).
class OrderActionDialog extends ConsumerStatefulWidget {
  const OrderActionDialog({
    required this.orderId,
    required this.title,
    required this.explanation,
    required this.confirm,
    required this.act,
    super.key,
  });

  final String orderId;
  final String title;
  final String explanation;
  final String confirm;

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

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        scrollable: true,
        title: Text(widget.title),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(widget.explanation),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey<String>('action-note'),
                  controller: _note,
                  enabled: !change.isBusy,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.actionNote,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? text) => _tooLong(l10n, text ?? ''),
                ),
                FailureMessage(change.failure),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('action-cancel'),
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('action-confirm'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(widget.confirm),
          ),
        ],
      ),
    );
  }
}

/// The Admin's price correction of one bought line: the new price paid per
/// unit and the reason, both required. A price whose customer price would
/// pass the line's bound is refused with the bound, said in the dialog
/// (`docs/09` section 45, `DL-66`).
class PriceCorrectionDialog extends ConsumerStatefulWidget {
  const PriceCorrectionDialog({
    required this.order,
    required this.item,
    super.key,
  });

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
    final NamedProduct? replacement = item.replacement;
    final String name = replacement == null
        ? _name(language, item.nameUz, item.nameRu)
        : _name(language, replacement.nameUz, replacement.nameRu);
    final int? paid = item.actualMarketPriceUzs;

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.correctPriceTitle(name)),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (paid != null)
                  Text(l10n.itemPricePaid(MoneyFormat.uzs(paid, language))),
                Text(
                  l10n.itemBilledPrice(
                    MoneyFormat.uzs(item.billableUnitPriceUzs!, language),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey<String>('correction-price'),
                  controller: _price,
                  enabled: !change.isBusy,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.correctPriceNew,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? text) =>
                      CatalogFormRules.marketPrice(l10n, text ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('correction-reason'),
                  controller: _reason,
                  enabled: !change.isBusy,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.correctPriceReason,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? text) => _optional(text ?? '') == null
                      ? l10n.fieldRequired
                      : _tooLong(l10n, text ?? ''),
                ),
                _CorrectionFailure(change.failure),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('action-cancel'),
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('correction-save'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}

/// A refused correction, saying the bound when the price passed it.
class _CorrectionFailure extends StatelessWidget {
  const _CorrectionFailure(this.failure);

  final ApiFailure? failure;

  @override
  Widget build(BuildContext context) {
    final ApiFailure? failure = this.failure;
    if (failure is ApiRefusal &&
        failure.code == 'price_correction_above_ceiling') {
      final Object? ceiling =
          failure.error.details['ceiling_customer_unit_price_uzs'];
      if (ceiling is int) {
        return Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              AppLocalizations.of(context).errorPriceAboveCeiling(
                MoneyFormat.uzs(ceiling, interfaceLanguage(context)),
              ),
              key: const ValueKey<String>('failure-message'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
      }
    }
    return FailureMessage(failure);
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
