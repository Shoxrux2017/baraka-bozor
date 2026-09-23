import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/feature_routes.dart';

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
///
/// From Wave 1 this file belongs to the wave owner, so adding a feature is a
/// serialized edit by one track rather than a file two tracks contend for.
const List<FeatureRoutes> featureRouteFragments = <FeatureRoutes>[];

/// The application's route table.
GoRouter buildRouter() => buildRouterFrom(featureRouteFragments);

/// Builds a router from [fragments], for tests that need a table other than
/// the production one.
///
/// The bootstrap route is collected alongside the fragments rather than added
/// afterwards, so a feature claiming `/` collides loudly instead of quietly
/// taking over the entry point.
GoRouter buildRouterFrom(List<FeatureRoutes> fragments) {
  return GoRouter(
    initialLocation: '/',
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
      path: '/',
      name: 'bootstrap',
      builder: (BuildContext context, GoRouterState state) =>
          const _BootstrapScreen(),
    ),
  ],
);

/// What the client shows before it knows whether a session exists.
///
/// It carries no text: `docs/07-architecture.md` section 27 forbids English UI
/// and how a language is chosen is still open as `S-27`. The session task
/// replaces this with the real bootstrap decision.
class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
