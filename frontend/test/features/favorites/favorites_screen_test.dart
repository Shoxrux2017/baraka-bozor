import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites.dart';
import 'package:baraka_bozor/features/favorites/presentation/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

void main() {
  late FakeFavoritesRepository favorites;
  late GoRouter router;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  FavoriteProduct favorite(String id, String name, {bool available = true}) =>
      FavoriteProduct(
        product: catalogProduct(
          id: id,
          nameUz: name,
          nameRu: name,
          isFavorite: true,
        ),
        isAvailable: available,
      );

  setUp(() {
    favorites = FakeFavoritesRepository(
      favorites: <FavoriteProduct>[
        favorite('p-1', 'Pomidor'),
        favorite('p-2', 'Olma', available: false),
      ],
    );
  });

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('uz'),
    Size? size,
    double textScale = 1,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('start')),
        ),
        GoRoute(
          path: AppPaths.customer,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: AppPaths.customerFavorites,
          builder: (BuildContext context, GoRouterState state) =>
              const FavoritesScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          cartRepositoryProvider.overrideWithValue(FakeCartRepository()),
          favoritesRepositoryProvider.overrideWithValue(favorites),
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
    router.go(AppPaths.customerFavorites);
    await tester.pumpAndSettle();
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(FavoritesScreen)));

  testWidgets('lists the favourites with filled hearts, and the tab bar', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.text('Sevimlilar'), findsOneWidget);
    expect(byKey('product-card-p-1'), findsOneWidget);
    expect(byKey('product-card-p-2'), findsOneWidget);
    final Icon heart = tester.widget<Icon>(
      find.descendant(of: byKey('heart-p-1'), matching: find.byType(Icon)),
    );
    expect(heart.icon, Icons.favorite);
    expect(
      tester.widget<IconButton>(byKey('heart-p-1')).color,
      KitColors.danger,
    );
    expect(
      tester.widget<CustomerTabBar>(find.byType(CustomerTabBar)).current,
      CustomerTab.favorites,
    );
  });

  testWidgets('an unavailable favourite says it is not sold', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(byKey('unavailable-p-2'), findsOneWidget);
    expect(byKey('add-p-2'), findsNothing);
    expect(byKey('add-p-1'), findsOneWidget);
    expect(find.text('Sotuvda yo\'q'), findsOneWidget);
  });

  testWidgets('un-hearting removes the card once the server confirms', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tester.tap(byKey('heart-p-1'));
    await tester.pumpAndSettle();

    expect(favorites.changes, <String>['remove:p-1']);
    expect(byKey('product-card-p-1'), findsNothing);
    expect(byKey('product-card-p-2'), findsOneWidget);
  });

  testWidgets('a refused un-heart keeps the card', (WidgetTester tester) async {
    await open(tester);
    favorites.nextFailure = const NetworkFailure();

    await tester.tap(byKey('heart-p-1'));
    await tester.pumpAndSettle();

    expect(byKey('product-card-p-1'), findsOneWidget);
  });

  testWidgets('with no favourites it shows the empty state and its button', (
    WidgetTester tester,
  ) async {
    favorites.rows = <FavoriteProduct>[];
    await open(tester);

    expect(find.text('Hozircha bo\'sh'), findsOneWidget);
    expect(byKey('favorites-empty'), findsOneWidget);
    final Icon basket = tester.widget<Icon>(
      find.descendant(
        of: byKey('favorites-empty'),
        matching: find.byIcon(Icons.shopping_basket_outlined),
      ),
    );
    expect(basket.size, 96);
    expect(basket.color, KitColors.primary);

    await tester.tap(find.text('Xaridga'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a failed load shows the reason and a retry', (
    WidgetTester tester,
  ) async {
    favorites.listFailure = const NetworkFailure();
    await open(tester);

    expect(byKey('retry-load'), findsOneWidget);
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

    favorites.listFailure = null;
    await tester.tap(byKey('retry-load'));
    await tester.pumpAndSettle();
    expect(byKey('product-card-p-1'), findsOneWidget);
  });

  testWidgets('loads the next page when the end comes into view', (
    WidgetTester tester,
  ) async {
    favorites.pageSize = 2;
    favorites.rows = <FavoriteProduct>[
      favorite('p-1', 'Pomidor'),
      favorite('p-2', 'Olma'),
      favorite('p-3', 'Anor'),
    ];
    await open(tester);
    expect(byKey('product-card-p-3'), findsOneWidget);
  });

  for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('fits 320x640 at text x2 in ${locale.languageCode}', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(byKey('product-card-p-1'), findsOneWidget);
    });

    testWidgets('the empty state fits 320x640 at text x2 in '
        '${locale.languageCode}', (WidgetTester tester) async {
      favorites.rows = <FavoriteProduct>[];
      await open(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(byKey('favorites-empty'), findsOneWidget);
    });
  }
}
