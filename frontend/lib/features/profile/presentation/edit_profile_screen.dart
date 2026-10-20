import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../application/profile_controllers.dart';
import '../domain/profile.dart';
import 'initials.dart';

/// The kit name editor (`DL-96` item 4): only the name changes; the phone is
/// shown locked, as it is the sign-in.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerProfile> profile = ref.watch(
      profileControllerProvider,
    );

    return Scaffold(
      key: const ValueKey<String>('edit-profile'),
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: l10n.profileEditTitle),
      body: SafeArea(
        child: profile.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          data: (CustomerProfile profile) =>
              _EditForm(key: ValueKey<String>(profile.id), profile: profile),
          error: (Object error, StackTrace _) => ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              FailureMessage(
                error is ApiFailure ? error : const UnexpectedFailure(),
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(profileControllerProvider),
                  child: Text(l10n.retryButton),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.profile, super.key});

  final CustomerProfile profile;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  static const int _maxLength = 120;

  late final TextEditingController _name = TextEditingController(
    text: widget.profile.fullName ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: formatPhone(widget.profile.phone),
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (name == widget.profile.fullName) {
      context.pop();
      return;
    }
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String saved = AppLocalizations.of(context).profileSaved;

    final CustomerProfile? result = await ref
        .read(renameControllerProvider.notifier)
        .rename(widget.profile, name);
    // A save for another account says nothing, and neither does one the
    // Customer has moved on from.
    if (result != null &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      router.pop();
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    }
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState rename = ref.watch(renameControllerProvider);

    return ListenableBuilder(
      listenable: _name,
      builder: (BuildContext context, Widget? _) {
        final bool empty = _name.text.trim().isEmpty;
        final String? initials = initialsOf(_name.text);
        final Color nameColor = empty ? KitColors.danger : KitColors.primary;

        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: KitColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: initials == null
                          ? const Icon(
                              Icons.person,
                              size: 36,
                              color: KitColors.primaryDark,
                            )
                          : Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: KitColors.primaryDark,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    key: const ValueKey<String>('profile-name-field'),
                    controller: _name,
                    enabled: !rename.isBusy,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(_maxLength),
                    ],
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (String _) => _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.profileNameLabel,
                      errorText: empty ? l10n.profileNameRequired : null,
                      errorMaxLines: 3,
                      border: _border(nameColor),
                      enabledBorder: _border(nameColor),
                      focusedBorder: _border(nameColor),
                      errorBorder: _border(KitColors.danger),
                      focusedErrorBorder: _border(KitColors.danger),
                      disabledBorder: _border(KitColors.line),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey<String>('profile-phone-field'),
                    controller: _phone,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    style: const TextStyle(color: KitColors.ink2),
                    decoration: InputDecoration(
                      labelText: l10n.profilePhoneLabel,
                      filled: true,
                      fillColor: KitColors.field,
                      suffixIcon: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: KitColors.muted,
                      ),
                      border: _border(KitColors.line),
                      enabledBorder: _border(KitColors.line),
                      focusedBorder: _border(KitColors.line),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.profilePhoneLocked,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.muted,
                    ),
                  ),
                  FailureMessage(rename.failure),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  key: const ValueKey<String>('profile-save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KitColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: empty || rename.isBusy ? null : _submit,
                  child: rename.isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.saveButton),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
