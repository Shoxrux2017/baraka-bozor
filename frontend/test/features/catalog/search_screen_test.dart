import 'dart:async';
import 'dart:convert';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/application/recent_searches.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/all_categories_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/home_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/search_screen.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/in_memory_stores.dart';

/// The search screen (`DL-83`, drawings 15 to 17) through the real router,
/// against a catalog in memory.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
  late FakeCartRepository cart;
  late InMemoryPreferenceStore preferences;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));
  final Finder field = byKey('search-field');

  bool focused(WidgetTester tester) =>
      tester.widget<TextField>(field).focusNode!.hasFocus;

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String recentKey(String account) => RecentSearches.preferenceKey(account);

  void remembered(String account, List<String> queries) {
    preferences.values[recentKey(account)] = jsonEncode(queries);
  }

  List<String> stored(String account) =>
      (jsonDecode(preferences.values[recentKey(account)]!) as List)
          .cast<String>();

  int asked(String prefix) =>
      catalog.requests.where((String r) => r.startsWith(prefix)).length;

  setUp(() {
    preferences = InMemoryPreferenceStore();
    cart = FakeCartRepository();
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    catalog = FakeCatalogRepository(
      categories: <CatalogCategory>[
        catalogCategory(),
        catalogCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
      ],
      products: <CatalogProduct>[
        catalogProduct(),
        catalogProduct(
          id: 'p-2',
          nameUz: 'Olma',
          nameRu: 'Яблоко',
          customerUnitPriceUzs: 3500,
        ),
        catalogProduct(
          id: 'p-3',
          nameUz: 'Banan',
          nameRu: 'Банан',
          customerUnitPriceUzs: 9000,
        ),
      ],
    )..featuredIds = <String>{'p-1', 'p-2'};
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  /// Opens the app on the home.
  Future<void> openHome(
    WidgetTester tester, {
    Locale device = const Locale('uz'),
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        catalog: catalog,
        cart: cart,
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the search from the home, as a Customer does.
  Future<void> openSearch(
    WidgetTester tester, {
    Locale device = const Locale('uz'),
  }) async {
    await openHome(tester, device: device);
    await tester.tap(byKey('catalog-search'));
    await tester.pumpAndSettle();
    catalog.requests.clear();
  }

  Future<void> typeAndPause(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump(SearchScreen.searchPause);
    await tester.pumpAndSettle();
  }

  double place(WidgetTester tester, String name) {
    final Offset at = tester.getTopLeft(find.text(name));
    return at.dy * 1000 + at.dx;
  }

  BuildContext screenContext(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  group('typing', () {
    testWidgets('a search is sent once typing pauses, not on every letter', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await tester.enterText(field, 'p');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'po');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, 'pom');
      await tester.pump(const Duration(milliseconds: 200));
      expect(asked('pom|'), 0, reason: 'still within the pause');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(asked('pom|'), 1);
      expect(asked('po|'), 0);
      expect(asked('p|'), 0);
      expect(find.text('Pomidor'), findsOneWidget);
      expect(find.text('Olma'), findsNothing);
    });

    testWidgets(
      'the answer to a search typed past never replaces the current one',
      (WidgetTester tester) async {
        final Completer<void> slow = Completer<void>();
        catalog.gates['pom'] = slow;
        await openSearch(tester);

        await tester.enterText(field, 'pom');
        await tester.pump(SearchScreen.searchPause);
        await tester.pump();
        expect(byKey('product-skeletons'), findsOneWidget);
        await typeAndPause(tester, 'olm');
        expect(find.text('Olma'), findsOneWidget);

        slow.complete();
        await tester.pumpAndSettle();

        expect(find.text('Olma'), findsOneWidget);
        expect(find.text('Pomidor'), findsNothing);
        expect(asked('pom|'), 1);
        expect(asked('olm|'), 1);
      },
    );

    testWidgets('a long paste is cut to what the server takes', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await typeAndPause(tester, 'a' * 150);

      expect(
        tester.widget<TextField>(field).controller!.text,
        'a' * ProductListQuery.searchMaxLength,
      );
      expect(
        catalog.requests.last,
        startsWith('${'a' * ProductListQuery.searchMaxLength}|'),
      );
    });

    testWidgets('spaces alone show the empty state and ask nothing', (
      WidgetTester tester,
    ) async {
      remembered('c', <String>['olma']);
      await openSearch(tester);
      await typeAndPause(tester, '   ');

      expect(catalog.requests.where((String r) => !r.startsWith('|')), isEmpty);
      expect(byKey('recent-0'), findsOneWidget);
      expect(byKey('search-sort'), findsNothing);
    });

    testWidgets('clearing the field brings the empty state back', (
      WidgetTester tester,
    ) async {
      remembered('c', <String>['olma']);
      await openSearch(tester);
      await typeAndPause(tester, 'ban');
      expect(find.text('Banan'), findsOneWidget);
      expect(byKey('recent-0'), findsNothing);

      await tester.tap(byKey('search-clear'));
      await tester.pumpAndSettle();
      expect(find.text('Banan'), findsNothing);
      expect(byKey('recent-0'), findsOneWidget);
      expect(byKey('search-sort'), findsNothing);
    });
  });

  group('the empty field', () {
    testWidgets('shows the recent queries, clearing them, then the '
        'recommended products', (WidgetTester tester) async {
      remembered('c', <String>['olma', 'pomidor', 'banan']);
      await openSearch(tester);

      expect(find.text(l10n(tester).searchRecentTitle), findsOneWidget);
      expect(byKey('recent-clear'), findsOneWidget);
      expect(find.text('olma'), findsOneWidget);
      expect(find.text('pomidor'), findsOneWidget);
      expect(find.text('banan'), findsOneWidget);
      expect(find.text(l10n(tester).recommendedTitle), findsOneWidget);
      expect(
        place(tester, l10n(tester).searchRecentTitle),
        lessThan(place(tester, l10n(tester).recommendedTitle)),
      );
      expect(
        tester.widget<TextField>(field).focusNode!.hasFocus,
        isTrue,
        reason: 'the field is focused on opening',
      );

      await tester.tap(byKey('recent-clear'));
      await tester.pumpAndSettle();
      expect(find.text('olma'), findsNothing);
      expect(find.text(l10n(tester).searchRecentTitle), findsNothing);
      expect(stored('c'), isEmpty);
    });

    testWidgets('has no recent section without recent queries', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      expect(find.text(l10n(tester).searchRecentTitle), findsNothing);
      expect(byKey('recent-clear'), findsNothing);
      expect(find.text(l10n(tester).recommendedTitle), findsOneWidget);
    });

    testWidgets('has no recommended section without a featured product', (
      WidgetTester tester,
    ) async {
      catalog.featuredIds = <String>{};
      remembered('c', <String>['olma']);
      await openSearch(tester);
      expect(find.text(l10n(tester).recommendedTitle), findsNothing);
      expect(byKey('open-recommended'), findsNothing);
      expect(byKey('recent-0'), findsOneWidget);
    });

    testWidgets('a tapped recent query fills the field, searches at once '
        'and moves to the front', (WidgetTester tester) async {
      remembered('c', <String>['olma', 'banan', 'pomidor']);
      await openSearch(tester);

      await tester.tap(byKey('recent-1'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field).controller!.text, 'banan');
      expect(asked('banan|'), 1);
      expect(find.text('Banan'), findsOneWidget);
      expect(stored('c'), <String>['banan', 'olma', 'pomidor']);
    });
  });

  group('the results', () {
    testWidgets('say how many were found, in uz and ru', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[
        for (int i = 1; i <= 4; i++)
          catalogProduct(id: 't-$i', nameUz: 'Tur $i', nameRu: 'Вид $i'),
      ];
      await openSearch(tester);
      await typeAndPause(tester, 'tur');
      expect(find.text('Topildi: 4 ta mahsulot'), findsOneWidget);
      expect(byKey('search-found'), findsOneWidget);
      expect(byKey('list-sort'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await openSearch(tester, device: const Locale('ru'));
      await typeAndPause(tester, 'вид');
      expect(find.text('Найдено: 4 товара'), findsOneWidget);
    });

    test('the Russian count takes the plural form of 1, 2 and 5', () {
      final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
      expect(ru.searchFound(1), 'Найдено: 1 товар');
      expect(ru.searchFound(2), 'Найдено: 2 товара');
      expect(ru.searchFound(5), 'Найдено: 5 товаров');
      expect(
        lookupAppLocalizations(const Locale('uz')).searchFound(1),
        'Topildi: 1 ta mahsulot',
      );
    });

    testWidgets('follow the sort, which the sort sheet changes and the '
        'provider remembers', (WidgetTester tester) async {
      await openSearch(tester);
      await typeAndPause(tester, 'o');
      expect(find.text('Pomidor'), findsOneWidget);
      expect(find.text('Olma'), findsOneWidget);
      expect(
        place(tester, 'Pomidor'),
        lessThan(place(tester, 'Olma')),
        reason: 'the shop order before a sort is chosen',
      );

      await tester.tap(byKey('list-sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n(tester).sortPriceAsc));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.text('Banan'), findsNothing, reason: 'still the results');
      expect(
        place(tester, 'Olma'),
        lessThan(place(tester, 'Pomidor')),
        reason: 'cheaper first in the results',
      );
      expect(
        ProviderScope.containerOf(screenContext(tester))
            .read(productSortProvider),
        ProductSort.priceAsc,
      );
    });

    testWidgets('dismissing the sort sheet changes nothing', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await typeAndPause(tester, 'o');
      await tester.tap(byKey('list-sort'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        place(tester, 'Pomidor'),
        lessThan(place(tester, 'Olma')),
        reason: 'the order is unchanged',
      );
    });

    testWidgets('a failed page shows the retry, and nothing is counted', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      catalog.nextFailure = const NetworkFailure();
      await typeAndPause(tester, 'pom');

      expect(byKey('stale-retry'), findsOneWidget);
      expect(byKey('search-found'), findsNothing);

      await tester.tap(byKey('stale-retry'));
      await tester.pumpAndSettle();
      expect(find.text('Pomidor'), findsOneWidget);
      expect(byKey('search-found'), findsOneWidget);
    });
  });

  group('nothing found', () {
    testWidgets('quotes the query, and "all categories" opens every '
        'category; back returns to the search with its query', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await typeAndPause(tester, 'shokolad');

      expect(byKey('search-nothing'), findsOneWidget);
      expect(find.text(l10n(tester).searchNothingTitle), findsOneWidget);
      expect(find.textContaining('«shokolad»'), findsOneWidget);
      expect(byKey('search-found'), findsNothing);

      await tester.tap(byKey('search-all-categories'));
      await tester.pumpAndSettle();
      expect(find.byType(AllCategoriesScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'shokolad');
      expect(byKey('search-nothing'), findsOneWidget);
    });
  });

  group('remembering', () {
    testWidgets('submitting on the keyboard remembers the query', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await tester.enterText(field, 'olma');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(stored('c'), <String>['olma']);
      expect(find.text('Olma'), findsOneWidget);
      expect(asked('olma|'), 1, reason: 'asked at once, without the pause');
    });

    testWidgets('going back with a query typed remembers it', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await typeAndPause(tester, 'banan');
      expect(preferences.values[recentKey('c')], isNull);

      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogHomeScreen), findsOneWidget);
      expect(stored('c'), <String>['banan']);
    });

    testWidgets('going back before the pause ends remembers what is typed', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await tester.enterText(field, 'banan');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();

      expect(stored('c'), <String>['banan']);
    });

    testWidgets('going back with an empty field remembers nothing', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();
      expect(preferences.values.containsKey(recentKey('c')), isFalse);
    });

    testWidgets('going back with only spaces remembers nothing', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await typeAndPause(tester, '   ');
      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();
      expect(preferences.values.containsKey(recentKey('c')), isFalse);
    });

    testWidgets("one account's query is not in another account's list", (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await typeAndPause(tester, 'banan');
      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();
      expect(stored('c'), <String>['banan']);

      await tester.pumpWidget(const SizedBox());
      tokens.tokens[SessionSlot.customer] = 'd';
      auth.identities[SessionSlot.customer] = user(id: 'd');
      await openSearch(tester);

      expect(find.text('banan'), findsNothing);
      expect(find.text(l10n(tester).searchRecentTitle), findsNothing);
      await typeAndPause(tester, 'olma');
      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();
      expect(stored('d'), <String>['olma']);
      expect(stored('c'), <String>['banan']);
    });

    testWidgets('signing out with the search open saves under the account '
        'that typed, and under no other', (WidgetTester tester) async {
      await openSearch(tester);
      await tester.enterText(field, 'banan');

      await ProviderScope.containerOf(screenContext(tester))
          .read(sessionControllerProvider.notifier)
          .logout(SessionMode.customer);
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsNothing);
      expect(
        preferences.values.keys.where(
          (String key) => key.startsWith('recent_searches.'),
        ),
        <String>[recentKey('c')],
      );
      expect(stored('c'), <String>['banan']);
    });
  });

  group('back stack', () {
    testWidgets('a product opened from the results returns to the same '
        'query and results', (WidgetTester tester) async {
      await openSearch(tester);
      await typeAndPause(tester, 'ban');
      await tester.tap(find.text('Banan'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'ban');
      expect(find.text('Banan'), findsOneWidget);
    });

    testWidgets('back from the search returns to where it was opened', (
      WidgetTester tester,
    ) async {
      await openSearch(tester);
      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogHomeScreen), findsOneWidget);
    });
  });

  group('entry points', () {
    testWidgets('the home field opens the search with the field focused; '
        'the home shows no results under it', (WidgetTester tester) async {
      await openHome(tester);
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(byKey('catalog-search'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogHomeScreen), findsOneWidget);
      expect(find.text('Banan'), findsNothing);
    });

    final Map<String, String> lists = <String, String>{
      'a category': CatalogPaths.category('c-1'),
      'all categories': CatalogPaths.categories,
      'the recommended products': CatalogPaths.recommended,
      'every product': CatalogPaths.products,
      'the favourites': AppPaths.customerFavorites,
    };
    for (final MapEntry<String, String> list in lists.entries) {
      testWidgets('the header of ${list.key} has the search icon, which '
          'opens the search', (WidgetTester tester) async {
        await openHome(tester);
        GoRouter.of(screenContext(tester)).push(list.value);
        await tester.pumpAndSettle();

        expect(byKey('open-search'), findsOneWidget);
        await tester.tap(byKey('open-search'));
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);

        await tester.tap(byKey('search-back'));
        await tester.pumpAndSettle();
        expect(byKey('open-search'), findsOneWidget);
      });
    }
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('large text on a small phone: every state raises no '
        'exception (${device.languageCode})', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      remembered('c', <String>[
        'olma',
        'a recent query that is long enough to need more than one line ' * 2,
        'banan',
      ]);

      await openSearch(tester, device: device);
      expect(tester.takeException(), isNull);
      expect(byKey('recent-clear'), findsOneWidget);

      await typeAndPause(tester, 'o');
      expect(tester.takeException(), isNull);
      for (final String key in <String>['search-back', 'list-sort']) {
        final Rect rect = tester.getRect(byKey(key));
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(320), reason: key);
        expect(rect.bottom, lessThanOrEqualTo(640), reason: key);
      }

      await typeAndPause(tester, 'shokolad');
      expect(byKey('search-nothing'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(byKey('search-all-categories'));
      await tester.pumpAndSettle();
      final Rect button = tester.getRect(byKey('search-all-categories'));
      expect(button.right, lessThanOrEqualTo(320));
      expect(button.bottom, lessThanOrEqualTo(640));

      catalog.nextFailure = const NetworkFailure();
      await typeAndPause(tester, 'pom');
      expect(byKey('stale-retry'), findsOneWidget);
      expect(
        tester.getRect(byKey('stale-retry')).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('the cart bar', () {
    testWidgets('shows under the results once the cart holds a line and '
        'opens the cart', (WidgetTester tester) async {
      catalog.productRows = <CatalogProduct>[catalogProduct(id: tomatoProduct)];
      await openSearch(tester, device: const Locale('ru'));
      await typeAndPause(tester, 'pom');
      expect(byKey('cart-summary'), findsNothing);

      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(quantity: '1.000', total: 18400),
      ]);
      await tester.tap(byKey('add-$tomatoProduct'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: byKey('cart-summary'),
          matching: find.text('1 товар'),
        ),
        findsOneWidget,
      );
      await tester.tap(byKey('cart-summary'));
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
    });
  });

  group('the order button', () {
    testWidgets('the field stays full width with a query; Найдено: 4 товара · '
        'Как в магазине sits above the cards', (WidgetTester tester) async {
      catalog.productRows = <CatalogProduct>[
        for (int i = 1; i <= 4; i++)
          catalogProduct(id: 't-$i', nameUz: 'Tur $i', nameRu: 'Вид $i'),
      ];
      await openSearch(tester, device: const Locale('ru'));
      final Rect empty = tester.getRect(field);
      await typeAndPause(tester, 'вид');

      expect(byKey('search-sort'), findsNothing);
      expect(tester.getRect(field), empty, reason: 'the field does not move');
      expect(tester.getRect(field).right, 800 - 16);
      expect(byKey('search-found'), findsOneWidget);
      expect(find.text('Найдено: 4 товара'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('list-sort'),
          matching: find.text('Как в магазине'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(byKey('search-found')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Вид 1')).top),
        reason: 'the row is above the cards',
      );
      expect(
        tester.getRect(byKey('list-sort')).top,
        tester.getRect(byKey('search-found')).top,
        reason: 'the order button is in the row',
      );
    });

    testWidgets('the order button opens the menu', (WidgetTester tester) async {
      await openSearch(tester);
      await typeAndPause(tester, 'pom');

      final Rect button = tester.getRect(byKey('list-sort'));
      await tester.tap(byKey('list-sort'));
      await tester.pumpAndSettle();

      expect(byKey('sort-menu'), findsOneWidget);
      expect(tester.getRect(byKey('sort-menu')).top, button.bottom + 2);
    });

    testWidgets('the count stays while another search loads and goes when '
        'it fails', (WidgetTester tester) async {
      catalog.productRows = <CatalogProduct>[
        for (int i = 1; i <= 4; i++)
          catalogProduct(id: 't-$i', nameUz: 'Tur $i', nameRu: 'Вид $i'),
      ];
      await openSearch(tester, device: const Locale('ru'));
      await typeAndPause(tester, 'вид');
      expect(find.text('Найдено: 4 товара'), findsOneWidget);

      final Completer<void> slow = Completer<void>();
      catalog.gates['вид2'] = slow;
      await tester.enterText(field, 'вид2');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();
      expect(byKey('search-found'), findsOneWidget);
      expect(find.text('Найдено: 4 товара'), findsOneWidget);

      slow.complete();
      await tester.pumpAndSettle();
      catalog.nextFailure = const NetworkFailure();
      await typeAndPause(tester, 'вид3');
      expect(byKey('stale-retry'), findsOneWidget);
      expect(find.text('Найдено: 4 товара'), findsNothing);
    });

    testWidgets('exposes a tap action to TalkBack', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openSearch(tester);
      await typeAndPause(tester, 'pom');

      final SemanticsNode node = tester.getSemantics(byKey('list-sort'));
      expect(node.label, contains(l10n(tester).sortShop));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('typing without flicker', () {
    List<CatalogProduct> thirty() => <CatalogProduct>[
      for (int i = 1; i <= 30; i++)
        catalogProduct(id: 't-$i', nameUz: 'Tur $i', nameRu: 'Вид $i'),
    ];

    double dimmedOpacity(WidgetTester tester) => tester
        .widget<SliverOpacity>(
          find.descendant(
            of: byKey('dimmed-cards'),
            matching: find.byType(SliverOpacity),
          ),
        )
        .opacity;

    testWidgets("typing a second query keeps the first one's cards dimmed "
        'under a 2 px line', (WidgetTester tester) async {
      catalog.productRows = thirty();
      await openSearch(tester);
      await typeAndPause(tester, 'tur');
      expect(find.text('Tur 1'), findsOneWidget);
      expect(byKey('search-progress'), findsNothing);

      final Completer<void> slow = Completer<void>();
      catalog.gates['tur 1'] = slow;
      await tester.enterText(field, 'tur 1');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(byKey('product-skeletons'), findsNothing);
      expect(find.text('Tur 1'), findsOneWidget);
      expect(dimmedOpacity(tester), 0.45);
      expect(tester.getSize(byKey('search-progress')).height, 2);

      slow.complete();
      await tester.pumpAndSettle();
      expect(byKey('search-progress'), findsNothing);
      expect(byKey('dimmed-cards'), findsNothing);
    });

    testWidgets('the new cards come and the count rolls to the new number', (
      WidgetTester tester,
    ) async {
      catalog.productRows = thirty();
      await openSearch(tester, device: const Locale('ru'));
      await typeAndPause(tester, 'вид');
      expect(find.text('Найдено: 30 товаров'), findsOneWidget);

      await tester.enterText(field, 'вид 1');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // 'Вид 1' and 'Вид 10' to 'Вид 19' are 11.
      expect(find.text('Найдено: 30 товаров'), findsOneWidget);
      expect(find.text('Найдено: 11 товаров'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Найдено: 30 товаров'), findsNothing);
      expect(find.text('Найдено: 11 товаров'), findsOneWidget);
    });

    testWidgets('the new cards fade in from 0.45 after the dim', (
      WidgetTester tester,
    ) async {
      catalog.productRows = thirty();
      await openSearch(tester);
      await typeAndPause(tester, 'tur');

      final Completer<void> slow = Completer<void>();
      catalog.gates['tur 1'] = slow;
      await tester.enterText(field, 'tur 1');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(byKey('dimmed-cards'), findsOneWidget);

      slow.complete();
      await tester.pump();
      await tester.pump();
      double opacity() => tester
          .widget<SliverFadeTransition>(
            find.descendant(
              of: byKey('product-cards'),
              matching: find.byType(SliverFadeTransition),
            ),
          )
          .opacity
          .value;
      expect(byKey('dimmed-cards'), findsNothing);
      expect(opacity(), inInclusiveRange(0.45, 0.6));

      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('the first query shows skeletons', (WidgetTester tester) async {
      catalog.productRows = thirty();
      final Completer<void> slow = Completer<void>();
      catalog.gates['tur'] = slow;
      await openSearch(tester);
      await tester.enterText(field, 'tur');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();

      expect(byKey('product-skeletons'), findsOneWidget);
      expect(byKey('dimmed-cards'), findsNothing);
      expect(byKey('search-progress'), findsNothing);

      slow.complete();
      await tester.pumpAndSettle();
      expect(find.text('Tur 1'), findsOneWidget);
    });

    testWidgets('a new query that fails drops the dimmed cards of another', (
      WidgetTester tester,
    ) async {
      catalog.productRows = thirty();
      await openSearch(tester, device: const Locale('ru'));
      await typeAndPause(tester, 'вид');
      expect(byKey('search-found'), findsOneWidget);

      final Completer<void> slow = Completer<void>();
      catalog.gates['вид 1'] = slow;
      await tester.enterText(field, 'вид 1');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(byKey('dimmed-cards'), findsOneWidget);

      catalog.nextFailure = const NetworkFailure();
      slow.complete();
      await tester.pumpAndSettle();

      expect(byKey('dimmed-cards'), findsNothing);
      expect(byKey('product-skeletons'), findsOneWidget);
      expect(byKey('stale-retry'), findsOneWidget);
      expect(byKey('search-found'), findsNothing);
      expect(byKey('search-progress'), findsNothing);
      expect(find.text('Вид 1'), findsNothing);

      await tester.tap(byKey('stale-retry'));
      await tester.pumpAndSettle();
      expect(find.text('Вид 1'), findsOneWidget);
      expect(byKey('search-found'), findsOneWidget);
    });

    testWidgets('a refresh of the same query that fails keeps its cards '
        'under the stale line', (WidgetTester tester) async {
      catalog.productRows = thirty();
      await openSearch(tester);
      await typeAndPause(tester, 'tur');

      final ProviderContainer container = ProviderScope.containerOf(
        screenContext(tester),
      );
      catalog.nextFailure = const NetworkFailure();
      container.invalidate(
        productListProvider(const ProductListQuery(search: 'tur')),
      );
      await tester.pumpAndSettle();

      expect(byKey('stale-line'), findsOneWidget);
      expect(find.text('Tur 1'), findsOneWidget);
      expect(byKey('product-skeletons'), findsNothing);
      expect(byKey('search-progress'), findsNothing);
    });

    testWidgets('with reduced motion the line stands still at half opacity', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      catalog.productRows = thirty();
      await openSearch(tester);
      await typeAndPause(tester, 'tur');

      final Completer<void> slow = Completer<void>();
      catalog.gates['tur 1'] = slow;
      await tester.enterText(field, 'tur 1');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();

      final Rect first = tester.getRect(byKey('search-progress-bar'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(byKey('search-progress-bar')), first);
      expect(first.width, tester.getSize(byKey('search-progress')).width);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: byKey('search-progress-bar'),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.5,
      );

      slow.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the running bar is 40 % wide and runs across the line', (
      WidgetTester tester,
    ) async {
      catalog.productRows = thirty();
      await openSearch(tester);
      await typeAndPause(tester, 'tur');

      final Completer<void> slow = Completer<void>();
      catalog.gates['tur 1'] = slow;
      await tester.enterText(field, 'tur 1');
      await tester.pump(SearchScreen.searchPause);
      await tester.pump();

      final Rect line = tester.getRect(byKey('search-progress'));
      expect(
        tester.getSize(byKey('search-progress-bar')).width,
        closeTo(line.width * 0.4, 0.01),
      );
      final double start = tester.getRect(byKey('search-progress-bar')).left;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.getRect(byKey('search-progress-bar')).left,
        greaterThan(start),
      );

      slow.complete();
      await tester.pumpAndSettle();
    });
  });

  group('the keyboard and the cart bar', () {
    void keyboardUp(WidgetTester tester) {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
    }

    testWidgets('scrolling the results hides the keyboard', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[
        for (int i = 1; i <= 30; i++)
          catalogProduct(id: 't-$i', nameUz: 'Tur $i', nameRu: 'Вид $i'),
      ];
      await openSearch(tester);
      await typeAndPause(tester, 'tur');
      await tester.showKeyboard(field);
      expect(focused(tester), isTrue);

      await tester.drag(byKey('product-grid'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(focused(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('scrolling the landing hides the keyboard', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(375, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      remembered('c', <String>['olma', 'pomidor', 'banan']);
      await openSearch(tester);
      expect(focused(tester), isTrue);

      await tester.drag(find.byType(ListView).first, const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(focused(tester), isFalse);
    });

    testWidgets('no cart bar while the keyboard is up; it comes back when '
        'it goes down', (WidgetTester tester) async {
      cart = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[cartLineJson(total: 18400)]),
      );
      await openSearch(tester);
      await typeAndPause(tester, 'pom');
      expect(byKey('cart-summary'), findsOneWidget);

      keyboardUp(tester);
      await tester.pumpAndSettle();
      expect(byKey('cart-summary'), findsNothing);
      expect(find.text('Pomidor'), findsOneWidget);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(byKey('cart-summary'), findsOneWidget);
    });

    testWidgets('the landing shows the cart bar', (WidgetTester tester) async {
      cart = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[cartLineJson(total: 18400)]),
      );
      await openSearch(tester);
      expect(byKey('recent-clear'), findsNothing);
      expect(byKey('cart-summary'), findsOneWidget);

      keyboardUp(tester);
      await tester.pumpAndSettle();
      expect(byKey('cart-summary'), findsNothing);
    });
  });

  group('the field flies', () {
    testWidgets('the home field flies up and stretches into the search '
        'field', (WidgetTester tester) async {
      await openHome(tester, device: const Locale('ru'));
      final Rect home = tester.getRect(byKey('catalog-search'));

      await tester.tap(byKey('catalog-search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 190));

      final Rect target = tester.getRect(field);
      final Rect copy = tester.getRect(
        find.byKey(const ValueKey<String>('flight-search-field')),
      );
      expect(copy.width, inExclusiveRange(target.width, home.width));
      expect(copy.left, inExclusiveRange(home.left, target.left));
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: byKey('catalog-search'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0,
        reason: 'the home field is hidden while its copy flies',
      );
      expect(focused(tester), isTrue);

      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('flight-search-field')),
        findsNothing,
      );
      expect(field.hitTestable(), findsOneWidget);

      await tester.tap(byKey('search-back'));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogHomeScreen), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: byKey('catalog-search'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
        reason: 'nothing stays hidden',
      );
    });

    testWidgets('with reduced motion search fades in', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openHome(tester, device: const Locale('ru'));
      await tester.tap(byKey('catalog-search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('flight-search-field')),
        findsNothing,
      );
      final double opacity = tester
          .widget<FadeTransition>(byKey('flight-page-fade'))
          .opacity
          .value;
      expect(opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
    });
  });
}
