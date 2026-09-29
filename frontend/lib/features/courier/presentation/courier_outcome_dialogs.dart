import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/courier_orders_controllers.dart';
import '../domain/courier_orders.dart';

/// A refusal of a handover: when the cash was not the final total, what
/// was to be collected, from the server's own answer (`docs/09` section
/// 37); otherwise the refusal's words.
class CashMismatchOr extends StatelessWidget {
  const CashMismatchOr({required this.failure, super.key});

  final ApiFailure? failure;

  @override
  Widget build(BuildContext context) {
    final ApiFailure? failure = this.failure;
    final Object? expected =
        failure is ApiRefusal && failure.code == 'cash_amount_mismatch'
        ? failure.error.details['expected_uzs']
        : null;
    if (expected is! int) {
      return FailureMessage(failure);
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        l10n.courierCashMismatch(MoneyFormat.uzs(expected, language)),
        key: const ValueKey<String>('courier-cash-mismatch'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// The cash typed as a whole number of UZS: digits, spaces allowed between
/// them, above zero; `null` when it is not.
int? cashFrom(String text) {
  final String digits = text.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{1,12}$').hasMatch(digits)) {
    return null;
  }
  final int amount = int.parse(digits);
  return amount > 0 ? amount : null;
}

/// Delivered (`docs/09` section 37): for a cash order the Courier types the
/// cash received, which the server holds to the final total; the field is
/// empty, so the entry is the Courier's own count rather than a tap on the
/// expected sum (`docs/04` section 28). After a handover without a sure
/// answer, the same amount goes again under the same key, and the field
/// shows it, locked. It stays open while the handover runs, shows a refusal,
/// and answers the completed order.
class DeliveredDialog extends ConsumerStatefulWidget {
  const DeliveredDialog({required this.order, super.key});

  final CourierOrder order;

  @override
  ConsumerState<DeliveredDialog> createState() => _DeliveredDialogState();
}

class _DeliveredDialogState extends ConsumerState<DeliveredDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _cash;

  @override
  void initState() {
    super.initState();
    _cash = TextEditingController(
      text: ref
          .read(unansweredHandoverProvider(widget.order.id))
          ?.sent
          ?.toString(),
    );
  }

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  bool get _takesCash => widget.order.paymentMethod == PaymentMethod.cash;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final CourierOrder? done = await ref
        .read(courierOutcomeProvider(widget.order.id).notifier)
        .delivered(_takesCash ? cashFrom(_cash.text) : null);
    if (done != null && mounted) {
      Navigator.of(context).pop(done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState state = ref.watch(
      courierOutcomeProvider(widget.order.id),
    );
    final UnansweredRequest<int?>? unanswered = ref.watch(
      unansweredHandoverProvider(widget.order.id),
    );
    final int? amount = widget.order.amountToCollectUzs;
    final bool busy = state.isBusy;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.courierDeliveredTitle),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_takesCash && amount != null) ...<Widget>[
                Text(l10n.courierCashPrompt(MoneyFormat.uzs(amount, language))),
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey<String>('courier-cash'),
                  controller: _cash,
                  readOnly: unanswered != null,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.courierCashField,
                    helperText: unanswered != null
                        ? l10n.courierHandoverRepeating
                        : null,
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                  ),
                  validator: (String? text) =>
                      unanswered == null && cashFrom(text ?? '') == null
                      ? l10n.courierCashInvalid
                      : null,
                ),
              ],
              CashMismatchOr(failure: state.failure),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('courier-delivered-cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('courier-delivered-confirm'),
            onPressed: busy ? null : _send,
            child: busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.courierDelivered,
                    ),
                  )
                : Text(l10n.courierDelivered),
          ),
        ],
      ),
    );
  }
}

/// Not delivered (`docs/09` section 37, `BR-DEL-003`): a reason, and a note
/// of up to 300 characters, required with "other". The order goes back to
/// an Operator. Unkeyed: a repeat is a natural one, so a retry after a lost
/// answer is simply sent again. It stays open while it runs, shows a
/// refusal, and answers the order as the failure left it.
class NotDeliveredDialog extends ConsumerStatefulWidget {
  const NotDeliveredDialog({required this.order, super.key});

  final CourierOrder order;

  @override
  ConsumerState<NotDeliveredDialog> createState() => _NotDeliveredDialogState();
}

class _NotDeliveredDialogState extends ConsumerState<NotDeliveredDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();
  DeliveryFailureReason? _reason;
  bool _reasonMissing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String? _checkNote(AppLocalizations l10n, String? text) {
    final String note = trimLikeServer(text ?? '');
    if (_reason == DeliveryFailureReason.other && note.isEmpty) {
      return l10n.fieldRequired;
    }
    return note.runes.length > 300 ? l10n.fieldTooLong(300) : null;
  }

  Future<void> _send() async {
    final DeliveryFailureReason? reason = _reason;
    setState(() => _reasonMissing = reason == null);
    if (!_form.currentState!.validate() || reason == null) {
      return;
    }
    final String note = trimLikeServer(_note.text);
    final CourierOrder? done = await ref
        .read(courierOutcomeProvider(widget.order.id).notifier)
        .notDelivered(reason, note.isEmpty ? null : note);
    if (done != null && mounted) {
      Navigator.of(context).pop(done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(
      courierOutcomeProvider(widget.order.id),
    );
    final bool busy = state.isBusy;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.courierNotDeliveredTitle),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.courierNotDeliveredExplained),
              // A radio for each reason, so a long one wraps rather than
              // being cut.
              RadioGroup<DeliveryFailureReason>(
                groupValue: _reason,
                onChanged: (DeliveryFailureReason? reason) {
                  if (reason != null && !busy) {
                    setState(() {
                      _reason = reason;
                      _reasonMissing = false;
                    });
                  }
                },
                child: Column(
                  children: <Widget>[
                    for (final DeliveryFailureReason reason
                        in DeliveryFailureReason.values)
                      RadioListTile<DeliveryFailureReason>(
                        key: ValueKey<String>('failure-${reason.code}'),
                        value: reason,
                        contentPadding: EdgeInsets.zero,
                        title: Text(OrderLabels.deliveryFailure(l10n, reason)),
                      ),
                  ],
                ),
              ),
              if (_reasonMissing)
                Text(
                  l10n.fieldRequired,
                  key: const ValueKey<String>('courier-failure-reason-missing'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextFormField(
                key: const ValueKey<String>('courier-failure-note'),
                controller: _note,
                readOnly: busy,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.courierNotDeliveredNote,
                ),
                validator: (String? text) => _checkNote(l10n, text),
              ),
              FailureMessage(state.failure),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('courier-not-delivered-cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('courier-not-delivered-confirm'),
            onPressed: busy ? null : _send,
            child: busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.courierNotDelivered,
                    ),
                  )
                : Text(l10n.courierNotDelivered),
          ),
        ],
      ),
    );
  }
}
