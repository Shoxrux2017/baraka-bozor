import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/platform/clock.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/widgets/skeleton_bar.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_paths.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_products_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_grid.dart';
import 'package:baraka_bozor/features/catalog/presentation/recommended_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/sort_menu.dart';
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
    DateTime Function()? clock,
    double sideInset = 0,
    bool settle = true,
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
          if (clock != null) clockProvider.overrideWithValue(clock),
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
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.symmetric(horizontal: sideInset),
              viewPadding: EdgeInsets.symmetric(horizontal: sideInset),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(path));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> pull(WidgetTester tester) async {
    await tester.drag(byKey('product-grid'), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Iterable<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message);

  void allFeatured() =>
      catalog.featuredIds = <String>{tomato.id, apple.id, bread.id};

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

  testWidgets('Рекомендуем shows 3 товара · Как в магазине and the menu '
      're-sorts it', (WidgetTester tester) async {
    allFeatured();
    await open(tester, CatalogPaths.recommended);
    expect(byKey('list-count-row'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('list-count-row'),
        matching: find.text('3 товара', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('list-sort'),
        matching: find.text('Как в магазине'),
      ),
      findsOneWidget,
    );
    expect(shownNames(tester), <String>['Яблоко', 'Помидор', 'Хлеб']);

    await tester.tap(byKey('list-sort'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('sort-price-asc'));
    await tester.pumpAndSettle();

    expect(shownNames(tester), <String>['Хлеб', 'Помидор', 'Яблоко']);
    expect(
      find.descendant(
        of: byKey('list-sort'),
        matching: find.text('Сначала дешевле'),
      ),
      findsOneWidget,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(byKey('list-sort')),
    );
    expect(container.read(productSortProvider), ProductSort.priceAsc);
  });

  testWidgets('Все товары has the count row instead of the chip', (
    WidgetTester tester,
  ) async {
    await open(tester, CatalogPaths.products);
    expect(byKey('sort-chip'), findsNothing);
    expect(byKey('list-count-row'), findsOneWidget);
    expect(find.text('3 товара', findRichText: true), findsOneWidget);
    expect(shownNames(tester), <String>['Яблоко', 'Помидор', 'Хлеб']);

    await tester.tap(byKey('list-sort'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('sort-price-desc'));
    await tester.pumpAndSettle();
    expect(shownNames(tester), <String>['Яблоко', 'Помидор', 'Хлеб']);
    expect(
      find.descendant(
        of: byKey('list-sort'),
        matching: find.text('Сначала дороже'),
      ),
      findsOneWidget,
    );
  });

  group('the order menu', () {
    ProductSort? result;
    Rect? lastButton;

    Future<void> openMenu(
      WidgetTester tester, {
      ProductSort current = ProductSort.priceDesc,
      Size size = const Size(375, 667),
      Offset at = const Offset(250, 100),
      FakeViewPadding padding = FakeViewPadding.zero,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = padding;
      addTearDown(tester.view.reset);
      result = null;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned(
                  left: at.dx,
                  top: at.dy,
                  child: Builder(
                    builder: (BuildContext context) => SizedBox(
                      key: const ValueKey<String>('anchor'),
                      width: 100,
                      height: 44,
                      child: TextButton(
                        onPressed: () async =>
                            result = await showSortMenu(context, current),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      lastButton = tester.getRect(byKey('anchor'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('the menu opens at its button with a check on the current '
        'order, without a dim, and a tap outside closes it', (
      WidgetTester tester,
    ) async {
      await openMenu(tester);

      final Rect menu = tester.getRect(byKey('sort-menu'));
      expect(menu.width, 232);
      expect(menu.top, lastButton!.bottom + 2);
      expect(menu.right, lastButton!.right - 6);
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .where((ModalBarrier b) => b.color != null && b.color!.a > 0),
        isEmpty,
        reason: 'no dim',
      );
      Finder check(String key) =>
          find.descendant(of: byKey(key), matching: find.byIcon(Icons.check));
      expect(check('sort-price-desc'), findsOneWidget);
      expect(check('sort-shop'), findsNothing);
      expect(check('sort-price-asc'), findsNothing);

      await tester.tapAt(const Offset(10, 600));
      await tester.pumpAndSettle();
      expect(byKey('sort-menu'), findsNothing);
      expect(result, isNull);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('sort-shop'));
      await tester.pumpAndSettle();
      expect(byKey('sort-menu'), findsNothing);
      expect(result, ProductSort.shop);
    });

    testWidgets('menu items read their name, selected or not', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await openMenu(tester);

      expect(
        tester.getSemantics(byKey('sort-price-desc')),
        matchesSemantics(
          label: 'Сначала дороже',
          isButton: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(
        tester.getSemantics(byKey('sort-shop')),
        matchesSemantics(
          label: 'Как в магазине',
          isButton: true,
          hasTapAction: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('lying, the menu stays inside the screen', (
      WidgetTester tester,
    ) async {
      await openMenu(
        tester,
        size: const Size(812, 375),
        at: const Offset(660, 300),
        padding: const FakeViewPadding(left: 47, right: 47),
      );

      final Rect menu = tester.getRect(byKey('sort-menu'));
      expect(menu.right, lessThanOrEqualTo(812 - 47 - 8));
      expect(menu.left, greaterThanOrEqualTo(47 + 8));
      expect(menu.bottom, lessThanOrEqualTo(375 - 8));
      expect(menu.top, greaterThanOrEqualTo(8));
    });

    testWidgets('the open menu meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      await openMenu(tester);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });
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

  testWidgets('a failed first page offers a retry in the stale line', (
    WidgetTester tester,
  ) async {
    catalog.nextFailure = const UnexpectedFailure();
    await open(tester, CatalogPaths.products);
    expect(byKey('stale-line'), findsOneWidget);
    expect(byKey('stale-retry'), findsOneWidget);
    await tester.tap(byKey('stale-retry'));
    await tester.pumpAndSettle();
    expect(find.text('Помидор'), findsOneWidget);
    expect(byKey('stale-line'), findsNothing);
  });

  group('the end of the list', () {
    setUp(() {
      catalog.productRows = <CatalogProduct>[
        for (int i = 0; i < 60; i++)
          catalogProduct(id: 'q-$i', nameRu: 'Товар $i', nameUz: 'Mahsulot $i'),
      ];
    });

    ScrollPosition positionOf(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: byKey('product-grid'),
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

    Future<void> openNarrow(WidgetTester tester, {double height = 812}) async {
      tester.view.physicalSize = Size(375, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, CatalogPaths.products);
    }

    /// Scrolls so that [after] pixels of content stay below the screen.
    Future<void> scrollToExtentAfter(WidgetTester tester, double after) async {
      final ScrollPosition position = positionOf(tester);
      position.jumpTo(position.maxScrollExtent - after);
      await tester.pump();
    }

    testWidgets('the next page is asked two rows before the end', (
      WidgetTester tester,
    ) async {
      catalog.pageSize = 20;
      await openNarrow(tester);
      expect(catalog.requests, <String>['|null|1']);

      await scrollToExtentAfter(tester, 3 * rowOf() + 5);
      expect(catalog.requests, <String>['|null|1']);

      await scrollToExtentAfter(tester, 3 * rowOf() - 15);
      expect(catalog.requests, contains('|null|2'));
      final Finder placeholders = byKey('product-placeholders');
      if (placeholders.evaluate().isNotEmpty) {
        expect(
          tester.getTopLeft(placeholders).dy,
          greaterThanOrEqualTo(tester.view.physicalSize.height),
        );
      }
    });

    testWidgets(
      'while the next page loads the placeholders stand at the end; then the '
      'new cards fade in',
      (WidgetTester tester) async {
        catalog.pageSize = 20;
        await openNarrow(tester);
        catalog.gates[''] = Completer<void>();
        await scrollToExtentAfter(tester, rowOf());
        final ScrollPosition position = positionOf(tester);
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();

        expect(byKey('product-placeholders'), findsOneWidget);
        final List<SkeletonBar> bars = tester
            .widgetList<SkeletonBar>(
              find.descendant(
                of: byKey('product-placeholders'),
                matching: find.byType(SkeletonBar),
              ),
            )
            .toList();
        expect(bars, hasLength(8));
        expect(bars.every((SkeletonBar b) => b.pulsing), isTrue);

        catalog.gates['']!.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final Finder fade = find.descendant(
          of: byKey('card-fade-q-20'),
          matching: find.byType(FadeTransition),
        );
        expect(byKey('product-card-q-20'), findsOneWidget);
        expect(
          tester.widget<FadeTransition>(fade.first).opacity.value,
          lessThan(1),
        );
        await tester.pump(const Duration(milliseconds: 160));
        expect(tester.widget<FadeTransition>(fade.first).opacity.value, 1);
      },
    );

    testWidgets('a short first page asks for the next at once', (
      WidgetTester tester,
    ) async {
      catalog.pageSize = 4;
      catalog.productRows = catalog.productRows.take(10).toList();
      await openNarrow(tester, height: 800);
      expect(catalog.requests, contains('|null|2'));
    });

    testWidgets(
      'a failed next page keeps the cards and offers Повторить in place of '
      'the placeholders',
      (WidgetTester tester) async {
        catalog.pageSize = 30;
        await openNarrow(tester);
        expect(find.text('Товар 0'), findsOneWidget);
        catalog.nextFailure = const UnexpectedFailure();
        final ScrollPosition position = positionOf(tester);
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();

        expect(byKey('product-page-failure'), findsOneWidget);
        expect(byKey('product-placeholders'), findsNothing);
        expect(find.text('Следующие товары не загрузились'), findsOneWidget);
        expect(find.text('Товар 29'), findsOneWidget);
        final Size retry = tester.getSize(byKey('load-more'));
        expect(retry.height, greaterThanOrEqualTo(44));
        expect(retry.width, greaterThanOrEqualTo(44));
        expect(
          tester.getSize(byKey('product-page-failure')).height,
          greaterThanOrEqualTo(56),
        );
        expect(
          find.descendant(
            of: byKey('load-more'),
            matching: find.text('Повторить'),
          ),
          findsOneWidget,
        );

        // Scrolling about asks for nothing until «Повторить».
        position.jumpTo(position.maxScrollExtent - 600);
        await tester.pump();
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(catalog.requests, <String>['|null|1', '|null|2']);

        await tester.tap(byKey('load-more'));
        await tester.pumpAndSettle();
        expect(byKey('product-page-failure'), findsNothing);
        expect(catalog.requests, <String>['|null|1', '|null|2', '|null|2']);
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.text('Товар 59'), findsOneWidget);
      },
    );

    testWidgets('offline, the failed page says there is no connection', (
      WidgetTester tester,
    ) async {
      catalog.pageSize = 30;
      await openNarrow(tester);
      catalog.nextFailure = const NetworkFailure();
      final ScrollPosition position = positionOf(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.text('Нет связи — следующие товары не загрузились'),
        findsOneWidget,
      );
    });

    testWidgets("the scroll indicator's length follows the total", (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[
        for (int i = 0; i < 40; i++)
          catalogProduct(id: 'q-$i', nameRu: 'Товар $i', nameUz: 'Mahsulot $i'),
      ];
      catalog.pageSize = 20;
      await openNarrow(tester);
      final ScrollPosition position = positionOf(tester);
      position.jumpTo(50);
      await tester.pump();

      final double row = rowOf();
      final double full =
          position.maxScrollExtent +
          position.viewportDimension +
          (20 - 10) * row -
          row;
      final double bottom = tester
          .widget<KitProductGrid>(find.byType(KitProductGrid))
          .padding
          .bottom;
      final double track = position.viewportDimension - 8 - bottom;
      expect(
        tester.getSize(byKey('scroll-indicator')).height,
        closeTo(track * position.viewportDimension / full, 1),
      );
    });
  });

  for (final String path in <String>[
    CatalogPaths.recommended,
    CatalogPaths.products,
  ]) {
    group('the grid on $path', () {
      setUp(allFeatured);

      testWidgets(
        'the first load shows pulsing skeletons, then the cards fade in',
        (WidgetTester tester) async {
          catalog.gates[''] = Completer<void>();
          await open(tester, path, settle: false);

          expect(byKey('product-skeletons'), findsOneWidget);
          final List<SkeletonBar> bars = tester
              .widgetList<SkeletonBar>(find.byType(SkeletonBar))
              .toList();
          expect(bars, hasLength(24));
          expect(bars.every((SkeletonBar b) => b.pulsing), isTrue);
          expect(find.text('Помидор'), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);

          catalog.gates['']!.complete();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('Помидор'), findsOneWidget);
          final double mid = tester
              .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
              .opacity
              .value;
          expect(mid, inExclusiveRange(0, 1));

          await tester.pumpAndSettle();
          expect(find.byType(SkeletonBar), findsNothing);
          expect(
            tester
                .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
                .opacity
                .value,
            1,
          );
        },
      );

      testWidgets(
        'a first load that fails shows Нет связи · Повторить over still '
        'skeletons',
        (WidgetTester tester) async {
          catalog.nextFailure = const NetworkFailure();
          await open(tester, path);

          expect(find.text('Нет связи'), findsOneWidget);
          expect(find.text('Повторить'), findsOneWidget);
          final List<SkeletonBar> bars = tester
              .widgetList<SkeletonBar>(find.byType(SkeletonBar))
              .toList();
          expect(bars, hasLength(24));
          expect(bars.any((SkeletonBar b) => b.pulsing), isFalse);

          await tester.tap(byKey('stale-retry'));
          await tester.pumpAndSettle();
          expect(byKey('stale-line'), findsNothing);
          expect(find.text('Помидор'), findsOneWidget);
          expect(find.byType(SkeletonBar), findsNothing);
        },
      );

      testWidgets(
        'a pull refreshes; offline it keeps the cards under the stale line '
        'with their time',
        (WidgetTester tester) async {
          // 12:46 in Tashkent.
          DateTime at = DateTime.utc(2026, 11, 2, 7, 46);
          await open(tester, path, clock: () => at);
          expect(byKey('stale-line'), findsNothing);
          catalog.requests.clear();
          announced(tester).toList();

          // Half an hour on: the line still names the first load's time.
          at = at.add(const Duration(minutes: 30));
          catalog.nextFailure = const NetworkFailure();
          await pull(tester);

          expect(catalog.requests, hasLength(1));
          expect(find.text('Помидор'), findsOneWidget);
          expect(find.text('Нет связи · данные на 12:46'), findsOneWidget);
          expect(
            tester.getBottomLeft(byKey('stale-line')).dy,
            lessThanOrEqualTo(
              tester.getTopLeft(byKey('product-card-${tomato.id}')).dy,
            ),
          );
          expect(
            announced(tester),
            contains('Нет связи. Показаны данные на 12:46'),
          );
        },
      );

      testWidgets(
        'a pull back online clears the line and announces Обновлено',
        (WidgetTester tester) async {
          DateTime at = DateTime.utc(2026, 11, 2, 7, 46);
          await open(tester, path, clock: () => at);
          at = at.add(const Duration(minutes: 30));
          catalog.nextFailure = const NetworkFailure();
          await pull(tester);
          expect(byKey('stale-line'), findsOneWidget);
          announced(tester).toList();

          await pull(tester);
          expect(byKey('stale-line'), findsNothing);
          expect(find.text('Помидор'), findsOneWidget);
          expect(announced(tester), contains('Обновлено'));
        },
      );
    });
  }

  group('the grid in other shapes', () {
    setUp(() {
      catalog.productRows = <CatalogProduct>[
        for (int i = 0; i < 8; i++)
          catalogProduct(
            id: 'g-$i',
            nameRu: 'Товар $i',
            nameUz: 'Mahsulot $i',
            customerUnitPriceUzs: 1000 + i,
          ),
      ];
    });

    int firstRow(WidgetTester tester) {
      final double top = tester.getTopLeft(byKey('product-card-g-0')).dy;
      int count = 0;
      for (int i = 0; i < 8; i++) {
        final Finder card = byKey('product-card-g-$i');
        if (card.evaluate().isNotEmpty && tester.getTopLeft(card).dy == top) {
          count++;
        }
      }
      return count;
    }

    testWidgets(
      'columns follow the width: 2 at 375, 4 lying at 812 with the side insets',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await open(tester, CatalogPaths.products);
        expect(firstRow(tester), 2);

        tester.view.physicalSize = const Size(812, 375);
        await open(tester, CatalogPaths.products, sideInset: 47);
        expect(firstRow(tester), 4);
        expect(
          tester.getTopLeft(byKey('product-card-g-0')).dx,
          greaterThanOrEqualTo(47 + 16),
        );
        expect(
          tester.getTopRight(byKey('product-card-g-3')).dx,
          lessThanOrEqualTo(812 - 47 - 16),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a new order dims the old cards until the new ones come', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.products);
      expect(find.text('Товар 0'), findsOneWidget);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(byKey('product-grid')),
      );

      catalog.gates[''] = Completer<void>();
      container.read(productSortProvider.notifier).set(ProductSort.priceDesc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Товар 0'), findsOneWidget);
      expect(find.byType(SkeletonBar), findsNothing);
      expect(
        tester
            .widget<SliverOpacity>(
              find.descendant(
                of: byKey('dimmed-cards'),
                matching: find.byType(SliverOpacity),
              ),
            )
            .opacity,
        closeTo(0.45, 0.001),
      );
      expect(
        tester.widget<SliverIgnorePointer>(byKey('dimmed-cards')).ignoring,
        isTrue,
      );

      catalog.gates['']!.complete();
      await tester.pumpAndSettle();
      expect(byKey('dimmed-cards'), findsNothing);
      expect(
        tester.getTopLeft(byKey('product-card-g-7')).dy,
        lessThan(tester.getTopLeft(byKey('product-card-g-0')).dy),
        reason: 'the new order puts the dearest first',
      );
    });

    testWidgets('a new order while the next page loads drops that page', (
      WidgetTester tester,
    ) async {
      catalog.pageSize = 30;
      catalog.productRows = <CatalogProduct>[
        for (int i = 0; i < 60; i++)
          catalogProduct(
            id: 'q-$i',
            nameRu: 'Товар $i',
            nameUz: 'Mahsulot $i',
            customerUnitPriceUzs: 1000 + i,
          ),
      ];
      await open(tester, CatalogPaths.products);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(byKey('product-grid')),
      );

      catalog.gates[''] = Completer<void>();
      await tester.drag(byKey('product-grid'), const Offset(0, -9000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        catalog.requests.where((String r) => r.endsWith('|2')),
        hasLength(1),
      );

      container.read(productSortProvider.notifier).set(ProductSort.priceDesc);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(byKey('dimmed-cards'), findsOneWidget);

      catalog.gates['']!.complete();
      await tester.pumpAndSettle();

      final ProductListState fresh = container
          .read(
            productListProvider(
              const ProductListQuery(sort: ProductSort.priceDesc),
            ),
          )
          .requireValue;
      expect(fresh.items, hasLength(30));
      expect(fresh.items.first.id, 'q-59');
      expect(byKey('dimmed-cards'), findsNothing);
      expect(find.text('Товар 59'), findsOneWidget);
      expect(find.text('Товар 0'), findsNothing);
      expect(
        tester.getTopLeft(byKey('product-card-q-59')).dy,
        lessThan(300),
        reason: 'the new list stands from the top',
      );
      expect(
        catalog.requests.where((String r) => r.endsWith('|2')),
        hasLength(1),
      );
    });
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
            await tester.tap(byKey('list-sort'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(byKey('sort-price-asc'), findsOneWidget);
          }
        },
      );
    }
  }
}
