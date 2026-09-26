import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/code_login_controller.dart';
import 'auth_scaffold.dart';
import 'phone_field.dart';

/// Step 1 of `docs/04-user-flows.md` section 2: the Customer's phone.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final CodeLoginState state = ref.read(codeLoginControllerProvider);
    final String? phone = state.forStaffAccount ? null : state.phone;
    _phone = TextEditingController(
      text: phone == null ? '' : phone.substring(phoneCountryCode.length),
    );
  }

  @override
  void dispose() {
    _phone.dispose();
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

    final bool sent = await ref
        .read(codeLoginControllerProvider.notifier)
        .requestCode(phone);

    // Only the request that is still current reports success, and the
    // screen may have gone while it ran.
    if (sent && mounted) {
      context.go(AppPaths.customerCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CodeLoginState state = ref.watch(codeLoginControllerProvider);

    return AuthScaffold(
      title: l10n.customerLoginTitle,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.customerLoginIntro),
              const SizedBox(height: 24),
              PhoneField(
                controller: _phone,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (String _) => _submit(),
              ),
              FailureMessage(state.failure),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('continue-button'),
                onPressed: state.busy ? null : _submit,
                child: Text(l10n.continueButton),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey<String>('staff-login-link'),
                onPressed: () => context.go(AppPaths.staffLogin),
                child: Text(l10n.staffLoginLink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
