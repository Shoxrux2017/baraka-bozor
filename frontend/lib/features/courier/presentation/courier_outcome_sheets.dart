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
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_fields.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit/kit_sheet.dart';
import '../application/courier_orders_controllers.dart';
import '../domain/courier_orders.dart';

/// What a handover was refused for when the cash was not the final total:
/// the amount to collect, from the server's own answer (`docs/09` section
/// 37); `null` for any other answer.
int? _expectedCash(ApiFailure? failure) {
  final Object? expected =
      failure is ApiRefusal && failure.code == 'cash_amount_mismatch'
      ? failure.error.details['expected_uzs']
      : null;
  return expected is int ? expected : null;
}

/// A refusal of a handover: when the cash was not the final total, what
/// was to be collected, in red; otherwise the refusal's words.
class CashMismatchOr extends StatelessWidget {
  const CashMismatchOr({required this.failure, super.key});

  final ApiFailure? failure;

  @override
  Widget build(BuildContext context) {
    final int? expected = _expectedCash(failure);
    if (expected == null) {
      return FailureMessage(failure);
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: KitNote(
        key: const ValueKey<String>('courier-cash-mismatch'),
        icon: Icons.error_outline,
        tone: KitTone.red,
        text: Text(
          l10n.courierCashMismatch(MoneyFormat.uzs(expected, language)),
        ),
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

/// Opens the handover of [order] in a sheet; answers the completed order.
Future<CourierOrder?> showDeliveredSheet(
  BuildContext context, {
  required CourierOrder order,
}) {
  return showKitSheet<CourierOrder>(
    context,
    title: AppLocalizations.of(context).courierDeliveredTitle,
    sheetKey: 'courier-delivered-sheet',
    builder: (BuildContext sheet) => _DeliveredSheet(order: order),
  );
}

/// Opens the failure of [order] in a sheet; answers the order as the failure
/// left it.
Future<CourierOrder?> showNotDeliveredSheet(
  BuildContext context, {
  required CourierOrder order,
}) {
  return showKitSheet<CourierOrder>(
    context,
    title: AppLocalizations.of(context).courierNotDeliveredTitle,
    sheetKey: 'courier-not-delivered-sheet',
    builder: (BuildContext sheet) => _NotDeliveredSheet(order: order),
  );
}

const TextStyle _explained = TextStyle(
  fontSize: 14,
  height: 1.4,
  color: KitColors.ink2,
);

Widget _busyLabel(bool busy, String label) {
  return busy
      ? SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
            semanticsLabel: label,
          ),
        )
      : Text(label);
}

/// Delivered (`docs/09` section 37): for a cash order the Courier types the
/// cash received, which the server holds to the final total; the field is
/// empty, so the entry is the Courier's own count rather than a tap on the
/// expected sum (`docs/04` section 28). After a handover without a sure
/// answer, the same amount goes again under the same key, and the field
/// shows it, locked. A sheet whose request runs cannot be closed; it shows a
/// refusal and answers the completed order.
class _DeliveredSheet extends ConsumerStatefulWidget {
  const _DeliveredSheet({required this.order});

  final CourierOrder order;

  @override
  ConsumerState<_DeliveredSheet> createState() => _DeliveredSheetState();
}

class _DeliveredSheetState extends ConsumerState<_DeliveredSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _cash;

  /// Whether this sheet sent the handover: a failure the outcome's state
  /// holds from before — the other outcome's, or a closed sheet's — is not
  /// this one's to say.
  bool _sent = false;

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
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _sent = true);
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
    final ApiFailure? failure = _sent ? state.failure : null;

    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_takesCash && amount != null) ...<Widget>[
                Text(
                  l10n.courierCashPrompt(MoneyFormat.uzs(amount, language)),
                  style: _explained,
                ),
                const SizedBox(height: 16),
                PriceField(
                  fieldKey: 'courier-cash',
                  controller: _cash,
                  label: l10n.courierCashField,
                  required: true,
                  enabled: unanswered == null && !busy,
                  helper: unanswered != null
                      ? l10n.courierHandoverRepeating
                      : null,
                  warn: _expectedCash(failure) != null,
                  validator: (String? text) =>
                      unanswered == null && cashFrom(text ?? '') == null
                      ? l10n.courierCashInvalid
                      : null,
                ),
              ] else
                KitNote(
                  icon: Icons.credit_card,
                  text: Text(l10n.courierOnlineNothingToTake),
                ),
              CashMismatchOr(failure: failure),
              const SizedBox(height: 20),
              KitActionPair(
                secondary: OutlinedButton(
                  key: const ValueKey<String>('courier-delivered-cancel'),
                  style: kitOutlined(),
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancelButton),
                ),
                primary: FilledButton(
                  key: const ValueKey<String>('courier-delivered-confirm'),
                  style: kitFilled(),
                  onPressed: busy ? null : _send,
                  child: _busyLabel(busy, l10n.courierDelivered),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Not delivered (`docs/09` section 37, `BR-DEL-003`): a reason, and a note
/// of up to 300 characters, required with "other". The order goes back to
/// an Operator. Unkeyed: a repeat is a natural one, so a retry after a lost
/// answer is simply sent again. A sheet whose request runs cannot be closed;
/// it shows a refusal and answers the order as the failure left it.
class _NotDeliveredSheet extends ConsumerStatefulWidget {
  const _NotDeliveredSheet({required this.order});

  final CourierOrder order;

  @override
  ConsumerState<_NotDeliveredSheet> createState() => _NotDeliveredSheetState();
}

class _NotDeliveredSheetState extends ConsumerState<_NotDeliveredSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();
  DeliveryFailureReason? _reason;
  bool _reasonMissing = false;

  /// Whether this sheet sent the failure; see [_DeliveredSheetState._sent].
  bool _sent = false;

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
    return noteTooLong(l10n, text ?? '');
  }

  Future<void> _send() async {
    final DeliveryFailureReason? reason = _reason;
    setState(() => _reasonMissing = reason == null);
    if (!(_form.currentState?.validate() ?? false) || reason == null) {
      return;
    }
    final String note = trimLikeServer(_note.text);
    setState(() => _sent = true);
    final CourierOrder? done = await ref
        .read(courierOutcomeProvider(widget.order.id).notifier)
        .notDelivered(reason, note.isEmpty ? null : note);
    if (done != null && mounted) {
      Navigator.of(context).pop(done);
    }
  }

  void _choose(DeliveryFailureReason reason) {
    setState(() {
      _reason = reason;
      _reasonMissing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(
      courierOutcomeProvider(widget.order.id),
    );
    final bool busy = state.isBusy;
    final bool other = _reason == DeliveryFailureReason.other;

    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.courierNotDeliveredExplained, style: _explained),
              const SizedBox(height: 8),
              Semantics(
                container: true,
                child: Column(
                  children: <Widget>[
                    for (final DeliveryFailureReason reason
                        in DeliveryFailureReason.values)
                      _ReasonRow(
                        rowKey: 'failure-${reason.code}',
                        label: OrderLabels.deliveryFailure(l10n, reason),
                        chosen: reason == _reason,
                        onTap: busy ? null : () => _choose(reason),
                      ),
                  ],
                ),
              ),
              if (_reasonMissing)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.fieldRequired,
                    key: const ValueKey<String>(
                      'courier-failure-reason-missing',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: KitColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              KitNoteField(
                fieldKey: 'courier-failure-note',
                controller: _note,
                label: other
                    ? l10n.courierNotDeliveredNote
                    : l10n.courierNotDeliveredNoteOptional,
                hint: other
                    ? l10n.courierOtherNoteHint
                    : l10n.courierNotDeliveredNoteHint,
                enabled: !busy,
                validator: (String? text) => _checkNote(l10n, text),
              ),
              FailureMessage(_sent ? state.failure : null),
              const SizedBox(height: 20),
              KitActionPair(
                secondary: OutlinedButton(
                  key: const ValueKey<String>('courier-not-delivered-cancel'),
                  style: kitOutlined(),
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancelButton),
                ),
                primary: FilledButton(
                  key: const ValueKey<String>('courier-not-delivered-confirm'),
                  style: kitFilled(color: KitColors.danger),
                  onPressed: busy ? null : _send,
                  child: _busyLabel(busy, l10n.courierNotDelivered),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One reason: a ring that fills when chosen, its text, a rule under it; the
/// whole row is the tap target.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.rowKey,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final String rowKey;
  final String label;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: chosen,
      child: InkWell(
        key: ValueKey<String>(rowKey),
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: KitColors.line)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: chosen ? KitColors.primary : KitColors.muted,
                        width: 2,
                      ),
                    ),
                    child: chosen
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: KitColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
