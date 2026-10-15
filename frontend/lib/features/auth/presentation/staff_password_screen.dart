import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/staff_password_controller.dart';
import 'auth_scaffold.dart';
import 'password_field.dart';

/// Screen 07 of `kit/01-vhod`: the phone is confirmed with the Telegram code,
/// and a Shopper or Courier adds the password. The back arrow gives the step
/// up and continues as the Customer.
class StaffPasswordScreen extends ConsumerStatefulWidget {
  const StaffPasswordScreen({super.key});

  @override
  ConsumerState<StaffPasswordScreen> createState() =>
      _StaffPasswordScreenState();
}

class _StaffPasswordScreenState extends ConsumerState<StaffPasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SessionController session = ref.read(
      sessionControllerProvider.notifier,
    );
    final StaffPasswordController controller = ref.read(
      staffPasswordControllerProvider.notifier,
    );

    final bool done = await controller.submit(_password.text);

    // A step the server no longer accepts is gone from the session, which
    // continues as the Customer; the way to a fresh code stays in reach.
    if (!done && controller.stepGone) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.staffStepExpired),
            action: SnackBarAction(
              label: l10n.getNewCodeButton,
              onPressed: () => session.logout(SessionMode.customer),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(staffPasswordControllerProvider);
    final ApiFailure? failure = state.failure;
    final bool wrongPassword =
        failure is ApiRefusal && failure.code == 'invalid_credentials';

    return AuthScaffold(
      title: l10n.staffPasswordTitle,
      subtitle: l10n.staffPasswordSubtitle,
      wordmark: false,
      onBack: state.isBusy
          ? null
          : () =>
                ref.read(sessionControllerProvider.notifier).dismissStaffStep(),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PasswordField(
                fieldKey: const ValueKey<String>('staff-password-field'),
                controller: _password,
                enabled: !state.isBusy,
                autofocus: true,
                textInputAction: TextInputAction.done,
                errorText: wrongPassword ? l10n.staffPasswordWrong : null,
                validator: (String? value) =>
                    (value ?? '').isEmpty ? l10n.passwordRequired : null,
                onSubmitted: (String _) => _submit(),
              ),
              if (!wrongPassword) FailureMessage(failure),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey<String>('staff-password-submit'),
                onPressed: state.isBusy ? null : _submit,
                child: Text(l10n.loginButton),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.staffPasswordForgot,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: KitColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
