import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/app/router.dart';
import 'package:baraka_bozor/core/routing/feature_routes.dart';
import 'package:baraka_bozor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_auth_repository.dart';
import '../support/in_memory_stores.dart';

/// The app without the platform plugins: in-memory stores and a fake
/// repository, so the widget tests never touch a method channel.
Widget appUnderTest() {
  return ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
      deviceLocaleProvider.overrideWithValue(const Locale('uz')),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    ],
    child: const BarakaBozorApp(),
  );
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('buildRouter', () {
    test('registers the bootstrap route and nothing else yet', () {
      final GoRouter router = buildRouter();
      addTearDown(router.dispose);

      // The analogue of the backend registry adding no production endpoint:
      // no feature route fragment exists yet, so the table is the bootstrap
      // route alone. A feature task changes this deliberately.
      expect(
        router.configuration.routes.whereType<GoRoute>().map(
          (GoRoute route) => route.path,
        ),
        <String>['/'],
      );
    });

    test('no feature route fragment is registered yet', () {
      expect(featureRouteFragments, isEmpty);
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

  group('BarakaBozorApp', () {
    testWidgets('boots into a neutral screen', (WidgetTester tester) async {
      await tester.pumpWidget(appUnderTest());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders no user-facing text on the bootstrap screen', (
      WidgetTester tester,
    ) async {
      // The bootstrap screen shows nothing until the session is known; the
      // auth screens of the next task carry the localized strings.
      await tester.pumpWidget(appUnderTest());
      await tester.pump();

      expect(find.byType(Text), findsNothing);
    });
  });
}
