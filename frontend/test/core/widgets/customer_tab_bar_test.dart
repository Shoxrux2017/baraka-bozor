import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/app/router.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/routing/feature_routes.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:baraka_bozor/features/favorites/presentation/favorites_routes.dart';
import 'package:baraka_bozor/features/favorites/presentation/favorites_screen.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/presentation/orders_routes.dart';
import 'package:baraka_bozor/features/orders/presentation/orders_screens.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/presentation/profile_routes.dart';
import 'package:baraka_bozor/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/fake_customer_orders_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/fake_favorites_repository.dart';
import '../../support/in_memory_stores.dart';

/// The tab bar's navigation rule on a test table: a stand-in home carrying
/// the bar, and the real favourites, orders and profile screens.
void main() {
  late GoRouter router;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  String location() =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('uz'),
  }) async {
    router = buildRouterFrom(<FeatureRoutes>[
      FeatureRoutes(
        feature: 'stand-in',
        routes: <RouteBase>[
          GoRoute(
            path: AppPaths.customer,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(
                  body: Text('stand-in home'),
                  bottomNavigationBar: CustomerTabBar(
                    current: CustomerTab.home,
                  ),
                ),
          ),
        ],
      ),
      favoritesRoutes,
      ordersRoutes,
      profileRoutes,
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          cartRepositoryProvider.overrideWithValue(FakeCartRepository()),
          favoritesRepositoryProvider.overrideWithValue(
            FakeFavoritesRepository(),
          ),
          customerOrdersRepositoryProvider.overrideWithValue(
            FakeCustomerOrdersRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go(AppPaths.customer);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('from the home a tab opens over it and back returns home', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tester.tap(byKey('open-favorites'));
    await tester.pumpAndSettle();
    expect(find.byType(FavoritesScreen), findsOneWidget);
    expect(location(), AppPaths.customerFavorites);

    await back(tester);
    expect(find.text('stand-in home'), findsOneWidget);
    expect(location(), AppPaths.customer);
  });

  testWidgets('from a tab another tab replaces it, and back returns home', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(byKey('open-favorites'));
    await tester.pumpAndSettle();

    await tester.tap(byKey('open-orders'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.byType(FavoritesScreen), findsNothing);

    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(location(), AppPaths.customerProfile);

    await back(tester);
    expect(find.text('stand-in home'), findsOneWidget);
  });

  testWidgets('the home tab goes home from a tab', (WidgetTester tester) async {
    await open(tester);
    await tester.tap(byKey('open-orders'));
    await tester.pumpAndSettle();

    await tester.tap(byKey('open-home'));
    await tester.pumpAndSettle();

    expect(find.text('stand-in home'), findsOneWidget);
    expect(location(), AppPaths.customer);
    expect(router.canPop(), isFalse);
  });

  testWidgets('the current tab does nothing', (WidgetTester tester) async {
    await open(tester);
    await tester.tap(byKey('open-favorites'));
    await tester.pumpAndSettle();

    await tester.tap(byKey('open-favorites'));
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesScreen), findsOneWidget);
    await back(tester);
    expect(find.text('stand-in home'), findsOneWidget);
  });

  testWidgets('the bar is 99 high, white, with the icons at 28 and labels', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);

    expect(tester.getSize(find.byType(CustomerTabBar)).height, 99);
    final Icon home = tester.widget<Icon>(
      find.descendant(of: byKey('open-home'), matching: find.byType(Icon)),
    );
    final Icon orders = tester.widget<Icon>(
      find.descendant(of: byKey('open-orders'), matching: find.byType(Icon)),
    );
    expect(home.size, 28);
    expect(home.icon, Icons.home);
    expect(home.color, KitColors.primary);
    expect(orders.icon, isNot(Icons.receipt_long));
    expect(orders.color, isNot(KitColors.primary));
    expect(find.bySemanticsLabel('Bosh sahifa'), findsOneWidget);
    expect(find.bySemanticsLabel('Sevimlilar'), findsOneWidget);
    expect(find.bySemanticsLabel('Buyurtmalar'), findsOneWidget);
    expect(find.bySemanticsLabel('Profil'), findsOneWidget);
    semantics.dispose();
  });
}
