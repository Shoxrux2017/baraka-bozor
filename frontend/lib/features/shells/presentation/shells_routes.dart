import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../auth/domain/app_user.dart';
import 'role_shell_screen.dart';

/// The areas of `docs/07-architecture.md` section 29, each entered through
/// its role's shell, until a feature takes an area over with a shell of its
/// own.
final FeatureRoutes shellsRoutes = FeatureRoutes(
  feature: 'shells',
  routes: <RouteBase>[
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
