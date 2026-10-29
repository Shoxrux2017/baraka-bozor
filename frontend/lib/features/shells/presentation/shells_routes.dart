import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../auth/domain/app_user.dart';
import '../../catalog/presentation/catalog_routes.dart';
import '../../favorites/presentation/favorites_routes.dart';
import '../../orders/presentation/orders_routes.dart';
import '../../profile/presentation/profile_routes.dart';
import 'role_shell_screen.dart';

/// The areas of `docs/07-architecture.md` section 29, each entered through
/// its role's shell, until a feature takes an area over with a shell of its
/// own.
final FeatureRoutes shellsRoutes = FeatureRoutes(
  feature: 'shells',
  routes: <RouteBase>[
    // The Customer's four tabs (`DL-118`): one branch each, in the order of
    // `CustomerTab`, so a tab keeps its screen, scroll and data while another
    // is shown. Each tab draws its own bar. A tab's path is reached by the
    // bar or `go`, never pushed.
    StatefulShellRoute(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell shell,
      ) => shell,
      navigatorContainerBuilder: _tabsContainer,
      branches: <StatefulShellBranch>[
        StatefulShellBranch(routes: <RouteBase>[catalogHomeRoute]),
        StatefulShellBranch(routes: <RouteBase>[favoritesTabRoute]),
        StatefulShellBranch(routes: <RouteBase>[ordersTabRoute]),
        StatefulShellBranch(routes: <RouteBase>[profileTabRoute]),
      ],
    ),
    // The Admin area (`features/admin`), the Operator's board
    // (`features/operations`), the Customer area, whose home is the catalog
    // (`features/catalog`), the Shopper's (`features/shopper`) and the
    // Courier's (`features/courier`) have features of their own that serve
    // their entries as well; the other areas keep this placeholder until
    // their features arrive.
    for (final UserRole role in UserRole.values)
      if (role != UserRole.admin &&
          role != UserRole.operator &&
          role != UserRole.customer &&
          role != UserRole.shopper &&
          role != UserRole.courier)
        GoRoute(
          path: AppPaths.homeOf(role),
          name: 'shell-${role.code}',
          builder: (BuildContext context, GoRouterState state) =>
              RoleShellScreen(role: role),
        ),
  ],
);

/// The tabs stacked like go_router's own indexed stack, with the hidden ones
/// out of the hero flights: a snack bar is shown by every tab's scaffold, and
/// the same hero tag in two of them would stop a route change (`DL-118`).
Widget _tabsContainer(
  BuildContext context,
  StatefulNavigationShell shell,
  List<Widget> children,
) {
  return IndexedStack(
    index: shell.currentIndex,
    children: <Widget>[
      for (int i = 0; i < children.length; i++)
        Offstage(
          offstage: i != shell.currentIndex,
          child: TickerMode(
            enabled: i == shell.currentIndex,
            child: HeroMode(
              enabled: i == shell.currentIndex,
              child: children[i],
            ),
          ),
        ),
    ],
  );
}
