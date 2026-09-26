import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/app_paths.dart';
import '../core/routing/feature_routes.dart';
import '../features/admin/presentation/admin_routes.dart';
import '../features/auth/presentation/auth_routes.dart';
import '../features/catalog/presentation/catalog_routes.dart';
import '../features/shells/presentation/shells_routes.dart';

/// The Flutter half of decision `D-8`: every feature route fragment the client
/// serves, in registration order.
///
/// A feature declares its routes in
/// `lib/features/<feature>/presentation/<feature>_routes.dart` and is added
/// here as one entry. Dart resolves imports at compile time and tree-shakes
/// what nothing references, so there is no Flutter equivalent of the backend
/// loader scanning a directory. What replaces it is
/// `test/app/route_registry_test.dart`, which reads `lib/features/` from disk
/// and fails when a fragment exists but is not listed below.
final List<FeatureRoutes> featureRouteFragments = <FeatureRoutes>[
  authRoutes,
  shellsRoutes,
  adminRoutes,
  catalogRoutes,
];

/// The application's route table. [redirect] is the session guard the root
/// provider supplies; [refreshListenable] makes the router re-evaluate it
/// when the session changes. A location no route serves — a mistyped
/// address in the panel — goes back to the entry point, from where the
/// guard opens the right area, so go_router's own English error page is
/// never shown (`docs/07-architecture.md` section 27).
GoRouter buildRouter({
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
}) => buildRouterFrom(
  featureRouteFragments,
  redirect: redirect,
  refreshListenable: refreshListenable,
);

/// Builds a router from [fragments], for tests that need a table other than
/// the production one.
///
/// The bootstrap route is collected alongside the fragments rather than added
/// afterwards, so a feature claiming `/` collides loudly instead of quietly
/// taking over the entry point.
GoRouter buildRouterFrom(
  List<FeatureRoutes> fragments, {
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: AppPaths.bootstrap,
    redirect: redirect,
    refreshListenable: refreshListenable,
    onException: (BuildContext context, GoRouterState state, GoRouter router) =>
        router.go(AppPaths.bootstrap),
    routes: collectFeatureRoutes(<FeatureRoutes>[
      _bootstrapFragment,
      ...fragments,
    ]),
  );
}

final FeatureRoutes _bootstrapFragment = FeatureRoutes(
  feature: 'app',
  routes: <RouteBase>[
    GoRoute(
      path: AppPaths.bootstrap,
      name: 'bootstrap',
      builder: (BuildContext context, GoRouterState state) =>
          const _BootstrapScreen(),
    ),
  ],
);

/// What the client shows until the session is known.
///
/// It carries no text: the session guard leaves it the moment the bootstrap
/// answers, and a stored language choice may still be loading, so any text
/// here could flash in the wrong language.
class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
