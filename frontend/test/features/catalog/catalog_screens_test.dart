import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_screens.dart';
import 'package:flutter/material.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/in_memory_stores.dart';

/// The Customer catalog (W1-12) through the real router, session and
/// screens, against a catalog in memory.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));
  final Finder search = byKey('catalog-search');

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
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
          categoryId: 'c-2',
          nameUz: 'Olma',
          nameRu: 'Яблоко',
          priceMode: PriceMode.fixed,
          unitCode: UnitCode.piece,
          customerUnitPriceUzs: 3500,
          descriptionRu: 'Сочные',
        ),
      ],
    );
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> open(
    WidgetTester tester, {
    Locale device = const Locale('uz'),
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        catalog: catalog,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeAndPause(WidgetTester tester, String text) async {
    await tester.enterText(search, text);
    await tester.pump(CatalogHomeScreen.searchPause);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the home lists the sections; a section lists its products at the customer price',
    (WidgetTester tester) async {
      await open(tester);

      expect(find.text('Sabzavotlar'), findsOneWidget);
      expect(find.text('Mevalar'), findsOneWidget);

      await tester.tap(find.text('Sabzavotlar'));
      await tester.pumpAndSettle();

      expect(find.text('Pomidor'), findsOneWidget);
      expect(find.text('Olma'), findsNothing);
      expect(
        find.text(
          l10n(tester).catalogPricePerUnit(
            MoneyFormat.uzs(18400, AppLanguage.uz),
            l10n(tester).unitKg,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n(tester).catalogEstimateNote), findsOneWidget);
      expect(catalog.requests, <String>['|c-1|1']);
    },
  );

  testWidgets('the names and the price words follow the interface language', (
    WidgetTester tester,
  ) async {
    await open(tester, device: const Locale('ru'));

    expect(find.text('Фрукты'), findsOneWidget);
    await tester.tap(find.text('Фрукты'));
    await tester.pumpAndSettle();
    expect(find.text('Яблоко'), findsOneWidget);
    expect(
      find.text('цена ориентировочная'),
      findsNothing,
      reason: 'a fixed price has no such note',
    );

    await tester.tap(find.text('Яблоко'));
    await tester.pumpAndSettle();

    expect(
      find.text('Olma'),
      findsOneWidget,
      reason: 'the other name under the first',
    );
    expect(find.text('Сочные'), findsOneWidget);
    expect(
      find.text('${MoneyFormat.uzs(3500, AppLanguage.ru)} / шт.'),
      findsOneWidget,
    );
  });

  testWidgets('an estimate product explains what its price means', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Sabzavotlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pomidor'));
    await tester.pumpAndSettle();

    expect(byKey('product-name'), findsOneWidget);
    expect(find.text('narx taxminiy'), findsOneWidget);
    expect(find.text(l10n(tester).catalogEstimateExplain), findsOneWidget);
  });

  testWidgets('scrolling to the end loads the next page, and the list ends', (
    WidgetTester tester,
  ) async {
    catalog.productRows = <CatalogProduct>[
      for (int i = 1; i <= 25; i++)
        catalogProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
    ];
    await open(tester);
    await tester.tap(find.text('Sabzavotlar'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mahsulot 25'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Mahsulot 25'), findsOneWidget);
    expect(catalog.requests, <String>['|c-1|1', '|c-1|2']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a search is sent once typing pauses', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await tester.enterText(search, 'p');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(search, 'po');
    await tester.pump(const Duration(milliseconds: 100));
    await typeAndPause(tester, 'pomi');

    expect(catalog.requests, <String>['pomi|null|1']);
    expect(find.text('Pomidor'), findsOneWidget);
    expect(find.text('Sabzavotlar'), findsNothing);

    await tester.tap(byKey('catalog-search-clear'));
    await tester.pumpAndSettle();
    expect(find.text('Sabzavotlar'), findsOneWidget);
  });

  testWidgets(
    'the answer to a search typed past never replaces the current one',
    (WidgetTester tester) async {
      final Completer<void> slow = Completer<void>();
      catalog.gates['pom'] = slow;
      await open(tester);

      // The first answer is held back, so its list shows a spinner that
      // never settles; time is advanced by hand.
      await tester.enterText(search, 'pom');
      await tester.pump(CatalogHomeScreen.searchPause);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await typeAndPause(tester, 'olm');
      expect(find.text('Olma'), findsOneWidget);

      slow.complete();
      await tester.pumpAndSettle();

      expect(find.text('Olma'), findsOneWidget);
      expect(find.text('Pomidor'), findsNothing);
      expect(catalog.requests, <String>['pom|null|1', 'olm|null|1']);
    },
  );

  testWidgets('a search with no match says so', (WidgetTester tester) async {
    await open(tester);

    await typeAndPause(tester, 'shokolad');

    expect(find.text(l10n(tester).catalogEmpty), findsOneWidget);
  });

  testWidgets('a product that no longer exists says so, with no retry', (
    WidgetTester tester,
  ) async {
    await open(tester);

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(CatalogPaths.product('p-404'));
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).errorNotFound), findsOneWidget);
    expect(byKey('retry-load'), findsNothing);
  });

  testWidgets('the search takes no more than the server does', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await typeAndPause(tester, 'a' * 150);

    expect(
      tester.widget<TextField>(search).controller!.text,
      'a' * ProductListQuery.searchMaxLength,
    );
    expect(
      catalog.requests.last,
      startsWith('${'a' * ProductListQuery.searchMaxLength}|'),
    );
  });

  testWidgets('after signing out the catalog asks for nothing more', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Sabzavotlar'));
    await tester.pumpAndSettle();
    final int sections = catalog.categoryLoads;
    final int lists = catalog.requests.length;

    await ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.customer);
    await tester.pumpAndSettle();

    expect(catalog.categoryLoads, sections);
    expect(catalog.requests, hasLength(lists));
  });

  testWidgets('a phone-wide window with large text fits', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    catalog.productRows = <CatalogProduct>[
      catalogProduct(
        nameUz: 'Pomidor pushti, Toshkent viloyatidan, yirik navli',
        nameRu: 'Помидоры розовые, из Ташкентской области, крупные',
      ),
    ];

    await open(tester);
    await tester.tap(find.text('Sabzavotlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Pomidor pushti'));
    await tester.pumpAndSettle();

    expect(byKey('product-name'), findsOneWidget);
  });

  testWidgets('a first page that failed shows progress while it is retried', (
    WidgetTester tester,
  ) async {
    catalog.nextFailure = const NetworkFailure();
    await open(tester);
    await tester.tap(find.text('Sabzavotlar'));
    await tester.pumpAndSettle();
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

    catalog.gates[''] = Completer<void>();
    await tester.tap(byKey('retry-load'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n(tester).errorNetwork), findsNothing);

    catalog.gates['']!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pomidor'), findsOneWidget);
  });

  testWidgets('a next page that failed offers its own retry', (
    WidgetTester tester,
  ) async {
    catalog.productRows = <CatalogProduct>[
      for (int i = 1; i <= 25; i++)
        catalogProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
    ];
    await open(tester);
    await tester.tap(find.text('Sabzavotlar'));
    await tester.pumpAndSettle();

    catalog.nextFailure = const NetworkFailure();
    await tester.scrollUntilVisible(byKey('load-more'), 300);
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    expect(find.text('Mahsulot 1'), findsNothing, reason: 'scrolled past');

    await tester.ensureVisible(byKey('load-more'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('load-more'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mahsulot 25'), 300);
    expect(byKey('load-more'), findsNothing);
  });

  testWidgets('sections that failed can be asked for again; none says so', (
    WidgetTester tester,
  ) async {
    catalog.categoriesFailure = const NetworkFailure();
    await open(tester);
    expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

    catalog.categoryRows = <CatalogCategory>[];
    await tester.tap(find.text(l10n(tester).retryButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n(tester).catalogNoProducts), findsOneWidget);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'with two sessions a phone-size window shows the mode on every screen '
      '(${device.languageCode})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tokens.tokens[SessionSlot.staff] = 's';
        auth.identities[SessionSlot.staff] = user(
          id: 's',
          role: UserRole.courier,
        );

        await open(tester, device: device);
        final Finder mode = byKey('active-mode');
        expect(mode, findsOneWidget, reason: 'in the staff shell');
        await tester.tap(byKey('switch-to-customer-button'));
        await tester.pumpAndSettle();
        expect(mode, findsOneWidget, reason: 'on the Customer home');
        expect(byKey('logout-button'), findsOneWidget);
        expect(byKey('switch-to-staff-button'), findsOneWidget);

        await tester.tap(
          find.text(device.languageCode == 'uz' ? 'Sabzavotlar' : 'Овощи'),
        );
        await tester.pumpAndSettle();
        expect(mode, findsOneWidget, reason: 'on a section');

        await tester.tap(
          find.text(device.languageCode == 'uz' ? 'Pomidor' : 'Помидор'),
        );
        await tester.pumpAndSettle();
        expect(mode, findsOneWidget, reason: 'on a product');
        await tester.scrollUntilVisible(
          find.textContaining(
            device.languageCode == 'uz' ? 'yig\'uvchi' : 'сборщик',
          ),
          200,
        );

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(byKey('switch-to-staff-button'));
        await tester.pumpAndSettle();
        expect(mode, findsOneWidget, reason: 'back in the staff shell');
      },
    );
  }
}
