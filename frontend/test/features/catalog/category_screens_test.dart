import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/active_mode_bar.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_categories_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/category_screen.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

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
          builder: (BuildContext context, GoRouterState state) =>
              const AllCategoriesScreen(),
        ),
        GoRoute(
          path: CatalogPaths.categoryPattern,
          builder: (BuildContext context, GoRouterState state) =>
              CategoryScreen(categoryId: state.pathParameters['category']!),
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
  });

  group('category screen', () {
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

    testWidgets('the rail starts at the top', (WidgetTester tester) async {
      await open(tester, CatalogPaths.category('c-3'));

      expect(
        tester.getTopLeft(byKey('rail-c-1')).dy,
        tester.getTopLeft(byKey('category-rail')).dy,
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
