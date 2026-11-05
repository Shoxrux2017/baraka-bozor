import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
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
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

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

        await tapAndSettle(tester, byKey('edit-save'));
        expect(orders.edits, isEmpty, reason: 'nothing changed');
        expect(byKey('order-editor'), findsNothing);

        await tapAndSettle(tester, byKey('order-edit'));
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
      await tapAndSettle(tester, byKey('edit-save'));

      expect(byKey('edit-none-left'), findsOneWidget);
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

        expect(byKey('edit-closed'), findsOneWidget);
        expect(find.text(l10n(tester).orderEditClosed), findsOneWidget);
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
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits, isEmpty, reason: 'nothing changed');
      expect(top(), AppPaths.customerOrder(orderOne));

      GoRouter.of(anywhere(tester)).go(AppPaths.customerOrderEdit(orderOne));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('edit-delivery-wish'), 'Ertalab');
      orders.answer = customerOrderJson(note: 'Ertalab');
      await tapAndSettle(tester, byKey('edit-save'));
      expect(orders.edits, hasLength(1));
      expect(tester.takeException(), isNull);
      expect(top(), AppPaths.customerOrder(orderOne));
      expect(byKey('order-status'), findsOneWidget);
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
        expect(byKey('edit-closed'), findsOneWidget);
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

    testWidgets(
      'the editor shows the goods preview and no delivery, fee or total',
      (WidgetTester tester) async {
        String id(int i) => '0192f0a0-0000-7000-8000-00000000c10$i';
        orders.rows = <Map<String, Object?>>[
          customerOrderJson(
            lines: <Object?>[
              // 1,5 kg at 18 400, 2 at 4 000, 3 at 4 000 and 1 at 31 400.
              orderLineJson(),
              orderLineJson(
                id: lineBread,
                productId: productBread,
                unit: 'piece',
                quantity: '2',
              ),
              orderLineJson(
                id: id(1),
                productId: id(2),
                unit: 'piece',
                quantity: '3',
              ),
              orderLineJson(
                id: id(3),
                productId: id(4),
                unit: 'piece',
                quantity: '1',
                patch: <String, Object?>{'customer_unit_price_uzs': 31400},
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
        String estimate(int amount) =>
            words.cartLineEstimate(MoneyFormat.uzs(amount, AppLanguage.ru));
        expect(find.text('Товары (4)'), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('edit-line-$lineTomato'),
            matching: find.text(estimate(27600)),
          ),
          findsOneWidget,
        );
        expect(find.text(estimate(79000)), findsOneWidget);
        expect(find.text('Доставка'), findsNothing);
        expect(find.text('Сервисный сбор'), findsNothing);
        expect(find.text('Итого'), findsNothing);
        expect(
          find.text('Доставку, сбор и итог пересчитаем после сохранения'),
          findsOneWidget,
        );

        await tapAndSettle(tester, byKey('line-plus-$lineBread'));
        expect(find.text('Товары (4)'), findsOneWidget);
        expect(find.text(estimate(83000)), findsOneWidget);
        await removeLine(tester, lineBread);
        expect(find.text('Товары (3)'), findsOneWidget);
        expect(find.text(estimate(71000)), findsOneWidget);
      },
    );

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

    testWidgets('a removal and a restore are announced', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        at: AppPaths.customerOrderEdit(orderOne),
        device: const Locale('ru'),
      );
      List<String> announced() => tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .toList();
      announced();

      await removeLine(tester, lineTomato);
      expect(announced(), <String>['Помидоры — убрали из заказа']);
      await tapAndSettle(tester, byKey('edit-restore-$lineTomato'));
      expect(announced(), <String>['Помидоры снова в заказе']);
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
}
