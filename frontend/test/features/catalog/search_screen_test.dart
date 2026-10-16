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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/in_memory_stores.dart';

/// The search screen (`DL-83`, drawings 15 to 17) through the real router,
/// against a catalog in memory.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
  late InMemoryPreferenceStore preferences;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));
  final Finder field = byKey('search-field');

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
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
      expect(byKey('search-sort'), findsOneWidget);

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

      await tester.tap(byKey('search-sort'));
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
      await tester.tap(byKey('search-sort'));
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

      expect(byKey('retry-load'), findsOneWidget);
      expect(byKey('search-found'), findsNothing);

      await tester.tap(byKey('retry-load'));
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
      for (final String key in <String>['search-back', 'search-sort']) {
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
      expect(byKey('retry-load'), findsOneWidget);
      expect(
        tester.getRect(byKey('retry-load')).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
