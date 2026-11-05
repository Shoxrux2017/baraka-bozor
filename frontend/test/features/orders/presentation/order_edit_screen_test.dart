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
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:baraka_bozor/features/orders/presentation/line_flash.dart';
import 'package:baraka_bozor/features/orders/presentation/order_edit_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

/// The order of the test page: tomatoes 2,5 kg at 14 000, flatbread 3 at
/// 3 000 and apples 1,5 kg at 18 000, delivery 15 000 and fee 5 000.
const String lineApple = '0192f0a0-0000-7000-8000-00000000c014';
const String productApple = '0192f0a0-0000-7000-8000-00000000c024';

Map<String, Object?> pageOrder({
  String status = 'new',
  bool changeable = true,
  String? supportPhone,
}) => customerOrderJson(
  status: status,
  changeable: changeable,
  supportPhone: supportPhone,
  lines: <Object?>[
    orderLineJson(
      quantity: '2.500',
      patch: <String, Object?>{
        'customer_unit_price_uzs': 14000,
        'line_total_uzs': 35000,
      },
    ),
    orderLineJson(
      id: lineBread,
      productId: productBread,
      unit: 'piece',
      quantity: '3',
      patch: <String, Object?>{
        'customer_unit_price_uzs': 3000,
        'line_total_uzs': 9000,
      },
    ),
    orderLineJson(
      id: lineApple,
      productId: productApple,
      quantity: '1.500',
      patch: <String, Object?>{
        'name_uz': 'Olma',
        'name_ru': 'Яблоки',
        'customer_unit_price_uzs': 18000,
        'line_total_uzs': 27000,
      },
    ),
  ],
  totals: <String, Object?>{
    'merchandise_subtotal_uzs': 71000,
    'service_fee_uzs': 5000,
    'delivery_fee_uzs': 15000,
    'total_uzs': 91000,
    'total_kind': 'estimate',
  },
);

