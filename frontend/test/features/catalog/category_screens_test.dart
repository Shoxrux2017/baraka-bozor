import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/platform/clock.dart';
import 'package:baraka_bozor/core/routing/app_page.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/active_mode_bar.dart';
import 'package:baraka_bozor/core/widgets/press_scale.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
import 'package:baraka_bozor/core/widgets/skeleton_bar.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_categories_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/category_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/category_tile.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_grid.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_address_map.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/nonlinear_text_scaler.dart';
import '../../support/fake_favorites_repository.dart';
import '../../support/in_memory_stores.dart';

/// Both sessions signed in, the Customer's active.
class _TwoSessions extends SessionController {
  @override
  Future<SessionState> build() async => SignedIn(
    activeMode: SessionMode.customer,
    staffUser: user(id: 's', role: UserRole.courier),
    customerUser: user(id: 'c'),
  );
}

void main() {
  late FakeCatalogRepository catalog;
  late GoRouter router;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  const String longName = 'Uzun nomli bolim va yana bir nechta soz';

  setUp(() {
    catalog = FakeCatalogRepository(
      categories: <CatalogCategory>[
        catalogCategory(imageUrl: 'https://example.test/veg.png'),
        catalogCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
        catalogCategory(
          id: 'c-3',
          nameUz: longName,
          nameRu: 'Очень длинное название раздела товаров',
        ),
      ],
      products: <CatalogProduct>[
        catalogProduct(),
        catalogProduct(
          id: 'p-2',
          categoryId: 'c-2',
          nameUz: 'Olma',
          nameRu: 'Яблоко',
        ),
      ],
    );
  });

  Future<void> open(
    WidgetTester tester,
    String path, {
    Locale locale = const Locale('uz'),
    bool twoSessions = false,
    bool settle = true,
    FakeCartRepository? cart,
    DateTime Function()? clock,
    TextScaler? textScaler,
  }) async {
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('start')),
        ),
        GoRoute(
          path: CatalogPaths.categories,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              appPage(state, const AllCategoriesScreen()),
        ),
        GoRoute(
          path: CatalogPaths.categoryPattern,
          pageBuilder: (BuildContext context, GoRouterState state) => appPage(
            state,
            CategoryScreen(
              categoryId: state.pathParameters['category']!,
              opening: state.extra is CategoryOpening
                  ? state.extra! as CategoryOpening
                  : null,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          if (twoSessions)
            sessionControllerProvider.overrideWith(_TwoSessions.new),
          catalogRepositoryProvider.overrideWithValue(catalog),
          cartRepositoryProvider.overrideWithValue(
            cart ?? FakeCartRepository(),
          ),
          if (clock != null) clockProvider.overrideWithValue(clock),
          favoritesRepositoryProvider.overrideWithValue(
            FakeFavoritesRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: textScaler == null
              ? null
              : (BuildContext context, Widget? child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
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
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('all categories', () {
    testWidgets('shows every category, a letter where there is no picture', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.categories);

      expect(byKey('category-c-1'), findsOneWidget);
      expect(byKey('category-c-2'), findsOneWidget);
      expect(byKey('category-c-3'), findsOneWidget);
      expect(find.text('Sabzavotlar'), findsOneWidget);
      expect(
        find.descendant(of: byKey('category-c-2'), matching: find.text('M')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: byKey('category-c-1'), matching: find.text('S')),
        findsNothing,
        reason: 'a category with a picture shows no letter',
      );
    });

    testWidgets('tapping a tile opens its category', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.categories);

      await tester.tap(byKey('category-c-2'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryScreen), findsOneWidget);
      expect(find.text('Olma'), findsOneWidget);
    });

    List<CatalogCategory> many(int n) => <CatalogCategory>[
      for (int i = 1; i <= n; i++)
        catalogCategory(id: 'c-$i', nameUz: 'Bolim $i', nameRu: 'Раздел $i'),
    ];

    Future<void> pull(WidgetTester tester) async {
      await tester.drag(byKey('category-grid'), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    void size(WidgetTester tester, double w, double h) {
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('the title is Категории', (WidgetTester tester) async {
      await open(tester, CatalogPaths.categories, locale: const Locale('ru'));

      expect(find.text('Категории'), findsOneWidget);
      expect(find.text('Разделы'), findsNothing);
    });

    testWidgets('the cart bar shows while the cart holds a line and the last '
        'tiles stay clear of it', (WidgetTester tester) async {
      size(tester, 375, 667);
      catalog.categoryRows = many(16);
      await open(tester, CatalogPaths.categories);
      expect(byKey('cart-summary'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await open(
        tester,
        CatalogPaths.categories,
        cart: FakeCartRepository(
          cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
        ),
      );
      expect(byKey('cart-summary'), findsOneWidget);

      await tester.drag(byKey('category-grid'), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(byKey('category-c-16')).bottom,
        lessThanOrEqualTo(tester.getTopLeft(byKey('cart-summary')).dy),
      );
    });

    testWidgets('columns follow the width: 4 at 375, 2 at text x2 with '
        'three-line names, 8 lying at 812', (WidgetTester tester) async {
      int columns() {
        final double top = tester.getTopLeft(byKey('category-c-1')).dy;
        int n = 0;
        for (int i = 1; i <= 16; i++) {
          final Finder f = byKey('category-c-$i');
          if (f.evaluate().isNotEmpty && tester.getTopLeft(f).dy == top) {
            n++;
          }
        }
        return n;
      }

      catalog.categoryRows = many(16);
      size(tester, 375, 812);
      await open(tester, CatalogPaths.categories);
      expect(columns(), 4);

      await tester.pumpWidget(const SizedBox());
      size(tester, 812, 375);
      await open(tester, CatalogPaths.categories);
      expect(columns(), 8);

      await tester.pumpWidget(const SizedBox());
      size(tester, 375, 812);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      catalog.categoryRows = <CatalogCategory>[
        ...many(4),
        catalogCategory(
          id: 'c-5',
          nameUz: longName,
          nameRu: 'Очень длинное название раздела товаров',
        ),
      ];
      await open(tester, CatalogPaths.categories);
      expect(columns(), 2);
      final Text name = tester.widget<Text>(
        find
            .descendant(of: byKey('category-c-5'), matching: find.byType(Text))
            .last,
      );
      expect(name.maxLines, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading shows pulsing skeletons, then the tiles fade in', (
      WidgetTester tester,
    ) async {
      catalog.categoriesGate = Completer<void>();
      await open(tester, CatalogPaths.categories, settle: false);

      final List<SkeletonBar> bars = tester
          .widgetList<SkeletonBar>(find.byType(SkeletonBar))
          .toList();
      expect(bars, hasLength(24));
      expect(bars.every((SkeletonBar b) => b.pulsing), isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(byKey('category-c-1'), findsNothing);

      catalog.categoriesGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double mid = tester
          .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
          .opacity
          .value;
      expect(mid, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonBar), findsNothing);
      expect(byKey('category-c-1'), findsOneWidget);
      expect(
        tester
            .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
            .opacity
            .value,
        1,
      );
    });

    double appearOpacity(WidgetTester tester, String id) => tester
        .widget<Opacity>(
          find.descendant(
            of: byKey('appear-$id'),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('pull to refresh brings a new category in at the end', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.categories);
      expect(byKey('category-c-4'), findsNothing);
      expect(appearOpacity(tester, 'c-1'), 1);

      catalog.categoryRows = <CatalogCategory>[
        ...catalog.categoryRows,
        catalogCategory(id: 'c-4', nameUz: 'Go`sht', nameRu: 'Мясо'),
      ];
      await tester.drag(byKey('category-grid'), const Offset(0, 300));
      for (int i = 0; i < 200 && byKey('appear-c-4').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(byKey('appear-c-4'), findsOneWidget);
      expect(appearOpacity(tester, 'c-4'), lessThan(1));
      expect(appearOpacity(tester, 'c-1'), 1);
      await tester.pumpAndSettle();
      expect(catalog.categoryLoads, 2);
      expect(appearOpacity(tester, 'c-4'), 1);
    });

    testWidgets('offline after a load keeps the tiles with the stale line and '
        'its time', (WidgetTester tester) async {
      // 12:46 in Tashkent.
      DateTime at = DateTime.utc(2026, 11, 2, 7, 46);
      await open(
        tester,
        CatalogPaths.categories,
        locale: const Locale('ru'),
        clock: () => at,
      );
      expect(byKey('stale-line'), findsNothing);

      // Half an hour on: the line still names the first load's time.
      at = at.add(const Duration(minutes: 30));
      catalog.categoriesFailure = const NetworkFailure();
      await pull(tester);

      expect(byKey('category-c-1'), findsOneWidget);
      expect(byKey('category-c-2'), findsOneWidget);
      expect(find.text('Нет связи · данные на 12:46'), findsOneWidget);
      expect(
        tester.getBottomLeft(byKey('stale-line')).dy,
        lessThanOrEqualTo(tester.getTopLeft(byKey('category-c-1')).dy),
      );

      await pull(tester);
      expect(byKey('stale-line'), findsNothing);
      expect(byKey('category-c-1'), findsOneWidget);
    });

    testWidgets('a first load that fails shows Нет связи · Повторить over '
        'still skeletons', (WidgetTester tester) async {
      catalog.categoriesFailure = const NetworkFailure();
      await open(tester, CatalogPaths.categories, locale: const Locale('ru'));

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
      expect(byKey('category-c-1'), findsOneWidget);
      expect(find.byType(SkeletonBar), findsNothing);
    });

    testWidgets('a pull announces Обновлено, or the stale words (P3-3)', (
      WidgetTester tester,
    ) async {
      DateTime at = DateTime.utc(2026, 11, 2, 7, 46);
      await open(
        tester,
        CatalogPaths.categories,
        locale: const Locale('ru'),
        clock: () => at,
      );
      tester.takeAnnouncements();

      await pull(tester);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Обновлено'),
      );

      at = at.add(const Duration(minutes: 30));
      catalog.categoriesFailure = const NetworkFailure();
      await pull(tester);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Нет связи. Показаны данные на 12:46'),
      );

      // The line's own retry does what the pull does.
      await tester.tap(byKey('stale-retry'));
      await tester.pumpAndSettle();
      expect(byKey('stale-line'), findsNothing);
      expect(
        tester.takeAnnouncements().map((a) => a.message),
        contains('Обновлено'),
      );
    });

    testWidgets('a retry after a failure shows its progress (P2-2)', (
      WidgetTester tester,
    ) async {
      catalog.categoriesFailure = const NetworkFailure();
      await open(tester, CatalogPaths.categories, locale: const Locale('ru'));
      final int loads = catalog.categoryLoads;
      catalog.categoriesGate = Completer<void>();

      await tester.tap(byKey('stale-retry'));
      await tester.pump();

      expect(
        tester
            .widgetList<SkeletonBar>(
              find.descendant(
                of: byKey('category-skeletons'),
                matching: find.byType(SkeletonBar),
              ),
            )
            .every((SkeletonBar b) => b.pulsing),
        isTrue,
      );
      expect(
        find.descendant(
          of: byKey('stale-retry'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(byKey('stale-retry')).onPressed, isNull);
      await tester.tap(byKey('stale-retry'), warnIfMissed: false);
      await tester.pump();
      expect(catalog.categoryLoads, loads + 1, reason: 'one request');

      catalog.categoriesGate!.complete();
      await tester.pumpAndSettle();
      expect(byKey('stale-line'), findsNothing);
    });

    testWidgets('a retry over kept tiles is busy and starts one request', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.categories, locale: const Locale('ru'));
      catalog.categoriesFailure = const NetworkFailure();
      await pull(tester);
      final int loads = catalog.categoryLoads;
      catalog.categoriesGate = Completer<void>();

      await tester.tap(byKey('stale-retry'));
      await tester.pump();
      expect(
        find.descendant(
          of: byKey('stale-retry'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(byKey('stale-retry'), warnIfMissed: false);
      await tester.pump();
      expect(catalog.categoryLoads, loads + 1);

      catalog.categoriesGate!.complete();
      await tester.pumpAndSettle();
      expect(byKey('stale-line'), findsNothing);
    });

    testWidgets(
      "with Android's nonlinear text at 200 % the categories stand in two "
      'columns',
      (WidgetTester tester) async {
        size(tester, 375, 812);
        await open(
          tester,
          CatalogPaths.categories,
          locale: const Locale('ru'),
          textScaler: const NonlinearTextScaler(2),
        );

        expect(
          tester.getTopLeft(byKey('category-c-2')).dy,
          tester.getTopLeft(byKey('category-c-1')).dy,
        );
        expect(
          tester.getTopLeft(byKey('category-c-3')).dy,
          greaterThan(tester.getTopLeft(byKey('category-c-1')).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a tile reads as its name and a button, a letter tile without '
        'the letter', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester, CatalogPaths.categories, locale: const Locale('ru'));

      final SemanticsNode node = tester.getSemantics(
        find.descendant(
          of: byKey('category-c-2'),
          matching: find.byType(PressScale),
        ),
      );
      expect(node.label, 'Фрукты');
      // ignore: deprecated_member_use
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      semantics.dispose();
    });

    testWidgets('the cart bar is one phrase', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(
        tester,
        CatalogPaths.categories,
        locale: const Locale('ru'),
        cart: FakeCartRepository(
          cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
        ),
      );
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('ru'),
      );
      final String phrase = l10n.cartSummarySpoken(
        l10n.cartSummaryCount(1),
        MoneyFormat.uzs(27600, AppLanguage.ru),
      );

      expect(find.bySemanticsLabel(phrase), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('→')), findsNothing);
      semantics.dispose();
    });

    for (final double scale in <double>[1, 2]) {
      testWidgets('every target of all categories meets iOSTapTargetGuideline '
          '(text x$scale)', (WidgetTester tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        size(tester, 320, 640);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await open(
          tester,
          CatalogPaths.categories,
          locale: const Locale('ru'),
          cart: FakeCartRepository(
            cart: cartOf(<Map<String, Object?>>[cartLineJson()]),
          ),
        );
        catalog.categoriesFailure = const NetworkFailure();
        await pull(tester);
        expect(byKey('stale-line'), findsOneWidget);
        expect(byKey('category-c-1'), findsOneWidget);

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        semantics.dispose();
      });
    }

    testWidgets('pressing a tile shrinks it to 0.96 and opens the category', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.categories);
      final Finder scale = find.descendant(
        of: byKey('category-c-2'),
        matching: find.byType(ScaleTransition),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(byKey('category-c-2')),
      );
      // In a scrolling grid the press is told after the press timeout.
      await tester.pump(kPressTimeout);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.widget<ScaleTransition>(scale).scale.value,
        closeTo(0.96, 0.001),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(CategoryScreen), findsOneWidget);
    });
  });

  group('opening from a tile', () {
    Finder flight() => byKey('category-well-flight');

    Finder categoryHeroes() => find.byWidgetPredicate(
      (Widget w) => w is Hero && w.flightShuttleBuilder == categoryWellFlight,
    );

    List<CatalogCategory> many(int n) => <CatalogCategory>[
      for (int i = 1; i <= n; i++)
        catalogCategory(id: 'c-$i', nameUz: 'Bolim $i', nameRu: 'Раздел $i'),
    ];

    Future<void> openApp(WidgetTester tester) async {
      final InMemoryTokenStore tokens = InMemoryTokenStore()
        ..tokens[SessionSlot.customer] = 'c';
      final FakeAuthRepository auth = FakeAuthRepository()
        ..identities[SessionSlot.customer] = user(id: 'c');
      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: auth,
          catalog: catalog,
          addresses: FakeAddressesRepository(),
          preferences: InMemoryPreferenceStore(),
          overrides: [addressMapProvider.overrideWithValue(FakeAddressMap())],
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pop(WidgetTester tester) async {
      await tester.binding.handlePopRoute();
      await tester.pump();
    }

    testWidgets('the picture flies from the tile into the rail, and back on '
        'pop', (WidgetTester tester) async {
      await open(tester, CatalogPaths.categories);

      await tester.tap(byKey('category-c-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(flight(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(flight(), findsNothing);
      expect(byKey('rail-c-2'), findsOneWidget);

      await pop(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(flight(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(flight(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("from the home's tile too", (WidgetTester tester) async {
      await openApp(tester);

      await tester.tap(byKey('category-c-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(flight(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(flight(), findsNothing);

      await pop(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(flight(), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a category far down the rail lands where its well ends up', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalog.categoryRows = many(12);
      await open(tester, CatalogPaths.categories);

      await tester.drag(byKey('category-grid'), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.tap(byKey('category-c-12'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // The last frame the shuttle is drawn in.
      Rect shuttle = tester.getRect(flight());
      for (int i = 0; i < 200 && flight().evaluate().isNotEmpty; i++) {
        shuttle = tester.getRect(flight());
        await tester.pump(const Duration(milliseconds: 16));
      }

      await tester.pumpAndSettle();
      final Rect landed = tester.getRect(
        find.descendant(
          of: byKey('rail-c-12'),
          matching: find.byType(CategoryPictureWell),
        ),
      );
      expect((shuttle.left - landed.left).abs(), lessThan(1));
      expect((shuttle.top - landed.top).abs(), lessThan(1));
      expect((shuttle.width - landed.width).abs(), lessThan(1));
    });

    testWidgets('one category on two screens opens and closes without a hero '
        'clash', (WidgetTester tester) async {
      await openApp(tester);
      expect(byKey('category-c-1'), findsOneWidget);

      await tester.tap(byKey('open-categories'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AllCategoriesScreen), findsOneWidget);

      await tester.tap(byKey('category-c-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await pop(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(AllCategoriesScreen), findsOneWidget);

      await pop(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(byKey('category-c-1'), findsOneWidget);
    });

    testWidgets('after a rail switch back flies nothing', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.categories);
      await tester.tap(byKey('category-c-1'));
      await tester.pumpAndSettle();

      await tester.tap(byKey('rail-c-2'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await pop(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(flight(), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(AllCategoriesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with reduced motion no Hero', (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester, CatalogPaths.categories);
      expect(categoryHeroes(), findsNothing);

      await tester.tap(byKey('category-c-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(categoryHeroes(), findsNothing);
      expect(flight(), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('with motion every tile and the rail carry a Hero', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.categories);
      expect(categoryHeroes(), findsNWidgets(3));
    });
  });

  group('category screen', () {
    testWidgets('a failed refresh keeps the rail (P3-1)', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.category('c-1'));
      expect(byKey('rail-c-1'), findsOneWidget);

      catalog.categoriesFailure = const NetworkFailure();
      ProviderScope.containerOf(tester.element(find.byType(CategoryScreen)))
          .invalidate(catalogCategoriesProvider);
      await tester.pumpAndSettle();

      expect(byKey('rail-c-1'), findsOneWidget);
      expect(byKey('retry-load'), findsNothing);
    });

    testWidgets('shows the rail with the current one selected, and products', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.category('c-1'));

      expect(byKey('rail-c-1'), findsOneWidget);
      expect(byKey('rail-c-2'), findsOneWidget);
      expect(byKey('rail-c-3'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: byKey('rail-c-1'),
                matching: find.text('Sabzavotlar'),
              ),
            )
            .style
            ?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: byKey('rail-c-2'),
                matching: find.text('Mevalar'),
              ),
            )
            .style
            ?.fontWeight,
        isNot(FontWeight.w700),
      );
      expect(find.text('Pomidor'), findsOneWidget);
      expect(find.text('Olma'), findsNothing);
    });

    testWidgets('a rail item shows the picture or the letter, and the '
        'selected one a green line', (WidgetTester tester) async {
      await open(tester, CatalogPaths.category('c-1'));

      expect(
        find.descendant(
          of: byKey('rail-c-1'),
          matching: find.byType(ProductImage),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ProductImage>(
              find.descendant(
                of: byKey('rail-c-1'),
                matching: find.byType(ProductImage),
              ),
            )
            .url,
        'https://example.test/veg.png',
      );
      expect(
        find.descendant(of: byKey('rail-c-2'), matching: find.text('M')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('rail-c-2'),
          matching: find.byType(ProductImage),
        ),
        findsNothing,
      );
      Finder line(String id) => find.descendant(
        of: byKey('rail-$id'),
        matching: find.byWidgetPredicate(
          (Widget w) => w is ColoredBox && w.color == KitColors.primary,
        ),
      );
      expect(line('c-1'), findsOneWidget);
      expect(line('c-2'), findsNothing);
    });

    testWidgets('the rail starts at the top, level with the products', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, CatalogPaths.category('c-3'));

      expect(
        tester.getTopLeft(byKey('rail-c-1')).dy,
        tester.getTopLeft(find.byType(KitProductGrid)).dy,
      );
    });

    testWidgets('choosing another rail item shows its products and title, '
        'and back leaves the screen', (WidgetTester tester) async {
      await open(tester, CatalogPaths.category('c-1'));

      await tester.tap(byKey('rail-c-2'));
      await tester.pumpAndSettle();

      expect(find.text('Olma'), findsOneWidget);
      expect(find.text('Pomidor'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Mevalar'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryScreen), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });

    testWidgets('an unknown category says it was not found', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.category('c-404'));

      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(Scaffold).last))
              .errorNotFound,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a 40-character name wraps in two lines without overflow', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.category('c-3'));

      expect(tester.takeException(), isNull);
      expect(find.byType(CategoryScreen), findsOneWidget);
    });
  });

  group('with two sessions the mode bar shows whatever the body shows', () {
    Finder modeOn(Type screen) => find.descendant(
      of: find.byType(screen),
      matching: find.byType(ActiveModeBar),
    );

    testWidgets('on every category', (WidgetTester tester) async {
      await open(tester, CatalogPaths.categories, twoSessions: true);
      expect(find.byType(AllCategoriesScreen), findsOneWidget);
      expect(modeOn(AllCategoriesScreen), findsOneWidget);
      expect(byKey('active-mode'), findsOneWidget);
    });

    testWidgets('on every category while it loads', (
      WidgetTester tester,
    ) async {
      catalog.categoriesGate = Completer<void>();
      await open(
        tester,
        CatalogPaths.categories,
        twoSessions: true,
        settle: false,
      );
      expect(find.byType(SkeletonBar), findsWidgets);
      expect(byKey('active-mode'), findsOneWidget);
      catalog.categoriesGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('on a category', (WidgetTester tester) async {
      await open(tester, CatalogPaths.category('c-1'), twoSessions: true);
      expect(find.text('Pomidor'), findsOneWidget);
      expect(modeOn(CategoryScreen), findsOneWidget);
      expect(byKey('active-mode'), findsOneWidget);
    });

    testWidgets('on a category while it loads', (WidgetTester tester) async {
      catalog.categoriesGate = Completer<void>();
      await open(
        tester,
        CatalogPaths.category('c-1'),
        twoSessions: true,
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(modeOn(CategoryScreen), findsOneWidget);
      expect(byKey('active-mode'), findsOneWidget);
      catalog.categoriesGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('on a category whose load failed', (WidgetTester tester) async {
      catalog.categoriesFailure = const UnexpectedFailure();
      await open(tester, CatalogPaths.category('c-1'), twoSessions: true);
      expect(byKey('retry-load'), findsOneWidget);
      expect(modeOn(CategoryScreen), findsOneWidget);
      expect(byKey('active-mode'), findsOneWidget);
    });

    testWidgets('on a category that does not exist', (
      WidgetTester tester,
    ) async {
      await open(tester, CatalogPaths.category('c-404'), twoSessions: true);
      expect(modeOn(CategoryScreen), findsOneWidget);
      expect(byKey('active-mode'), findsOneWidget);
    });
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final String path in <String>[
      CatalogPaths.categories,
      CatalogPaths.category('c-3'),
    ]) {
      testWidgets('large text on a small phone raises no exception '
          '($path, ${device.languageCode})', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await open(tester, path, locale: device);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
