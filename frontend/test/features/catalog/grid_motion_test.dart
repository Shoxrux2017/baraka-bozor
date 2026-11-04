import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_grid.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:baraka_bozor/features/favorites/presentation/not_sold_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

void main() {
  const ProductListQuery query = ProductListQuery.favorites();
  late FakeFavoritesRepository favorites;
  late ProviderContainer container;
  late GoRouter router;
  final ValueNotifier<Set<String>> leaving = ValueNotifier<Set<String>>(
    <String>{},
  );
  ValueChanged<CatalogProduct>? heartOff;
  Future<void> Function()? beforeRefresh;
  bool withHeading = false;
  VoidCallback? removeAll;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  CatalogProduct item(String id, {bool available = true}) => catalogProduct(
    id: id,
    nameUz: id,
    nameRu: id,
    isFavorite: true,
    isAvailable: available,
  );

  Offset at(WidgetTester tester, String id) => tester.getTopLeft(
    find.descendant(
      of: byKey('card-motion-$id'),
      matching: find.byType(KitProductCard),
    ),
  );

  double opacityOf(WidgetTester tester, String id) => tester
      .widget<Opacity>(
        find
            .descendant(
              of: byKey('card-motion-$id'),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  setUp(() {
    favorites = FakeFavoritesRepository(
      favorites: <CatalogProduct>[for (int i = 1; i <= 5; i++) item('p-$i')],
    );
    leaving.value = <String>{};
    heartOff = null;
    beforeRefresh = null;
    withHeading = false;
    removeAll = null;
  });

  Future<void> open(WidgetTester tester, {bool reduced = false}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: ValueListenableBuilder<Set<String>>(
              valueListenable: leaving,
              builder: (BuildContext context, Set<String> gone, Widget? _) =>
                  KitProductGrid(
                    query: query,
                    leaving: gone,
                    onHeartOff: heartOff,
                    beforeRefresh: beforeRefresh,
                    notSoldHeading: withHeading
                        ? (int count) => NotSoldHeading(
                            count: count,
                            onRemoveAll: removeAll,
                          )
                        : null,
                  ),
            ),
          ),
        ),
        GoRoute(
          path: CatalogPaths.productPattern,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('product page')),
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
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(KitProductGrid)),
    );
  }

  ProductListController list() =>
      container.read(productListProvider(query).notifier);

  testWidgets('a leaving card melts and takes no taps', (
    WidgetTester tester,
  ) async {
    await open(tester);
    leaving.value = <String>{'p-1'};
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 95));
    expect(opacityOf(tester, 'p-1'), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 95));
    expect(opacityOf(tester, 'p-1'), 0);
    await tester.tapAt(at(tester, 'p-1') + const Offset(60, 120));
    await tester.pumpAndSettle();
    expect(find.text('product page'), findsNothing);
  });

  testWidgets('when a card is withdrawn its neighbours glide into place', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final Offset third = at(tester, 'p-3');
    final Offset second = at(tester, 'p-2');
    list().withdraw(<String>{'p-1'});
    await tester.pump();
    expect(byKey('card-motion-p-1'), findsNothing);
    expect(at(tester, 'p-3').dy, closeTo(third.dy, 0.5));
    await tester.pump(const Duration(milliseconds: 140));
    final Offset middle = at(tester, 'p-3');
    expect(middle.dy, lessThan(third.dy));
    expect(middle.dy, greaterThan(second.dy));
    await tester.pump(const Duration(milliseconds: 140));
    expect(at(tester, 'p-3').dx, closeTo(second.dx, 0.5));
    expect(at(tester, 'p-3').dy, closeTo(second.dy, 0.5));
  });

  testWidgets('a restored card arrives at its old place', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final Offset first = at(tester, 'p-1');
    final ListWithdrawal withdrawal = list().withdraw(<String>{'p-1'})!;
    await tester.pumpAndSettle();
    list().restore(withdrawal);
    await tester.pump();
    expect(opacityOf(tester, 'p-1'), 0);
    await tester.pump(const Duration(milliseconds: 130));
    expect(opacityOf(tester, 'p-1'), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 130));
    expect(opacityOf(tester, 'p-1'), 1);
    expect(at(tester, 'p-1').dx, closeTo(first.dx, 0.5));
    expect(at(tester, 'p-1').dy, closeTo(first.dy, 0.5));
  });

  testWidgets('a later page still fades in and nothing glides', (
    WidgetTester tester,
  ) async {
    favorites.rows = <CatalogProduct>[
      for (int i = 1; i <= 40; i++) item('p-$i'),
    ];
    await open(tester);
    final Completer<void> hold = Completer<void>();
    favorites.listHold = hold;
    await tester.drag(byKey('product-grid'), const Offset(0, -6000));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    final Offset before = at(tester, 'p-19');
    hold.complete();
    favorites.listHold = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(at(tester, 'p-19'), before);
    expect(byKey('card-fade-p-21'), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(
            find.descendant(
              of: byKey('card-fade-p-21'),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value,
      allOf(greaterThan(0), lessThan(1)),
    );
    expect(opacityOf(tester, 'p-21'), 1, reason: 'no arrival of its own');
  });

  testWidgets('with reduced motion nothing glides and an arrival only fades', (
    WidgetTester tester,
  ) async {
    await open(tester, reduced: true);
    final Offset second = at(tester, 'p-2');
    final ListWithdrawal withdrawal = list().withdraw(<String>{'p-1'})!;
    await tester.pump();
    expect(at(tester, 'p-3').dx, closeTo(second.dx, 0.5));
    expect(at(tester, 'p-3').dy, closeTo(second.dy, 0.5));
    await tester.pumpAndSettle();
    list().restore(withdrawal);
    await tester.pump();
    expect(opacityOf(tester, 'p-1'), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityOf(tester, 'p-1'), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityOf(tester, 'p-1'), 1);
  });

  testWidgets(
    'not-sold cards stand under «Нет в продаже · 2» with «Убрать все»',
    (WidgetTester tester) async {
      favorites.rows = <CatalogProduct>[
        item('p-1'),
        item('p-2'),
        item('p-3', available: false),
        item('p-4', available: false),
      ];
      withHeading = true;
      removeAll = () {};
      await open(tester);
      final Finder heading = byKey('not-sold-heading');
      expect(heading, findsOneWidget);
      expect(
        find.descendant(of: heading, matching: find.text('Нет в продаже')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.text('Убрать все')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(heading).dy,
        greaterThan(at(tester, 'p-1').dy + 100),
        reason: 'under the sold card',
      );
      expect(
        at(tester, 'p-3').dy,
        greaterThanOrEqualTo(tester.getBottomLeft(heading).dy),
      );
      expect(at(tester, 'p-3').dy, closeTo(at(tester, 'p-4').dy, 0.5));
      expect(find.bySemanticsLabel('Нет в продаже, 2 товара'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Убрать все снятые с продажи: 2 товара'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the heading waits for the first not-sold card', (
    WidgetTester tester,
  ) async {
    favorites.rows = <CatalogProduct>[
      for (int i = 1; i <= 20; i++) item('p-$i'),
      item('p-21', available: false),
      item('p-22', available: false),
    ];
    withHeading = true;
    await open(tester);
    final Completer<void> hold = Completer<void>();
    favorites.listHold = hold;
    await tester.drag(byKey('product-grid'), const Offset(0, -6000));
    await tester.pump(const Duration(seconds: 1));
    expect(byKey('not-sold-heading'), findsNothing);
    hold.complete();
    favorites.listHold = null;
    await tester.pumpAndSettle();
    await tester.drag(byKey('product-grid'), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(byKey('not-sold-heading'), findsOneWidget);
  });

  testWidgets('a red heart with onHeartOff calls it and sends nothing', (
    WidgetTester tester,
  ) async {
    final List<String> called = <String>[];
    heartOff = (CatalogProduct p) => called.add(p.id);
    await open(tester);
    await tester.tap(byKey('heart-p-1'));
    await tester.pumpAndSettle();
    expect(called, <String>['p-1']);
    expect(favorites.changes, isEmpty);
  });

  testWidgets('a pull awaits beforeRefresh before asking again', (
    WidgetTester tester,
  ) async {
    final Completer<void> hold = Completer<void>();
    beforeRefresh = () => hold.future;
    await open(tester);
    final int loads = favorites.listLoads;
    await tester.drag(byKey('product-grid'), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(favorites.listLoads, loads);
    hold.complete();
    await tester.pumpAndSettle();
    expect(favorites.listLoads, loads + 1);
  });

  testWidgets('the grid with the heading passes the tap-target guideline', (
    WidgetTester tester,
  ) async {
    favorites.rows = <CatalogProduct>[
      item('p-1'),
      item('p-2', available: false),
    ];
    withHeading = true;
    removeAll = () {};
    await open(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  });
}
