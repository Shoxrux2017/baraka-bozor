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

    return NoCodeSheetBody(
      text: telegram
          ? l10n.codeNotArrivedText(phone)
          : l10n.codeNotArrivedTextOther(phone),
      phone: state.phone ?? '',
      sending: state.running == CodeLoginAction.resend,
      resendInSeconds: state.resendInSeconds,
      canResend: state.canResend,
      failure: state.failedAction == CodeLoginAction.resend
          ? state.failure
          : null,
      place: AuthNoticePlace.code,
      onResend: () => _resend(context, ref),
      onChangePhone: onChangePhone,
    );
  }
}

/// The body of a «Не пришёл код?» sheet (`DL-139`, shared by the account
/// deletion in `DL-140`): [text] on where to look, a notice for a refused
/// [failure], the resend button and, only with [onChangePhone], «Изменить
/// номер». [phone] is the E.164 number the code went to. A notice's retry
/// calls [onResend].
class NoCodeSheetBody extends StatelessWidget {
  const NoCodeSheetBody({
    required this.text,
    required this.phone,
    required this.sending,
    required this.resendInSeconds,
    required this.canResend,
    required this.failure,
    required this.place,
    required this.onResend,
    this.onChangePhone,
    super.key,
  });

  final String text;
  final String phone;
  final bool sending;
  final int resendInSeconds;
  final bool canResend;
  final ApiFailure? failure;
  final AuthNoticePlace place;
  final VoidCallback onResend;
  final VoidCallback? onChangePhone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ApiFailure? shown = failure;
    final bool hourLimit =
        shown is ApiRefusal &&
        shown.code == 'rate_limited' &&
        shown.error.details['limit'] == 'phone_hourly';

    final SubmitFace face;
    final String label;
    if (sending) {
      face = SubmitFace.busy;
      label = l10n.sendingCode;
    } else if (resendInSeconds > 0) {
      face = SubmitFace.off;
      label = l10n.resendIn(formatCountdown(resendInSeconds));
    } else if (hourLimit) {
      face = SubmitFace.off;
      label = l10n.resendCode;
    } else {
      // Off too when a lock started while the sheet was open.
      face = canResend ? SubmitFace.ready : SubmitFace.off;
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
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: KitColors.ink2,
              ),
            ),
            if (shown != null)
              AuthNotice(
                view: authNoticeOf(l10n, shown, phone: phone, place: place),
                onAction: (AuthNoticeAction action) {
                  switch (action) {
                    case AuthNoticeAction.retry:
                      onResend();
                    case AuthNoticeAction.changeNumber:
                      if (!sending) {
                        onChangePhone?.call();
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
              onPressed: onResend,
            ),
            if (onChangePhone case final VoidCallback change) ...<Widget>[
              const SizedBox(height: 6),
              TextButton(
                key: const ValueKey<String>('no-code-change-phone'),
                onPressed: sending ? null : change,
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
          ],
        ),
      ),
    );
  }
}