/// The order's editor (`docs/09` section 21, `DL-43`, `DL-132`) through the
/// real router and screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late FakeCartRepository cart;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
    cart = FakeCartRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    String? at,
    bool alone = false,
    Size size = const Size(800, 2400),
    double textScale = 1,
    TextScaler? scaler,
    Object? extra,
    Locale device = const Locale('uz'),
    FakePhoneCalls? phoneCalls,
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
        orders: orders,
        cart: cart,
        device: device,
        textScaler: scaler,
        phoneCalls: phoneCalls,
      ),
    );
    await tester.pumpAndSettle();
    if (at != null) {
      final GoRouter router = GoRouter.of(anywhere(tester));
      alone ? router.go(at, extra: extra) : router.push(at, extra: extra);
      await tester.pumpAndSettle();
    }
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

  /// Takes a line out of the editor: its options sheet, then the remove
  /// button in it.
  Future<void> removeLine(WidgetTester tester, String key) async {
    await tapAndSettle(tester, byKey('edit-options-$key'));
    await tapAndSettle(tester, byKey('edit-remove-$key'));
  }

  group('editing', () {
    testWidgets(
      'sends every line the order keeps and the wish, and nothing when nothing changed',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await tapAndSettle(tester, byKey('order-edit'));
        expect(byKey('order-editor'), findsOneWidget);

        expect(
          tester.widget<FilledButton>(byKey('edit-save')).onPressed,
          isNull,
          reason: 'nothing changed: the button says so and waits',
        );
        expect(orders.edits, isEmpty);
        expect(byKey('order-editor'), findsOneWidget);

        await removeLine(tester, lineBread);
        // 1,5 kg steps by half a kilo: two plus taps make 2,5.
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await tester.enterText(byKey('edit-delivery-wish'), '');
        orders.answer = customerOrderJson(
          note: null,
          lines: <Object?>[
            orderLineJson(quantity: '2.500'),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
              status: 'removed',
              removedReason: 'customer_removed',
            ),
          ],
        );
        await tapAndSettle(tester, byKey('edit-save'));

        final (String id, List<OrderEditLine> lines, String? wish) =
            orders.edits.single;
        expect(id, orderOne);
        expect(lines.single.productId, productTomato);
        expect(lines.single.quantity, '2.5');
        expect(wish, isNull);
        expect(byKey('order-editor'), findsNothing);
        expect(byKey('order-line-$lineBread'), findsNothing);
      },
    );

    testWidgets('at least one line stays', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await removeLine(tester, lineTomato);
      await removeLine(tester, lineBread);

      expect(
        find.descendant(
          of: byKey('edit-save'),
          matching: find.text(l10n(tester).orderEditKeepOne),
        ),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);
      expect(orders.edits, isEmpty);
    });

    testWidgets(
      'an order whose shopping started is reloaded, and no longer edited',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrder(orderOne));
        await tapAndSettle(tester, byKey('order-edit'));
        orders
          ..failure = const ApiRefusal(
            ApiError(status: 409, code: 'order_editing_locked'),
          )
          ..rows = <Map<String, Object?>>[
            customerOrderJson(status: 'shopping', changeable: false),
          ];
        await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');

        await tapAndSettle(tester, byKey('edit-save'));

        // The wish the Customer typed did not save, and the view says so.
        expect(byKey('edit-locked'), findsOneWidget);
        expect(byKey('edit-closed'), findsNothing);
        expect(find.text(l10n(tester).orderEditLockedTitle), findsOneWidget);
        expect(find.text('Yetkazish istagi: «Ertalab»'), findsOneWidget);
        expect(byKey('edit-save'), findsNothing);
        await tapAndSettle(tester, byKey('edit-back-to-order'));
        expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
        expect(byKey('order-edit'), findsNothing);
      },
    );

    testWidgets('an order past editing opened by its address is not edited', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(status: 'cancelled', changeable: false),
      ];
      await open(tester, at: AppPaths.customerOrderEdit(orderOne), alone: true);

      expect(byKey('edit-closed'), findsOneWidget);
      expect(byKey('order-editor'), findsNothing);
      await tapAndSettle(tester, byKey('edit-back-to-order'));
      expect(
        GoRouter.of(anywhere(tester))
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        AppPaths.customerOrder(orderOne),
      );
      expect(byKey('order-status'), findsOneWidget);
    });

    testWidgets('an editor opened by its address leaves for the order', (
      WidgetTester tester,
    ) async {
      String top() =>
          GoRouter.of(anywhere(tester))
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation;

      await open(tester, at: AppPaths.customerOrderEdit(orderOne), alone: true);
      expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);
      expect(orders.edits, isEmpty, reason: 'nothing changed');
      expect(top(), AppPaths.customerOrderEdit(orderOne));

      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      orders.answer = customerOrderJson(note: 'Ertalab');
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits, hasLength(1));
      expect(tester.takeException(), isNull);
      expect(top(), AppPaths.customerOrder(orderOne));
      expect(byKey('order-status'), findsOneWidget);
      expect(
        byKey('edit-banner'),
        findsNothing,
        reason: 'an editor opened by its address says nothing on the order',
      );
    });

    testWidgets('an order gone meanwhile is said so, not edited', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      orders
        ..failure = const ApiRefusal(
          ApiError(status: 404, code: 'resource_not_found'),
        )
        ..rows = <Map<String, Object?>>[];
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');

      await tapAndSettle(tester, byKey('edit-save'));

      expect(byKey('order-editor'), findsNothing);
      expect(find.text(l10n(tester).errorNotFound), findsOneWidget);
    });

    testWidgets(
      'a reload that failed is said so, and retried, never the old form',
      (WidgetTester tester) async {
        await open(tester, at: AppPaths.customerOrderEdit(orderOne));
        orders
          ..failure = const ApiRefusal(
            ApiError(status: 409, code: 'order_editing_locked'),
          )
          ..loadFailure = const NetworkFailure()
          ..rows = <Map<String, Object?>>[
            customerOrderJson(status: 'shopping', changeable: false),
          ];
        await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');

        await tapAndSettle(tester, byKey('edit-save'));
        expect(byKey('order-editor'), findsNothing);
        expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

        await tester.tap(byKey('retry-load'));
        await tester.pump();
        expect(byKey('order-editor'), findsNothing, reason: 'not the old form');
        expect(byKey('retry-load'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();
        expect(byKey('edit-locked'), findsOneWidget);
        expect(find.text('Yetkazish istagi: «Ertalab»'), findsOneWidget);
      },
    );

    testWidgets('a quantity changed alone is sent', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tapAndSettle(tester, byKey('line-qty-$lineTomato'));
      await tester.enterText(byKey('line-quantity'), '1,75');
      await tapAndSettle(tester, byKey('quantity-done'));
      expect(
        find.descendant(
          of: byKey('edit-line-$lineTomato'),
          matching: find.text('1,75 ${l10n(tester).unitKg}'),
        ),
        findsOneWidget,
      );
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      expect(orders.edits.single.$2.first.quantity, '1.75');
      expect(orders.edits.single.$2, hasLength(2));
    });

    testWidgets('the plus and the minus step by the unit', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
      await tapAndSettle(tester, byKey('line-plus-$lineBread'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      expect(
        orders.edits.single.$2.map((OrderEditLine l) => l.quantity),
        <String>['1', '3'],
      );
    });

    testWidgets('a rule changed alone is sent', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
      await tapAndSettle(
        tester,
        byKey('substitution-contact_before_substitution'),
      );
      await tapAndSettle(tester, byKey('edit-options-done'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));
      expect(
        orders.edits.single.$2.first.substitutionPolicy,
        SubstitutionPolicy.contactBefore,
      );
      expect(orders.edits.single.$2, hasLength(2));
    });

    testWidgets('a note changed alone is sent, trimmed', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      await tester.enterText(byKey('line-note'), '  Yangi  ');
      await tapAndSettle(tester, byKey('edit-options-done'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits.single.$2[1].customerNote, 'Yangi');
    });

    testWidgets('the options sheet applies only on "Готово"', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      await tester.enterText(byKey('line-note'), 'Yangi');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('edit-options-done'), findsNothing, reason: 'closed');
      expect(find.text('Yangi'), findsNothing);

      orders.answer = customerOrderJson();
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits.single.$2[1].customerNote, isNull);
    });

    testWidgets('the sheet refuses a quantity of 0 and stays open', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
      await tester.enterText(byKey('line-quantity'), '0');
      await tapAndSettle(tester, byKey('edit-options-done'));

      expect(find.text(l10n(tester).cartQuantityFraction), findsOneWidget);
      expect(byKey('edit-options-done'), findsOneWidget);
    });

    testWidgets('the sheet answers its quantity, note and rule', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      await tester.enterText(byKey('line-quantity'), '5');
      await tester.enterText(byKey('line-note'), 'Yangi');
      await tapAndSettle(tester, byKey('substitution-remove_if_unavailable'));
      await tapAndSettle(tester, byKey('edit-options-done'));
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));

      final OrderEditLine bread = orders.edits.single.$2[1];
      expect(bread.quantity, '5');
      expect(bread.customerNote, 'Yangi');
      expect(bread.substitutionPolicy, SubstitutionPolicy.removeIfUnavailable);
    });

    testWidgets('the minus at the minimum removes the line', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(quantity: '1'),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
            ),
          ],
        ),
      ];
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));

      Finder bin(String line) => find.descendant(
        of: byKey('line-minus-$line'),
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(bin(lineTomato), findsNothing, reason: '1 kg steps down to 0,5');
      await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
      expect(bin(lineTomato), findsOneWidget, reason: '0,5 kg is the minimum');
      expect(bin(lineBread), findsNothing);

      await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
      expect(byKey('line-minus-$lineTomato'), findsNothing);
      expect(
        find.descendant(
          of: byKey('edit-restore-$lineTomato'),
          matching: find.text(l10n(tester).orderEditKeepLine),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('edit-restore-$lineTomato'));
      expect(byKey('line-minus-$lineTomato'), findsOneWidget, reason: 'kept');
    });

    testWidgets('a line taken out is not sent', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await removeLine(tester, lineTomato);

      expect(byKey('edit-removed-$lineTomato'), findsOneWidget);
      expect(byKey('edit-options-$lineTomato'), findsNothing);
      expect(byKey('line-plus-$lineTomato'), findsNothing);
      orders.answer = customerOrderJson();
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits.single.$2.single.productId, productBread);
    });

    testWidgets('only an estimate price carries "≈" in the editor', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
            ),
          ],
        ),
      ];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );

      final AppLocalizations words = l10n(tester);
      String sum(int amount) => MoneyFormat.uzs(amount, AppLanguage.ru);
      Finder inLine(String id, String text) => find.descendant(
        of: byKey('edit-line-$id'),
        matching: find.text(text),
      );
      expect(
        inLine(
          lineTomato,
          words.cartLineEstimate(
            words.catalogPricePerUnit(sum(18400), words.unitKg),
          ),
        ),
        findsOneWidget,
      );
      expect(
        inLine(lineTomato, words.cartLineEstimate(sum(27600))),
        findsOneWidget,
      );
      expect(
        inLine(
          lineBread,
          words.catalogPricePerUnit(sum(4000), words.unitPiece),
        ),
        findsOneWidget,
      );
      expect(inLine(lineBread, sum(8000)), findsOneWidget);
    });

    testWidgets('a line without a quantity leaves the goods unsummed', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            // A piece line holding half a piece: no quantity the unit takes.
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '1.500',
            ),
          ],
        ),
      ];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );

      expect(tester.widget<Text>(byKey('edit-goods')).data, '—');
      expect(find.text('Товары (2)'), findsOneWidget);
    });

    testWidgets(
      'a line shows its own price per unit and the note and rule in its options row',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(
            lines: <Object?>[
              orderLineJson(
                note: 'Pishgan',
                patch: <String, Object?>{
                  'substitution_policy': 'remove_if_unavailable',
                },
              ),
            ],
          ),
        ];
        await open(tester, at: AppPaths.customerOrderEdit(orderOne));

        final AppLocalizations words = l10n(tester);
        final Finder tomato = byKey('edit-line-$lineTomato');
        expect(
          find.descendant(
            of: tomato,
            matching: find.text(
              words.cartLineEstimate(
                words.catalogPricePerUnit(
                  MoneyFormat.uzs(18400, AppLanguage.uz),
                  words.unitKg,
                ),
              ),
            ),
          ),
          findsOneWidget,
        );
        // The note and the rule stand in the options row, one line.
        expect(
          find.descendant(
            of: byKey('edit-options-$lineTomato'),
            matching: find.text(
              '«Pishgan» · ${ruleShort(words, SubstitutionPolicy.removeIfUnavailable)}',
            ),
          ),
          findsOneWidget,
        );
        expect(byKey('line-rule-$lineTomato'), findsNothing);
        expect(byKey('line-note-$lineTomato'), findsNothing);
      },
    );

    testWidgets('a wish longer than 160 characters is refused before sending', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tester.enterText(byKey('edit-delivery-wish'), 'a' * 161);
      await tapAndSettle(tester, byKey('edit-save'));

      expect(find.text(l10n(tester).fieldTooLong(160)), findsOneWidget);
      expect(orders.edits, isEmpty);

      await tester.enterText(
        byKey('edit-delivery-wish'),
        '  ${'a' * 160}\u0085',
      );
      orders.answer = customerOrderJson(note: 'a' * 160);
      await tapAndSettle(tester, byKey('edit-save'));
      expect(
        orders.edits.single.$3,
        'a' * 160,
        reason: 'trimmed as the server',
      );
    });

    testWidgets('one save at a time', (WidgetTester tester) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      await tester.pump();
      final Completer<void> hold = Completer<void>();
      orders
        ..hold = hold
        ..answer = customerOrderJson(note: 'Ertalab');

      await tester.tap(byKey('edit-save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);
      orders.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(orders.edits, hasLength(1));
    });
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'an order and its editor fit a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          at: AppPaths.customerOrder(orderOne),
          size: const Size(320, 640),
          textScale: 2,
          device: language,
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('order-edit'));
        expect(byKey('order-editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
        expect(byKey('edit-options-done'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('the lines of the editor', () {
    testWidgets('at large text a line keeps its sum whole over the stepper', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            // 12 kg at 123 400: a sum too wide to stand beside the stepper.
            orderLineJson(
              quantity: '12.000',
              patch: <String, Object?>{'customer_unit_price_uzs': 123400},
            ),
          ],
        ),
      ];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        size: const Size(360, 800),
        scaler: const NonlinearTextScaler(2),
        device: const Locale('ru'),
      );

      final Finder sum = byKey('edit-sum-$lineTomato');
      expect(tester.takeException(), isNull);
      expect(
        find.ancestor(of: sum, matching: find.byType(FittedBox)),
        findsNothing,
        reason: 'the sum is not shrunk to fit',
      );
      expect(
        tester.getRect(sum).width,
        tester.getSize(sum).width,
        reason: 'it is drawn at its full size',
      );
      expect(
        tester.getTopLeft(byKey('line-minus-$lineTomato')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(sum).dy),
        reason: 'the stepper stands under the sum',
      );
    });

    testWidgets('a removed line reads as removed and offers Вернуть', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );
      await removeLine(tester, lineTomato);

      expect(byKey('edit-removed-$lineTomato'), findsOneWidget);
      expect(
        tester.getSemantics(byKey('edit-line-$lineTomato')).label,
        'Помидоры — убрали из заказа',
      );
      final Finder restore = byKey('edit-restore-$lineTomato');
      expect(
        find.descendant(of: restore, matching: find.text('Вернуть')),
        findsOneWidget,
      );
      expect(tester.getSize(restore).height, 44);
      handle.dispose();
    });

    testWidgets('a removed line folds to its compact row with Вернуть', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );
      Finder fold() => find
          .ancestor(
            of: byKey('edit-line-$lineTomato'),
            matching: find.byType(AnimatedSize),
          )
          .first;
      final double full = tester.getSize(fold()).height;

      await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
      await tester.tap(byKey('edit-remove-$lineTomato'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final double mid = tester.getSize(fold()).height;
      await tester.pumpAndSettle();
      final double compact = tester.getSize(fold()).height;

      expect(compact, lessThan(full));
      expect(mid, inExclusiveRange(compact, full), reason: 'on its way');
      expect(tester.getSize(byKey('edit-removed-$lineTomato')).height, 44);
      expect(tester.getSize(byKey('edit-restore-$lineTomato')).height, 44);
      expect(byKey('line-plus-$lineTomato'), findsNothing);
      expect(byKey('edit-options-$lineTomato'), findsNothing);
    });

    testWidgets('with reduced motion a removed line takes its row at once', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tapAndSettle(tester, byKey('edit-options-$lineTomato'));
      await tester.tap(byKey('edit-remove-$lineTomato'));
      await tester.pump();

      Finder fade() => find
          .ancestor(
            of: byKey('edit-removed-$lineTomato'),
            matching: find.byType(Opacity),
          )
          .first;
      expect(tester.widget<Opacity>(fade()).opacity, closeTo(0.35, 0.01));
      await tester.pump(const Duration(milliseconds: 220));
      expect(tester.widget<Opacity>(fade()).opacity, 1);
    });

    testWidgets('Вернуть brings the line back at its price', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );
      final AppLocalizations words = l10n(tester);
      final String sum = words.cartLineEstimate(
        MoneyFormat.uzs(27600, AppLanguage.ru),
      );
      await removeLine(tester, lineTomato);
      expect(byKey('edit-sum-$lineTomato'), findsNothing);

      await tapAndSettle(tester, byKey('edit-restore-$lineTomato'));

      expect(byKey('edit-removed-$lineTomato'), findsNothing);
      expect(tester.widget<Text>(byKey('edit-sum-$lineTomato')).data, sum);
      expect(find.text('Товары (2)'), findsOneWidget);
    });

    testWidgets('a removal buzzes lightly, a restore does not', (
      WidgetTester tester,
    ) async {
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
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(quantity: '0.500'),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
            ),
          ],
        ),
      ];
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      expect(haptics, isEmpty);

      await removeLine(tester, lineBread);
      expect(haptics, <String>['HapticFeedbackType.lightImpact']);

      await tapAndSettle(tester, byKey('edit-restore-$lineBread'));
      expect(haptics, hasLength(1), reason: 'a restore is silent');

      await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
      expect(byKey('edit-removed-$lineTomato'), findsOneWidget);
      expect(haptics, hasLength(2), reason: 'the minus at the minimum');
    });

    testWidgets(
      'each line has a Комментарий · замена похожим row that opens its sheet',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(
            lines: <Object?>[
              orderLineJson(note: 'Твёрдые, для салата'),
              orderLineJson(
                id: lineBread,
                productId: productBread,
                unit: 'piece',
                quantity: '2',
              ),
            ],
          ),
        ];
        await open(
          tester,
          at: AppPaths.customerOrderEdit(orderOne),
          device: const Locale('ru'),
        );

        Finder words(String line, String text) => find.descendant(
          of: byKey('edit-options-$line'),
          matching: find.text(text),
        );
        expect(
          words(lineTomato, '«Твёрдые, для салата» · замена похожим'),
          findsOneWidget,
        );
        expect(
          words(lineBread, 'Комментарий · замена похожим'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: byKey('edit-options-$lineBread'),
            matching: find.byIcon(Icons.edit_note),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: byKey('edit-options-$lineBread'),
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(byKey('edit-options-$lineBread')).height, 44);

        await tapAndSettle(tester, byKey('edit-options-$lineBread'));
        expect(byKey('edit-options-done'), findsOneWidget);
      },
    );

    testWidgets('the top of a line takes no tap, its quantity does', (
      WidgetTester tester,
    ) async {
      await open(tester, at: AppPaths.customerOrderEdit(orderOne));
      await tester.tap(find.text('Pomidor'));
      await tester.pumpAndSettle();
      expect(byKey('edit-options-done'), findsNothing);

      await tapAndSettle(tester, byKey('line-qty-$lineTomato'));
      expect(byKey('line-quantity'), findsOneWidget, reason: 'its sheet');
    });

    testWidgets('the line sheet has × Отмена and Готово', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );
      final Finder cancel = find.byTooltip('Отмена');

      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      expect(cancel, findsOneWidget);
      expect(tester.getSize(cancel).height, greaterThanOrEqualTo(44));
      expect(
        find.descendant(
          of: byKey('edit-options-done'),
          matching: find.text('Готово'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('edit-options-done'),
          matching: find.text('Сохранить'),
        ),
        findsNothing,
      );

      // × changes nothing.
      await tester.enterText(byKey('line-note'), 'Мягкий');
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(byKey('edit-options-done'), findsNothing);
      expect(
        find.descendant(
          of: byKey('edit-options-$lineBread'),
          matching: find.text('Комментарий · замена похожим'),
        ),
        findsOneWidget,
      );

      // «Готово» applies.
      await tapAndSettle(tester, byKey('edit-options-$lineBread'));
      await tester.enterText(byKey('line-note'), 'Мягкий');
      await tapAndSettle(tester, byKey('edit-options-done'));
      expect(
        find.descendant(
          of: byKey('edit-options-$lineBread'),
          matching: find.text('«Мягкий» · замена похожим'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the options row starts under the name at normal size', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(note: 'Твёрдые, для салата, не слишком спелые'),
          ],
        ),
      ];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        size: const Size(360, 800),
        device: const Locale('ru'),
      );
      final Finder words = find.descendant(
        of: byKey('edit-options-$lineTomato'),
        matching: find.byType(Text),
      );

      expect(
        tester
            .getTopLeft(
              find.descendant(
                of: byKey('edit-options-$lineTomato'),
                matching: find.byIcon(Icons.edit_note),
              ),
            )
            .dx,
        20 + 68,
      );
      expect(tester.widget<Text>(words).maxLines, 1);
      expect(tester.widget<Text>(words).overflow, TextOverflow.ellipsis);
    });

    testWidgets('at large text the options row wraps from the start', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(note: 'Qattiq, salat uchun, juda ham pishmagan'),
          ],
        ),
      ];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        size: const Size(360, 800),
        scaler: const NonlinearTextScaler(2),
      );
      final Finder words = find.descendant(
        of: byKey('edit-options-$lineTomato'),
        matching: find.byType(Text),
      );

      expect(
        tester
            .getTopLeft(
              find.descendant(
                of: byKey('edit-options-$lineTomato'),
                matching: find.byIcon(Icons.edit_note),
              ),
            )
            .dx,
        20,
        reason: 'from the start at large text',
      );
      expect(tester.widget<Text>(words).maxLines, isNull);
      expect(
        tester.getSize(words).height,
        greaterThan(2 * 13 * 1.5),
        reason: 'the words wrap onto lines',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a kept line reads its name, quantity and sum and names its actions',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await open(
          tester,
          at: AppPaths.customerOrderEdit(orderOne),
          device: const Locale('ru'),
        );
        final AppLocalizations words = l10n(tester);
        final String sum = words.cartLineEstimate(
          MoneyFormat.uzs(27600, AppLanguage.ru),
        );

        final SemanticsNode line = tester.getSemantics(
          byKey('edit-line-$lineTomato'),
        );
        expect(line.label, 'Помидоры, 1,5 кг, $sum');
        // The name, the price and the sum are not read again one by one.
        expect(find.bySemanticsLabel('Помидоры'), findsNothing);
        // The options row and the stepper's buttons are its own actions.
        final SemanticsNode options = tester.getSemantics(
          byKey('edit-options-$lineTomato'),
        );
        expect(
          options.label,
          'Комментарий и замена: Комментарий · замена похожим',
        );
        expect(
          options.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        for (final String button in <String>[
          'line-minus-$lineTomato',
          'line-plus-$lineTomato',
        ]) {
          expect(
            tester
                .getSemantics(byKey(button))
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isTrue,
            reason: button,
          );
        }
        handle.dispose();
      },
    );

    testWidgets('an added line reads as a new product at the current price', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        extra: catalogProduct(
          id: productMilk,
          nameUz: 'Sut',
          nameRu: 'Молоко',
          unitCode: UnitCode.piece,
          priceMode: PriceMode.fixed,
          customerUnitPriceUzs: 12000,
        ),
        device: const Locale('ru'),
      );

      expect(
        tester.getSemantics(byKey('edit-line-added-$productMilk')).label,
        'Молоко, новый товар по текущей цене, 1 шт., '
        '${MoneyFormat.uzs(12000, AppLanguage.ru)}',
      );
      expect(byKey('edit-adds-added-$productMilk'), findsOneWidget);
      handle.dispose();
    });

    for (final (String, TextScaler) scale in <(String, TextScaler)>[
      ('100 %', TextScaler.noScaling),
      ('200 %', const NonlinearTextScaler(2)),
    ]) {
      testWidgets(
        'a new, a removed and a stepped line meet the guideline at ${scale.$1}',
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          await open(
            tester,
            at: AppPaths.customerOrderEdit(orderOne),
            size: const Size(360, 2400),
            scaler: scale.$2,
            extra: catalogProduct(
              id: productMilk,
              nameUz: 'Sut',
              nameRu: 'Молоко',
              unitCode: UnitCode.piece,
              priceMode: PriceMode.fixed,
              customerUnitPriceUzs: 12000,
            ),
            device: const Locale('ru'),
          );
          await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
          await removeLine(tester, lineBread);

          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          expect(tester.takeException(), isNull);
          handle.dispose();
        },
      );
    }
  });

  group('the sums, the minimum and the save', () {
    String uzs(int amount) => MoneyFormat.uzs(amount, AppLanguage.ru);
    String est(int amount) =>
        lookupAppLocalizations(const Locale('ru'))
            .cartLineEstimate(uzs(amount));
    String textOf(WidgetTester tester, String key) =>
        tester.widget<Text>(byKey(key)).data!;
    Finder inButton(String text) =>
        find.descendant(of: byKey('edit-save'), matching: find.text(text));

    /// The preview that answers 3 kg of tomatoes: 7 000 more than before.
    Map<String, Object?> threeKilos(String id, List<OrderEditLine> lines) =>
        editPreviewJson(
          merchandise: 78000,
          total: 98000,
          before: 91000,
          change: 7000,
        );

    Future<void> openPage(
      WidgetTester tester, {
      Size size = const Size(800, 2400),
      TextScaler? scaler,
      bool alone = false,
    }) async {
      orders.rows = <Map<String, Object?>>[pageOrder()];
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        alone: alone,
        size: size,
        scaler: scaler,
        device: const Locale('ru'),
      );
    }

    /// Waits for the draft to be quiet and the server's answer.
    Future<void> answered(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
    }

    List<String> announced(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message)
        .toList();

    testWidgets(
      "the list and the footer show the order's sums before any change",
      (WidgetTester tester) async {
        await openPage(tester);

        expect(textOf(tester, 'edit-goods'), est(71000));
        expect(textOf(tester, 'edit-delivery'), uzs(15000));
        expect(textOf(tester, 'edit-fee'), uzs(5000));
        expect(textOf(tester, 'edit-total'), est(91000));
        expect(find.text('Товары (3)'), findsOneWidget);
        expect(textOf(tester, 'edit-footer-total'), est(91000));
        expect(byKey('edit-change'), findsNothing, reason: 'hidden at 0');
        expect(
          textOf(tester, 'edit-was'),
          'Доставка ${uzs(15000)} и сбор ${uzs(5000)} включены',
        );
        expect(byKey('edit-recount'), findsNothing);
        expect(orders.previewCalls, isEmpty);
      },
    );

    testWidgets(
      'a change shows the previewed delivery, fee and total, the change and Было',
      (WidgetTester tester) async {
        orders.previews = threeKilos;
        await openPage(tester);

        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);

        expect(textOf(tester, 'edit-goods'), est(78000));
        expect(textOf(tester, 'edit-delivery'), uzs(15000));
        expect(textOf(tester, 'edit-fee'), uzs(5000));
        expect(textOf(tester, 'edit-total'), est(98000));
        expect(textOf(tester, 'edit-footer-total'), est(98000));
        expect(textOf(tester, 'edit-change'), '+7 000 сум');
        expect(
          textOf(tester, 'edit-was'),
          'Было ${est(91000)} · доставка и сбор те же',
        );
        expect(orders.previewCalls, hasLength(1));
      },
    );

    testWidgets(
      'a lower total shows the change down, and a new fee says Было',
      (WidgetTester tester) async {
        orders.previews = (String id, List<OrderEditLine> lines) =>
            editPreviewJson(
              merchandise: 62000,
              deliveryFee: 12000,
              total: 79000,
              before: 91000,
              change: -12000,
            );
        await openPage(tester);

        await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
        await answered(tester);

        expect(textOf(tester, 'edit-change'), '−12 000 сум');
        expect(textOf(tester, 'edit-delivery'), uzs(12000));
        expect(textOf(tester, 'edit-was'), 'Было ${est(91000)}');
        final DecoratedBox pill = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: byKey('edit-change'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect((pill.decoration as BoxDecoration).color, KitColors.primaryWash);
      },
    );

    testWidgets('while a newer preview waits the sums stay dimmed', (
      WidgetTester tester,
    ) async {
      orders.previews = threeKilos;
      await openPage(tester);
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: byKey('edit-footer-total'),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 1);

      final Completer<void> hold = Completer<void>();
      orders.holdPreview = hold;
      await tester.tap(byKey('line-plus-$lineTomato'));
      await tester.pump(const Duration(milliseconds: 450));
      expect(opacity(), 0.45);
      expect(textOf(tester, 'edit-footer-total'), est(91000));

      orders.holdPreview = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(textOf(tester, 'edit-footer-total'), est(98000));
    });

    testWidgets('sums roll to the new answer', (WidgetTester tester) async {
      orders.previews = threeKilos;
      await openPage(tester);

      await tester.tap(byKey('line-plus-$lineTomato'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      final String between = textOf(tester, 'edit-footer-total');
      expect(between, isNot(est(91000)));
      expect(between, isNot(est(98000)));

      await tester.pump(const Duration(milliseconds: 400));
      expect(textOf(tester, 'edit-footer-total'), est(98000));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'offline the footer says the totals come after saving and the save still goes',
      (WidgetTester tester) async {
        orders.previewFailure = const NetworkFailure();
        await openPage(tester);

        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);

        expect(textOf(tester, 'edit-recount'), l10n(tester).orderEditRecount);
        expect(byKey('edit-footer-total'), findsNothing);
        expect(byKey('edit-change'), findsNothing);
        expect(textOf(tester, 'edit-goods'), '—');
        expect(textOf(tester, 'edit-total'), '—');
        expect(
          tester.widget<FilledButton>(byKey('edit-save')).onPressed,
          isNotNull,
        );

        orders.answer = pageOrder();
        await tapAndSettle(tester, byKey('edit-save'));
        expect(orders.edits.single.$2.first.quantity, '3');
      },
    );

    testWidgets(
      'a shortfall shows the strip and greys the button with the sum',
      (WidgetTester tester) async {
        orders.previews = (String id, List<OrderEditLine> lines) =>
            editPreviewJson(
              merchandise: 9000,
              total: 29000,
              before: 91000,
              change: -62000,
              minimum: 50000,
              shortfall: 41000,
            );
        await openPage(tester);
        expect(byKey('edit-minimum'), findsNothing);

        await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
        await answered(tester);

        expect(
          find.descendant(
            of: byKey('edit-minimum'),
            matching: find.text(
              'До минимальной суммы ${uzs(50000)} не хватает ${uzs(41000)}',
            ),
          ),
          findsOneWidget,
        );
        expect(inButton('Не хватает ${uzs(41000)}'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(byKey('edit-save')).onPressed,
          isNull,
        );
        expect(tester.getSize(byKey('edit-minimum-add')).height, 44);

        await tapAndSettle(tester, byKey('edit-minimum-add'));
        expect(
          GoRouter.of(anywhere(tester))
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation,
          AppPaths.customerOrderAdd(orderOne),
          reason: 'the picker opens',
        );
      },
    );

    testWidgets(
      'a save refused for the minimum shows the strip from its details',
      (WidgetTester tester) async {
        await openPage(tester);
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        orders.failure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'minimum_order_not_reached',
            details: <String, Object?>{
              'minimum_order_uzs': 50000,
              'shortfall_uzs': 41000,
            },
          ),
        );
        announced(tester);

        await tapAndSettle(tester, byKey('edit-save'));

        final String words =
            'До минимальной суммы ${uzs(50000)} не хватает ${uzs(41000)}';
        expect(
          find.descendant(
            of: byKey('edit-minimum'),
            matching: find.text(words),
          ),
          findsOneWidget,
        );
        expect(inButton('Не хватает ${uzs(41000)}'), findsOneWidget);
        expect(
          find.text(l10n(tester).errorMinimumOrderPlain),
          findsNothing,
          reason: 'the strip says it, not the red line',
        );
        expect(announced(tester), contains('Не сохранено. $words'));
      },
    );

    testWidgets('the button says Нет изменений, then Сохранить изменения (3)', (
      WidgetTester tester,
    ) async {
      await openPage(tester);
      expect(inButton('Нет изменений'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('edit-save')).onPressed, isNull);

      await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
      expect(inButton('Сохранить изменения (1)'), findsOneWidget);
      await removeLine(tester, lineBread);
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      await tester.pumpAndSettle();

      expect(inButton('Сохранить изменения (3)'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('edit-save')).onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'with no line kept the button says Оставьте хотя бы один товар',
      (WidgetTester tester) async {
        await openPage(tester);
        await removeLine(tester, lineTomato);
        await removeLine(tester, lineBread);
        await removeLine(tester, lineApple);

        expect(inButton('Оставьте хотя бы один товар'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(byKey('edit-save')).onPressed,
          isNull,
        );
        expect(byKey('edit-none-left'), findsNothing);
      },
    );

    testWidgets(
      'saving says Сохраняем…, then ✓ Сохранено, buzzes and returns with the order',
      (WidgetTester tester) async {
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
        orders.rows = <Map<String, Object?>>[pageOrder()];
        await open(tester, device: const Locale('ru'));
        final Future<CustomerOrder?> result = GoRouter.of(anywhere(tester))
            .push<CustomerOrder>(AppPaths.customerOrderEdit(orderOne));
        await tester.pumpAndSettle();
        await tester.tap(byKey('line-plus-$lineTomato'));
        await tester.pump();
        final Completer<void> hold = Completer<void>();
        orders
          ..hold = hold
          ..answer = pageOrder();
        announced(tester);
        haptics.clear();

        await tester.tap(byKey('edit-save'));
        await tester.pump();
        expect(inButton('Сохраняем…'), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('edit-save'),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(haptics, isEmpty);

        orders.hold = null;
        hold.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        expect(inButton('Сохранено'), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('edit-save'),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
        expect(haptics, <String>['HapticFeedbackType.lightImpact']);
        expect(announced(tester), <String>[
          'Заказ изменён. Итого ${est(91000)}',
        ]);

        await tester.pump(const Duration(milliseconds: 600));
        expect(byKey('order-editor'), findsOneWidget, reason: 'stands 650 ms');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(byKey('order-editor'), findsNothing);
        expect((await result)!.id, orderOne);
      },
    );

    testWidgets(
      'a product the server no longer sells is named, and Убрать takes it out',
      (WidgetTester tester) async {
        orders.previewFailure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'product_unavailable',
            details: <String, Object?>{
              'product_ids': <Object?>[productApple],
            },
          ),
        );
        await openPage(tester);
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);

        expect(
          find.descendant(
            of: byKey('edit-gone'),
            matching: find.text(
              'Яблоки: нет в продаже — уберите, чтобы сохранить',
            ),
          ),
          findsOneWidget,
        );
        expect(inButton('Сначала уберите: Яблоки'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(byKey('edit-save')).onPressed,
          isNull,
        );

        await tapAndSettle(tester, byKey('edit-gone-remove'));
        expect(byKey('edit-gone'), findsNothing);
        expect(byKey('edit-removed-$lineApple'), findsOneWidget);
      },
    );

    testWidgets(
      'a step is announced with the new total once its preview answers',
      (WidgetTester tester) async {
        orders.previews = threeKilos;
        await openPage(tester);
        announced(tester);

        await tester.tap(byKey('line-plus-$lineTomato'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          announced(tester),
          isEmpty,
          reason: 'the total is not known yet',
        );

        await answered(tester);
        expect(announced(tester), <String>[
          'Помидоры, 3 кг. Итого ${est(98000)}',
        ]);
      },
    );

    testWidgets('of quick steps only the last is announced', (
      WidgetTester tester,
    ) async {
      orders.previews = threeKilos;
      await openPage(tester);
      announced(tester);

      await tester.tap(byKey('line-plus-$lineTomato'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(byKey('line-plus-$lineTomato'));
      await answered(tester);

      expect(announced(tester), <String>[
        'Помидоры, 3,5 кг. Итого ${est(98000)}',
      ]);
    });

    testWidgets('a removal and a restore are announced with the total', (
      WidgetTester tester,
    ) async {
      await openPage(tester);
      announced(tester);

      await removeLine(tester, lineBread);
      await answered(tester);
      expect(announced(tester), <String>[
        'Хлеб — убрали из заказа. Итого ${est(91000)}',
      ]);

      await tapAndSettle(tester, byKey('edit-restore-$lineBread'));
      expect(announced(tester), <String>[
        'Хлеб снова в заказе. Итого ${est(91000)}',
      ]);
    });

    testWidgets('a failed preview leaves the change to be said alone', (
      WidgetTester tester,
    ) async {
      orders.previewFailure = const NetworkFailure();
      await openPage(tester);
      announced(tester);

      await removeLine(tester, lineBread);
      await answered(tester);

      expect(announced(tester), <String>['Хлеб — убрали из заказа']);
    });

    for (final (String, TextScaler) scale in <(String, TextScaler)>[
      ('100 %', TextScaler.noScaling),
      ('200 %', const NonlinearTextScaler(2)),
    ]) {
      testWidgets(
        'every button state and both strips meet the guideline at ${scale.$1}',
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          orders.previews = (String id, List<OrderEditLine> lines) =>
              editPreviewJson(
                merchandise: 9000,
                total: 29000,
                before: 91000,
                change: -62000,
                minimum: 50000,
                shortfall: 41000,
              );
          await openPage(tester, size: const Size(360, 2400), scaler: scale.$2);
          expect(inButton('Нет изменений'), findsOneWidget);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

          await tapAndSettle(tester, byKey('line-minus-$lineTomato'));
          await answered(tester);
          expect(byKey('edit-minimum'), findsOneWidget);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

          orders.previewFailure = const ApiRefusal(
            ApiError(
              status: 409,
              code: 'product_unavailable',
              details: <String, Object?>{
                'product_ids': <Object?>[productApple],
              },
            ),
          );
          await tapAndSettle(tester, byKey('line-plus-$lineBread'));
          await answered(tester);
          expect(byKey('edit-gone'), findsOneWidget);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

          await tapAndSettle(tester, byKey('edit-gone-remove'));
          await removeLine(tester, lineTomato);
          await removeLine(tester, lineBread);
          expect(inButton('Оставьте хотя бы один товар'), findsOneWidget);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          expect(tester.takeException(), isNull);
          handle.dispose();
        },
      );
    }

    testWidgets(
      'at 200 % on 360 dp the footer total, its pill and Было do not overflow',
      (WidgetTester tester) async {
        orders.previews = threeKilos;
        await openPage(
          tester,
          size: const Size(360, 800),
          scaler: const NonlinearTextScaler(2),
        );
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);

        expect(tester.takeException(), isNull);
        for (final String key in <String>[
          'edit-footer-total',
          'edit-change',
          'edit-was',
          'edit-save',
        ]) {
          final Rect box = tester.getRect(byKey(key));
          expect(box.left, greaterThanOrEqualTo(0), reason: key);
          expect(box.right, lessThanOrEqualTo(360), reason: key);
        }
      },
    );
  });

  group('leaving and refusals', () {
    const String phone = '+998712000000';

    Finder inButton(String text) =>
        find.descendant(of: byKey('edit-save'), matching: find.text(text));

    List<String> announced(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message)
        .toList();

    Future<void> answered(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
    }

    /// The editor opened over the order, in Russian.
    Future<void> openEditor(
      WidgetTester tester, {
      Map<String, Object?>? order,
      Size size = const Size(800, 2400),
      TextScaler? scaler,
      FakePhoneCalls? phoneCalls,
    }) async {
      orders.rows = <Map<String, Object?>>[order ?? pageOrder()];
      await open(
        tester,
        at: AppPaths.customerOrder(orderOne),
        size: size,
        scaler: scaler,
        device: const Locale('ru'),
        phoneCalls: phoneCalls,
      );
      await tapAndSettle(tester, byKey('order-edit'));
      expect(byKey('order-editor'), findsOneWidget);
    }

    /// Two changes: the flatbread out, the tomatoes from 2,5 to 3 kg.
    Future<void> twoChanges(WidgetTester tester) async {
      await removeLine(tester, lineBread);
      await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
      await answered(tester);
    }

    testWidgets('with changes × asks before leaving', (
      WidgetTester tester,
    ) async {
      await openEditor(tester);
      await twoChanges(tester);

      await tapAndSettle(tester, byKey('edit-close'));

      expect(byKey('edit-leave-sheet'), findsOneWidget);
      expect(byKey('order-editor'), findsOneWidget, reason: 'still here');
      for (final String text in <String>[
        'Выйти без сохранения?',
        'Не сохранятся 2 изменения:',
        '− Хлеб',
        'Помидоры: 2,5 кг → 3 кг',
        'Продолжить изменять',
        'Выйти без сохранения',
      ]) {
        expect(
          find.descendant(
            of: byKey('edit-leave-sheet'),
            matching: find.text(text),
          ),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets(
      'Продолжить изменять keeps the edits, Выйти без сохранения leaves',
      (WidgetTester tester) async {
        await openEditor(tester);
        await twoChanges(tester);

        await tapAndSettle(tester, byKey('edit-close'));
        await tapAndSettle(tester, byKey('edit-keep-editing'));
        expect(byKey('edit-leave-sheet'), findsNothing);
        expect(byKey('edit-removed-$lineBread'), findsOneWidget);
        expect(inButton('Сохранить изменения (2)'), findsOneWidget);

        await tapAndSettle(tester, byKey('edit-close'));
        await tapAndSettle(tester, byKey('edit-leave'));
        expect(byKey('order-editor'), findsNothing);
        expect(byKey('order-edit'), findsOneWidget, reason: 'the order');
        expect(orders.edits, isEmpty);
      },
    );

    testWidgets('a tap outside the exit sheet keeps editing', (
      WidgetTester tester,
    ) async {
      await openEditor(tester);
      await twoChanges(tester);
      await tapAndSettle(tester, byKey('edit-close'));

      await tester.tapAt(const Offset(400, 40));
      await tester.pumpAndSettle();

      expect(byKey('edit-leave-sheet'), findsNothing);
      expect(byKey('order-editor'), findsOneWidget);
    });

    testWidgets('system back asks too', (WidgetTester tester) async {
      await openEditor(tester);
      await twoChanges(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('edit-leave-sheet'), findsOneWidget);
      expect(byKey('order-editor'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('edit-leave-sheet'), findsNothing, reason: 'back keeps');
      expect(byKey('order-editor'), findsOneWidget);
    });

    testWidgets('without changes × and back leave at once', (
      WidgetTester tester,
    ) async {
      await openEditor(tester);
      await tapAndSettle(tester, byKey('edit-close'));
      expect(byKey('edit-leave-sheet'), findsNothing);
      expect(byKey('order-editor'), findsNothing);

      await tapAndSettle(tester, byKey('order-edit'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('order-editor'), findsNothing);
    });

    testWidgets('a quantity to be set anew alone does not hold the editor', (
      WidgetTester tester,
    ) async {
      await openEditor(
        tester,
        order: customerOrderJson(
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
      );

      await tapAndSettle(tester, byKey('edit-close'));

      expect(byKey('edit-leave-sheet'), findsNothing);
      expect(byKey('order-editor'), findsNothing);
    });

    testWidgets(
      'a Shopper assigned shows the amber note, a new order the green one',
      (WidgetTester tester) async {
        await openEditor(tester, order: pageOrder(status: 'shopping_assigned'));
        expect(
          tester.widget<Text>(byKey('edit-info')).data,
          'Сборщик уже назначен и скоро начнёт покупать — после этого '
          'заказ не изменить. Сохраните изменения сразу. Цена товаров, '
          'что уже в заказе, не меняется.',
        );
        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsNothing);
        final BoxDecoration amber =
            tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: byKey('edit-info'),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(amber.color, KitColors.warningWash);
      },
    );

    testWidgets('a new order shows the green note', (
      WidgetTester tester,
    ) async {
      await openEditor(tester);
      expect(find.text(l10n(tester).orderEditInfo), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    /// The order a refusal because shopping started reloads.
    Map<String, Object?> shopping({String? supportPhone = phone}) => pageOrder(
      status: 'shopping',
      changeable: false,
      supportPhone: supportPhone,
    );

    const ApiRefusal locked = ApiRefusal(
      ApiError(status: 409, code: 'order_editing_locked'),
    );

    testWidgets('a refusal because shopping started shows what did not save', (
      WidgetTester tester,
    ) async {
      final FakePhoneCalls calls = FakePhoneCalls();
      await openEditor(
        tester,
        order: pageOrder(supportPhone: phone),
        phoneCalls: calls,
      );
      await twoChanges(tester);
      orders
        ..failure = locked
        ..rows = <Map<String, Object?>>[shopping()];
      announced(tester);

      await tapAndSettle(tester, byKey('edit-save'));

      expect(byKey('edit-locked'), findsOneWidget);
      expect(byKey('edit-closed'), findsNothing);
      expect(byKey('order-editor'), findsNothing);
      for (final String text in <String>[
        'Сборщик уже начал покупать',
        'Изменения не сохранились — заказ остался прежним. '
            'Если что-то важно, позвоните в поддержку.',
        'Что не сохранилось',
        '− Хлеб',
        'Помидоры: 2,5 кг → 3 кг',
        'Позвонить в поддержку',
        'Открыть заказ',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(announced(tester), <String>[
        'Не сохранено: Сборщик уже начал покупать. '
            'Не сохранилось изменений: 2',
      ]);

      await tapAndSettle(tester, byKey('edit-call-support'));
      expect(calls.calls, <String>[phone]);

      await tapAndSettle(tester, byKey('edit-back-to-order'));
      expect(byKey('edit-locked'), findsNothing);
      expect(find.text(l10n(tester).orderStateShopping), findsOneWidget);
    });

    testWidgets(
      'without a support phone the lock view offers only Открыть заказ',
      (WidgetTester tester) async {
        await openEditor(tester);
        await twoChanges(tester);
        orders
          ..failure = locked
          ..rows = <Map<String, Object?>>[shopping(supportPhone: null)];

        await tapAndSettle(tester, byKey('edit-save'));

        expect(byKey('edit-locked'), findsOneWidget);
        expect(byKey('edit-call-support'), findsNothing);
        expect(find.text('Позвонить в поддержку'), findsNothing);
        expect(
          find.text('Изменения не сохранились — заказ остался прежним.'),
          findsOneWidget,
        );
        expect(byKey('edit-back-to-order'), findsOneWidget);
      },
    );

    testWidgets("a cancelled order's lock view says Заказ отменён", (
      WidgetTester tester,
    ) async {
      await openEditor(tester);
      await twoChanges(tester);
      orders
        ..failure = locked
        ..rows = <Map<String, Object?>>[
          pageOrder(status: 'cancelled', changeable: false),
        ];

      await tapAndSettle(tester, byKey('edit-save'));

      expect(byKey('edit-locked'), findsOneWidget);
      expect(find.text('Заказ отменён'), findsOneWidget);
      expect(find.text('Сборщик уже начал покупать'), findsNothing);
    });

    testWidgets('a preview that finds the order locked shows the lock view', (
      WidgetTester tester,
    ) async {
      await openEditor(tester, order: pageOrder(supportPhone: phone));
      await removeLine(tester, lineBread);
      orders
        ..previewFailure = locked
        ..rows = <Map<String, Object?>>[shopping()];
      announced(tester);

      await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
      await answered(tester);

      expect(byKey('edit-locked'), findsOneWidget);
      expect(find.text('− Хлеб'), findsOneWidget);
      expect(find.text('Помидоры: 2,5 кг → 3 кг'), findsOneWidget);
      expect(announced(tester), <String>[
        'Не сохранено: Сборщик уже начал покупать. '
            'Не сохранилось изменений: 2',
      ]);
    });

    testWidgets('a save refused for another reason keeps the editor', (
      WidgetTester tester,
    ) async {
      await openEditor(tester);
      await twoChanges(tester);
      orders.failure = const NetworkFailure();

      await tapAndSettle(tester, byKey('edit-save'));

      expect(byKey('edit-locked'), findsNothing);
      expect(byKey('order-editor'), findsOneWidget);
      expect(inButton('Сохранить изменения (2)'), findsOneWidget);
    });

    ApiRefusal gone(List<String> ids) => ApiRefusal(
      ApiError(
        status: 409,
        code: 'product_unavailable',
        details: <String, Object?>{'product_ids': ids},
      ),
    );

    testWidgets(
      'a product no longer sold is framed red with Убрать, and the footer '
      'strip too',
      (WidgetTester tester) async {
        await openEditor(tester);
        orders.previewFailure = gone(<String>[productApple]);
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);

        expect(byKey('edit-marked-$lineApple'), findsOneWidget);
        expect(byKey('edit-marked-$lineTomato'), findsNothing);
        expect(
          find.descendant(
            of: byKey('edit-line-$lineApple'),
            matching: find.text('Сейчас нет в продаже'),
          ),
          findsOneWidget,
        );
        final BoxDecoration frame =
            tester
                    .widget<DecoratedBox>(byKey('edit-marked-$lineApple'))
                    .decoration
                as BoxDecoration;
        expect(frame.border!.top.color, KitColors.danger);
        expect(frame.border!.top.width, 1.5);
        expect(byKey('edit-gone'), findsOneWidget);
        expect(byKey('edit-marked-remove-$lineApple'), findsOneWidget);

        await tapAndSettle(tester, byKey('edit-marked-remove-$lineApple'));
        expect(byKey('edit-marked-$lineApple'), findsNothing);
        expect(byKey('edit-removed-$lineApple'), findsOneWidget);
        expect(byKey('edit-gone'), findsNothing);
      },
    );

    testWidgets(
      'a save refused for it scrolls to the line and flashes it red',
      (WidgetTester tester) async {
        await openEditor(tester, size: const Size(360, 440));
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);
        final Rect view = tester.getRect(byKey('order-editor'));
        expect(
          tester.getRect(byKey('edit-line-$lineApple')).top,
          greaterThan(view.bottom),
          reason: 'the apples are below the fold',
        );
        orders.failure = gone(<String>[productApple]);
        announced(tester);

        await tester.tap(byKey('edit-save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final LineFlash flash = tester.widget<LineFlash>(
          find.ancestor(
            of: byKey('edit-line-$lineApple'),
            matching: find.byType(LineFlash),
          ),
        );
        expect(flash.flash, 1);
        expect(flash.color, KitColors.dangerWash);
        await tester.pumpAndSettle();

        expect(
          tester.getRect(byKey('edit-marked-$lineApple')).top,
          lessThan(view.bottom),
        );
        expect(byKey('edit-marked-remove-$lineApple'), findsOneWidget);
        expect(announced(tester), <String>[
          'Не сохранено. Яблоки: нет в продаже — уберите, чтобы сохранить',
        ]);
        expect(byKey('edit-locked'), findsNothing);
        expect(inButton('Сначала уберите: Яблоки'), findsOneWidget);
      },
    );

    testWidgets(
      'Убрать in the strip removes every marked product and the button '
      'comes back',
      (WidgetTester tester) async {
        await openEditor(tester);
        orders.previewFailure = gone(<String>[productApple, productBread]);
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);
        expect(inButton('Сначала уберите: Хлеб и ещё 1'), findsOneWidget);

        await tapAndSettle(tester, byKey('edit-gone-remove'));
        await answered(tester);

        expect(byKey('edit-gone'), findsNothing);
        expect(byKey('edit-removed-$lineApple'), findsOneWidget);
        expect(byKey('edit-removed-$lineBread'), findsOneWidget);
        expect(inButton('Сохранить изменения (3)'), findsOneWidget);
      },
    );

    for (final (String, TextScaler) scale in <(String, TextScaler)>[
      ('100 %', TextScaler.noScaling),
      ('200 %', const NonlinearTextScaler(2)),
    ]) {
      testWidgets('the exit sheet, the lock view and a marked line meet the '
          'guideline at ${scale.$1}', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await openEditor(
          tester,
          order: pageOrder(supportPhone: phone),
          size: const Size(360, 800),
          scaler: scale.$2,
        );
        orders.previewFailure = gone(<String>[productApple]);
        await tapAndSettle(tester, byKey('line-plus-$lineTomato'));
        await answered(tester);
        expect(byKey('edit-marked-$lineApple'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await tapAndSettle(tester, byKey('edit-close'));
        expect(byKey('edit-leave-sheet'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await tapAndSettle(tester, byKey('edit-keep-editing'));

        await tapAndSettle(tester, byKey('edit-gone-remove'));
        await answered(tester);
        orders
          ..failure = locked
          ..rows = <Map<String, Object?>>[shopping()];
        await tapAndSettle(tester, byKey('edit-save'));
        expect(byKey('edit-locked'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }
  });
}
