import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/session/session_state.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/change_password_controller.dart';
import 'auth_scaffold.dart';

/// The password rule of `docs/09-api-contracts.md` section 10.
const int passwordMinLength = 10;
const int passwordMaxLength = 128;

/// Step 4 of `docs/04-user-flows.md` section 3: the temporary password is
/// replaced before anything else opens. The gate clears on success and the
/// router moves on to the role shell.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _fresh = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _fresh.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool changed = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(
          currentPassword: _current.text,
          newPassword: _fresh.text,
          newPasswordConfirmation: _confirmation.text,
        );

    if (changed) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(changePasswordControllerProvider);

    return AuthScaffold(
      title: l10n.changePasswordTitle,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.changePasswordRequiredIntro),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey<String>('current-password-field'),
                controller: _current,
                obscureText: true,
                autofocus: true,
                autofillHints: const <String>[AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l10n.currentPasswordLabel,
                ),
                validator: (String? value) =>
                    (value ?? '').isEmpty ? l10n.passwordRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('new-password-field'),
                controller: _fresh,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.newPasswordLabel,
                  helperText: l10n.passwordRuleHint,
                ),
                validator: (String? value) {
                  final int length = (value ?? '').length;
                  return length < passwordMinLength ||
                          length > passwordMaxLength
                      ? l10n.passwordRuleHint
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('confirm-password-field'),
                controller: _confirmation,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.confirmPasswordLabel,
                ),
                validator: (String? value) =>
                    value != _fresh.text ? l10n.passwordsDoNotMatch : null,
                onFieldSubmitted: (String _) => _submit(),
              ),
              FailureMessage(state.failure),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('save-password-button'),
                onPressed: state.isBusy ? null : _submit,
                child: Text(l10n.savePasswordButton),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey<String>('logout-button'),
                onPressed: () => ref
                    .read(sessionControllerProvider.notifier)
                    .logout(SessionMode.staff),
                child: Text(l10n.logoutButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
