import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
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

import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

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
    await tester.pumpAndSettle();
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
