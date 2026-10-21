import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_sheet.dart';
import '../../profile/presentation/language_sheet.dart';

/// A staff area's own actions in one menu of the app bar, opened as a kit
/// sheet: the interface language, the way into Customer mode for a Shopper
/// or a Courier, and the way out. One button keeps the app bar from crowding
/// a phone's width (`DL-69` (5), `DL-98`).
class StaffAreaMenu extends ConsumerWidget {
  const StaffAreaMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn) {
      return const SizedBox.shrink();
    }

    return IconButton(
      key: const ValueKey<String>('staff-menu'),
      icon: const Icon(Icons.more_vert, color: KitColors.ink),
      tooltip: l10n.staffMenu,
      onPressed: () => showKitSheet<void>(
        context,
        title: l10n.staffMenu,
        sheetKey: 'staff-menu-sheet',
        builder: (BuildContext sheet) => _MenuBody(
          offerCustomerMode: state.canOfferCustomerMode,
          activeMode: state.activeMode,
          openLanguage: () => showLanguageSheet(context),
        ),
      ),
    );
  }
}

class _MenuBody extends ConsumerWidget {
  const _MenuBody({
    required this.offerCustomerMode,
    required this.activeMode,
    required this.openLanguage,
  });

  final bool offerCustomerMode;
  final SessionMode activeMode;
  final VoidCallback openLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage? language = ref.watch(languageControllerProvider).value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MenuRow(
            key: const ValueKey<String>('staff-menu-language'),
            icon: Icons.language,
            title: l10n.languageLabel,
            subtitle: language == AppLanguage.ru
                ? l10n.languageRussian
                : l10n.languageUzbek,
            onTap: () {
              Navigator.of(context).pop();
              openLanguage();
            },
          ),
          if (offerCustomerMode)
            _MenuRow(
              key: const ValueKey<String>('switch-to-customer-button'),
              icon: Icons.shopping_bag_outlined,
              title: l10n.switchToCustomer,
              subtitle: l10n.staffCustomerModeHint,
              onTap: () {
                Navigator.of(context).pop();
                // The Customer session opened with the code that signed in,
                // so the switch asks for nothing (`docs/02-user-roles.md`
                // section 10).
                ref
                    .read(sessionControllerProvider.notifier)
                    .switchMode(SessionMode.customer);
              },
            ),
          _MenuRow(
            key: const ValueKey<String>('logout-button'),
            icon: Icons.logout,
            title: l10n.logoutButton,
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              ref.read(sessionControllerProvider.notifier).logout(activeMode);
            },
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = danger ? KitColors.danger : KitColors.primaryDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger ? KitColors.dangerWash : KitColors.primaryWash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: danger ? KitColors.danger : KitColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KitColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            if (!danger)
              const Icon(Icons.chevron_right, size: 22, color: KitColors.muted),
          ],
        ),
      ),
    );
  }
}
