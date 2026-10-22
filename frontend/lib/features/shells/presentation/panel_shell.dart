import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../auth/domain/app_user.dart';
import 'panel_menu.dart';

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
      path: AppPaths.adminCustomers,
      icon: Icons.people_outline,
      label: (AppLocalizations l10n) => l10n.customersTitle,
    ),
    PanelSection(
      path: AppPaths.adminLegalDocuments,
      icon: Icons.description_outlined,
      label: (AppLocalizations l10n) => l10n.legalDocumentsTitle,
    ),
    PanelSection(
      path: AppPaths.adminSettings,
      icon: Icons.settings_outlined,
      label: (AppLocalizations l10n) => l10n.adminSectionSettings,
    ),
  ],
];

/// The frame of every web panel screen, the Admin's and the Operator's: the
/// side menu with the role's sections, the user card, the language and the way
/// out (`DL-100`). The menu is whole from [fullMenuWidth], folded to icons
/// from [railWidth], and behind a menu button in a top bar below.
class PanelShell extends ConsumerWidget {
  const PanelShell({required this.location, required this.child, super.key});

  /// Where the router is, to mark the current section.
  final String location;

  final Widget child;

  static const double fullMenuWidth = 1360;
  static const double railWidth = 1200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final UserRole? role = state is SignedIn ? state.activeUser.role : null;
    final List<PanelSection> sections = role == null
        ? const <PanelSection>[]
        : panelSectionsOf(role);
    final double width = MediaQuery.sizeOf(context).width;
    final int selected = _selected(sections);
    void go(int index) => context.go(sections[index].path);

    if (width >= railWidth) {
      return Scaffold(
        backgroundColor: KitColors.page,
        body: Row(
          children: <Widget>[
            PanelMenu(
              sections: sections,
              selected: selected,
              folded: width < fullMenuWidth,
              onSelect: go,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: KitColors.page,
      drawer: PanelDrawerMenu(
        sections: sections,
        selected: selected,
        onSelect: (int index) {
          Navigator.of(context).pop();
          go(index);
        },
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: KitColors.line)),
              ),
              child: Row(
                children: <Widget>[
                  Builder(
                    builder: (BuildContext context) => IconButton(
                      icon: const Icon(Icons.menu, color: KitColors.ink2),
                      tooltip: MaterialLocalizations.of(context)
                          .openAppDrawerTooltip,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const BrandWordmark(size: 19),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
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
