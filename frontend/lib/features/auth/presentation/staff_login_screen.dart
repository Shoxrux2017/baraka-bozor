import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/staff_login_controller.dart';
import 'auth_scaffold.dart';
import 'phone_field.dart';

/// Steps 1 and 2 of `docs/04-user-flows.md` section 3: phone and password.
/// On success the session changes and the router moves on.
class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String? phone = PhoneField.phoneOf(_phone);
    if (phone == null) {
      return;
    }
    await ref
        .read(staffLoginControllerProvider.notifier)
        .login(phone: phone, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(staffLoginControllerProvider);

    return AuthScaffold(
      title: l10n.staffLoginTitle,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PhoneField(controller: _phone, autofocus: true),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('password-field'),
                controller: _password,
                obscureText: true,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l10n.passwordLabel),
                validator: (String? value) =>
                    (value ?? '').isEmpty ? l10n.passwordRequired : null,
                onFieldSubmitted: (String _) => _submit(),
              ),
              FailureMessage(state.failure),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('login-button'),
                onPressed: state.isBusy ? null : _submit,
                child: Text(l10n.loginButton),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey<String>('customer-login-link'),
                onPressed: () => context.go(AppPaths.auth),
                child: Text(l10n.customerLoginLink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
