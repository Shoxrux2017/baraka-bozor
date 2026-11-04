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

/// The signed-in Customer, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'c';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

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
          pageBuilder: (BuildContext context, GoRouterState state) =>
              const NoTransitionPage<void>(child: Scaffold(body: Text('home'))),
        ),
        GoRoute(
          path: AppPaths.customerFavorites,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              const NoTransitionPage<void>(child: FavoritesScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWith(
            (Ref ref) => ref.watch(_account),
          ),
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
    expect(tester.widget<Text>(byKey('unavailable-p-2')).data, 'Sotuvda yo\'q');
    expect(
      find.descendant(
        of: byKey('not-sold-heading'),
        matching: find.text('Sotuvda yo\'q'),
      ),
      findsOneWidget,
      reason: 'the heading over the not-sold group (DL-129)',
    );
  });

  testWidgets(
    'taking a heart off keeps the other cards and asks the server for no list',
    (WidgetTester tester) async {
      favorites.rows = <CatalogProduct>[
        favorite('p-1', 'Pomidor'),
        favorite('p-3', 'Anor'),
        favorite('p-2', 'Olma', available: false),
      ];
      await open(tester);

      await tester.tap(byKey('heart-p-1'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(favorites.changes, <String>['remove:p-1']);
      expect(favorites.requests, <String>['default|1']);
      expect(byKey('product-card-p-3'), findsOneWidget);
      expect(byKey('product-card-p-2'), findsOneWidget);
    },
  );

  /// Takes the heart of [id] off and waits until the card has left and the
  /// bar stands.
  Future<void> heartOff(WidgetTester tester, String id) async {
    await tester.tap(byKey('heart-$id'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Lets the bar end by itself and the sending finish.
  Future<void> letBarEnd(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  Color heartColor(WidgetTester tester, String id) =>
      tester.widget<IconButton>(byKey('heart-$id')).color!;

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  group('a heart taken off', () {
    setUp(() {
      favorites.rows = <CatalogProduct>[
        favorite('p-1', 'Помидоры'),
        favorite('p-3', 'Яблоки'),
        favorite('p-4', 'Груши'),
      ];
    });

    testWidgets(
      'the card melts and the bar says «Убрали из избранного: Помидоры · '
      'Вернуть» for 5 s, then the removal is sent',
      (WidgetTester tester) async {
        await open(tester, locale: const Locale('ru'));

        await tester.tap(byKey('heart-p-1'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          byKey('product-card-p-1'),
          findsOneWidget,
          reason: 'the card melts first',
        );
        expect(find.text('Вернуть'), findsNothing);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 300));

        expect(byKey('product-card-p-1'), findsNothing);
        expect(find.text('Убрали из избранного: Помидоры'), findsOneWidget);
        expect(find.text('Вернуть'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        expect(find.text('Вернуть'), findsOneWidget);
        expect(favorites.changes, isEmpty, reason: 'not sent while the bar is');

        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
        expect(find.text('Вернуть'), findsNothing);
        expect(favorites.changes, <String>['remove:p-1']);
        expect(byKey('product-card-p-1'), findsNothing);
      },
    );

    testWidgets('«Вернуть» puts the card back at its place and sends nothing', (
      WidgetTester tester,
    ) async {
      await open(tester, locale: const Locale('ru'));

      await heartOff(tester, 'p-1');
      await tester.tap(find.text('Вернуть'));
      await tester.pumpAndSettle();
      await letBarEnd(tester);

      expect(byKey('product-card-p-1'), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('product-card-p-1')).dx,
        lessThan(tester.getTopLeft(byKey('product-card-p-3')).dx),
        reason: 'back at the first place',
      );
      expect(heartColor(tester, 'p-1'), KitColors.danger);
      expect(favorites.changes, isEmpty);
      expect(favorites.requests, <String>['default|1']);
    });

    testWidgets('offline the card comes back to its place and says why', (
      WidgetTester tester,
    ) async {
      await open(tester, locale: const Locale('ru'));
      favorites.nextFailure = const NetworkFailure();

      await heartOff(tester, 'p-1');
      await letBarEnd(tester);

      expect(favorites.changes, <String>['remove:p-1']);
      expect(byKey('product-card-p-1'), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('product-card-p-1')).dx,
        lessThan(tester.getTopLeft(byKey('product-card-p-3')).dx),
      );
      expect(heartColor(tester, 'p-1'), KitColors.danger);
      expect(find.text('Не удалось убрать: нет связи'), findsOneWidget);
      expect(favorites.requests, <String>['default|1']);
    });

    testWidgets('another failure says it did not work', (
      WidgetTester tester,
    ) async {
      await open(tester, locale: const Locale('ru'));
      favorites.nextFailure = const UnexpectedFailure();

      await heartOff(tester, 'p-1');
      await letBarEnd(tester);

      expect(byKey('product-card-p-1'), findsOneWidget);
      expect(
        find.text('Не удалось убрать. Попробуйте ещё раз'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a second heart taken off sends the first at once; «Вернуть» brings '
      'back only the second',
      (WidgetTester tester) async {
        await open(tester, locale: const Locale('ru'));

        await heartOff(tester, 'p-1');
        expect(favorites.changes, isEmpty);
        await heartOff(tester, 'p-3');
        expect(favorites.changes, <String>['remove:p-1']);
        await tester.pumpAndSettle();
        expect(find.text('Убрали из избранного: Яблоки'), findsOneWidget);

        await tester.tap(find.text('Вернуть'));
        await tester.pumpAndSettle();
        await letBarEnd(tester);

        expect(byKey('product-card-p-3'), findsOneWidget);
        expect(byKey('product-card-p-1'), findsNothing);
        expect(favorites.changes, <String>['remove:p-1']);
      },
    );

    testWidgets('a new order during the bar sends the removal first', (
      WidgetTester tester,
    ) async {
      await open(tester, locale: const Locale('ru'));

      await heartOff(tester, 'p-1');
      await tester.tap(byKey('list-sort'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('sort-price-asc'));
      await tester.pumpAndSettle();

      expect(favorites.calls, <String>[
        'list:default|1',
        'remove:p-1',
        'list:price_asc|1',
      ]);
      expect(find.text('Вернуть'), findsNothing);
      expect(byKey('product-card-p-1'), findsNothing);
    });

    testWidgets('a pull during the bar sends the removal first', (
      WidgetTester tester,
    ) async {
      await open(tester, locale: const Locale('ru'));

      await heartOff(tester, 'p-1');
      await tester.fling(byKey('product-grid'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(favorites.calls, <String>[
        'list:default|1',
        'remove:p-1',
        'list:default|1',
      ]);
      expect(find.text('Вернуть'), findsNothing);
      expect(byKey('product-card-p-1'), findsNothing);
    });

    testWidgets('another Customer during the bar: nothing is sent', (
      WidgetTester tester,
    ) async {
      await open(tester, locale: const Locale('ru'));
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(FavoritesScreen)),
      );

      await heartOff(tester, 'p-1');
      container.read(_account.notifier).signIn('c2');
      await tester.pump();
      await letBarEnd(tester);

      expect(favorites.changes, isEmpty);
      expect(find.text('Вернуть'), findsNothing);
      expect(byKey('product-card-p-1'), findsOneWidget);
      expect(heartColor(tester, 'p-1'), KitColors.danger);
    });

    testWidgets('a screen reader hears the removal and «Вернуть»', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester, locale: const Locale('ru'));
      announced(tester);

      await heartOff(tester, 'p-1');
      expect(announced(tester), contains('Убрали из избранного: Помидоры'));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Вернуть'), findsOneWidget, reason: 'it persists');
      expect(favorites.changes, isEmpty);

      await tester.tap(find.text('Вернуть'));
      await tester.pumpAndSettle();
      expect(announced(tester), contains('Снова в избранном: Помидоры'));
      expect(favorites.changes, isEmpty);
      handle.dispose();
    });

    testWidgets('with reduced motion the card leaves after 160 ms', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester, locale: const Locale('ru'));

      await tester.tap(byKey('heart-p-1'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Вернуть'), findsNothing);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Вернуть'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await letBarEnd(tester);
    });

    testWidgets('leaving the screen before the card has left forgets the '
        'heart', (WidgetTester tester) async {
      await open(tester, locale: const Locale('ru'));
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(FavoritesScreen)),
      );

      await tester.tap(byKey('heart-p-1'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(favoriteOverridesProvider)['p-1'], isFalse);
      router.go(AppPaths.customer);
      await tester.pumpAndSettle();

      expect(container.read(favoriteOverridesProvider), isEmpty);
      expect(favorites.changes, isEmpty);
    });

    testWidgets('«Убрать все» takes every not-sold card and sends one '
        'removal', (WidgetTester tester) async {
      favorites.rows = <CatalogProduct>[
        favorite('s-1', 'Помидоры'),
        favorite('s-2', 'Яблоки'),
        for (int i = 0; i < 25; i++)
          favorite('n-$i', 'Товар $i', available: false),
      ];
      await open(
        tester,
        locale: const Locale('ru'),
        size: const Size(390, 1600),
      );
      expect(byKey('not-sold-remove-all'), findsOneWidget);

      await tester.tap(byKey('not-sold-remove-all'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Убрали из избранного: 25 товаров'),
        findsOneWidget,
        reason: 'the whole count, loaded or not',
      );
      expect(byKey('not-sold-heading'), findsNothing);
      expect(byKey('product-placeholders'), findsNothing);
      expect(byKey('product-card-s-1'), findsOneWidget);
      await letBarEnd(tester);

      expect(favorites.removeNotSoldCalls, 1);
      expect(favorites.changes, <String>['remove-not-sold']);
      expect(favorites.requests, <String>['default|1']);
      expect(byKey('not-sold-heading'), findsNothing);
    });
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

    // The not-sold cards stand under their heading, on a row of their own.
    expect(
      tester.getBottomLeft(byKey('product-card-p-2')).dy,
      lessThan(tester.getTopLeft(byKey('not-sold-heading')).dy),
    );
    expect(
      tester.getBottomLeft(byKey('not-sold-heading')).dy,
      lessThanOrEqualTo(tester.getTopLeft(byKey('product-card-p-1')).dy),
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
