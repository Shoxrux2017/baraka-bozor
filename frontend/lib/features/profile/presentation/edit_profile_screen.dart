import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/submit_button.dart';
import '../application/profile_controllers.dart';
import '../domain/profile.dart';
import 'initials.dart';

/// The kit name editor (`DL-96` item 4, `DL-135`): it opens ready to type, the
/// save button wakes only when the name differs, and the phone is plain text
/// as it is the sign-in.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerProfile> profile = ref.watch(
      profileControllerProvider,
    );
    final bool hasName = (profile.value?.fullName ?? '').trim().isNotEmpty;

    return Scaffold(
      key: const ValueKey<String>('edit-profile'),
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: hasName ? l10n.profileChangeName : l10n.profileSetName,
      ),
      body: SafeArea(
        child: profile.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          skipError: true,
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

  late final String _saved = widget.profile.fullName ?? '';
  late final TextEditingController _name = TextEditingController(text: _saved)
    ..selection = TextSelection.collapsed(offset: _saved.length);
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// What the save button shows: busy while a rename is on its way, off while
  /// the name is empty or the saved one, ready otherwise.
  ({SubmitFace face, String label, String? hint}) _button(
    AppLocalizations l10n,
    MutationState rename,
  ) {
    final String name = _name.text.trim();
    if (rename.isBusy) {
      return (face: SubmitFace.busy, label: l10n.saveButton, hint: null);
    }
    if (name.isEmpty) {
      return (face: SubmitFace.off, label: l10n.profileNameEnter, hint: null);
    }
    if (name == _saved) {
      return (
        face: SubmitFace.off,
        label: l10n.saveButton,
        hint: l10n.profileNameUnchanged,
      );
    }
    return (face: SubmitFace.ready, label: l10n.saveButton, hint: null);
  }

  Future<void> _submit() async {
    final String name = _name.text.trim();
    if (name.isEmpty || name == _saved) {
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

  void _clear() {
    _name.clear();
    _focus.requestFocus();
    announce(context, AppLocalizations.of(context).profileNameCleared);
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState rename = ref.watch(renameControllerProvider);
    final bool keyboardUp = View.of(context).viewInsets.bottom > 0;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_name, _focus]),
      builder: (BuildContext context, Widget? _) {
        final String? initials = initialsOf(_name.text);
        final bool focused = _focus.hasFocus;
        final ({SubmitFace face, String label, String? hint}) button = _button(
          l10n,
          rename,
        );
        final TextStyle labelStyle = TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: focused ? KitColors.primaryDark : KitColors.muted,
        );

        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: <Widget>[
                  ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _focus.unfocus,
                      child: Center(
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
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    hint: l10n.profileNameHelper,
                    child: TextField(
                      key: const ValueKey<String>('profile-name-field'),
                      controller: _name,
                      focusNode: _focus,
                      autofocus: true,
                      enabled: !rename.isBusy,
                      inputFormatters: <TextInputFormatter>[
                        LengthLimitingTextInputFormatter(_maxLength),
                      ],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 16,
                        color: KitColors.ink,
                      ),
                      onSubmitted: (String _) {
                        if (button.face == SubmitFace.ready) {
                          _submit();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: l10n.profileNameLabel,
                        labelStyle: labelStyle,
                        floatingLabelStyle: labelStyle,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        helper: ExcludeSemantics(
                          child: Text(
                            l10n.profileNameHelper,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: KitColors.muted,
                            ),
                          ),
                        ),
                        helperMaxLines: 3,
                        constraints: const BoxConstraints(minHeight: 58),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: _border(KitColors.fieldEdge, 1),
                        enabledBorder: _border(KitColors.fieldEdge, 1),
                        disabledBorder: _border(KitColors.fieldEdge, 1),
                        focusedBorder: _border(KitColors.primary, 2),
                        suffixIconConstraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        suffixIcon: focused && _name.text.isNotEmpty
                            ? IconButton(
                                key: const ValueKey<String>(
                                  'profile-name-clear',
                                ),
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                tooltip: l10n.profileClearName,
                                color: KitColors.muted,
                                icon: const Icon(Icons.cancel),
                                onPressed: _clear,
                              )
                            : null,
                      ),
                    ),
                  ),
                  _PhoneBlock(phone: widget.profile.phone),
                  FailureMessage(rename.failure),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, keyboardUp ? 12 : 28),
              child: SubmitButton(
                buttonKey: const ValueKey<String>('profile-save'),
                face: button.face,
                label: button.label,
                offHint: button.hint,
                onPressed: _submit,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The sign-in number as plain text under a hairline: no field, no focus, read
/// by a screen reader as one phrase (`DL-135`).
class _PhoneBlock extends StatelessWidget {
  const _PhoneBlock({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String formatted = formatPhone(phone);

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Semantics(
        container: true,
        label: l10n.profilePhoneSpoken(
          l10n.profilePhoneLabel,
          formatted,
          l10n.profilePhoneLocked,
        ),
        excludeSemantics: true,
        child: Container(
          key: const ValueKey<String>('profile-phone-block'),
          padding: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: KitColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.profilePhoneLabel,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: KitColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      formatted,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: KitColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.profilePhoneLocked,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
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
