import 'package:flutter/material.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import 'auth_scaffold.dart';

/// The scrim of the kit's dialogs.
const Color authDialogBarrier = Color(0x14151D16);

/// Screen 03 of `kit/01-vhod`: the number is read back before a code is
/// sent to it. "Send" runs [onSend] while the dialog stays, and cannot be
/// left until it answers; the dialog then closes with whether the code was
/// sent. "Edit" closes it with `false`.
Future<bool> showConfirmPhoneDialog(
  BuildContext context, {
  required String phone,
  required Future<bool> Function() onSend,
}) async {
  final bool? sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: authDialogBarrier,
    builder: (BuildContext context) =>
        _ConfirmPhoneDialog(phone: phone, onSend: onSend),
  );
  return sent ?? false;
}

class _ConfirmPhoneDialog extends StatefulWidget {
  const _ConfirmPhoneDialog({required this.phone, required this.onSend});

  final String phone;
  final Future<bool> Function() onSend;

  @override
  State<_ConfirmPhoneDialog> createState() => _ConfirmPhoneDialogState();
}

class _ConfirmPhoneDialogState extends State<_ConfirmPhoneDialog> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final bool sent = await widget.onSend();
    if (mounted) {
      Navigator.of(context).pop(sent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_sending,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.confirmPhoneTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: appFontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                formatPhone(widget.phone),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: appFontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.confirmPhoneBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey<String>('confirm-phone-edit'),
                      style: authOutlinedButtonStyle,
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(l10n.editButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('confirm-phone-send'),
                      onPressed: _sending ? null : _send,
                      child: Text(l10n.sendButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
