import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_screens.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

/// Adding products to a placed order (`docs/03` section 11, `docs/09`
/// section 21, `DL-52`) through the real router, editor and picker, with the
/// repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late FakeCatalogRepository catalog;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  String top(WidgetTester tester) =>
      GoRouter.of(anywhere(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;

  const String productRice = '0192f0a0-0000-7000-8000-00000000c024';

  Finder editorScroll() => find
      .descendant(of: byKey('order-editor'), matching: find.byType(Scrollable))
      .first;

  Map<String, Object?> milkLine() => orderLineJson(
    id: lineMilk,
    productId: productMilk,
    unit: 'piece',
    quantity: '2',
  );

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
    catalog = FakeCatalogRepository(
      categories: <CatalogCategory>[catalogCategory()],
      products: <CatalogProduct>[
        catalogProduct(
          id: productMilk,
          nameUz: 'Sut',
          nameRu: 'Молоко',
          unitCode: UnitCode.piece,
          priceMode: PriceMode.fixed,
          customerUnitPriceUzs: 12000,
        ),
        // The order's tomato, its id in another case.
        catalogProduct(id: productTomato.toUpperCase()),
        catalogProduct(
          id: productRice,
          categoryId: 'c-2',
          nameUz: 'Guruch',
          nameRu: 'Рис',
        ),
      ],
    );
  });

  Future<void> open(
    WidgetTester tester, {
    String at = '',
    bool alone = false,
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('uz'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        catalog: catalog,
        orders: orders,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    final GoRouter router = GoRouter.of(anywhere(tester));
    if (alone) {
      router.go(at);
    } else {
      router
        ..push(AppPaths.customerOrder(orderOne))
        ..push(at.isEmpty ? AppPaths.customerOrderEdit(orderOne) : at);
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(byKey('pick-search'), text);
    await tester.pump(CatalogHomeScreen.searchPause);
    await tester.pumpAndSettle();
  }

  Future<void> addMilk(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('edit-add-product'));
    await tapAndSettle(tester, byKey('pick-category-c-1'));
    await tapAndSettle(tester, byKey('product-$productMilk'));
  }

  testWidgets(
    'a product picked from a category is added at its price, and sent after the lines kept',
    (WidgetTester tester) async {
      await open(tester);
      await addMilk(tester);

      expect(top(tester), AppPaths.customerOrderEdit(orderOne));
      final Finder added = byKey('edit-line-added-$productMilk');
      expect(added, findsOneWidget);
      expect(
        find.descendant(of: added, matching: find.text('Sut')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: added,
          matching: find.text(l10n(tester).orderAddedLine),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(of: added, matching: byKey('line-quantity')).first,
        '3',
      );
      orders.answer = customerOrderJson(
        lines: <Object?>[
          orderLineJson(),
          orderLineJson(
            id: lineBread,
            productId: productBread,
            unit: 'piece',
            quantity: '2',
          ),
          milkLine(),
        ],
      );
      await tapAndSettle(tester, byKey('edit-save'));

      final List<OrderEditLine> sent = orders.edits.single.$2;
      expect(sent.map((OrderEditLine l) => l.productId), <String>[
        productTomato,
        productBread,
        productMilk,
      ]);
      expect(sent.last.quantity, '3');
      expect(sent.last.customerNote, isNull);
      expect(sent.last.substitutionPolicy, SubstitutionPolicy.allowSimilar);
      expect(top(tester), AppPaths.customerOrder(orderOne));
    },
  );

  testWidgets('a search finds the product to add', (WidgetTester tester) async {
    await open(tester);
    await tapAndSettle(tester, byKey('edit-add-product'));
    expect(byKey('pick-categories'), findsOneWidget);

    await search(tester, 'sut');
    expect(catalog.requests.last, startsWith('sut|null|'));
    await tapAndSettle(tester, byKey('product-$productMilk'));

    expect(byKey('edit-line-added-$productMilk'), findsOneWidget);
  });

  testWidgets('a product already in the order keeps its line, and says so', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('edit-remove-$lineTomato'));
    expect(
      find.descendant(
        of: byKey('edit-line-$lineTomato'),
        matching: byKey('line-quantity'),
      ),
      findsNothing,
    );

    await tapAndSettle(tester, byKey('edit-add-product'));
    await search(tester, 'pom');
    await tapAndSettle(tester, byKey('product-${productTomato.toUpperCase()}'));

    expect(find.text(l10n(tester).orderAddAlreadyIn), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('edit-line-added-'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: byKey('edit-line-$lineTomato'),
        matching: byKey('line-quantity'),
      ),
      findsOneWidget,
      reason: 'the line is kept again',
    );
  });

  testWidgets('an added product dropped again leaves nothing to send', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await addMilk(tester);
    await tapAndSettle(tester, byKey('edit-remove-added-$productMilk'));
    expect(byKey('edit-line-added-$productMilk'), findsNothing);

    await tapAndSettle(tester, byKey('edit-save'));
    expect(orders.edits, isEmpty);
    expect(top(tester), AppPaths.customerOrder(orderOne));
  });

  testWidgets('a product the server no longer sells is marked, the edit kept', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await addMilk(tester);
    orders.failure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'product_unavailable',
        details: <String, Object?>{
          'product_ids': <Object?>[productMilk],
        },
      ),
    );
    final int loads = orders.loads.length;

    await tapAndSettle(tester, byKey('edit-save'));

    expect(orders.loads.length, greaterThan(loads), reason: 'reloaded');
    expect(byKey('edit-unavailable-added-$productMilk'), findsOneWidget);
    expect(byKey('edit-unavailable-$lineTomato'), findsNothing);
    expect(find.text(l10n(tester).errorProductUnavailable), findsOneWidget);
    expect(top(tester), AppPaths.customerOrderEdit(orderOne));

    // A save the form stops sends nothing, and the marks stay.
    final Finder tomato = find
        .descendant(
          of: byKey('edit-line-$lineTomato'),
          matching: byKey('line-quantity'),
        )
        .first;
    await tester.enterText(tomato, '');
    await tapAndSettle(tester, byKey('edit-save'));
    expect(orders.edits, hasLength(1));
    expect(byKey('edit-unavailable-added-$productMilk'), findsOneWidget);
    await tester.enterText(tomato, '1,5');

    await tapAndSettle(tester, byKey('edit-remove-added-$productMilk'));
    orders.answer = customerOrderJson(note: 'Ertalab');
    await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
    await tapAndSettle(tester, byKey('edit-save'));
    expect(orders.edits.last.$2.map((OrderEditLine l) => l.productId), <String>[
      productTomato,
      productBread,
    ]);
    expect(top(tester), AppPaths.customerOrder(orderOne));
  });

  group('after a save whose answer was lost', () {
    // The server made the edit; the answer never came, and the order loads
    // again with the milk in it.
    Future<void> lose(WidgetTester tester) async {
      await open(tester);
      await addMilk(tester);
      orders
        ..failure = const NetworkFailure()
        ..rows = <Map<String, Object?>>[
          customerOrderJson(
            lines: <Object?>[
              orderLineJson(),
              orderLineJson(
                id: lineBread,
                productId: productBread,
                unit: 'piece',
                quantity: '2',
              ),
              orderLineJson(
                id: lineMilk,
                productId: productMilk,
                unit: 'piece',
                quantity: '1',
              ),
            ],
          ),
        ];
      await tapAndSettle(tester, byKey('edit-save'));
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    }

    testWidgets('dropping the product again is sent', (
      WidgetTester tester,
    ) async {
      await lose(tester);
      await tapAndSettle(tester, byKey('edit-remove-added-$productMilk'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      expect(orders.edits, hasLength(2));
      expect(
        orders.edits.last.$2.map((OrderEditLine l) => l.productId),
        <String>[productTomato, productBread],
      );
      expect(top(tester), AppPaths.customerOrder(orderOne));
    });

    testWidgets('keeping it is what the order holds, and nothing is sent', (
      WidgetTester tester,
    ) async {
      await lose(tester);
      await tapAndSettle(tester, byKey('edit-save'));

      expect(orders.edits, hasLength(1));
      expect(top(tester), AppPaths.customerOrder(orderOne));
    });
  });

  testWidgets('a product already in the order is brought into view', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(360, 500));
    await tester.scrollUntilVisible(
      byKey('edit-add-product'),
      300,
      scrollable: editorScroll(),
    );
    expect(
      tester.getRect(byKey('edit-line-$lineTomato')).top,
      lessThan(0),
      reason: 'out of sight when the picker opens',
    );
    await tapAndSettle(tester, byKey('edit-add-product'));
    await search(tester, 'pom');
    await tapAndSettle(tester, byKey('product-${productTomato.toUpperCase()}'));

    expect(
      tester.getRect(byKey('edit-line-$lineTomato')).top,
      greaterThanOrEqualTo(0),
    );
  });

  testWidgets('a line to correct out of sight stops the save and is shown', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(360, 500));
    await tester.enterText(
      find
          .descendant(
            of: byKey('edit-line-$lineTomato'),
            matching: byKey('line-quantity'),
          )
          .first,
      'abc',
    );
    await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
    await tester.scrollUntilVisible(
      byKey('edit-save'),
      300,
      scrollable: editorScroll(),
    );
    expect(tester.getRect(byKey('edit-line-$lineTomato')).bottom, lessThan(0));

    await tester.tap(byKey('edit-save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(orders.edits, isEmpty);
    expect(find.text(l10n(tester).cartQuantityFraction), findsOneWidget);
    final Finder field = find
        .descendant(
          of: byKey('edit-line-$lineTomato'),
          matching: byKey('line-quantity'),
        )
        .first;
    expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(500));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('an order holds at most 100 lines', (WidgetTester tester) async {
    String id(int group, int i) =>
        '0192f0a0-0000-7000-800$group-${i.toString().padLeft(12, '0')}';
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(
        lines: <Object?>[
          for (int i = 0; i < orderMaxLines; i++)
            orderLineJson(
              id: id(1, i),
              productId: id(2, i),
              unit: 'piece',
              quantity: '1',
            ),
        ],
      ),
    ];
    await open(tester);

    await tester.scrollUntilVisible(
      byKey('edit-add-product'),
      2000,
      scrollable: find
          .descendant(
            of: byKey('order-editor'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester.widget<OutlinedButton>(byKey('edit-add-product')).onPressed,
      isNull,
    );
    expect(find.text(l10n(tester).orderAddFull(100)), findsOneWidget);

    await tester.scrollUntilVisible(
      byKey('edit-remove-${id(1, 99)}'),
      -300,
      scrollable: find
          .descendant(
            of: byKey('order-editor'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapAndSettle(tester, byKey('edit-remove-${id(1, 99)}'));
    expect(
      tester.widget<OutlinedButton>(byKey('edit-add-product')).onPressed,
      isNotNull,
    );
    expect(byKey('edit-full'), findsNothing);

    // One added in its place, then the line kept again: one too many.
    await addMilk(tester);
    await tapAndSettle(tester, byKey('edit-remove-${id(1, 99)}'));
    await tester.scrollUntilVisible(
      byKey('edit-full'),
      300,
      scrollable: find
          .descendant(
            of: byKey('order-editor'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapAndSettle(tester, byKey('edit-save'));
    expect(orders.edits, isEmpty);
    expect(byKey('order-editor'), findsOneWidget);
  });

  testWidgets(
    'back from a category shows the categories, and then the editor',
    (WidgetTester tester) async {
      await open(tester);
      await tapAndSettle(tester, byKey('edit-add-product'));
      await tapAndSettle(tester, byKey('pick-category-c-1'));
      expect(byKey('product-$productMilk'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('pick-categories'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('order-editor'), findsOneWidget);
      expect(byKey('edit-line-added-$productMilk'), findsNothing);
    },
  );

  testWidgets('a picker opened by its address alone opens the editor', (
    WidgetTester tester,
  ) async {
    await open(tester, at: AppPaths.customerOrderAdd(orderOne), alone: true);
    await tapAndSettle(tester, byKey('pick-category-c-1'));
    await tapAndSettle(tester, byKey('product-$productMilk'));

    expect(tester.takeException(), isNull);
    expect(top(tester), AppPaths.customerOrderEdit(orderOne));
    expect(byKey('edit-line-added-$productMilk'), findsOneWidget);
  });

  testWidgets('a search in the picker looks through the whole catalog', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('edit-add-product'));
    await tapAndSettle(tester, byKey('pick-category-c-1'));

    await search(tester, 'guruch');
    expect(catalog.requests.last, startsWith('guruch|null|'));
    expect(byKey('product-$productRice'), findsOneWidget);
    expect(byKey('pick-category'), findsNothing);

    await tapAndSettle(tester, byKey('pick-search-clear'));
    expect(byKey('pick-category'), findsOneWidget, reason: 'the category back');
    expect(byKey('product-$productMilk'), findsOneWidget);
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the picker and an added line fit a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          size: const Size(360, 800),
          textScale: 2,
          device: language,
        );
        await tapAndSettle(tester, byKey('edit-add-product'));
        await tapAndSettle(tester, byKey('pick-category-c-1'));
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('product-$productMilk'));
        expect(byKey('edit-line-added-$productMilk'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
