import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/code_login_controller.dart';
import 'code_boxes.dart';
import 'lock_message.dart';

/// Steps 3 and 4 of `docs/04-user-flows.md` section 2: the code itself, the
/// verify button and a resend once the server allows one.
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
  void didUpdateWidget(CodeEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.locked && !oldWidget.state.locked) {
      _code.clear();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = widget.state;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CodeBoxes(
            controller: _code,
            invalidMessage: l10n.codeInvalidFormat,
            onSubmitted: _verify,
          ),
          FailureMessage(state.failure),
          LockMessage(lockedSeconds: state.lockedSeconds),
          if (state.lockOver)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.codeLockOver,
                key: const ValueKey<String>('lock-over-message'),
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(
            key: const ValueKey<String>('verify-button'),
            onPressed: state.busy || state.locked ? null : _verify,
            child: Text(l10n.verifyButton),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey<String>('resend-button'),
            onPressed: state.canResend ? _resend : null,
            style: TextButton.styleFrom(
              disabledForegroundColor: KitColors.muted,
              textStyle: const TextStyle(
                fontFamily: appFontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            child: Text(
              state.resendInSeconds > 0
                  ? l10n.resendIn(formatCountdown(state.resendInSeconds))
                  : l10n.resendCode,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seconds as `m:ss`, the way the resend countdown reads.
String formatCountdown(int seconds) {
  final int clamped = seconds < 0 ? 0 : seconds;
  return '${clamped ~/ 60}:${(clamped % 60).toString().padLeft(2, '0')}';
}

/// Where the code went, in one line: the Telegram text names the channel and
/// the phone; SMS says so; any other channel (the development and test-phone
/// ones) says only that a code was sent to the phone.
String codeSentText(AppLocalizations l10n, CodeLoginState state) {
  final String phone = formatPhone(state.phone ?? '');
  return switch (RequestedCodeChannel.of(state.requested?.channel)) {
    RequestedCodeChannel.telegram => l10n.codeSentToPhone(phone),
    RequestedCodeChannel.sms => '${l10n.codeSentSms}\n$phone',
    RequestedCodeChannel.other => l10n.codeSentOnPhone(phone),
  };
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
