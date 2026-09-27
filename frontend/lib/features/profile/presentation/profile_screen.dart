import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/profile_controllers.dart';
import '../domain/profile.dart';

/// The Customer's profile (`docs/03-features.md` section 3): the phone they
/// sign in with, their name — which checkout needs — the interface language,
/// and the way to their addresses.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerProfile> profile = ref.watch(
      profileControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SafeArea(
        child: UnderActiveMode(
          child: profile.when(
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: !profile.hasError,
            data: (CustomerProfile profile) => ListView(
              key: const ValueKey<String>('profile-list'),
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  formatPhone(profile.phone),
                  key: const ValueKey<String>('profile-phone'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _NameForm(key: ValueKey<String>(profile.id), profile: profile),
                const SizedBox(height: 24),
                const _LanguageChoice(),
                const Divider(height: 32),
                ListTile(
                  key: const ValueKey<String>('profile-addresses'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.home_outlined),
                  title: Text(l10n.addressesTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppPaths.customerAddresses),
                ),
              ],
            ),
            error: (Object error, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FailureMessage(
                      error is ApiFailure ? error : const UnexpectedFailure(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(profileControllerProvider),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

class _NameForm extends ConsumerStatefulWidget {
  const _NameForm({required this.profile, super.key});

  final CustomerProfile profile;

  @override
  ConsumerState<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends ConsumerState<_NameForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.fullName ?? '',
  );

  @override
  void didUpdateWidget(_NameForm old) {
    super.didUpdateWidget(old);
    // A reload brings the name as the server has it; a name the Customer is
    // still typing stays (`DL-28` (9)).
    if (_name.text == (old.profile.fullName ?? '')) {
      _name.text = widget.profile.fullName ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = _name.text.trim();
    if (name == widget.profile.fullName) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noChanges)));
      return;
    }

    final CustomerProfile? saved = await ref
        .read(renameControllerProvider.notifier)
        .rename(widget.profile, name);
    // A save for another account says nothing, and neither does one the
    // Customer has moved on from — to the addresses above the profile.
    if (saved != null &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState rename = ref.watch(renameControllerProvider);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            key: const ValueKey<String>('profile-name'),
            controller: _name,
            enabled: !rename.isBusy,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (String _) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.profileName,
              helperText: widget.profile.fullName == null
                  ? l10n.profileNameNeeded
                  : null,
              border: const OutlineInputBorder(),
            ),
            validator: (String? text) {
              final String value = (text ?? '').trim();
              if (value.isEmpty) {
                return l10n.fieldRequired;
              }
              return value.runes.length > 120 ? l10n.fieldTooLong(120) : null;
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey<String>('profile-save'),
              onPressed: rename.isBusy ? null : _submit,
              child: Text(l10n.saveButton),
            ),
          ),
          FailureMessage(rename.failure),
        ],
      ),
    );
  }
}

/// The interface language, the same choice as the app bar's switch: stored
/// on the device and reported to the server for push texts
/// (`docs/07-architecture.md` section 27).
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage? current = ref.watch(languageControllerProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.languageLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<AppLanguage>(
          key: const ValueKey<String>('profile-language'),
          segments: <ButtonSegment<AppLanguage>>[
            ButtonSegment<AppLanguage>(
              value: AppLanguage.uz,
              label: Text(l10n.languageUzbek),
            ),
            ButtonSegment<AppLanguage>(
              value: AppLanguage.ru,
              label: Text(l10n.languageRussian),
            ),
          ],
          selected: <AppLanguage>{?current},
          emptySelectionAllowed: true,
          onSelectionChanged: (Set<AppLanguage> selected) {
            if (selected.isNotEmpty) {
              ref
                  .read(languageControllerProvider.notifier)
                  .select(selected.single);
            }
          },
        ),
      ],
    );
  }
}
