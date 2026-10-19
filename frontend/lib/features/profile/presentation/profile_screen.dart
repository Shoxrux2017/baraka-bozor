import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../legal/application/legal_providers.dart';
import '../../legal/domain/legal.dart';
import '../application/profile_controllers.dart';
import '../domain/profile.dart';
import 'delete_account_sheets.dart';
import 'language_sheet.dart';
import 'profile_header.dart';

/// The Customer's profile tab (`docs/03-features.md` section 3, kit drawings
/// 32 and 32а): the header with the initials, the name and the phone; the rows
/// for the name, the addresses, the language, support, the two documents and
/// the deletion; and the way out of the session under them (`DL-75`,
/// `DL-96` item 6).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerProfile> profile = ref.watch(
      profileControllerProvider,
    );

    return CustomerTabScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: const CustomerTabBar(current: CustomerTab.profile),
        body: Column(
          children: <Widget>[
            // The header runs up under the status bar.
            ColoredBox(
              color: KitColors.primary,
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.paddingOf(context).top,
              ),
            ),
            Expanded(
              child: UnderActiveMode(
                child: profile.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: !profile.hasError,
                  data: (CustomerProfile profile) => ListView(
                    key: const ValueKey<String>('profile-list'),
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      ProfileHeader(profile: profile),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: _Rows(profile: profile),
                      ),
                      const _LogoutButton(),
                    ],
                  ),
                  // The language and the way out are on the profile in every
                  // state of it.
                  error: (Object error, StackTrace _) => ListView(
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      const _PlainTitle(),
                      FailureMessage(
                        error is ApiFailure ? error : const UnexpectedFailure(),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(profileControllerProvider),
                          child: Text(l10n.retryButton),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _LanguageRow(),
                      const _LogoutButton(),
                    ],
                  ),
                  loading: () => ListView(
                    padding: const EdgeInsets.all(20),
                    children: const <Widget>[
                      _PlainTitle(),
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                      SizedBox(height: 120),
                      _LanguageRow(),
                      _LogoutButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title over a profile that has no header yet.
class _PlainTitle extends StatelessWidget {
  const _PlainTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Semantics(
        header: true,
        child: Text(
          AppLocalizations.of(context).profileTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
      ),
    );
  }
}

/// The rows under the header, a line between each pair.
class _Rows extends ConsumerWidget {
  const _Rows({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LegalIndex? documents = ref.watch(legalIndexProvider).value;
    final SessionState? session = ref.watch(sessionControllerProvider).value;
    final String? support = profile.supportPhone;
    final String? name = profile.fullName;
    final bool hasName = name != null && name.trim().isNotEmpty;

    final List<Widget> rows = <Widget>[
      _ProfileRow(
        rowKey: 'profile-edit',
        icon: Icons.edit_square,
        title: hasName ? l10n.profileEdit : l10n.profileSetName,
        onTap: () => context.push(AppPaths.customerEditProfile),
      ),
      _ProfileRow(
        rowKey: 'profile-addresses',
        icon: Icons.location_on,
        title: l10n.addressesTitle,
        onTap: () => context.push(AppPaths.customerAddresses),
      ),
      const _LanguageRow(),
      if (support != null && support.isNotEmpty)
        _ProfileRow(
          rowKey: 'profile-support',
          icon: Icons.support_agent,
          title: l10n.profileSupport,
          value: formatPhone(support),
          chevron: false,
          onTap: () => _call(context, ref, support),
        ),
      if (documents?.privacy != null)
        _ProfileRow(
          rowKey: 'profile-privacy',
          icon: Icons.verified_user,
          title: l10n.profilePrivacy,
          onTap: () => context.push(AppPaths.legal(LegalDocumentKind.privacy)),
        ),
      if (documents?.terms != null)
        _ProfileRow(
          rowKey: 'profile-terms',
          icon: Icons.event_note,
          title: l10n.legalTerms,
          onTap: () => context.push(AppPaths.legal(LegalDocumentKind.terms)),
        ),
      // A staff sign-in shares the phone, so deleting the account would
      // erase it too (`DL-96`).
      if (session is SignedIn && session.staffUser == null)
        _ProfileRow(
          rowKey: 'profile-delete',
          icon: Icons.delete,
          title: l10n.profileDeleteAccount,
          color: KitColors.danger,
          chevron: false,
          onTap: () => showDeleteAccountSheet(context),
        ),
    ];

    return Column(
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          rows[i],
          if (i < rows.length - 1)
            const Divider(height: 1, thickness: 1, color: KitColors.line),
        ],
      ],
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String phone) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool opened = await ref.read(phoneCallsProvider).call(phone);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.callFailed(formatPhone(phone)))),
      );
    }
  }
}

/// The language row, with the chosen language as its value; it opens the
/// language sheet.
class _LanguageRow extends ConsumerWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage? current = ref.watch(languageControllerProvider).value;

    return _ProfileRow(
      rowKey: 'profile-language',
      icon: Icons.translate,
      title: l10n.profileLanguage,
      value: switch (current) {
        AppLanguage.uz => l10n.languageUzbek,
        AppLanguage.ru => l10n.languageRussian,
        null => null,
      },
      onTap: () => showLanguageSheet(context),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.color = KitColors.ink,
    this.chevron = true,
  });

  final String rowKey;
  final IconData icon;
  final String title;
  final String? value;
  final Color color;
  final bool chevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>(rowKey),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (value != null) ...<Widget>[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: KitColors.muted),
                ),
              ),
            ],
            if (chevron) ...<Widget>[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 22, color: KitColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// The way out of the Customer session, under the rows so it is there
/// whatever state the profile is in.
class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SizedBox(
        height: 56,
        child: FilledButton.icon(
          key: const ValueKey<String>('logout-button'),
          style: FilledButton.styleFrom(
            backgroundColor: KitColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.logout),
          label: Text(AppLocalizations.of(context).logoutButton),
          onPressed: () => ref
              .read(sessionControllerProvider.notifier)
              .logout(state.activeMode),
        ),
      ),
    );
  }
}
