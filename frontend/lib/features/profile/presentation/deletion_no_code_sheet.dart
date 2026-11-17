import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/kit/kit_sheet.dart';
import '../../../app/providers.dart';
import '../../auth/presentation/auth_notice.dart';
import '../../auth/presentation/code_entry.dart';
import '../../auth/presentation/no_code_sheet.dart';
import '../application/account_deletion_controller.dart';

/// The «Не пришёл код?» sheet of the account deletion (`DL-140`): where to
/// look and a new code, with no way to change the number. Resolves true when
/// a new code was sent; the resend is the deletion controller's.
Future<bool> showDeletionNoCodeSheet(BuildContext context) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? sent = await showKitSheet<bool>(
    context,
    title: l10n.codeNotArrived,
    sheetKey: 'delete-no-code-sheet',
    builder: (BuildContext sheet) => const _DeletionNoCodeBody(),
  );
  return sent ?? false;
}

class _DeletionNoCodeBody extends ConsumerWidget {
  const _DeletionNoCodeBody();

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    final bool sent = await ref
        .read(accountDeletionControllerProvider.notifier)
        .resend();
    if (!sent || !context.mounted) {
      return;
    }
    final AccountDeletionState state = ref.read(
      accountDeletionControllerProvider,
    );
    announce(
      context,
      codeSentSpoken(
        AppLocalizations.of(context),
        phone: _phoneOf(ref),
        channel: state.requested?.channel,
      ),
    );
    Navigator.of(context).pop(true);
  }

  String _phoneOf(WidgetRef ref) =>
      ref.read(
        sessionControllerProvider.select((AsyncValue<SessionState> session) {
          final SessionState? current = session.value;
          return current is SignedIn ? current.customerUser?.phone : null;
        }),
      ) ??
      '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AccountDeletionState state = ref.watch(
      accountDeletionControllerProvider,
    );
    final String phone = _phoneOf(ref);
    final bool telegram =
        RequestedCodeChannel.of(state.requested?.channel) ==
        RequestedCodeChannel.telegram;

    return NoCodeSheetBody(
      text: telegram
          ? l10n.deleteNoCodeText(formatPhone(phone))
          : l10n.deleteNoCodeTextOther(formatPhone(phone)),
      phone: phone,
      sending: state.running == DeletionAction.resend,
      resendInSeconds: state.resendInSeconds,
      canResend: state.canResend,
      failure: state.failedAction == DeletionAction.resend
          ? state.failure
          : null,
      place: AuthNoticePlace.deletion,
      onResend: () => _resend(context, ref),
    );
  }
}
