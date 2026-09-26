import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/language_menu.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import 'admin_paths.dart';

/// One section of the Admin area in the navigation.
final class AdminSection {
  const AdminSection({
    required this.path,
    required this.icon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;
}

/// The sections, in the order the navigation lists them. A later task adds
/// its section here together with its route.
final List<AdminSection> adminSections = <AdminSection>[
  AdminSection(
    path: AppPaths.admin,
    icon: Icons.home_outlined,
    label: (AppLocalizations l10n) => l10n.adminSectionHome,
  ),
  AdminSection(
    path: AdminPaths.categories,
    icon: Icons.category_outlined,
    label: (AppLocalizations l10n) => l10n.adminSectionCategories,
  ),
  AdminSection(
    path: AdminPaths.products,
    icon: Icons.inventory_2_outlined,
    label: (AppLocalizations l10n) => l10n.adminSectionProducts,
  ),
  AdminSection(
    path: AdminPaths.settings,
    icon: Icons.settings_outlined,
    label: (AppLocalizations l10n) => l10n.adminSectionSettings,
  ),
];

/// The frame of every Admin screen on the web panel: the area's name, the
/// language switch and the way out, and the sections — a rail beside the
/// content on a wide window, a drawer on a narrow one.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.location, required this.child, super.key});

  /// Where the router is, to mark the current section.
  final String location;

  final Widget child;

  static const double railBreakpoint = 840;

  int get _selected {
    for (int i = adminSections.length - 1; i >= 0; i--) {
      if (AppPaths.isInside(location, adminSections[i].path)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final bool wide = MediaQuery.sizeOf(context).width >= railBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shellAdmin),
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
      drawer: wide
          ? null
          : NavigationDrawer(
              selectedIndex: _selected,
              onDestinationSelected: (int index) {
                Navigator.of(context).pop();
                context.go(adminSections[index].path);
              },
              children: <Widget>[
                const SizedBox(height: 12),
                for (final AdminSection section in adminSections)
                  NavigationDrawerDestination(
                    icon: Icon(section.icon),
                    label: Text(section.label(l10n)),
                  ),
              ],
            ),
      body: SafeArea(
        child: wide
            ? Row(
                children: <Widget>[
                  NavigationRail(
                    key: const ValueKey<String>('admin-rail'),
                    selectedIndex: _selected,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (int index) =>
                        context.go(adminSections[index].path),
                    destinations: <NavigationRailDestination>[
                      for (final AdminSection section in adminSections)
                        NavigationRailDestination(
                          icon: Icon(section.icon),
                          label: Text(section.label(l10n)),
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
}

/// The Admin landing page: the sections, until the board of a later wave
/// takes its place (interview 9.2).
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text(
          l10n.adminHomeIntro,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final AdminSection section in adminSections.skip(1))
          Card(
            child: ListTile(
              key: ValueKey<String>('admin-section-${section.path}'),
              leading: Icon(section.icon),
              title: Text(section.label(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(section.path),
            ),
          ),
      ],
    );
  }
}
