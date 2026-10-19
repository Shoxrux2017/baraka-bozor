import 'package:flutter/material.dart';

import '../../../core/formatting/server_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// Asks before cancelling, with a reason of up to 300 characters: optional
/// for a direct cancel, required for a request to an Operator (`DL-65` (1)).
/// Answers the reason typed, empty or not, or `null` when the Customer keeps
/// the order. After a cancel whose outcome is unknown it shows that cancel's
/// reason, which a retry sends again unchanged — required or not, since the
/// same request goes again.
Future<String?> showCancelSheet(
  BuildContext context, {
  required int orderNumber,
  required bool request,
  required bool unconfirmed,
  required String? reason,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext sheet) => _CancelSheet(
    orderNumber: orderNumber,
    request: request,
    unconfirmed: unconfirmed,
    reason: reason,
  ),
);

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({
    required this.orderNumber,
    required this.request,
    required this.unconfirmed,
    required this.reason,
  });

  final int orderNumber;
  final bool request;
  final bool unconfirmed;
  final String? reason;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  static const int _limit = 300;

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _reason = TextEditingController(
    text: widget.reason ?? '',
  );

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

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
    return reason.runes.length > _limit ? l10n.fieldTooLong(_limit) : null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int kept = trimLikeServer(_reason.text).runes.length;
    final bool stacked = MediaQuery.textScalerOf(context).scale(14) > 18;

    final Widget keep = OutlinedButton(
      key: const ValueKey<String>('cancel-keep'),
      style: OutlinedButton.styleFrom(
        foregroundColor: KitColors.ink,
        side: const BorderSide(color: KitColors.line),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: Text(
        l10n.orderCancelKeepKit,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
    final Widget confirm = FilledButton(
      key: const ValueKey<String>('cancel-confirm'),
      style: FilledButton.styleFrom(
        backgroundColor: KitColors.danger,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {
        if (_form.currentState!.validate()) {
          Navigator.of(context).pop(_reason.text);
        }
      },
      child: Text(
        widget.request ? l10n.requestSend : l10n.orderCancelShort,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KitColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.request
                            ? l10n.requestSheetTitle
                            : l10n.cancelSheetTitle(widget.orderNumber),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('cancel-sheet-close'),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    icon: const Icon(Icons.close, color: KitColors.ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: KitColors.line),
              const SizedBox(height: 14),
              Text(
                widget.request ? l10n.requestSheetHint : l10n.cancelSheetHint,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: KitColors.ink2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.request
                    ? l10n.orderRequestCancelReason
                    : l10n.orderCancelReason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey<String>('cancel-reason'),
                controller: _reason,
                readOnly: widget.unconfirmed,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 15, color: KitColors.ink),
                decoration: InputDecoration(
                  hintText: l10n.cancelReasonHint,
                  hintStyle: const TextStyle(color: KitColors.muted),
                  filled: true,
                  fillColor: KitColors.field,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (String? text) => _check(l10n, text),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '$kept / $_limit',
                  style: TextStyle(
                    fontSize: 12,
                    color: kept > _limit ? KitColors.danger : KitColors.muted,
                  ),
                ),
              ),
              if (widget.unconfirmed) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  l10n.orderCancelRepeating,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: KitColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (stacked) ...<Widget>[
                confirm,
                const SizedBox(height: 10),
                keep,
              ] else
                Row(
                  children: <Widget>[
                    Expanded(child: keep),
                    const SizedBox(width: 12),
                    Expanded(child: confirm),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
