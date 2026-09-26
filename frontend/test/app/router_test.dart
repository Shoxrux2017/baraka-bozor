import 'dart:async';

import 'package:baraka_bozor/app/router.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/routing/feature_routes.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';
import '../support/fake_auth_repository.dart';
import '../support/in_memory_stores.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('buildRouter', () {
    test('registers the bootstrap route, the auth screens, the six areas and '
        'the admin screens', () {
      final GoRouter router = buildRouter();
      addTearDown(router.dispose);

      // Paths of every page route, a shell's pages included.
      Iterable<String> paths(List<RouteBase> routes) sync* {
        for (final RouteBase route in routes) {
          if (route is GoRoute) {
            yield route.path;
          }
          yield* paths(route.routes);
        }
      }

      expect(paths(router.configuration.routes), <String>[
        AppPaths.bootstrap,
        AppPaths.auth,
        AppPaths.customerCode,
        AppPaths.staffLogin,
        AppPaths.changePassword,
        AppPaths.customerMode,
        AppPaths.unreachable,
        AppPaths.wrongSurface,
        AppPaths.customer,
        AppPaths.shopper,
        AppPaths.courier,
        AppPaths.operations,
        AppPaths.manager,
        AppPaths.admin,
        AdminPaths.categories,
        AdminPaths.products,
        AdminPaths.newProduct,
        AdminPaths.productPattern,
        AdminPaths.settings,
      ]);
    });

    test('registers the auth, shells and admin fragments, in that order', () {
      expect(
        featureRouteFragments.map((FeatureRoutes f) => f.feature),
        <String>['auth', 'shells', 'admin'],
      );
    });

    test('rejects a fragment that collides with the bootstrap route', () {
      // The bootstrap route goes through the same collision check as every
      // feature fragment, so a feature cannot quietly take over "/".
      expect(
        () => buildRouterFrom(<FeatureRoutes>[
          FeatureRoutes(
            feature: 'catalog',
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (BuildContext context, GoRouterState state) =>
                    const SizedBox.shrink(),
              ),
            ],
          ),
        ]),
        throwsStateError,
      );
    });
  });

  group('a registered fragment', () {
    testWidgets('is reachable through the built router', (
      WidgetTester tester,
    ) async {
      // Registration has to put the routes in the table that actually serves
      // navigation. Asserting the list contents would not show that; navigating
      // to the route does.
      final GoRouter router = buildRouterFrom(<FeatureRoutes>[
        FeatureRoutes(
          feature: 'fixture',
          routes: <RouteBase>[
            GoRoute(
              path: '/fixture',
              name: 'fixture',
              builder: (BuildContext context, GoRouterState state) =>
                  const SizedBox.shrink(
                    key: ValueKey<String>('fixture-screen'),
                  ),
            ),
          ],
        ),
      ]);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/fixture');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('fixture-screen')),
        findsOneWidget,
      );
    });
  });

  group('an unknown location', () {
    testWidgets('goes back to the entry point instead of an error page', (
      WidgetTester tester,
    ) async {
      final GoRouter router = buildRouterFrom(<FeatureRoutes>[]);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/nowhere/at/all');
      // Not pumpAndSettle: the entry point shows a progress indicator, which
      // never settles.
      await tester.pump();
      await tester.pump();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppPaths.bootstrap,
      );
      expect(find.textContaining('Page Not Found'), findsNothing);
    });
  });

  group('BarakaBozorApp', () {
    testWidgets('boots into a neutral screen with no text', (
      WidgetTester tester,
    ) async {
      // The bootstrap screen shows nothing until the session is known; a
      // stored language choice may still be loading, and any text here could
      // flash in the wrong language.
      final FakeAuthRepository repository = FakeAuthRepository()
        ..identities[SessionSlot.staff] = user()
        ..holdAnswers = Completer<void>();
      await tester.pumpWidget(
        appUnderTest(
          tokens: InMemoryTokenStore(<SessionSlot, String>{
            SessionSlot.staff: 's',
          }),
          repository: repository,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);

      repository.holdAnswers!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('leaves the bootstrap screen once the session is known', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(appUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey<String>('phone-field')), findsOneWidget);
    });
  });
}
