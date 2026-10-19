import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/countdown_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../../../core/storage/token_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../auth/presentation/code_boxes.dart';
import '../../auth/presentation/code_entry.dart';
import '../../auth/presentation/lock_message.dart';
import '../../catalog/application/recent_searches.dart';
import '../application/account_deletion_controller.dart';
import 'delete_account_sheets.dart';

/// Screen 36а: the code sent to the phone, and the deletion behind it. It
/// keeps the sign-in code's rules: a resend once the server allows one, the
/// lock after three wrong codes, the entry closed until a new code.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool _ready(AccountDeletionState state) =>
      _code.text.length == loginCodeLength && state.entryOpen && !state.busy;

  Future<void> _resend() async {
    _code.clear();
    await ref.read(accountDeletionControllerProvider.notifier).resend();
  }

  Future<void> _delete() async {
    final AccountDeletionController controller = ref.read(
      accountDeletionControllerProvider.notifier,
    );
    final SessionController session = ref.read(
      sessionControllerProvider.notifier,
    );
    final String? account = ref.read(customerAccountProvider);
    final RecentSearches? searches = account == null
        ? null
        : ref.read(recentSearchesProvider(account).notifier);

    final DeletionOutcome outcome = await controller.delete(_code.text);
    if (!mounted) {
      return;
    }

    switch (outcome) {
      case DeletionOutcome.deleted:
        await searches?.clear();
        if (!mounted) {
          return;
        }
        controller.reset();
        // The page of the deleted account opens first and the session is
        // forgotten after it: the server has already revoked the token, and
        // the page is open to a signed-out phone.
        context.go(AppPaths.accountDeleted);
        await session.dropSession(SessionSlot.customer);
      case DeletionOutcome.unfinished:
        final order = ref.read(accountDeletionControllerProvider).unfinished;
        if (order != null) {
          await showUnfinishedOrderSheet(context, order, leaveScreen: true);
        }
      case DeletionOutcome.refused:
        _code.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AccountDeletionState state = ref.watch(
      accountDeletionControllerProvider,
    );
    final String phone =
        ref.watch(
          sessionControllerProvider.select((AsyncValue<SessionState> session) {
            final SessionState? current = session.value;
            return current is SignedIn ? current.customerUser?.phone : null;
          }),
        ) ??
        '';

    return Scaffold(
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
                    const SizedBox(height: 24),
                    CodeBoxes(
                      controller: _code,
                      invalidMessage: l10n.codeInvalidFormat,
                      enabled: state.entryOpen && !state.busy,
                      accent: KitColors.danger,
                      onSubmitted: () {
                        if (_ready(state)) {
                          _delete();
                        }
                      },
                    ),
                    FailureMessage(state.failure),
                    LockMessage(
                      lockedSeconds: state.lockedSeconds,
                      lockOver: state.lockOver,
                    ),
                    if (state.lockOver)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          l10n.codeLockOver,
                          key: const ValueKey<String>('lock-over-message'),
                        ),
                      ),
                    const SizedBox(height: 12),
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
                            ? l10n.resendIn(
                                formatCountdown(state.resendInSeconds),
                              )
                            : l10n.resendCode,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FilledButton(
                key: const ValueKey<String>('delete-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: KitColors.danger.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _ready(state) ? _delete : null,
                child: Text(
                  l10n.profileDeleteAccount,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
