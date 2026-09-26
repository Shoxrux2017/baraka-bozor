import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/code_login_controller.dart';

/// The number of digits in a login code (`docs/09-api-contracts.md`
/// section 6).
const int loginCodeLength = 6;

/// Steps 3 and 4 of `docs/04-user-flows.md` section 2: where the code went,
/// the code itself, and a resend once the server allows one. Shared by the
/// Customer login and the Customer-mode entry, which differ only in whose
/// phone the code went to.
///
/// On a successful verification the session changes and the router leaves
/// this screen; nothing here navigates.
class CodeEntry extends ConsumerStatefulWidget {
  const CodeEntry({required this.state, super.key});

  final CodeLoginState state;

  @override
  ConsumerState<CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends ConsumerState<CodeEntry> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    await ref.read(codeLoginControllerProvider.notifier).verify(_code.text);
  }

  Future<void> _resend() async {
    _code.clear();
    await ref.read(codeLoginControllerProvider.notifier).resend();
  }

  String _sentText(AppLocalizations l10n, RequestedCodeChannel channel) =>
      switch (channel) {
        RequestedCodeChannel.telegram => l10n.codeSentTelegram,
        RequestedCodeChannel.sms => l10n.codeSentSms,
        RequestedCodeChannel.other => l10n.codeSentGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = widget.state;
    final String phone = state.phone ?? '';

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _sentText(l10n, RequestedCodeChannel.of(state.requested?.channel)),
            key: const ValueKey<String>('code-sent-text'),
          ),
          const SizedBox(height: 4),
          Text(l10n.codeSentToPhone(formatPhone(phone))),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey<String>('code-field'),
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.oneTimeCode],
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(loginCodeLength),
            ],
            decoration: InputDecoration(labelText: l10n.codeLabel),
            validator: (String? value) =>
                (value ?? '').length == loginCodeLength
                ? null
                : l10n.codeInvalidFormat,
            onFieldSubmitted: (String _) => _verify(),
          ),
          FailureMessage(state.failure),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('verify-button'),
            onPressed: state.busy ? null : _verify,
            child: Text(l10n.verifyButton),
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const ValueKey<String>('resend-button'),
            onPressed: state.canResend ? _resend : null,
            child: Text(
              state.resendInSeconds > 0
                  ? l10n.resendIn(state.resendInSeconds)
                  : l10n.resendCode,
            ),
          ),
        ],
      ),
    );
  }
}

/// The delivery channels a screen distinguishes. `fake` and `test` are the
/// development and test-phone channels of `docs/09` section 6 and read as
/// "sent", nothing more specific.
enum RequestedCodeChannel {
  telegram,
  sms,
  other;

  static RequestedCodeChannel of(String? channel) => switch (channel) {
    'telegram' => RequestedCodeChannel.telegram,
    'sms' => RequestedCodeChannel.sms,
    _ => RequestedCodeChannel.other,
  };
}
