import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/language_menu.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../auth/domain/app_user.dart';

/// One section of the web panel's navigation.
final class PanelSection {
  const PanelSection({
    required this.path,
    required this.icon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;
}

/// The sections a staff role sees, in the order the navigation lists them
/// (`docs/02-user-roles.md` section 7, `DL-37` (17)): the board first for
/// the Operator and the Admin, then the Admin's own sections. A later task
/// adds its section here together with its route.
List<PanelSection> panelSectionsOf(UserRole role) => <PanelSection>[
  if (role == UserRole.operator || role == UserRole.admin)
    PanelSection(
      path: AppPaths.operations,
      icon: Icons.receipt_long_outlined,
      label: (AppLocalizations l10n) => l10n.panelSectionBoard,
    ),
  if (role == UserRole.admin) ...<PanelSection>[
    PanelSection(
      path: AppPaths.adminCategories,
      icon: Icons.category_outlined,
      label: (AppLocalizations l10n) => l10n.adminSectionCategories,
    ),
    PanelSection(
      path: AppPaths.adminProducts,
      icon: Icons.inventory_2_outlined,
      label: (AppLocalizations l10n) => l10n.adminSectionProducts,
    ),
    PanelSection(
      path: AppPaths.adminStaff,
      icon: Icons.badge_outlined,
      label: (AppLocalizations l10n) => l10n.adminSectionStaff,
    ),
    PanelSection(
      path: AppPaths.adminSettings,
      icon: Icons.settings_outlined,
      label: (AppLocalizations l10n) => l10n.adminSectionSettings,
    ),
  ],
];

/// The frame of every web panel screen, the Admin's and the Operator's: the
/// signed-in role's name, the language switch and the way out, and that
/// role's sections — a rail beside the content on a wide window, a drawer on
/// a narrow one, and none when the role has a single section.
class PanelShell extends ConsumerWidget {
  const PanelShell({required this.location, required this.child, super.key});

  /// Where the router is, to mark the current section.
  final String location;

  final Widget child;

  static const double railBreakpoint = 840;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final UserRole? role = state is SignedIn ? state.activeUser.role : null;
    final List<PanelSection> sections = role == null
        ? const <PanelSection>[]
        : panelSectionsOf(role);
    final bool navigates = sections.length > 1;
    final bool wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    final int selected = _selected(sections);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          role == UserRole.admin ? l10n.shellAdmin : l10n.shellOperations,
        ),
        actions: <Widget>[
          const LanguageMenuButton(),
          if (state is SignedIn)
            IconButton(
              key: const ValueKey<String>('logout-button'),
              icon: const Icon(Icons.logout),
              tooltip: l10n.logoutButton,
              onPressed: () => ref
                  .read(sessionControllerProvider.notifier)
                  .logout(state.activeMode),
            ),
        ],
      ),
      drawer: navigates && !wide
          ? NavigationDrawer(
              key: const ValueKey<String>('panel-drawer'),
              selectedIndex: selected,
              onDestinationSelected: (int index) {
                Navigator.of(context).pop();
                context.go(sections[index].path);
              },
              children: <Widget>[
                const SizedBox(height: 12),
                for (final PanelSection section in sections)
                  NavigationDrawerDestination(
                    icon: Icon(section.icon),
                    label: Text(
                      section.label(l10n),
                      key: ValueKey<String>('panel-section-${section.path}'),
                    ),
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: navigates && wide
            ? Row(
                children: <Widget>[
                  NavigationRail(
                    key: const ValueKey<String>('panel-rail'),
                    selectedIndex: selected,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (int index) =>
                        context.go(sections[index].path),
                    destinations: <NavigationRailDestination>[
                      for (final PanelSection section in sections)
                        NavigationRailDestination(
                          icon: Icon(section.icon),
                          label: Text(
                            section.label(l10n),
                            key: ValueKey<String>(
                              'panel-section-${section.path}',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              )
            : child,
      ),
    );
  }

  int _selected(List<PanelSection> sections) {
    for (int i = sections.length - 1; i >= 0; i--) {
      if (AppPaths.isInside(location, sections[i].path)) {
        return i;
      }
    }
    return 0;
  }
}
