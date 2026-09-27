import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../../core/routing/feature_routes.dart';
import '../../shells/presentation/panel_shell.dart';
import 'board_screen.dart';

/// The board of the Operator and the Admin (`docs/07-architecture.md`
/// section 27, `DL-37` (17)): feature `operations` under
/// [AppPaths.operations], inside the panel's shell. The session guard admits
/// the Operator and the Admin here; the backend decides what each request
/// may do.
final FeatureRoutes operationsRoutes = FeatureRoutes(
  feature: 'operations',
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          PanelShell(location: state.uri.path, child: child),
      routes: <RouteBase>[
        GoRoute(
          path: AppPaths.operations,
          name: 'operations-board',
          builder: (BuildContext context, GoRouterState state) =>
              const BoardScreen(),
        ),
      ],
    ),
  ],
);
