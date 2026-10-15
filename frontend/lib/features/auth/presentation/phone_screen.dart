import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/code_login_controller.dart';
import 'auth_scaffold.dart';
import 'confirm_phone_dialog.dart';
import 'phone_field.dart';

/// Step 1 of `docs/04-user-flows.md` section 2 (screen 02 of
/// `kit/01-vhod`): the Customer's phone. The number is read back in a dialog
/// before the code is requested.
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
    final String? phone = state.phone;
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

    final bool sent = await showConfirmPhoneDialog(
      context,
      phone: phone,
      onSend: () =>
          ref.read(codeLoginControllerProvider.notifier).requestCode(phone),
    );

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
      subtitle: l10n.customerLoginIntro,
      footer: Text(
        l10n.termsLine,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          height: 1.55,
          color: KitColors.muted,
        ),
      ),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PhoneField(
                controller: _phone,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (String _) => _submit(),
              ),
              FailureMessage(state.failure),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey<String>('continue-button'),
                onPressed: state.busy ? null : _submit,
                child: Text(l10n.getCodeButton),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const _TelegramMark(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.codeComesInTelegram,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KitColors.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Telegram mark without an asset: a blue disc with a white paper plane.
class _TelegramMark extends StatelessWidget {
  const _TelegramMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Color(0xFF2AABEE),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: -0.5236,
          child: const Icon(Icons.send_rounded, size: 11, color: Colors.white),
        ),
      ),
    );
  }
}
