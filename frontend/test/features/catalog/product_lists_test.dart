import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_paths.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_products_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/recommended_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/sort_sheet.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

void main() {
  late FakeCatalogRepository catalog;
  late FakeCartRepository cart;
  late GoRouter router;
  String? cartOpened;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  final CatalogProduct tomato = catalogProduct(
    id: '0192f0a0-0000-7000-8000-0000000000a1',
    nameRu: 'Помидор',
    nameUz: 'Pomidor',
    customerUnitPriceUzs: 18000,
  );
  final CatalogProduct apple = catalogProduct(
    id: '0192f0a0-0000-7000-8000-0000000000a2',
    nameRu: 'Яблоко',
    nameUz: 'Olma',
    customerUnitPriceUzs: 30000,
  );
  final CatalogProduct bread = catalogProduct(
    id: '0192f0a0-0000-7000-8000-0000000000a3',
    nameRu: 'Хлеб',
    nameUz: 'Non',
    unitCode: UnitCode.piece,
    customerUnitPriceUzs: 4000,
  );

  setUp(() {
    // Shop order: apple, tomato, bread.
    catalog = FakeCatalogRepository(products: [apple, tomato, bread]);
    cart = FakeCartRepository();
    cartOpened = null;
  });

  Future<void> open(
    WidgetTester tester,
    String path, {
    Locale locale = const Locale('ru'),
  }) async {
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('start')),
        ),
        GoRoute(
          path: CatalogPaths.recommended,
          builder: (BuildContext context, GoRouterState state) =>
              const RecommendedScreen(),
        ),
        GoRoute(
          path: CatalogPaths.products,
          builder: (BuildContext context, GoRouterState state) =>
              const AllProductsScreen(),
        ),
        GoRoute(
          path: CartPaths.cart,
          builder: (BuildContext context, GoRouterState state) {
            cartOpened = state.uri.path;
            return const Scaffold(body: Text('cart page'));
          },
        ),
        GoRoute(
          path: CatalogPaths.productPattern,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('product page')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          catalogRepositoryProvider.overrideWithValue(catalog),
          cartRepositoryProvider.overrideWithValue(cart),
          favoritesRepositoryProvider.overrideWithValue(
            FakeFavoritesRepository(),
          ),
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
    unawaited(router.push(path));
    await tester.pumpAndSettle();
  }

  List<String> shownNames(WidgetTester tester) => <String>[
    for (final Text t in tester.widgetList<Text>(find.byType(Text)))
      if (<String>['Помидор', 'Яблоко', 'Хлеб'].contains(t.data)) t.data!,
  ];

  testWidgets('recommended lists only the featured products', (
    WidgetTester tester,
  ) async {
    catalog.featuredIds = <String>{
      '0192f0a0-0000-7000-8000-0000000000a1',
      '0192f0a0-0000-7000-8000-0000000000a3',
    };
    await open(tester, CatalogPaths.recommended);
    expect(find.text('Рекомендуем'), findsOneWidget);
    expect(shownNames(tester), <String>['Помидор', 'Хлеб']);
    expect(find.text('Яблоко'), findsNothing);
  });

  testWidgets('an empty recommended list says so', (WidgetTester tester) async {
    await open(tester, CatalogPaths.recommended);
    expect(
      find.text(
        AppLocalizations.of(tester.element(find.text('Рекомендуем')))
            .recommendedEmpty,
      ),
      findsOneWidget,
    );
    expect(find.text('Хлеб'), findsNothing);
  });

  testWidgets('every product follows the shop order and the chip sorts it', (
    WidgetTester tester,
  ) async {
    await open(tester, CatalogPaths.products);
    expect(find.text('Все товары'), findsOneWidget);
    expect(shownNames(tester), <String>['Яблоко', 'Помидор', 'Хлеб']);
    expect(
      find.descendant(
        of: byKey('sort-chip'),
        matching: find.text('Как в магазине'),
      ),
      findsOneWidget,
    );

    await tester.tap(byKey('sort-chip'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('sort-price-asc'));
    await tester.pumpAndSettle();

    expect(shownNames(tester), <String>['Хлеб', 'Помидор', 'Яблоко']);
    expect(
      find.descendant(
        of: byKey('sort-chip'),
        matching: find.text('Сначала дешевле'),
      ),
      findsOneWidget,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(byKey('sort-chip')),
    );
    expect(container.read(productSortProvider), ProductSort.priceAsc);
  });

  testWidgets('the sheet marks the current choice and returns the tapped one', (
    WidgetTester tester,
  ) async {
    ProductSort? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showSortSheet(context, ProductSort.priceDesc),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Сортировка'), findsOneWidget);
    Finder check(String key) => find.descendant(
      of: byKey(key),
      matching: find.byIcon(Icons.check_circle),
    );
    expect(check('sort-price-desc'), findsOneWidget);
    expect(check('sort-shop'), findsNothing);
    expect(check('sort-price-asc'), findsNothing);

    await tester.tap(byKey('sort-shop'));
    await tester.pumpAndSettle();
    expect(result, ProductSort.shop);
  });

  testWidgets('the cart bar appears after a quick add and opens the cart', (
    WidgetTester tester,
  ) async {
    await open(tester, CatalogPaths.products);
    expect(byKey('cart-summary'), findsNothing);

    cart.answer = cartOf(<Map<String, Object?>>[
      cartLineJson(
        productId: '0192f0a0-0000-7000-8000-0000000000a1',
        quantity: '1.000',
        price: 18000,
        total: 18000,
      ),
    ]);
    await tester.tap(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'));
    await tester.pumpAndSettle();

    expect(byKey('cart-summary'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('cart-summary'),
        matching: find.text('1 товар'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('cart-summary'),
        matching: find.text('≈ ${MoneyFormat.uzs(18000, AppLanguage.ru)}'),
      ),
      findsOneWidget,
    );

    await tester.tap(byKey('cart-summary'));
    await tester.pumpAndSettle();
    expect(cartOpened, CartPaths.cart);
  });

  testWidgets('the cart bar counts in the plural of the language', (
    WidgetTester tester,
  ) async {
    cart.current = cartOf(<Map<String, Object?>>[
      cartLineJson(
        id: tomatoLine,
        productId: '0192f0a0-0000-7000-8000-0000000000a1',
      ),
      cartLineJson(
        id: breadLine,
        productId: '0192f0a0-0000-7000-8000-0000000000a2',
      ),
    ]);
    await open(tester, CatalogPaths.products);
    expect(find.text('2 товара'), findsOneWidget);
  });

  testWidgets('a failed first page offers a retry', (
    WidgetTester tester,
  ) async {
    catalog.nextFailure = const UnexpectedFailure();
    await open(tester, CatalogPaths.products);
    expect(byKey('retry-load'), findsOneWidget);
    await tester.tap(byKey('retry-load'));
    await tester.pumpAndSettle();
    expect(find.text('Помидор'), findsOneWidget);
  });

  testWidgets('a failed next page keeps the loaded ones and offers a retry', (
    WidgetTester tester,
  ) async {
    catalog.pageSize = 30;
    catalog.productRows = <CatalogProduct>[
      for (int i = 0; i < 60; i++)
        catalogProduct(id: 'q-$i', nameRu: 'Товар $i', nameUz: 'Mahsulot $i'),
    ];
    await open(tester, CatalogPaths.products);
    expect(find.text('Товар 0'), findsOneWidget);
    catalog.nextFailure = const UnexpectedFailure();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -9000));
    await tester.pumpAndSettle();
    expect(byKey('load-more'), findsOneWidget);
    await tester.tap(byKey('load-more'));
    await tester.pumpAndSettle();
    expect(byKey('load-more'), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -9000));
    await tester.pumpAndSettle();
    expect(find.text('Товар 59'), findsOneWidget);
  });

  for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final String path in <String>[
      CatalogPaths.recommended,
      CatalogPaths.products,
    ]) {
      testWidgets(
        '$path fits 320x640 at text scale 2 in ${locale.languageCode}',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          catalog.featuredIds = <String>{
            '0192f0a0-0000-7000-8000-0000000000a1',
            '0192f0a0-0000-7000-8000-0000000000a3',
            '0192f0a0-0000-7000-8000-0000000000a2',
          };
          cart.current = cartOf(<Map<String, Object?>>[
            cartLineJson(
              id: tomatoLine,
              productId: '0192f0a0-0000-7000-8000-0000000000a1',
            ),
          ]);
          await open(tester, path, locale: locale);
          expect(tester.takeException(), isNull);
          expect(byKey('cart-summary'), findsOneWidget);
          if (path == CatalogPaths.products) {
            await tester.tap(byKey('sort-chip'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(byKey('sort-price-asc'), findsOneWidget);
          }
        },
      );
    }
  }
}
