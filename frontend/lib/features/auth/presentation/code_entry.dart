import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/submit_button.dart';
import '../application/code_login_controller.dart';
import '../data/clipboard_code.dart';
import '../data/telegram_launcher.dart';
import 'auth_notice.dart';
import 'code_boxes.dart';
import 'lock_card.dart';
import 'no_code_sheet.dart';
import 'rise_in.dart';
import 'telegram_mark.dart';

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

  /// The boxes' text when [_onCodeEdit] last looked.
  String _lastCodeText = '';

  /// The wrong-code moment: the boxes are red and take no input.
  Timer? _redTimer;
  bool _red = false;

  /// The clipboard held text at the page's start or the app's last resume, so
  /// the paste chip may show; it never reads the text before a tap.
  bool _mayPaste = false;

  /// The «Не пришёл код?» sheet is open and shows a refused resend itself.
  bool _sheetOpen = false;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkClipboard);
    _checkClipboard();
    _lastCodeText = _code.text;
    _code.addListener(_onCodeEdit);
  }

  /// A failed check belongs to the digits it was sent with: once the boxes
  /// change it is dropped, so a retry can only send what is on screen.
  void _onCodeEdit() {
    if (_code.text == _lastCodeText) {
      return;
    }
    _lastCodeText = _code.text;
    final CodeLoginState state = ref.read(codeLoginControllerProvider);
    if (state.failedAction == CodeLoginAction.verify) {
      ref.read(codeLoginControllerProvider.notifier).clearFailure();
    }
  }

  Future<void> _checkClipboard() async {
    final bool holds = await ref.read(clipboardCodeProvider).mayHoldCode();
    if (mounted && holds != _mayPaste) {
      setState(() => _mayPaste = holds);
    }
  }

  /// A tap on the chip: a code fills the boxes and the usual paste verify
  /// follows; none hides the chip until the next resume.
  Future<void> _paste() async {
    final String? code = await ref.read(clipboardCodeProvider).readCode();
    if (!mounted) {
      return;
    }
    if (code == null) {
      setState(() => _mayPaste = false);
      return;
    }
    _code.text = code;
  }

  Future<void> _openTelegram() async {
    final bool opened = await ref.read(telegramLauncherProvider).open();
    // During the lock the sheet would offer a resend the lock refuses.
    if (!opened && mounted && !ref.read(codeLoginControllerProvider).locked) {
      await _noCode();
    }
  }

  Future<void> _noCode() async {
    setState(() => _sheetOpen = true);
    final bool sent = await showNoCodeSheet(context);
    if (!mounted) {
      return;
    }
    final CodeLoginController controller = ref.read(
      codeLoginControllerProvider.notifier,
    );
    if (ref.read(codeLoginControllerProvider).failedAction ==
        CodeLoginAction.resend) {
      controller.clearFailure();
    }
    setState(() => _sheetOpen = false);
    if (sent) {
      _code.clear();
    }
  }

  void _onNoticeAction(AuthNoticeAction action) {
    switch (action) {
      case AuthNoticeAction.retry:
        _retry();
      case AuthNoticeAction.newCode:
        unawaited(_resend());
      case AuthNoticeAction.changeNumber:
        unawaited(Navigator.of(context).maybePop());
      case AuthNoticeAction.otherNumber:
        break;
    }
  }

  /// A failed check is sent again from the boxes as they stand; a failed
  /// resend repeats itself. With fewer than six digits there is nothing to
  /// send, so the failure is only dismissed.
  void _retry() {
    final CodeLoginController controller = ref.read(
      codeLoginControllerProvider.notifier,
    );
    if (ref.read(codeLoginControllerProvider).failedAction !=
        CodeLoginAction.verify) {
      unawaited(controller.retry());
    } else if (_code.text.length == loginCodeLength) {
      unawaited(_verify());
    } else {
      controller.clearFailure();
    }
  }

  /// The failure this page shows: only a resend or a verify that failed (the
  /// phone page shows a refused request).
  ApiFailure? _noticeFailure(CodeLoginState state) {
    final CodeLoginAction? action = state.failedAction;
    return action == CodeLoginAction.resend || action == CodeLoginAction.verify
        ? state.failure
        : null;
  }

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
    _lifecycle.dispose();
    _pending?.cancel();
    _redTimer?.cancel();
    _code.removeListener(_onCodeEdit);
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
          // While the sheet is open a check's notice stays in the tree,
          // hidden, so closing the sheet does not announce it again; a
          // refused resend is the sheet's own to show.
          if (_noticeFailure(state) case final ApiFailure failure
              when !_sheetOpen || state.failedAction == CodeLoginAction.verify)
            Visibility(
              key: const ValueKey<String>('code-notice'),
              visible: !_sheetOpen,
              maintainState: true,
              child: AuthNotice(
                view: authNoticeOf(
                  l10n,
                  failure,
                  phone: state.phone ?? '',
                  place: AuthNoticePlace.code,
                ),
                onAction: _onNoticeAction,
              ),
            ),
          ListenableBuilder(
            listenable: _code,
            builder: (BuildContext context, Widget? _) {
              final bool showChip =
                  _mayPaste &&
                  state.entryOpen &&
                  !state.busy &&
                  _code.text.length < loginCodeLength &&
                  _look == CodeBoxesLook.entry;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showChip) _PasteChip(onTap: _paste),
                  const SizedBox(height: 28),
                  _button(l10n, state),
                ],
              );
            },
          ),
          // As drawn, also during the lock: the next code comes there too.
          if (telegram) ...<Widget>[
            const SizedBox(height: 12),
            _TelegramButton(onTap: _openTelegram),
          ],
          if (!state.locked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                key: const ValueKey<String>('code-no-code'),
                onPressed: _noCode,
                style: TextButton.styleFrom(
                  foregroundColor: KitColors.primaryDark,
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.codeNotArrived),
              ),
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

/// «Вставить код»: a green-washed chip that reads the clipboard when tapped.
class _PasteChip extends StatelessWidget {
  const _PasteChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return RiseIn(
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Center(
          child: TextButton.icon(
            key: const ValueKey<String>('code-paste'),
            onPressed: onTap,
            icon: const Icon(Icons.content_paste, size: 20),
            label: Text(l10n.codePaste),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              backgroundColor: KitColors.primaryWash,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Открыть Telegram»: white, a hairline edge and the Telegram mark.
class _TelegramButton extends StatelessWidget {
  const _TelegramButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return OutlinedButton(
      key: const ValueKey<String>('code-open-telegram'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: KitColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: KitColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const TelegramMark(size: 24),
          const SizedBox(width: 10),
          Flexible(child: Text(l10n.codeOpenTelegram)),
        ],
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
