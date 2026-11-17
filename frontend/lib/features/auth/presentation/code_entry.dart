import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/submit_button.dart';
import '../application/code_login_controller.dart';
import 'code_boxes.dart';
import 'lock_card.dart';
import 'rise_in.dart';

/// Steps 3 and 4 of `docs/04-user-flows.md` section 2: the code itself and
/// the one button under it (`DL-139`).
///
/// The sixth digit verifies by itself, 140 ms after it is typed and 160 ms
/// after a paste; the button says what is going on and sends the same call
/// when it is pressed first. A wrong code turns the boxes red for 520 ms,
/// then they clear; three wrong codes put the lock card in their place, and
/// when it runs out the button asks for a new code.
///
/// On a successful verification the session changes and the router leaves
/// this screen; nothing here navigates.
class CodeEntry extends ConsumerStatefulWidget {
  const CodeEntry({required this.state, required this.buttonKey, super.key});

  final CodeLoginState state;

  /// The key of the main button's box, which the page keeps above the
  /// keyboard.
  final GlobalKey buttonKey;

  @override
  ConsumerState<CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends ConsumerState<CodeEntry> {
  static const Duration _typedWait = Duration(milliseconds: 140);
  static const Duration _pastedWait = Duration(milliseconds: 160);
  static const Duration _redHold = Duration(milliseconds: 520);

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _code = TextEditingController();

  /// The wait between the sixth digit and the verify it starts.
  Timer? _pending;

  /// The wrong-code moment: the boxes are red and take no input.
  Timer? _redTimer;
  bool _red = false;

  @override
  void didUpdateWidget(CodeEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    final CodeLoginState now = widget.state;
    final CodeLoginState before = oldWidget.state;
    if (now.locked && !before.locked) {
      _pending?.cancel();
      _code.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (now.misses > before.misses) {
      _onWrongCode(now);
    }
    if (now.accepted && !before.accepted) {
      unawaited(HapticFeedback.successNotification());
      announce(context, AppLocalizations.of(context).codeAccepted);
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    _redTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _onWrongCode(CodeLoginState state) {
    _pending?.cancel();
    unawaited(HapticFeedback.errorNotification());
    announce(context, _attemptsText(AppLocalizations.of(context), state));
    _red = true;
    _redTimer?.cancel();
    _redTimer = Timer(_redHold, () {
      if (!mounted) {
        return;
      }
      _code.clear();
      setState(() => _red = false);
    });
  }

  String _attemptsText(AppLocalizations l10n, CodeLoginState state) {
    final int? left = state.attemptsLeft;
    return left == null ? l10n.errorCodeInvalid : l10n.codeWrongLeft(left);
  }

  /// The sixth digit came: verify soon, unless the code changed, the boxes
  /// are red, a call is running or the lock came first.
  void _onCompleted(bool pasted) {
    _pending?.cancel();
    _pending = Timer(pasted ? _pastedWait : _typedWait, () {
      if (mounted && _code.text.length == loginCodeLength) {
        _verify();
      }
    });
  }

  Future<void> _verify() async {
    _pending?.cancel();
    final CodeLoginState state = widget.state;
    if (!state.entryOpen || state.busy || state.accepted || _red) {
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    await ref.read(codeLoginControllerProvider.notifier).verify(_code.text);
  }

  Future<void> _resend() async {
    _code.clear();
    final bool sent = await ref
        .read(codeLoginControllerProvider.notifier)
        .resend();
    if (!sent || !mounted) {
      return;
    }
    final CodeLoginState state = ref.read(codeLoginControllerProvider);
    announce(
      context,
      codeSentSpoken(
        AppLocalizations.of(context),
        phone: state.phone ?? '',
        channel: state.requested?.channel,
      ),
    );
  }

  CodeBoxesLook get _look {
    final CodeLoginState state = widget.state;
    if (state.accepted) {
      return CodeBoxesLook.right;
    }
    if (_red) {
      return CodeBoxesLook.wrong;
    }
    if (state.running == CodeLoginAction.verify) {
      return CodeBoxesLook.checking;
    }
    return CodeBoxesLook.entry;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = widget.state;
    final bool telegram =
        RequestedCodeChannel.of(state.requested?.channel) ==
        RequestedCodeChannel.telegram;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.entryOpen) ...<Widget>[
            const SizedBox(height: 24),
            CodeBoxes(
              controller: _code,
              invalidMessage: l10n.codeInvalidFormat,
              onSubmitted: _verify,
              onCompleted: _onCompleted,
              look: _look,
              misses: state.misses,
              spokenLabel: telegram
                  ? l10n.codeFieldSpoken
                  : l10n.codeFieldSpokenOther,
            ),
          ] else
            LockCard(lockedSeconds: state.lockedSeconds, over: state.lockOver),
          if (state.wrongCode)
            RiseIn(
              key: ValueKey<String>('attempts-${state.misses}'),
              child: Padding(
                key: const ValueKey<String>('code-attempts'),
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _attemptsText(l10n, state),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KitColors.danger,
                  ),
                ),
              ),
            ),
          FailureMessage(state.failure),
          const SizedBox(height: 28),
          ListenableBuilder(
            listenable: _code,
            builder: (BuildContext context, Widget? _) => _button(l10n, state),
          ),
        ],
      ),
    );
  }

  Widget _button(AppLocalizations l10n, CodeLoginState state) {
    final bool six = _code.text.length == loginCodeLength;
    final SubmitFace face;
    final String label;
    final VoidCallback? onPressed;
    if (state.lockOver) {
      final bool sending = state.running == CodeLoginAction.resend;
      face = sending ? SubmitFace.busy : SubmitFace.ready;
      label = sending ? l10n.sendingCode : l10n.codeNewCode;
      onPressed = _resend;
    } else if (state.accepted) {
      face = SubmitFace.done;
      label = l10n.codeAccepted;
      onPressed = null;
    } else if (state.running == CodeLoginAction.verify) {
      face = SubmitFace.busy;
      label = l10n.codeChecking;
      onPressed = null;
    } else {
      face = state.entryOpen && six && !_red && !state.busy
          ? SubmitFace.ready
          : SubmitFace.off;
      label = l10n.verifyButton;
      onPressed = _verify;
    }
    return KeyedSubtree(
      key: widget.buttonKey,
      child: SubmitButton(
        buttonKey: const ValueKey<String>('verify-button'),
        face: face,
        label: label,
        onPressed: onPressed,
      ),
    );
  }
}

/// The spoken "code sent" line for a code sent to [phone] over [channel].
String codeSentSpoken(
  AppLocalizations l10n, {
  required String phone,
  required String? channel,
}) {
  final String shown = formatPhone(phone);
  return switch (RequestedCodeChannel.of(channel)) {
    RequestedCodeChannel.telegram => l10n.codeSentSpoken(shown),
    RequestedCodeChannel.sms => l10n.codeSentSmsSpoken(shown),
    RequestedCodeChannel.other => l10n.codeSentOtherSpoken(shown),
  };
}

/// Where a code went, in one line: the Telegram text names the channel and
/// the phone; SMS says so; any other channel (the development and test-phone
/// ones) says only that a code was sent to the phone. The account deletion
/// page draws it.
String codeSentLine(
  AppLocalizations l10n, {
  required String phone,
  required String? channel,
}) {
  final String formatted = formatPhone(phone);
  return switch (RequestedCodeChannel.of(channel)) {
    RequestedCodeChannel.telegram => l10n.codeSentToPhone(formatted),
    RequestedCodeChannel.sms => '${l10n.codeSentSms}\n$formatted',
    RequestedCodeChannel.other => l10n.codeSentOnPhone(formatted),
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
