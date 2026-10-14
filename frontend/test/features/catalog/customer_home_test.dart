import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/customer_home_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/in_memory_stores.dart';

/// The Customer home's floating bar (design 4a), through the real router.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;

  const int sections = 12;
  const String lastCategoryId = 'c-$sections';

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    catalog = FakeCatalogRepository(
      categories: <CatalogCategory>[
        for (int i = 1; i <= sections; i++)
          catalogCategory(
            id: 'c-$i',
            nameUz: 'Bo\'lim $i',
            nameRu: 'Раздел $i',
          ),
      ],
      products: <CatalogProduct>[catalogProduct()],
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

  testWidgets(
    'the floating bar opens the orders and the profile over the home',
    (WidgetTester tester) async {
      await open(tester);
      expect(
        find.descendant(
          of: find.byType(CustomerHomeNav),
          matching: byKey('open-orders'),
        ),
        findsOneWidget,
      );
      await tester.tap(byKey('open-orders'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomeNav), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(byKey('open-profile'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomeNav), findsNothing);
    },
  );

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'large text on a small phone: the bar fits and the last section is '
      'reachable (${device.languageCode})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        await open(tester, device: device);
        expect(tester.takeException(), isNull);
        final Finder last = byKey('category-$lastCategoryId');
        await tester.dragUntilVisible(
          last,
          byKey('category-list'),
          const Offset(0, -100),
        );
        await tester.drag(byKey('category-list'), const Offset(0, -2000));
        await tester.pumpAndSettle();
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(find.byType(CustomerHomeNav), findsNothing);
      },
    );
  }
}
