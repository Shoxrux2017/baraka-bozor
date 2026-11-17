import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/retry_strip.dart';
import '../../../core/widgets/submit_button.dart';
import '../../auth/data/clipboard_code.dart';
import '../../auth/data/telegram_launcher.dart';
import '../../auth/presentation/auth_notice.dart';
import '../../auth/presentation/code_actions.dart';
import '../../auth/presentation/code_boxes.dart';
import '../../auth/presentation/code_entry.dart';
import '../../auth/presentation/lock_card.dart';
import '../../auth/presentation/rise_in.dart';
import '../application/account_deletion_controller.dart';
import 'delete_account_sheets.dart';
import 'deletion_no_code_sheet.dart';

/// Screen 36а: the code sent to the phone, and the deletion behind it
/// (`DL-140`). It takes the sign-in code's pieces — the boxes, the lock card,
/// the paste chip, «Открыть Telegram» — but nothing deletes by itself: the
/// sixth digit only turns the red button ready, and only that button (or the
/// keyboard's done key) deletes.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const Duration _redHold = Duration(milliseconds: 520);

  final TextEditingController _code = TextEditingController();

  /// The wrong-code moment: the boxes are red and take no input.
  Timer? _redTimer;
  bool _red = false;

  /// The boxes' text when [_onCodeEdit] last looked.
  String _lastCodeText = '';

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
    unawaited(_checkClipboard());
    _code.addListener(_onCodeEdit);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _redTimer?.cancel();
    _code.removeListener(_onCodeEdit);
    _code.dispose();
    super.dispose();
  }

  /// A failed delete belongs to the digits it was sent with: once the boxes
  /// change it is dropped, so a retry can only send what is on screen.
  void _onCodeEdit() {
    if (_code.text == _lastCodeText) {
      return;
    }
    _lastCodeText = _code.text;
    final AccountDeletionState state = ref.read(
      accountDeletionControllerProvider,
    );
    if (state.failedAction == DeletionAction.delete) {
      ref.read(accountDeletionControllerProvider.notifier).clearFailure();
    }
  }

  Future<void> _checkClipboard() async {
    final bool holds = await ref.read(clipboardCodeProvider).mayHoldCode();
    if (mounted && holds != _mayPaste) {
      setState(() => _mayPaste = holds);
    }
  }

  /// A tap on the chip: a code fills the boxes and nothing more; none hides
  /// the chip until the next resume.
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
    if (!opened &&
        mounted &&
        !ref.read(accountDeletionControllerProvider).locked) {
      await _noCode();
    }
  }

  Future<void> _noCode() async {
    setState(() => _sheetOpen = true);
    final bool sent = await showDeletionNoCodeSheet(context);
    if (!mounted) {
      return;
    }
    final AccountDeletionController controller = ref.read(
      accountDeletionControllerProvider.notifier,
    );
    if (ref.read(accountDeletionControllerProvider).failedAction ==
        DeletionAction.resend) {
      controller.clearFailure();
    }
    setState(() => _sheetOpen = false);
    if (sent) {
      _code.clear();
    }
  }

  void _onWrongCode(AccountDeletionState state) {
    unawaited(HapticFeedback.errorNotification());
    announce(context, _attemptsText(AppLocalizations.of(context), state));
    setState(() => _red = true);
    _redTimer?.cancel();
    _redTimer = Timer(_redHold, () {
      if (!mounted) {
        return;
      }
      _code.clear();
      setState(() => _red = false);
    });
  }

  String _attemptsText(AppLocalizations l10n, AccountDeletionState state) {
    final int? left = state.attemptsLeft;
    return left == null ? l10n.errorCodeInvalid : l10n.codeWrongLeft(left);
  }

  void _onFlowChange(AccountDeletionState before, AccountDeletionState now) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (now.locked && !before.locked) {
      _redTimer?.cancel();
      _red = false;
      _code.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (now.misses > before.misses) {
      _onWrongCode(now);
    }
    if (now.running == DeletionAction.delete &&
        before.running != DeletionAction.delete) {
      announce(context, l10n.deleteDeleting);
    }
    if (now.running == DeletionAction.check &&
        before.running != DeletionAction.check) {
      announce(context, l10n.deleteCheckingSpoken);
    }
    if (!_stripShown(before) && _stripShown(now)) {
      announce(
        context,
        now.failedAction == DeletionAction.resend
            ? l10n.deleteSendOffline
            : l10n.deleteOffline,
      );
    }
  }

  /// The offline strip: a delete or a resend that found no connection.
  bool _stripShown(AccountDeletionState state) =>
      state.offline &&
      !_sheetOpen &&
      (state.failedAction == DeletionAction.delete ||
          state.failedAction == DeletionAction.resend);

  /// A refusal that is not a missing connection, for the notice in the body.
  ApiFailure? _noticeFailure(AccountDeletionState state) {
    final DeletionAction? action = state.failedAction;
    if (state.failure == null ||
        state.offline ||
        _sheetOpen ||
        (action != DeletionAction.delete && action != DeletionAction.resend)) {
      return null;
    }
    return state.failure;
  }

  bool _ready(AccountDeletionState state) =>
      _code.text.length == loginCodeLength &&
      state.entryOpen &&
      !state.busy &&
      !_red;

  Future<void> _resend() async {
    _code.clear();
    final bool sent = await ref
        .read(accountDeletionControllerProvider.notifier)
        .resend();
    if (!sent || !mounted) {
      return;
    }
    announce(
      context,
      codeSentSpoken(
        AppLocalizations.of(context),
        phone: _phone(),
        channel: ref.read(accountDeletionControllerProvider).requested?.channel,
      ),
    );
  }

  /// A failed delete is sent again from the boxes as they stand; a failed
  /// resend repeats itself. With fewer than six digits there is nothing to
  /// send, so the failure is only dismissed.
  void _retry() {
    final AccountDeletionState state = ref.read(
      accountDeletionControllerProvider,
    );
    if (state.failedAction == DeletionAction.resend) {
      unawaited(_resend());
    } else if (_code.text.length == loginCodeLength) {
      unawaited(_delete());
    } else {
      ref.read(accountDeletionControllerProvider.notifier).clearFailure();
    }
  }

  void _onNoticeAction(AuthNoticeAction action) {
    switch (action) {
      case AuthNoticeAction.retry:
        _retry();
      case AuthNoticeAction.newCode:
        unawaited(_resend());
      case AuthNoticeAction.otherNumber || AuthNoticeAction.changeNumber:
        break;
    }
  }

  String _phone() =>
      ref.read(
        sessionControllerProvider.select((AsyncValue<SessionState> session) {
          final SessionState? current = session.value;
          return current is SignedIn ? current.customerUser?.phone : null;
        }),
      ) ??
      '';

  Future<void> _delete() async {
    final AccountDeletionController controller = ref.read(
      accountDeletionControllerProvider.notifier,
    );
    if (_code.text.length != loginCodeLength || _red) {
      return;
    }
    final String? account = ref.read(customerAccountProvider);

    final DeletionOutcome outcome = await controller.delete(_code.text);
    if (!mounted) {
      return;
    }

    switch (outcome) {
      case DeletionOutcome.deleted:
        // The page of the deleted account opens first and the session is
        // forgotten after it: the server has already revoked the token, and
        // the page is open to a signed-out phone.
        unawaited(HapticFeedback.successNotification());
        context.go(AppPaths.accountDeleted);
        if (account != null) {
          await controller.forgetAccount(account);
        }
      case DeletionOutcome.unfinished:
        final order = ref.read(accountDeletionControllerProvider).unfinished;
        if (order != null) {
          await showUnfinishedOrderSheet(context, order, leaveScreen: true);
        }
      case DeletionOutcome.refused:
        break;
    }
  }

  CodeBoxesLook _look(AccountDeletionState state) {
    if (_red) {
      return CodeBoxesLook.wrong;
    }
    if (state.running == DeletionAction.delete ||
        state.running == DeletionAction.check) {
      return CodeBoxesLook.checking;
    }
    return CodeBoxesLook.entry;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AccountDeletionState state = ref.watch(
      accountDeletionControllerProvider,
    );
    ref.listen<AccountDeletionState>(
      accountDeletionControllerProvider,
      (AccountDeletionState? before, AccountDeletionState next) =>
          _onFlowChange(before ?? const AccountDeletionState(), next),
    );
    final String phone =
        ref.watch(
          sessionControllerProvider.select((AsyncValue<SessionState> session) {
            final SessionState? current = session.value;
            return current is SignedIn ? current.customerUser?.phone : null;
          }),
        ) ??
        '';
    final bool telegram =
        RequestedCodeChannel.of(state.requested?.channel) ==
        RequestedCodeChannel.telegram;
    final ApiFailure? notice = _noticeFailure(state);

    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        key: const ValueKey<String>('delete-account-screen'),
        backgroundColor: Colors.white,
        appBar: kitAppBar(title: l10n.deleteCodeTitle),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: KitColors.dangerWash,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 28,
                            color: KitColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.deleteCodeHeading,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: KitColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        codeSentLine(
                          l10n,
                          phone: phone,
                          channel: state.requested?.channel,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: KitColors.ink2,
                        ),
                      ),
                      if (state.entryOpen) ...<Widget>[
                        const SizedBox(height: 24),
                        CodeBoxes(
                          controller: _code,
                          invalidMessage: l10n.codeInvalidFormat,
                          onSubmitted: () {
                            if (_ready(state)) {
                              unawaited(_delete());
                            }
                          },
                          look: _look(state),
                          misses: state.misses,
                          spokenLabel: telegram
                              ? l10n.codeFieldSpoken
                              : l10n.codeFieldSpokenOther,
                        ),
                      ] else
                        LockCard(
                          lockedSeconds: state.lockedSeconds,
                          over: state.lockOver,
                        ),
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
                      if (notice != null)
                        AuthNotice(
                          view: authNoticeOf(
                            l10n,
                            notice,
                            phone: phone,
                            place: AuthNoticePlace.deletion,
                          ),
                          onAction: _onNoticeAction,
                        ),
                      ListenableBuilder(
                        listenable: _code,
                        builder: (BuildContext context, Widget? _) {
                          final bool showChip =
                              _mayPaste &&
                              state.entryOpen &&
                              !state.busy &&
                              _code.text.length < loginCodeLength &&
                              _look(state) == CodeBoxesLook.entry;
                          return showChip
                              ? CodePasteChip(onTap: _paste)
                              : const SizedBox.shrink();
                        },
                      ),
                      if (state.entryOpen) ...<Widget>[
                        if (telegram) ...<Widget>[
                          const SizedBox(height: 22),
                          OpenTelegramButton(onTap: _openTelegram),
                        ],
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
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_stripShown(state))
                      RetryStrip(
                        message: state.failedAction == DeletionAction.resend
                            ? l10n.deleteSendOffline
                            : l10n.deleteOffline,
                        onRetry: _retry,
                        stripKey: const ValueKey<String>(
                          'delete-offline-strip',
                        ),
                      ),
                    ListenableBuilder(
                      listenable: _code,
                      builder: (BuildContext context, Widget? _) =>
                          _mainButton(l10n, state, telegram),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainButton(
    AppLocalizations l10n,
    AccountDeletionState state,
    bool telegram,
  ) {
    final SubmitFace face;
    final String label;
    final VoidCallback? onPressed;
    Color fill = KitColors.danger;
    if (state.lockOver) {
      final bool sending = state.running == DeletionAction.resend;
      face = sending ? SubmitFace.busy : SubmitFace.ready;
      label = sending ? l10n.sendingCode : l10n.codeNewCode;
      onPressed = _resend;
      fill = KitColors.primary;
    } else if (state.running == DeletionAction.delete) {
      face = SubmitFace.busy;
      label = l10n.deleteDeleting;
      onPressed = null;
    } else if (state.running == DeletionAction.check) {
      face = SubmitFace.busy;
      label = l10n.codeChecking;
      onPressed = null;
    } else if (!state.entryOpen) {
      face = SubmitFace.off;
      label = l10n.profileDeleteAccount;
      onPressed = null;
    } else if (_ready(state)) {
      face = SubmitFace.ready;
      label = l10n.profileDeleteAccount;
      onPressed = _delete;
    } else {
      face = SubmitFace.off;
      label = _code.text.length == loginCodeLength
          ? l10n.profileDeleteAccount
          : _code.text.isEmpty
          ? (telegram ? l10n.deleteEnterCode : l10n.deleteEnterCodeOther)
          : l10n.phoneDigitsLeft(loginCodeLength - _code.text.length);
      onPressed = null;
    }
    return SubmitButton(
      buttonKey: const ValueKey<String>('delete-submit'),
      face: face,
      label: label,
      onPressed: onPressed,
      fill: fill,
    );
  }
}
