import 'dart:async';

import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/aisles.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_products_screen.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';
import '../../support/nonlinear_text_scaler.dart';

/// «Все товары» aisle by aisle, with its chips row (`DL-128`).
void main() {
  late FakeCatalogRepository catalog;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  /// [aisles] as (id, Russian name, product count): the categories, and the
  /// products in the shop's order, aisle by aisle.
  void stock(List<(String, String, int)> aisles, {int? pageSize}) {
    catalog.categoryRows = <CatalogCategory>[
      for (final (String id, String name, int count) in aisles)
        catalogCategory(
          id: id,
          nameRu: name,
          nameUz: '$name uz',
          productCount: count,
        ),
    ];
    catalog.productRows = <CatalogProduct>[
      for (final (String id, String name, int count) in aisles)
        for (int i = 1; i <= count; i++)
          catalogProduct(
            id: 'p-$id-$i',
            categoryId: id,
            nameRu: '$name $i',
            nameUz: '$name $i uz',
            customerUnitPriceUzs: 1000 * i,
          ),
    ];
    if (pageSize != null) {
      catalog.pageSize = pageSize;
    }
  }

  final List<(String, String, int)> three = <(String, String, int)>[
    ('c-1', 'Овощи', 20),
    ('c-2', 'Фрукты', 20),
    ('c-3', 'Молоко', 20),
  ];

  setUp(() {
    catalog = FakeCatalogRepository();
    catalog.pageSize = 100;
  });

  /// Runs the clock for [ms]; a list with more to come never settles, as its
  /// placeholders pulse.
  Future<void> run(WidgetTester tester, {int ms = 2500}) async {
    for (int t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('ru'),
    TextScaler? textScaler,
    double sideInset = 0,
    bool reduced = false,
    bool paged = false,
  }) async {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const AllProductsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          catalogRepositoryProvider.overrideWithValue(catalog),
          cartRepositoryProvider.overrideWithValue(FakeCartRepository()),
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
              textScaler: textScaler,
              disableAnimations: reduced,
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (paged) {
      await run(tester);
    } else {
      await tester.pumpAndSettle();
    }
  }

  void size(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Iterable<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message);

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: byKey('product-grid'),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  /// Whether the chip of [id] is the lit one (bold text).
  bool lit(WidgetTester tester, String id) {
    final AnimatedDefaultTextStyle style = tester.widget(
      find.descendant(
        of: byKey('aisle-chip-$id'),
        matching: find.byType(AnimatedDefaultTextStyle),
      ),
    );
    return style.style.fontWeight == FontWeight.w700;
  }

  double gridTop(WidgetTester tester) =>
      tester.getTopLeft(byKey('product-grid')).dy;

  Future<void> chooseOrder(WidgetTester tester, String key) async {
    await tester.tap(byKey('list-sort'));
    await tester.pumpAndSettle();
    await tester.tap(byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('in the shop order the products stand under aisle headings', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    size(tester, 520, 1600);
    stock(<(String, String, int)>[('c-1', 'Овощи', 8), ('c-2', 'Фрукты', 3)]);
    await open(tester);

    expect(byKey('aisle-c-1'), findsOneWidget);
    expect(byKey('aisle-c-2'), findsOneWidget);
    expect(find.text('Овощи 8', findRichText: true), findsOneWidget);
    expect(
      tester.getSemantics(byKey('aisle-c-1')),
      matchesSemantics(label: 'Овощи, 8 товаров', isHeader: true),
    );
    expect(
      tester.getSemantics(byKey('aisle-c-2')),
      matchesSemantics(label: 'Фрукты, 3 товара', isHeader: true),
    );

    // Three cards to a row: the eighth vegetable stands in a half row, and
    // the fruit begin on a row of their own under their heading.
    final Offset seventh = tester.getTopLeft(byKey('p-c-1-7'));
    final Offset eighth = tester.getTopLeft(byKey('p-c-1-8'));
    final Offset fruit = tester.getTopLeft(byKey('p-c-2-1'));
    expect(eighth.dy, seventh.dy);
    expect(eighth.dx, greaterThan(seventh.dx));
    expect(fruit.dx, tester.getTopLeft(byKey('p-c-1-1')).dx);
    expect(
      tester.getRect(byKey('aisle-c-2')).top,
      greaterThan(tester.getRect(byKey('p-c-1-8')).bottom),
    );
    expect(
      fruit.dy,
      greaterThanOrEqualTo(tester.getRect(byKey('aisle-c-2')).bottom),
    );
    expect(byKey('aisle-chips'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a heading reads in Uzbek and the first stands closer to the '
      'count row', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    size(tester, 375, 1200);
    stock(<(String, String, int)>[('c-1', 'Овощи', 4), ('c-2', 'Фрукты', 3)]);
    await open(tester, locale: const Locale('uz'));

    expect(
      tester.getSemantics(byKey('aisle-c-1')),
      matchesSemantics(label: 'Овощи uz, 4 ta mahsulot', isHeader: true),
    );
    // 2 above the first heading's text, 14 above the next one's.
    final double first = tester.getSize(byKey('aisle-c-1')).height;
    final double second = tester.getSize(byKey('aisle-c-2')).height;
    expect(first, second - 12);
    handle.dispose();
  });

  testWidgets('a heading sets the count 6 px after the name on one baseline', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 1200);
    stock(<(String, String, int)>[('c-1', 'Овощи', 8)]);
    await open(tester);

    final RenderParagraph paragraph = tester.renderObject(
      find.descendant(of: byKey('aisle-c-1'), matching: find.byType(RichText)),
    );
    final TextBox name = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5),
        )
        .single;
    final TextBox count = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 6, extentOffset: 7),
        )
        .single;
    expect(count.left - name.right, closeTo(6, 0.5));
    expect(count.bottom, closeTo(name.bottom, 6), reason: 'one line');
  });

  testWidgets('a product of a category the shop does not list has no heading', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 1200);
    stock(<(String, String, int)>[('c-1', 'Овощи', 2), ('c-2', 'Фрукты', 2)]);
    catalog.categoryRows = <CatalogCategory>[catalog.categoryRows.last];
    await open(tester);

    expect(byKey('aisle-c-1'), findsNothing);
    expect(byKey('aisle-c-2'), findsOneWidget);
    expect(byKey('p-c-1-1'), findsOneWidget);
  });

  testWidgets('a price order is flat and the chips fold', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 1200);
    stock(<(String, String, int)>[('c-1', 'Овощи', 4), ('c-2', 'Фрукты', 4)]);
    await open(tester);
    expect(byKey('aisle-chips'), findsOneWidget);
    final double open0 = gridTop(tester);

    await chooseOrder(tester, 'sort-price-asc');

    expect(byKey('aisle-c-1'), findsNothing);
    expect(byKey('aisle-c-2'), findsNothing);
    expect(byKey('aisle-chips'), findsNothing);
    expect(gridTop(tester), lessThan(open0));
    // Cheapest first, aisles mixed.
    expect(
      tester.getTopLeft(byKey('p-c-1-1')).dy,
      tester.getTopLeft(byKey('p-c-2-1')).dy,
    );

    await chooseOrder(tester, 'sort-shop');
    expect(byKey('aisle-c-1'), findsOneWidget);
    expect(byKey('aisle-chips'), findsOneWidget);
    expect(gridTop(tester), open0);
    expect(lit(tester, 'c-1'), isTrue);
  });

  testWidgets('the chips fold in 220 ms', (WidgetTester tester) async {
    size(tester, 375, 1200);
    stock(<(String, String, int)>[('c-1', 'Овощи', 4), ('c-2', 'Фрукты', 4)]);
    await open(tester);
    final double shown = gridTop(tester);

    await tester.tap(byKey('list-sort'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('sort-price-asc'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(gridTop(tester), lessThan(shown));
    expect(byKey('aisle-chips'), findsOneWidget, reason: 'half folded');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(byKey('aisle-chips'), findsNothing);
  });

  testWidgets('the chips fold at once with reduced motion', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 1200);
    stock(<(String, String, int)>[('c-1', 'Овощи', 4), ('c-2', 'Фрукты', 4)]);
    await open(tester, reduced: true);
    final double stillShown = gridTop(tester);
    await tester.tap(byKey('list-sort'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('sort-price-asc'));
    await tester.pump();
    await tester.pump();
    expect(byKey('aisle-chips'), findsNothing);
    expect(gridTop(tester), lessThan(stillShown));
  });

  testWidgets('scrolling lights the aisle in view', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three);
    await open(tester);
    expect(lit(tester, 'c-1'), isTrue);

    final double row = tester.getSize(byKey('p-c-1-1')).height + 12;
    position(tester).jumpTo(10 * row + 300);
    await tester.pumpAndSettle();
    expect(lit(tester, 'c-1'), isFalse);
    expect(lit(tester, 'c-2'), isTrue);
    expect(lit(tester, 'c-3'), isFalse);

    position(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(lit(tester, 'c-1'), isTrue);
    expect(lit(tester, 'c-2'), isFalse);
  });

  testWidgets('a chip tap glides to its aisle and announces it', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three);
    await open(tester);
    announced(tester).toList();

    await tester.tap(byKey('aisle-chip-c-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      position(tester).pixels,
      allOf(greaterThan(0), lessThan(position(tester).maxScrollExtent)),
      reason: 'mid-glide',
    );
    expect(lit(tester, 'c-2'), isTrue, reason: 'lit from the tap');
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(byKey('aisle-c-2')).dy - gridTop(tester),
      closeTo(6, 0.5),
    );
    expect(announced(tester), contains('Фрукты, 20 товаров'));
    expect(lit(tester, 'c-2'), isTrue);

    // After 700 ms scrolling lights the aisles again.
    await tester.pump(const Duration(milliseconds: 800));
    position(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(lit(tester, 'c-1'), isTrue);
  });

  testWidgets('with reduced motion a chip tap jumps', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three);
    await open(tester, reduced: true);

    await tester.tap(byKey('aisle-chip-c-2'));
    await tester.pump();
    await tester.pump();

    expect(
      tester.getTopLeft(byKey('aisle-c-2')).dy - gridTop(tester),
      closeTo(6, 0.5),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a chip tap beyond the loaded pages loads them first', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three, pageSize: 20);
    await open(tester, paged: true);
    expect(byKey('aisle-c-3'), findsNothing);
    expect(catalog.requests, <String>['|null|1']);

    await tester.tap(byKey('aisle-chip-c-3'));
    await run(tester);

    expect(catalog.requests, <String>['|null|1', '|null|2', '|null|3']);
    expect(byKey('aisle-c-3'), findsOneWidget);
    expect(
      tester.getTopLeft(byKey('aisle-c-3')).dy - gridTop(tester),
      closeTo(6, 0.5),
    );
    expect(lit(tester, 'c-3'), isTrue);
    expect(announced(tester), contains('Молоко, 20 товаров'));
  });

  testWidgets('a jump that cannot load stops at the failure row', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three, pageSize: 20);
    await open(tester, paged: true);
    catalog.nextFailure = const NetworkFailure();
    announced(tester).toList();

    await tester.tap(byKey('aisle-chip-c-3'));
    await run(tester);

    expect(byKey('aisle-c-3'), findsNothing, reason: 'nothing to glide to');
    expect(byKey('product-page-failure'), findsOneWidget);
    final Rect grid = tester.getRect(byKey('product-grid'));
    expect(
      tester.getRect(byKey('product-page-failure')).bottom,
      lessThanOrEqualTo(grid.bottom),
      reason: 'the row is in view',
    );
    expect(
      announced(tester).where((String m) => m.contains('Молоко')),
      isEmpty,
    );

    await tester.tap(byKey('load-more'));
    await run(tester);
    expect(byKey('product-page-failure'), findsNothing);
    expect(catalog.requests.last, '|null|2');
  });

  testWidgets('a second chip tap during a jump goes to the second aisle', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three, pageSize: 20);
    await open(tester, paged: true);
    final Completer<void> gate = Completer<void>();
    catalog.gates[''] = gate;
    announced(tester).toList();

    await tester.tap(byKey('aisle-chip-c-3'));
    await tester.pump();
    await tester.tap(byKey('aisle-chip-c-2'));
    await tester.pump();
    catalog.gates.remove('');
    gate.complete();
    await run(tester);

    expect(lit(tester, 'c-2'), isTrue);
    expect(lit(tester, 'c-3'), isFalse);
    expect(
      tester.getTopLeft(byKey('aisle-c-2')).dy - gridTop(tester),
      closeTo(6, 0.5),
    );
    final List<String> said = announced(tester).toList();
    expect(said, contains('Фрукты, 20 товаров'));
    expect(said.where((String m) => m.contains('Молоко')), isEmpty);
  });

  testWidgets('another order starts at the first aisle', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three);
    await open(tester);
    await tester.tap(byKey('aisle-chip-c-3'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(lit(tester, 'c-3'), isTrue);

    position(tester).jumpTo(0);
    await tester.pumpAndSettle();
    await chooseOrder(tester, 'sort-price-desc');
    await chooseOrder(tester, 'sort-shop');

    expect(lit(tester, 'c-1'), isTrue);
    expect(lit(tester, 'c-3'), isFalse);
    expect(position(tester).pixels, 0);
  });

  testWidgets('chips read Фрукты, раздел 2 из 8 and the current one is '
      'selected', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    size(tester, 375, 800);
    stock(<(String, String, int)>[
      for (int i = 1; i <= 8; i++) ('c-$i', i == 2 ? 'Фрукты' : 'Раздел $i', 3),
    ]);
    await open(tester);

    expect(
      tester.getSemantics(byKey('aisle-chip-c-2')),
      matchesSemantics(
        label: 'Фрукты, раздел 2 из 8',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
      ),
    );
    expect(
      tester.getSemantics(byKey('aisle-chip-c-1')),
      matchesSemantics(
        label: 'Раздел 1, раздел 1 из 8',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the chips follow the aisle in view and the lit one is drawn '
      'in the kit colours', (WidgetTester tester) async {
    size(tester, 375, 800);
    stock(<(String, String, int)>[
      for (int i = 1; i <= 8; i++) ('c-$i', 'Раздел номер $i', 6),
    ]);
    await open(tester);
    expect(tester.getRect(byKey('aisle-chip-c-8')).left, greaterThan(375));

    // 6 products an aisle: a heading and 3 rows of 301 each, 8 aisles.
    position(tester).jumpTo(7 * 937 + 400);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    final Rect chip = tester.getRect(byKey('aisle-chip-c-8'));
    expect(chip.right, lessThanOrEqualTo(375));
    expect(chip.left, greaterThanOrEqualTo(0));
    final AnimatedContainer pill = tester.widget(
      find.descendant(
        of: byKey('aisle-chip-c-8'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((pill.decoration! as BoxDecoration).color, KitColors.primaryWash);
    expect(
      tester.getSize(byKey('aisle-chip-c-8')).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: byKey('aisle-chip-c-8'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .height,
      34,
    );
  });

  testWidgets('at text x2 on 320 wide the headings wrap and nothing '
      'overflows', (WidgetTester tester) async {
    size(tester, 320, 640);
    stock(<(String, String, int)>[
      ('c-1', 'Молочные продукты и яйца', 4),
      ('c-2', 'Хлеб', 4),
    ]);
    await open(tester, textScaler: const NonlinearTextScaler(2));

    final double long = tester.getSize(byKey('aisle-c-1')).height;
    expect(long, greaterThan(80), reason: 'the long name wraps to two lines');
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(byKey('aisle-chip-c-1')).height,
      greaterThanOrEqualTo(44),
    );

    position(tester).jumpTo(position(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // What the list measures is what the heading draws.
    position(tester).jumpTo(0);
    await tester.pumpAndSettle();
    final CatalogCategory category = catalog.categoryRows.first;
    expect(
      tester.getSize(byKey('aisle-c-1')).height,
      aisleHeadingExtent(
        category,
        320 - 32,
        const NonlinearTextScaler(2),
        TextDirection.ltr,
        language: AppLanguage.ru,
        first: true,
      ),
    );
  });

  testWidgets('lying with a notch the chips row keeps clear of the camera', (
    WidgetTester tester,
  ) async {
    size(tester, 812, 375);
    stock(<(String, String, int)>[
      for (int i = 1; i <= 8; i++) ('c-$i', 'Раздел номер $i', 6),
    ]);
    await open(tester, sideInset: 47);

    final Rect row = tester.getRect(byKey('aisle-chips'));
    expect(row.left, greaterThanOrEqualTo(47));
    expect(row.right, lessThanOrEqualTo(812 - 47));
    expect(
      tester.getRect(byKey('aisle-chip-c-1')).left,
      greaterThanOrEqualTo(47),
    );
  });

  testWidgets('Все товары with chips meets the tap target guideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    size(tester, 375, 667);
    stock(three);
    await open(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

    size(tester, 320, 640);
    await open(tester, textScaler: const NonlinearTextScaler(2));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a later page still announces itself under the headings', (
    WidgetTester tester,
  ) async {
    size(tester, 375, 800);
    stock(three, pageSize: 20);
    await open(tester, paged: true);
    announced(tester).toList();

    position(tester).jumpTo(position(tester).maxScrollExtent);
    await run(tester);

    expect(announced(tester), contains('Загружено ещё 20 товаров'));
    final ProductListState list = ProviderScope.containerOf(
      tester.element(byKey('product-grid')),
    ).read(productListProvider(const ProductListQuery())).requireValue;
    expect(list.items, hasLength(40));
  });
}
