import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/customer_name_controller.dart';
import 'auth_scaffold.dart';
import 'welcome_dialog.dart';

/// Screen 05 of `kit/01-vhod`: a new Customer gives the name the Shopper and
/// the Courier will see. Saving it opens the Customer area behind a welcome.
class CustomerNameScreen extends ConsumerStatefulWidget {
  const CustomerNameScreen({super.key});

  @override
  ConsumerState<CustomerNameScreen> createState() => _CustomerNameScreenState();
}

class _CustomerNameScreenState extends ConsumerState<CustomerNameScreen> {
  static const int _maxNameLength = 120;

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String name = _name.text.trim();
    final CustomerNameController controller = ref.read(
      customerNameControllerProvider.notifier,
    );

    // The name is saved, but the Customer area opens only once the welcome
    // is read: it replaces this screen, and the welcome with it.
    final bool saved = await controller.rename(name);

    if (saved && mounted) {
      await showWelcomeDialog(context, name: name);
      controller.finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(customerNameControllerProvider);

    return AuthScaffold(
      title: l10n.nameTitle,
      subtitle: l10n.nameSubtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              key: const ValueKey<String>('customer-name-field'),
              controller: _name,
              enabled: !state.isBusy,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.name],
              decoration: InputDecoration(
                hintText: l10n.profileName,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              validator: (String? text) {
                final String value = (text ?? '').trim();
                if (value.isEmpty) {
                  return l10n.fieldRequired;
                }
                return value.runes.length > _maxNameLength
                    ? l10n.fieldTooLong(_maxNameLength)
                    : null;
              },
              onFieldSubmitted: (String _) => _submit(),
            ),
            FailureMessage(state.failure),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey<String>('customer-name-continue'),
              onPressed: state.isBusy ? null : _submit,
              child: Text(l10n.continueButton),
            ),
          ],
        ),
      ),
    );
  }
}
