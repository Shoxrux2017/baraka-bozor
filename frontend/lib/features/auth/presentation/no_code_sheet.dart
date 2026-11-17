import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/countdown_format.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_sheet.dart';
import '../../../core/widgets/submit_button.dart';
import '../application/code_login_controller.dart';
import 'auth_notice.dart';
import 'code_entry.dart';

/// The «Не пришёл код?» sheet (`DL-139`): where to look for the code, a new
/// code, and a way to change the number. Resolves true when a new code was
/// sent; «Изменить номер» closes the sheet and then pops the code page.
Future<bool> showNoCodeSheet(BuildContext context) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  bool changeNumber = false;
  final bool? sent = await showKitSheet<bool>(
    context,
    title: l10n.codeNotArrived,
    sheetKey: 'no-code-sheet',
    builder: (BuildContext sheet) => _NoCodeBody(
      onChangePhone: () {
        changeNumber = true;
        Navigator.of(sheet).pop(false);
      },
    ),
  );
  if (changeNumber && context.mounted) {
    await Navigator.of(context).maybePop();
  }
  return sent ?? false;
}

class _NoCodeBody extends ConsumerWidget {
  const _NoCodeBody({required this.onChangePhone});

  final VoidCallback onChangePhone;

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    final bool sent = await ref
        .read(codeLoginControllerProvider.notifier)
        .resend();
    if (!sent || !context.mounted) {
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
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = ref.watch(codeLoginControllerProvider);
    final String phone = formatPhone(state.phone ?? '');
    final bool telegram =
        RequestedCodeChannel.of(state.requested?.channel) ==
        RequestedCodeChannel.telegram;
    final bool sending = state.running == CodeLoginAction.resend;

    final ApiFailure? failure = state.failedAction == CodeLoginAction.resend
        ? state.failure
        : null;
    final bool hourLimit =
        failure is ApiRefusal &&
        failure.code == 'rate_limited' &&
        failure.error.details['limit'] == 'phone_hourly';

    final SubmitFace face;
    final String label;
    if (sending) {
      face = SubmitFace.busy;
      label = l10n.sendingCode;
    } else if (state.resendInSeconds > 0) {
      face = SubmitFace.off;
      label = l10n.resendIn(formatCountdown(state.resendInSeconds));
    } else if (hourLimit) {
      face = SubmitFace.off;
      label = l10n.resendCode;
    } else {
      // Off too when a lock started while the sheet was open.
      face = state.canResend ? SubmitFace.ready : SubmitFace.off;
      label = l10n.resendCode;
    }

    return PopScope(
      canPop: !sending,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              telegram
                  ? l10n.codeNotArrivedText(phone)
                  : l10n.codeNotArrivedTextOther(phone),
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: KitColors.ink2,
              ),
            ),
            if (failure != null)
              AuthNotice(
                view: authNoticeOf(
                  l10n,
                  failure,
                  phone: state.phone ?? '',
                  place: AuthNoticePlace.code,
                ),
                onAction: (AuthNoticeAction action) {
                  switch (action) {
                    case AuthNoticeAction.retry:
                      _resend(context, ref);
                    case AuthNoticeAction.changeNumber:
                      if (!sending) {
                        onChangePhone();
                      }
                    case AuthNoticeAction.otherNumber ||
                        AuthNoticeAction.newCode:
                      break;
                  }
                },
              ),
            const SizedBox(height: 20),
            SubmitButton(
              buttonKey: const ValueKey<String>('resend-button'),
              face: face,
              label: label,
              onPressed: () => _resend(context, ref),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey<String>('no-code-change-phone'),
              onPressed: sending ? null : onChangePhone,
              style: TextButton.styleFrom(
                foregroundColor: KitColors.primaryDark,
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(l10n.changePhone),
            ),
          ],
        ),
      ),
    );
  }
}
