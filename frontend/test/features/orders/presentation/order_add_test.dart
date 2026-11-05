import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/category_tile.dart';
import 'package:baraka_bozor/features/catalog/presentation/search_screen.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:baraka_bozor/features/orders/presentation/line_flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

/// Adding products to a placed order (`docs/03` section 11, `docs/09`
/// section 21, `DL-52`, `DL-132`) through the real router, editor and picker,
/// with the repositories faked.
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
  final String tomato = productTomato.toUpperCase();

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
      categories: <CatalogCategory>[
        catalogCategory(),
        catalogCategory(id: 'c-2', nameUz: 'Mevalar', nameRu: 'Фрукты'),
      ],
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
        catalogProduct(id: tomato),
        catalogProduct(
          id: productRice,
          categoryId: 'c-2',
          nameUz: 'Guruch',
          nameRu: 'Рис',
          customerUnitPriceUzs: 8000,
        ),
      ],
    );
  });

  Future<void> open(
    WidgetTester tester, {
    String at = '',
    bool alone = false,
    Size size = const Size(800, 2400),
    TextScaler scaler = TextScaler.noScaling,
    Locale device = const Locale('uz'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        catalog: catalog,
        orders: orders,
        device: device,
        textScaler: scaler == TextScaler.noScaling ? null : scaler,
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
    await tester.pump(SearchScreen.searchPause);
    await tester.pumpAndSettle();
  }

  /// Takes a line out of the editor: its options sheet, then the remove
  /// button in it.
  Future<void> removeLine(WidgetTester tester, String key) async {
    await tapAndSettle(tester, byKey('edit-options-$key'));
    await tapAndSettle(tester, byKey('edit-remove-$key'));
  }

  /// Opens the picker from the editor, and the first section.
  Future<void> openSection(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('edit-add-product'));
    await tapAndSettle(tester, byKey('pick-section-c-1'));
  }

  /// Leaves the picker by the system back, which returns from a section to
  /// the tiles first.
  Future<void> backToEditor(WidgetTester tester) async {
    while (byKey('pick-search').evaluate().isNotEmpty) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  }

  /// The semantics node that reads a picker row.
  SemanticsNode rowNode(WidgetTester tester, String id) => tester.getSemantics(
    find
        .ancestor(
          of: byKey('product-$id'),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.label != null,
          ),
        )
        .first,
  );

  /// The milk added in the picker, which then returns to the editor.
  Future<void> addMilk(WidgetTester tester) async {
    await openSection(tester);
    await tapAndSettle(tester, byKey('pick-$productMilk'));
    await tapAndSettle(tester, byKey('pick-done'));
  }

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  /// Every light buzz the platform is asked for.
  List<String> catchHaptics(WidgetTester tester) {
    final List<String> haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return haptics;
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
          matching: find.text(l10n(tester).orderEditNew),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('line-plus-added-$productMilk'));
      await tapAndSettle(tester, byKey('line-plus-added-$productMilk'));
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
    expect(byKey('pick-tiles'), findsOneWidget);

    await search(tester, 'sut');
    expect(catalog.requests.last, startsWith('sut|null|'));
    await tapAndSettle(tester, byKey('pick-$productMilk'));
    await tapAndSettle(tester, byKey('pick-done'));

    expect(byKey('edit-line-added-$productMilk'), findsOneWidget);
  });

  testWidgets('a product taken out in the editor is kept again by its plus', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await removeLine(tester, lineTomato);
    expect(byKey('line-plus-$lineTomato'), findsNothing);

    await tapAndSettle(tester, byKey('edit-add-product'));
    await search(tester, 'pom');
    await tapAndSettle(tester, byKey('pick-$tomato'));
    expect(byKey('pick-minus-$tomato'), findsOneWidget);
    expect(
      byKey('pick-bar'),
      findsNothing,
      reason: 'not a line this visit adds',
    );
    await backToEditor(tester);

    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('edit-line-added-'),
      ),
      findsNothing,
    );
    expect(
      byKey('line-plus-$lineTomato'),
      findsOneWidget,
      reason: 'the line is kept again',
    );
  });

  testWidgets('an added product dropped again leaves nothing to send', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await addMilk(tester);
    await removeLine(tester, 'added-$productMilk');
    expect(byKey('edit-line-added-$productMilk'), findsNothing);

    expect(
      find.descendant(
        of: byKey('edit-save'),
        matching: find.text(l10n(tester).orderEditNoChanges),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);
    expect(orders.edits, isEmpty);
    expect(top(tester), AppPaths.customerOrderEdit(orderOne));
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
    await tester.enterText(byKey('edit-delivery-wish'), 'a' * 161);
    await tapAndSettle(tester, byKey('edit-save'));
    expect(orders.edits, hasLength(1));
    expect(byKey('edit-unavailable-added-$productMilk'), findsOneWidget);

    await removeLine(tester, 'added-$productMilk');
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
      await removeLine(tester, 'added-$productMilk');
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      expect(orders.edits, hasLength(2));
      expect(
        orders.edits.last.$2.map((OrderEditLine l) => l.productId),
        <String>[productTomato, productBread],
      );
      expect(top(tester), AppPaths.customerOrder(orderOne));
    });

    testWidgets('dropping it while the order still loads again is sent', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await addMilk(tester);
      final Completer<void> reload = Completer<void>();
      orders
        ..failure = const NetworkFailure()
        ..loadHold = reload
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
              milkLine(),
            ],
          ),
        ];
      await tapAndSettle(tester, byKey('edit-save'));
      await removeLine(tester, 'added-$productMilk');
      orders.answer = customerOrderJson();
      await tester.tap(byKey('edit-save'));
      await tester.pump();

      expect(
        orders.edits,
        hasLength(2),
        reason: 'what the order holds is unknown',
      );
      orders.loadHold = null;
      reload.complete();
      await tester.pumpAndSettle();
      expect(top(tester), AppPaths.customerOrder(orderOne));
    });

    testWidgets('keeping it is what the order holds, and nothing is sent', (
      WidgetTester tester,
    ) async {
      await lose(tester);

      expect(
        find.descendant(
          of: byKey('edit-save'),
          matching: find.text(l10n(tester).orderEditNoChanges),
        ),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);
      expect(orders.edits, hasLength(1));
      expect(top(tester), AppPaths.customerOrderEdit(orderOne));
    });
  });

  testWidgets(
    'a line kept again after its removal was made is shown as added, and sent',
    (WidgetTester tester) async {
      await open(tester);
      await removeLine(tester, lineTomato);
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      orders
        ..failure = const NetworkFailure()
        ..rows = <Map<String, Object?>>[
          customerOrderJson(
            note: 'Ertalab',
            lines: <Object?>[
              orderLineJson(
                status: 'removed',
                removedReason: 'customer_removed',
              ),
              orderLineJson(
                id: lineBread,
                productId: productBread,
                unit: 'piece',
                quantity: '2',
              ),
            ],
          ),
        ];
      await tapAndSettle(tester, byKey('edit-save'));
      expect(byKey('edit-adds-$lineTomato'), findsNothing);

      expect(
        find.descendant(
          of: byKey('edit-restore-$lineTomato'),
          matching: find.text(l10n(tester).orderEditKeepLine),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('edit-restore-$lineTomato'));
      expect(byKey('edit-adds-$lineTomato'), findsOneWidget);
      orders.answer = customerOrderJson(note: 'Ertalab');
      await tapAndSettle(tester, byKey('edit-save'));
      expect(
        orders.edits.last.$2.map((OrderEditLine l) => l.productId),
        <String>[productTomato, productBread],
      );
    },
  );

  testWidgets('a save that goes hides the keyboard', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    final Completer<void> hold = Completer<void>();
    orders
      ..hold = hold
      ..answer = customerOrderJson(note: 'Ertalab');

    await tester.tap(byKey('edit-save'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    orders.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a note over 300 is refused in the sheet, and the old one is sent',
    (WidgetTester tester) async {
      await open(tester, size: const Size(360, 500));
      await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
      await tester.enterText(byKey('line-note'), 'a' * 301);
      await tapAndSettle(tester, byKey('edit-options-done'));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
      expect(byKey('edit-options-done'), findsOneWidget, reason: 'stays open');

      // Closing it any other way leaves the note as it was.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('edit-options-done'), findsNothing);
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      orders.answer = customerOrderJson(note: 'Ertalab');
      await tapAndSettle(tester, byKey('edit-save'));

      expect(orders.edits.single.$2.first.customerNote, isNull);
    },
  );

  testWidgets('a line whose quantity the unit no longer takes is set anew', (
    WidgetTester tester,
  ) async {
    // 1,5 pieces: the product has become a whole unit.
    orders.rows = <Map<String, Object?>>[
      customerOrderJson(
        lines: <Object?>[
          orderLineJson(unit: 'piece', quantity: '1.500'),
          orderLineJson(
            id: lineBread,
            productId: productBread,
            unit: 'piece',
            quantity: '2',
          ),
        ],
      ),
    ];
    await open(tester);

    await tapAndSettle(tester, byKey('edit-save'));

    expect(tester.takeException(), isNull);
    expect(orders.edits, isEmpty);
    expect(byKey('quantity-done'), findsOneWidget, reason: 'asked anew');
    await tester.enterText(byKey('line-quantity'), '2');
    await tapAndSettle(tester, byKey('quantity-done'));
    orders.answer = customerOrderJson();
    await tapAndSettle(tester, byKey('edit-save'));
    expect(orders.edits.single.$2.first.quantity, '2');
  });

  testWidgets('an added product is tagged "Новый" and priced now', (
    WidgetTester tester,
  ) async {
    await open(tester, device: const Locale('ru'));
    await addMilk(tester);

    final AppLocalizations words = l10n(tester);
    final Finder added = byKey('edit-line-added-$productMilk');
    expect(
      find.descendant(
        of: byKey('edit-adds-added-$productMilk'),
        matching: find.text('Новый'),
      ),
      findsOneWidget,
    );
    // The milk's price now, 12 000, not the tomato's 18 400, and a fixed
    // price has no "≈".
    expect(
      find.descendant(
        of: added,
        matching: find.text(
          words.catalogPricePerUnit(
            MoneyFormat.uzs(12000, AppLanguage.ru),
            words.unitPiece,
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: added,
        matching: find.text(MoneyFormat.uzs(12000, AppLanguage.ru)),
      ),
      findsOneWidget,
    );
    await tapAndSettle(tester, byKey('line-plus-added-$productMilk'));
    expect(
      find.descendant(
        of: added,
        matching: find.text(MoneyFormat.uzs(24000, AppLanguage.ru)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the picker shows "≈" only on an estimate price', (
    WidgetTester tester,
  ) async {
    await open(tester, device: const Locale('ru'));
    await openSection(tester);

    final AppLocalizations words = l10n(tester);
    expect(
      find.descendant(
        of: byKey('product-$productMilk'),
        matching: find.text(MoneyFormat.uzs(12000, AppLanguage.ru)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('product-$productMilk'),
        matching: find.text(
          words.cartLineEstimate(MoneyFormat.uzs(12000, AppLanguage.ru)),
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: byKey('product-$tomato'),
        matching: find.text(
          words.cartLineEstimate(MoneyFormat.uzs(18400, AppLanguage.ru)),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a pick keeps the picker open and turns the plus into a stepper',
    (WidgetTester tester) async {
      final List<String> haptics = catchHaptics(tester);
      await open(tester, device: const Locale('ru'));
      await openSection(tester);
      expect(byKey('pick-step-$productMilk'), findsNothing);
      expect(byKey('pick-bar'), findsNothing);
      announced(tester);

      await tester.tap(byKey('pick-$productMilk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final double midway = tester
          .getSize(byKey('pick-step-$productMilk'))
          .width;
      expect(midway, greaterThan(44));
      expect(midway, lessThan(124), reason: 'the plus is growing');
      await tester.pumpAndSettle();

      expect(tester.getSize(byKey('pick-step-$productMilk')).width, 124);
      expect(tester.getSize(byKey('pick-step-$productMilk')).height, 44);
      expect(
        byKey('pick-$productMilk'),
        findsNothing,
        reason: 'the plus is gone',
      );
      expect(
        find.descendant(
          of: byKey('pick-step-$productMilk'),
          matching: find.text('1 ${l10n(tester).unitPiece}'),
        ),
        findsOneWidget,
      );
      expect(top(tester), AppPaths.customerOrderAdd(orderOne), reason: 'open');
      expect(haptics, <String>['HapticFeedbackType.lightImpact']);
      expect(announced(tester), <String>[
        'Добавили: Молоко, 1 ${l10n(tester).unitPiece}. Добавлено товаров: 1',
      ]);
      expect(
        find.descendant(
          of: byKey('product-$productMilk'),
          matching: find.text(l10n(tester).orderPickAddedNow),
        ),
        findsOneWidget,
      );
      expect(byKey('pick-bar'), findsOneWidget);
    },
  );

  testWidgets('a pick with reduced motion takes the stepper by a fade', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester);
    await openSection(tester);

    await tester.tap(byKey('pick-$productMilk'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.getSize(byKey('pick-step-$productMilk')).width, 124);
    await tester.pumpAndSettle();
  });

  testWidgets('the bar counts what this visit added and Готово returns', (
    WidgetTester tester,
  ) async {
    await open(tester, device: const Locale('ru'));
    await openSection(tester);
    await tapAndSettle(tester, byKey('pick-$productMilk'));
    final AppLocalizations words = l10n(tester);
    expect(
      find.descendant(
        of: byKey('pick-bar'),
        matching: find.text('Добавлено: 1 товар'),
      ),
      findsOneWidget,
    );

    // The rice stands in another section: a search finds it.
    await search(tester, 'guruch');
    await tapAndSettle(tester, byKey('pick-$productRice'));

    expect(
      find.descendant(
        of: byKey('pick-bar'),
        matching: find.text('Добавлено: 2 товара'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('pick-bar'),
        matching: find.text(
          words.cartLineEstimate(MoneyFormat.uzs(20000, AppLanguage.ru)),
        ),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('pick-done'));
    expect(top(tester), AppPaths.customerOrderEdit(orderOne));
    expect(byKey('edit-line-added-$productMilk'), findsOneWidget);
    expect(byKey('edit-line-added-$productRice'), findsOneWidget);
  });

  testWidgets(
    'a product already in the order shows its stepper and Уже в заказе',
    (WidgetTester tester) async {
      await open(tester, device: const Locale('ru'));
      await openSection(tester);

      expect(byKey('pick-$tomato'), findsNothing);
      expect(byKey('pick-minus-$tomato'), findsOneWidget);
      expect(byKey('pick-plus-$tomato'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('product-$tomato'),
          matching: find.text('Уже в заказе'),
        ),
        findsOneWidget,
      );
      expect(byKey('pick-bar'), findsNothing, reason: 'nothing added here');
      expect(byKey('pick-$productMilk'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('product-$productMilk'),
          matching: find.text('Уже в заказе'),
        ),
        findsNothing,
      );

      // The stepper steps the editor's own line.
      final Finder quantity = find.descendant(
        of: byKey('pick-step-$tomato'),
        matching: find.byType(Text),
      );
      final String before = tester.widget<Text>(quantity).data!;
      await tapAndSettle(tester, byKey('pick-plus-$tomato'));
      expect(tester.widget<Text>(quantity).data, isNot(before));
      await backToEditor(tester);
      expect(byKey('edit-line-$lineTomato'), findsOneWidget);
      expect(byKey('pick-search'), findsNothing, reason: 'the picker is gone');
    },
  );

  testWidgets('the stepper\'s bin takes the product out again', (
    WidgetTester tester,
  ) async {
    await open(tester, device: const Locale('ru'));
    await openSection(tester);
    await tapAndSettle(tester, byKey('pick-$productMilk'));
    announced(tester);
    expect(byKey('pick-bar'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('pick-minus-$productMilk'),
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsOneWidget,
      reason: 'a piece cannot go below 1',
    );
    expect(find.byTooltip(l10n(tester).orderEditRemoveShort), findsOneWidget);

    await tapAndSettle(tester, byKey('pick-minus-$productMilk'));

    expect(
      byKey('pick-$productMilk'),
      findsOneWidget,
      reason: 'the plus again',
    );
    expect(byKey('pick-step-$productMilk'), findsNothing);
    expect(byKey('pick-bar'), findsNothing);
    expect(announced(tester), <String>['Молоко — убрали из заказа']);
    await backToEditor(tester);
    expect(byKey('edit-line-added-$productMilk'), findsNothing);
  });

  testWidgets('a line taken out in the editor is not marked in the picker', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await removeLine(tester, lineTomato);
    await openSection(tester);

    expect(byKey('pick-$tomato'), findsOneWidget);
    expect(byKey('pick-step-$tomato'), findsNothing);
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
      scrollable: editorScroll(),
    );
    expect(
      tester.widget<OutlinedButton>(byKey('edit-add-product')).onPressed,
      isNull,
    );
    expect(find.text(l10n(tester).orderAddFull(100)), findsOneWidget);

    await removeLine(tester, id(1, 99));
    expect(
      tester.widget<OutlinedButton>(byKey('edit-add-product')).onPressed,
      isNotNull,
    );
    expect(byKey('edit-full'), findsNothing);

    // The picker fills the place: the plus is off for the rest, and the bar
    // says why.
    await openSection(tester);
    expect(
      tester.widget<IconButton>(byKey('pick-$tomato')).onPressed,
      isNotNull,
    );
    await tapAndSettle(tester, byKey('pick-$productMilk'));
    expect(tester.widget<IconButton>(byKey('pick-$tomato')).onPressed, isNull);
    expect(
      find.descendant(
        of: byKey('pick-bar'),
        matching: find.text(l10n(tester).orderAddFull(100)),
      ),
      findsOneWidget,
    );
    await tapAndSettle(tester, byKey('pick-done'));

    // The line kept again: one too many.
    await tapAndSettle(tester, byKey('edit-restore-${id(1, 99)}'));
    await tester.scrollUntilVisible(
      byKey('edit-full'),
      300,
      scrollable: editorScroll(),
    );
    expect(
      find.descendant(
        of: byKey('edit-save'),
        matching: find.text(l10n(tester).orderAddFull(100)),
      ),
      findsOneWidget,
      reason: 'the button says why it waits',
    );
    expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);
    expect(orders.edits, isEmpty);
    expect(byKey('order-editor'), findsOneWidget);
  });

  testWidgets('back from a section returns to the tiles, then to the editor', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await openSection(tester);
    expect(byKey('product-$productMilk'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(byKey('pick-tiles'), findsOneWidget);
    expect(top(tester), AppPaths.customerOrderAdd(orderOne));

    // «‹ Все разделы» goes back to the tiles as well.
    await tapAndSettle(tester, byKey('pick-section-c-1'));
    await tapAndSettle(tester, byKey('pick-all-sections'));
    expect(byKey('pick-tiles'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(byKey('order-editor'), findsOneWidget);
    expect(byKey('edit-line-added-$productMilk'), findsNothing);
  });

  testWidgets(
    'sections are photo tiles, and a section shows Все разделы and its name',
    (WidgetTester tester) async {
      await open(tester, device: const Locale('ru'));
      await tapAndSettle(tester, byKey('edit-add-product'));

      expect(find.byType(ListTile), findsNothing);
      for (final String id in const <String>['c-1', 'c-2']) {
        expect(
          find.descendant(
            of: byKey('pick-section-$id'),
            matching: find.byType(CategoryPictureWell),
          ),
          findsOneWidget,
        );
      }
      final Rect first = tester.getRect(byKey('pick-section-c-1'));
      final Rect second = tester.getRect(byKey('pick-section-c-2'));
      expect(first.top, second.top, reason: 'two in a row');
      expect(second.left, greaterThan(first.right));
      expect(first.height, greaterThanOrEqualTo(118));
      expect(
        find.descendant(
          of: byKey('pick-section-c-1'),
          matching: find.text('Овощи'),
        ),
        findsOneWidget,
      );
      expect(byKey('pick-all-sections'), findsNothing);

      await tapAndSettle(tester, byKey('pick-section-c-1'));

      expect(byKey('pick-tiles'), findsNothing);
      expect(
        find.descendant(
          of: byKey('pick-all-sections'),
          matching: find.text('Все разделы'),
        ),
        findsOneWidget,
      );
      expect(byKey('pick-crumb-name'), findsOneWidget);
      expect(tester.widget<Text>(byKey('pick-crumb-name')).data, 'Овощи');
      expect(byKey('pick-category'), findsNothing, reason: 'no chip any more');
    },
  );

  testWidgets('the tiles and rows are read with what they do', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await open(tester, device: const Locale('ru'));
    await tapAndSettle(tester, byKey('edit-add-product'));
    expect(
      tester.getSemantics(byKey('pick-section-c-1')).label,
      'Овощи, раздел',
    );
    await tapAndSettle(tester, byKey('pick-section-c-1'));

    final AppLocalizations words = l10n(tester);
    expect(
      rowNode(tester, productMilk).label,
      words.orderPickRowSpoken(
        'Молоко',
        MoneyFormat.uzs(12000, AppLanguage.ru),
        words.unitPiece,
      ),
    );
    expect(find.byTooltip('Добавить: Молоко'), findsOneWidget);
    expect(rowNode(tester, tomato).label, startsWith('Помидор, в заказе '));
    expect(find.byTooltip(words.cartStepMinus), findsOneWidget);
    expect(find.byTooltip(words.cartStepPlus), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'at large text the tiles stand in one column and the price wraps',
    (WidgetTester tester) async {
      catalog.productRows.add(
        catalogProduct(
          id: '0192f0a0-0000-7000-8000-00000000c030',
          nameUz: 'Juda uzun',
          nameRu: 'Очень длинный',
          customerUnitPriceUzs: 99999999,
        ),
      );
      await open(
        tester,
        size: const Size(360, 800),
        scaler: const NonlinearTextScaler(2),
        device: const Locale('ru'),
      );
      await tapAndSettle(tester, byKey('edit-add-product'));

      final Rect first = tester.getRect(byKey('pick-section-c-1'));
      final Rect second = tester.getRect(byKey('pick-section-c-2'));
      expect(second.left, first.left, reason: 'one column');
      expect(second.top, greaterThan(first.bottom));
      expect(tester.takeException(), isNull);

      await tapAndSettle(tester, byKey('pick-section-c-1'));
      final Finder price = find.descendant(
        of: byKey('product-0192f0a0-0000-7000-8000-00000000c030'),
        matching: find.text(
          l10n(tester)
              .cartLineEstimate(MoneyFormat.uzs(99999999, AppLanguage.ru)),
        ),
      );
      expect(price, findsOneWidget);
      expect(
        tester.getSize(price).height,
        greaterThan(28 * 1.5),
        reason: 'wrapped to more than one line',
      );
      expect(
        find.descendant(
          of: byKey('product-0192f0a0-0000-7000-8000-00000000c030'),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('at large text the stepper takes the row\'s width', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      size: const Size(360, 800),
      scaler: const NonlinearTextScaler(2),
    );
    await openSection(tester);
    await tapAndSettle(tester, byKey('pick-$productMilk'));

    final Rect row = tester.getRect(byKey('product-$productMilk'));
    final Rect stepper = tester.getRect(byKey('pick-step-$productMilk'));
    expect(stepper.left, row.left + 20 + 68, reason: 'under the words');
    expect(stepper.right, row.right - 20);
    expect(stepper.height, 44);
    final Rect name = tester.getRect(
      find
          .descendant(
            of: byKey('product-$productMilk'),
            matching: find.text('Sut'),
          )
          .first,
    );
    expect(stepper.top, greaterThanOrEqualTo(name.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lines added in the picker arrive in the editor, scrolled to and flashed',
    (WidgetTester tester) async {
      String id(int group, int i) =>
          '0192f0a0-0000-7000-800$group-${i.toString().padLeft(12, '0')}';
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            for (int i = 0; i < 8; i++)
              orderLineJson(
                id: id(1, i),
                productId: id(2, i),
                unit: 'piece',
                quantity: '1',
              ),
          ],
        ),
      ];
      await open(
        tester,
        size: const Size(360, 640),
        device: const Locale('ru'),
      );
      await openSection(tester);
      await tapAndSettle(tester, byKey('pick-$productMilk'));
      // While the picker is open the editor does not show the line yet.
      expect(byKey('edit-line-added-$productMilk'), findsNothing);
      await tester.pump(const Duration(milliseconds: 450));
      announced(tester);

      await tester.tap(byKey('pick-done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final Finder line = byKey('edit-line-added-$productMilk');
      expect(line, findsOneWidget);
      final Finder flash = find.ancestor(
        of: line,
        matching: find.byType(LineFlash),
      );
      expect(tester.widget<LineFlash>(flash).flash, 1);
      expect(tester.widget<LineFlash>(flash).color, KitColors.lineFlash);
      final DecoratedBox wash = tester.widget<DecoratedBox>(
        find.descendant(of: flash, matching: byKey('line-flash')),
      );
      expect(
        (wash.decoration as BoxDecoration).color!.a,
        greaterThan(0),
        reason: 'green while it flashes',
      );
      await tester.pumpAndSettle();

      final Rect viewport = tester.getRect(byKey('order-editor'));
      expect(
        tester.getRect(flash).top - viewport.top,
        closeTo(viewport.height / 3, 3),
        reason: 'a third of the view',
      );
      expect(
        announced(tester).where(
          (String m) =>
              m.startsWith('Молоко, 1 ${l10n(tester).unitPiece}. Итого'),
        ),
        hasLength(1),
      );
    },
  );

  testWidgets('arriving lines unfold together once the picker is closed', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await openSection(tester);
    await tapAndSettle(tester, byKey('pick-$productMilk'));
    await search(tester, 'guruch');
    await tapAndSettle(tester, byKey('pick-$productRice'));

    await tester.tap(byKey('pick-done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    Finder foldOf(String product) => find.ancestor(
      of: byKey('edit-line-added-$product'),
      matching: find.byType(Fold),
    );
    final double milkMid = tester.getSize(foldOf(productMilk)).height;
    final double riceMid = tester.getSize(foldOf(productRice)).height;
    await tester.pumpAndSettle();
    final double milkFull = tester.getSize(foldOf(productMilk)).height;
    expect(milkMid, lessThan(milkFull), reason: 'still unfolding');
    expect(riceMid, closeTo(milkMid, 4), reason: 'together, not staggered');
  });

  testWidgets('a picker opened by its address alone opens the editor', (
    WidgetTester tester,
  ) async {
    await open(tester, at: AppPaths.customerOrderAdd(orderOne), alone: true);

    expect(tester.takeException(), isNull);
    expect(top(tester), AppPaths.customerOrderEdit(orderOne));
    expect(byKey('order-editor'), findsOneWidget);
    expect(byKey('pick-search'), findsNothing);
  });

  testWidgets('a lock found while the picker is open shows the lock view', (
    WidgetTester tester,
  ) async {
    await open(tester, device: const Locale('ru'));
    await openSection(tester);
    // The server has locked the order; the next preview says so.
    orders
      ..rows = <Map<String, Object?>>[customerOrderJson(changeable: false)]
      ..previewFailure = const ApiRefusal(
        ApiError(status: 409, code: 'order_editing_locked'),
      );

    await tester.tap(byKey('pick-$productMilk'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(byKey('pick-search'), findsNothing, reason: 'the picker closed');
    expect(byKey('edit-locked'), findsOneWidget);
    expect(top(tester), AppPaths.customerOrderEdit(orderOne));
  });

  testWidgets('a search in the picker looks through the whole catalog', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await openSection(tester);

    await search(tester, 'guruch');
    expect(catalog.requests.last, startsWith('guruch|null|'));
    expect(byKey('product-$productRice'), findsOneWidget);
    expect(byKey('pick-all-sections'), findsNothing);

    await tapAndSettle(tester, byKey('pick-search-clear'));
    expect(
      byKey('pick-all-sections'),
      findsOneWidget,
      reason: 'the section back',
    );
    expect(byKey('product-$productMilk'), findsOneWidget);
  });

  for (final (String, TextScaler) scale in <(String, TextScaler)>[
    ('100 %', TextScaler.noScaling),
    ('200 %', const NonlinearTextScaler(2)),
  ]) {
    testWidgets(
      'the tiles, a section with plus and stepper rows, and the bar meet the guideline at ${scale.$1}',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await open(
          tester,
          size: const Size(360, 800),
          scaler: scale.$2,
          device: const Locale('ru'),
        );
        await tapAndSettle(tester, byKey('edit-add-product'));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await tapAndSettle(tester, byKey('pick-section-c-1'));
        // The tomato stands with its stepper, the milk with its plus.
        expect(byKey('pick-minus-$tomato'), findsOneWidget);
        expect(byKey('pick-$productMilk'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await tapAndSettle(tester, byKey('pick-$productMilk'));
        expect(byKey('pick-bar'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  }

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the picker and an added line fit a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        String id(int i) => '0192f0a0-0000-7000-8000-00000000c10$i';
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(
            note: 'a' * 160,
            lines: <Object?>[
              orderLineJson(note: 'b' * 300),
              orderLineJson(
                id: lineBread,
                productId: productBread,
                unit: 'piece',
                quantity: '9999',
              ),
              orderLineJson(id: id(1), productId: id(2), quantity: '1234.500'),
              orderLineJson(
                id: id(3),
                productId: id(4),
                unit: 'piece',
                quantity: '1',
                patch: <String, Object?>{'customer_unit_price_uzs': 99999999},
              ),
            ],
          ),
        ];
        catalog.productRows.add(
          catalogProduct(
            id: '0192f0a0-0000-7000-8000-00000000c030',
            nameUz: 'Juda uzun nomli mahsulot ' * 3,
            nameRu: 'Очень длинное название товара ' * 3,
            customerUnitPriceUzs: 99999999,
          ),
        );
        await open(
          tester,
          size: const Size(320, 640),
          scaler: const NonlinearTextScaler(2),
          device: language,
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('edit-add-product'));
        await tapAndSettle(tester, byKey('pick-section-c-1'));
        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w is InkWell &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('product-'),
          ),
          findsWidgets,
          reason: 'the rows in view; the list builds the rest as it scrolls',
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('pick-$productMilk'));
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('pick-done'));
        expect(byKey('edit-line-added-$productMilk'), findsOneWidget);
        await tester.enterText(byKey('edit-delivery-wish'), 'c' * 160);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
