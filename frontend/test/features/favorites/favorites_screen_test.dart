import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_grid.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
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

  CatalogProduct favorite(
    String id,
    String name, {
    bool available = true,
    int price = 18400,
  }) => catalogProduct(
    id: id,
    nameUz: name,
    nameRu: name,
    isFavorite: true,
    isAvailable: available,
    customerUnitPriceUzs: price,
  );

  setUp(() {
    favorites = FakeFavoritesRepository(
      favorites: <CatalogProduct>[
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
    FakeCartRepository? cart,
    bool settle = true,
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
          cartRepositoryProvider.overrideWithValue(
            cart ?? FakeCartRepository(),
          ),
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('the header has the search and the cart with its count', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      cart: FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[
          cartLineJson(),
          cartLineJson(id: breadLine, productId: breadProduct, unit: 'piece'),
        ]),
      ),
    );

    final Finder bar = find.byType(AppBar);
    expect(
      find.descendant(of: bar, matching: byKey('open-search')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: byKey('open-cart')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(byKey('open-search')).dx,
      lessThan(tester.getCenter(byKey('open-cart')).dx),
      reason: 'the search, then the cart',
    );
    expect(tester.widget<Text>(byKey('cart-count')).data, '2');
    expect(
      tester
          .getCenter(
            find.descendant(of: bar, matching: find.text('Sevimlilar')),
          )
          .dx,
      closeTo(tester.getCenter(bar).dx, 1),
      reason: 'the title stays centred',
    );
  });

  testWidgets('lists the favourites with filled hearts, and the tab bar', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Sevimlilar'),
      ),
      findsOneWidget,
    );
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

  testWidgets('each card is keyed by its product', (WidgetTester tester) async {
    await open(tester);

    expect(
      tester
          .widgetList<KitProductCard>(find.byType(KitProductCard))
          .map((KitProductCard c) => c.key),
      <Key>[const ValueKey<String>('p-1'), const ValueKey<String>('p-2')],
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
    favorites.rows = <CatalogProduct>[];
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

  testWidgets(
    'favourites show the count and the order: «24 товара · Сначала новые»',
    (WidgetTester tester) async {
      favorites.rows = <CatalogProduct>[
        for (int i = 0; i < 24; i++) favorite('p-$i', 'Товар $i'),
      ];
      await open(tester, locale: const Locale('ru'));

      expect(byKey('list-count-row'), findsOneWidget);
      expect(find.text('24 товара', findRichText: true), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('list-sort'),
          matching: find.text('Сначала новые'),
        ),
        findsOneWidget,
      );
      expect(favorites.requests, <String>['default|1']);
    },
  );

  testWidgets(
    'the order menu offers new, cheaper and dearer and asks the server again',
    (WidgetTester tester) async {
      favorites.rows = <CatalogProduct>[
        favorite('p-1', 'Pomidor', price: 3000),
        favorite('p-2', 'Olma', price: 1000),
        favorite('p-3', 'Anor', price: 2000),
      ];
      await open(tester, locale: const Locale('ru'));

      await tester.tap(byKey('list-sort'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: byKey('sort-menu'),
          matching: find.text('Сначала новые'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('sort-menu'),
          matching: find.text('Как в магазине'),
        ),
        findsNothing,
      );
      expect(byKey('sort-price-asc'), findsOneWidget);
      expect(byKey('sort-price-desc'), findsOneWidget);

      await tester.tap(byKey('sort-price-asc'));
      await tester.pumpAndSettle();

      expect(favorites.requests, <String>['default|1', 'price_asc|1']);
      expect(
        tester.getTopLeft(byKey('product-card-p-2')).dx,
        lessThan(tester.getTopLeft(byKey('product-card-p-3')).dx),
        reason: 'the cheapest comes first',
      );
      expect(
        find.descendant(
          of: byKey('list-sort'),
          matching: find.text('Сначала дешевле'),
        ),
        findsOneWidget,
      );
    },
  );

  group('on a long list', () {
    setUp(() {
      favorites.rows = <CatalogProduct>[
        for (int i = 0; i < 60; i++) favorite('p-$i', 'Товар $i'),
      ];
    });

    ScrollPosition positionOf(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: byKey('favorites-grid'),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    double rowOf() =>
        kitCardExtent(
          TextScaler.noScaling,
          size: KitCardSize.regular,
          imageHeight: 150,
        ) +
        12;

    testWidgets('favourites load with skeletons and page two rows ahead', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final Completer<void> hold = Completer<void>();
      favorites.listHold = hold;
      await open(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(byKey('product-skeletons'), findsOneWidget);
      expect(byKey('product-card-p-0'), findsNothing);

      favorites.listHold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('product-skeletons'), findsNothing);
      expect(byKey('product-card-p-0'), findsOneWidget);
      expect(favorites.requests, <String>['default|1']);

      final ScrollPosition position = positionOf(tester);
      position.jumpTo(position.maxScrollExtent - 3 * rowOf() - 5);
      await tester.pump();
      expect(favorites.requests, <String>['default|1']);

      position.jumpTo(position.maxScrollExtent - 3 * rowOf() + 15);
      await tester.pump();
      expect(favorites.requests, contains('default|2'));
    });
  });

  testWidgets(
    'a failed first page stands as still skeletons under the stale line',
    (WidgetTester tester) async {
      favorites.listFailure = const NetworkFailure();
      await open(tester);

      expect(byKey('stale-line'), findsOneWidget);
      expect(byKey('product-skeletons'), findsOneWidget);
      expect(byKey('retry-load'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      favorites.listFailure = null;
      await tester.tap(byKey('stale-retry'));
      await tester.pumpAndSettle();
      expect(byKey('stale-line'), findsNothing);
      expect(byKey('product-card-p-1'), findsOneWidget);
    },
  );

  testWidgets('empty favourites draw no count row', (
    WidgetTester tester,
  ) async {
    favorites.rows = <CatalogProduct>[];
    await open(tester);

    expect(byKey('favorites-empty'), findsOneWidget);
    expect(byKey('list-count-row'), findsNothing);
    expect(byKey('list-sort'), findsNothing);
  });

  testWidgets('favourites pass the tap-target guideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester);

    expect(byKey('list-count-row'), findsOneWidget);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the not-sold favourites stand after the sold ones', (
    WidgetTester tester,
  ) async {
    favorites.rows = <CatalogProduct>[
      favorite('p-1', 'Olma', available: false),
      favorite('p-2', 'Pomidor'),
    ];
    await open(tester);

    expect(
      tester.getTopLeft(byKey('product-card-p-2')).dx,
      lessThan(tester.getTopLeft(byKey('product-card-p-1')).dx),
    );
    expect(byKey('unavailable-p-1'), findsOneWidget);
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
      favorites.rows = <CatalogProduct>[];
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
