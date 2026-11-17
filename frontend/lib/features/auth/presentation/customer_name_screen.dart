import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/session/session_state.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/submit_button.dart';
import '../application/customer_name_controller.dart';
import '../application/welcome_notice.dart';
import 'auth_notice.dart';
import 'auth_scaffold.dart';

/// Screen 05 of `kit/01-vhod`: a new Customer gives the name the Shopper and
/// the Courier will see. The button waits for a letter; a saved name shows ✓
/// «Готово» for 500 ms and opens the home, which welcomes the Customer with a
/// strip (`DL-139`).
class CustomerNameScreen extends ConsumerStatefulWidget {
  const CustomerNameScreen({super.key});

  @override
  ConsumerState<CustomerNameScreen> createState() => _CustomerNameScreenState();
}

class _CustomerNameScreenState extends ConsumerState<CustomerNameScreen> {
  static const int _maxNameLength = 120;
  static const Duration _savedHold = Duration(milliseconds: 500);
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final GlobalKey _buttonKey = GlobalKey();
  final TextEditingController _name = TextEditingController();

  /// The name is saved and the ✓ is on show.
  bool _saved = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _hasLetter => _letter.hasMatch(_name.text.trim());

  Future<void> _submit() async {
    if (_saved) {
      return;
    }
    if (!(_form.currentState?.validate() ?? false) || !_hasLetter) {
      return;
    }
    final String name = _name.text.trim();
    final String? account = ref.read(customerAccountProvider);
    final CustomerNameController controller = ref.read(
      customerNameControllerProvider.notifier,
    );
    final WelcomeNotice welcome = ref.read(welcomeNoticeProvider.notifier);

    // The name is saved, but the Customer area opens only after the ✓: it
    // replaces this screen, and the session with it.
    final bool saved = await controller.rename(name);
    if (!saved || !mounted) {
      return;
    }
    setState(() => _saved = true);
    await Future<void>.delayed(_savedHold);
    if (!mounted) {
      return;
    }
    if (account != null) {
      welcome.show(Welcome(accountId: account, name: name));
    }
    controller.finish();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(customerNameControllerProvider);
    final bool hasStaffSession = switch (ref
        .watch(sessionControllerProvider)
        .value) {
      final SignedIn signedIn => signedIn.staffUser != null,
      _ => false,
    };
    final ApiFailure? failure = state.failure;
    final bool still = state.isBusy || _saved;

    const TextStyle linkStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final ButtonStyle linkButton = TextButton.styleFrom(
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: linkStyle,
    );

    return AuthScaffold(
      title: l10n.nameTitle,
      subtitle: l10n.nameSubtitle,
      keepVisible: _buttonKey,
      child: Form(
        key: _form,
        child: ListenableBuilder(
          listenable: _name,
          builder: (BuildContext context, Widget? _) {
            final SubmitFace face = _saved
                ? SubmitFace.done
                : state.isBusy
                ? SubmitFace.busy
                : _hasLetter
                ? SubmitFace.ready
                : SubmitFace.off;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: ExcludeSemantics(
                    child: Text(
                      l10n.nameLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KitColors.ink2,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  label: l10n.fieldRequiredSpoken(l10n.nameLabel),
                  child: TextFormField(
                    key: const ValueKey<String>('customer-name-field'),
                    controller: _name,
                    enabled: !still,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.name],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                    decoration: InputDecoration(
                      // The example is a hint widget, so no reader says it as
                      // if it were the name.
                      hint: ExcludeSemantics(
                        child: Text(
                          l10n.nameExample,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: KitColors.muted,
                          ),
                        ),
                      ),
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
                ),
                if (failure != null)
                  AuthNotice(
                    view: authNoticeOf(
                      l10n,
                      failure,
                      phone: '',
                      place: AuthNoticePlace.name,
                    ),
                    onAction: (AuthNoticeAction _) => _submit(),
                  ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _buttonKey,
                  child: SubmitButton(
                    buttonKey: const ValueKey<String>('customer-name-continue'),
                    face: face,
                    label: switch (face) {
                      SubmitFace.busy => l10n.nameSaving,
                      SubmitFace.done => l10n.nameSaved,
                      _ => l10n.continueButton,
                    },
                    offHint: l10n.nameOffHint,
                    onPressed: _submit,
                  ),
                ),
                if (hasStaffSession) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey<String>('customer-name-to-staff'),
                    style: linkButton.copyWith(
                      foregroundColor: const WidgetStatePropertyAll<Color>(
                        KitColors.primaryDark,
                      ),
                    ),
                    onPressed: still
                        ? null
                        : () => ref
                              .read(sessionControllerProvider.notifier)
                              .switchMode(SessionMode.staff),
                    child: Text(l10n.switchToStaff),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey<String>('customer-name-logout'),
                  style: linkButton.copyWith(
                    foregroundColor: const WidgetStatePropertyAll<Color>(
                      KitColors.muted,
                    ),
                  ),
                  onPressed: still
                      ? null
                      : () => ref
                            .read(sessionControllerProvider.notifier)
                            .logout(SessionMode.customer),
                  child: Text(l10n.nameOtherNumber),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
