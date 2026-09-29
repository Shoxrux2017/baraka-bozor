import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/shopper/data/shopper_orders_api.dart';
import 'package:baraka_bozor/features/shopper/domain/price_guard.dart';
import 'package:baraka_bozor/features/shopper/domain/shopper_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Shopper at the market (`docs/09` sections 30 to 35, `DL-70`) through
/// the real router, controllers and screens: buying with the typo guard,
/// asking the Customer when the server says so, a purchase and a completion
/// sent again under their key, a line not found, a replacement, and the
/// screen that follows the completion.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeShopperOrdersRepository shopper;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String money(int amount) => MoneyFormat.uzs(amount, AppLanguage.uz);

  Map<String, Object?> tomato({
    String status = 'pending',
    Map<String, Object?>? patch,
  }) => shopperLineJson(status: status, patch: patch);

  Map<String, Object?> bread({
    String status = 'pending',
    Map<String, Object?>? patch,
  }) => shopperLineJson(bread: true, status: status, patch: patch);

  ShopperOrder shopping(List<Object?> items, {String status = 'shopping'}) =>
      shopperOrder(status: status, items: items);

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(id: 's', role: UserRole.shopper);
    shopper = FakeShopperOrdersRepository(
      rows: <ShopperOrderRow>[
        ShopperOrdersApi.parseRow(
          shopperRowJson(status: 'shopping', accepted: true),
        ),
      ],
      details: <String, ShopperOrder>{
        shopperOrderA: shopping(<Object?>[tomato(), bread()]),
      },
    );
  });

  Future<void> openOrder(
    WidgetTester tester, {
    Size size = const Size(420, 1800),
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
        shopper: shopper,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('shopper-order-$shopperOrderA'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> buy(WidgetTester tester, String line, {String? price}) async {
    await tapAndSettle(tester, byKey('buy-$line'));
    if (price != null) {
      await tester.enterText(byKey('purchase-price'), price);
    }
    await tapAndSettle(tester, byKey('purchase-save'));
  }

  test('the typo guard doubts a price above three times the market price or '
      'below a third of it, and nothing in between', () {
    expect(looksMistyped(48000, 16000), isFalse);
    expect(looksMistyped(48001, 16000), isTrue);
    expect(looksMistyped(5334, 16000), isFalse);
    expect(looksMistyped(5333, 16000), isTrue);
    // Exactly a third, or exactly three times, is not doubted.
    expect(looksMistyped(5000, 15000), isFalse);
    expect(looksMistyped(45000, 15000), isFalse);
    expect(looksMistyped(16000, 16000), isFalse);

    expect(parsePrice('16 500'), 16500);
    expect(parsePrice('1000000000'), 1000000000);
    for (final String wrong in <String>['', '0', '1000000001', '12,5', 'abc']) {
      expect(parsePrice(wrong), isNull, reason: wrong);
    }
  });

  testWidgets('an open line offers buy, replace — where its policy allows — '
      'and not found; a waiting line and an order not started offer nothing', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(),
      bread(
        patch: <String, Object?>{
          'substitution_policy': 'remove_if_unavailable',
        },
      ),
    ]);
    await openOrder(tester);

    expect(byKey('buy-$shopperLineTomato'), findsOneWidget);
    expect(byKey('replace-$shopperLineTomato'), findsOneWidget);
    expect(byKey('unavailable-$shopperLineTomato'), findsOneWidget);
    expect(byKey('buy-$shopperLineBread'), findsOneWidget);
    expect(byKey('replace-$shopperLineBread'), findsNothing);

    shopper.details[shopperOrderA] = shopping(<Object?>[
      shopperAskedLineJson('price_over_tolerance'),
      bread(status: 'purchased'),
    ]);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(byKey('buy-$shopperLineTomato'), findsNothing);
    expect(byKey('buy-$shopperLineBread'), findsNothing);

    shopper.details[shopperOrderA] = shopperOrder(accepted: true);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(byKey('buy-$shopperLineTomato'), findsNothing);
    expect(byKey('shopper-complete'), findsNothing);
  });

  testWidgets('an estimate is bought with its quantity and the price paid', (
    WidgetTester tester,
  ) async {
    shopper.afterAction[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'purchased'),
      bread(),
    ]);
    await openOrder(tester);

    await buy(tester, shopperLineTomato);
    expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
    expect(shopper.actions, isEmpty);

    await tester.enterText(byKey('purchase-quantity'), '1,8');
    await tester.enterText(byKey('purchase-price'), '16 500');
    await tapAndSettle(tester, byKey('purchase-save'));

    expect(shopper.actions, <String>[
      'purchase:$shopperLineTomato:1.8:16500:$shopperProductTomato',
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(byKey('shopper-line-bought-$shopperLineTomato'), findsOneWidget);
  });

  testWidgets('a price the typo guard doubts is confirmed before it is sent', (
    WidgetTester tester,
  ) async {
    shopper.afterAction[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'purchased'),
      bread(),
    ]);
    await openOrder(tester);

    await buy(tester, shopperLineTomato, price: '60000');
    expect(
      find.text(l10n(tester).typoExplained(money(60000), money(16000))),
      findsOneWidget,
    );
    await tapAndSettle(tester, byKey('typo-cancel'));
    expect(shopper.actions, isEmpty);
    expect(byKey('purchase-price'), findsOneWidget, reason: 'to correct it');

    await tapAndSettle(tester, byKey('purchase-save'));
    await tapAndSettle(tester, byKey('typo-confirm'));
    expect(shopper.actions, <String>[
      'purchase:$shopperLineTomato:2:60000:$shopperProductTomato',
    ]);
  });

  testWidgets('a fixed line is bought without a price', (
    WidgetTester tester,
  ) async {
    shopper.afterAction[shopperOrderA] = shopping(<Object?>[
      tomato(),
      bread(status: 'purchased'),
    ]);
    await openOrder(tester);

    await buy(tester, shopperLineBread);

    expect(shopper.actions, <String>[
      'purchase:$shopperLineBread:2:null:$shopperProductBread',
    ]);
  });

  testWidgets('with a replacement authorized, the replacement is bought, and '
      'judged by its own price, unless the original is chosen', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(patch: <String, Object?>{'replacement': shopperReplacementJson()}),
      bread(),
    ]);
    await openOrder(tester);

    // Refused surely, so each attempt below is sent anew.
    shopper.actionFailure = const ApiRefusal(
      ApiError(status: 409, code: 'item_already_resolved'),
    );

    // 47 000 is above three times the replacement's 15 500.
    await buy(tester, shopperLineTomato, price: '47000');
    expect(byKey('typo-confirm'), findsOneWidget);
    await tapAndSettle(tester, byKey('typo-cancel'));

    // The replacement is named when bought.
    await tester.enterText(byKey('purchase-price'), '15000');
    await tapAndSettle(tester, byKey('purchase-save'));

    // The original's 16 000 makes 47 000 no slip, and it is named.
    await tapAndSettle(tester, byKey('buy-original'));
    await tester.enterText(byKey('purchase-price'), '47000');
    await tapAndSettle(tester, byKey('purchase-save'));
    expect(byKey('typo-confirm'), findsNothing);
    expect(shopper.actions, <String>[
      'purchase:$shopperLineTomato:2:15000:$shopperProductCherry',
      'purchase:$shopperLineTomato:2:47000:$shopperProductTomato',
    ]);
    expect(find.text(l10n(tester).errorItemAlreadyResolved), findsOneWidget);
    expect(shopper.loads.last, 'order:$shopperOrderA');
  });

  testWidgets('a price above the bound is asked of the Customer, with a note', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.actionFailure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'customer_approval_required',
        details: <String, Object?>{
          'approval_type': 'price_over_tolerance',
          'ceiling_customer_unit_price_uzs': 21160,
          'proposed_customer_unit_price_uzs': 25300,
        },
      ),
    );

    await buy(tester, shopperLineTomato, price: '22000');
    expect(
      tester.widget<Text>(byKey('purchase-needs-customer')).data,
      l10n(tester).purchaseAboveBound,
    );

    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        shopperAskedLineJson('price_over_tolerance'),
        bread(),
      ]);
    await tester.enterText(byKey('ask-note'), ' Narx oshgan ');
    await tapAndSettle(tester, byKey('ask-price'));

    expect(shopper.actions, <String>[
      'purchase:$shopperLineTomato:2:22000:$shopperProductTomato',
      'ask-price:$shopperLineTomato:22000:$shopperProductTomato:Narx oshgan',
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(byKey('shopper-line-question-$shopperLineTomato'), findsOneWidget);
  });

  testWidgets('less than the Customer is owed is asked of them', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.actionFailure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'customer_approval_required',
        details: <String, Object?>{
          'approval_type': 'reduced_quantity',
          'required_quantity': '2.000',
        },
      ),
    );

    await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
    await tester.enterText(byKey('purchase-quantity'), '1,5');
    await tester.enterText(byKey('purchase-price'), '16000');
    await tapAndSettle(tester, byKey('purchase-save'));
    expect(
      tester.widget<Text>(byKey('purchase-needs-customer')).data,
      l10n(tester).purchaseBelowQuantity('2 ${l10n(tester).unitKg}'),
    );

    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        shopperAskedLineJson('reduced_quantity'),
        bread(),
      ]);
    await tapAndSettle(tester, byKey('ask-quantity'));

    expect(shopper.actions.last, 'ask-quantity:$shopperLineTomato:1.5:null');
  });

  testWidgets('a purchase without a sure answer is sent again as it was, '
      'under its key; a sure refusal lets go of the key', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.actionFailure = const NetworkFailure();

    await buy(tester, shopperLineTomato, price: '16500');
    expect(byKey('purchase-dialog-unconfirmed'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(byKey('purchase-price')).enabled,
      isFalse,
    );
    await tapAndSettle(tester, byKey('purchase-cancel'));
    expect(byKey('purchase-unconfirmed-$shopperLineTomato'), findsOneWidget);

    // Opened again, the purchase is the one sent.
    shopper.actionFailure = const ApiRefusal(
      ApiError(status: 409, code: 'shopping_not_active'),
    );
    await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: byKey('purchase-price'),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '16500',
    );
    await tapAndSettle(tester, byKey('purchase-save'));
    expect(shopper.keys, hasLength(2));
    expect(shopper.keys.first, shopper.keys.last);
    expect(shopper.actions.toSet(), <String>{
      'purchase:$shopperLineTomato:2:16500:$shopperProductTomato',
    });
    expect(find.text(l10n(tester).errorShoppingNotActive), findsOneWidget);

    // That answer was sure: the next purchase is a new one, with a new key.
    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(status: 'purchased'),
        bread(),
      ]);
    await tester.enterText(byKey('purchase-price'), '17000');
    await tapAndSettle(tester, byKey('purchase-save'));
    expect(shopper.keys, hasLength(3));
    expect(shopper.keys.last, isNot(shopper.keys.first));
    expect(
      shopper.actions.last,
      'purchase:$shopperLineTomato:2:17000:$shopperProductTomato',
    );
  });

  testWidgets('a line not found is confirmed, with a note; the last one '
      'cancels the order', (WidgetTester tester) async {
    shopper.afterAction[shopperOrderA] = ShopperOrdersApi.parseOrder(
      <String, Object?>{
        ...shopperOrderJson(
          status: 'cancelled',
          items: <Object?>[
            tomato(status: 'removed'),
            bread(status: 'removed'),
          ],
        ),
        'assignment': null,
        'can_accept': false,
        'can_start': false,
      },
    );
    await openOrder(tester);

    await tapAndSettle(tester, byKey('unavailable-$shopperLineTomato'));
    expect(find.text(l10n(tester).unavailableExplained), findsOneWidget);
    await tester.enterText(byKey('unavailable-note'), 'Qolmagan');
    final int loads = shopper.loads
        .where((String load) => load == 'order:$shopperOrderA')
        .length;
    await tapAndSettle(tester, byKey('unavailable-confirm'));
    expect(
      shopper.loads.where((String load) => load == 'order:$shopperOrderA'),
      hasLength(loads),
      reason: 'an order no longer the Shopper\'s is not asked for again',
    );

    expect(shopper.actions, <String>[
      'unavailable:$shopperLineTomato:Qolmagan',
    ]);
    // The order is the Shopper's no more: back on the list, told why.
    expect(byKey('shopper-order'), findsNothing);
    expect(find.text(l10n(tester).shopperOrderCancelled), findsOneWidget);
    expect(find.text(l10n(tester).shellShopper), findsOneWidget);
  });

  testWidgets('an order that can no longer be read says so, and leads back', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.details.remove(shopperOrderA);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(byKey('shopper-order-gone'), findsOneWidget);
    expect(byKey('retry-load'), findsNothing);
    await tapAndSettle(tester, byKey('shopper-order-gone-back'));
    expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);
  });

  testWidgets('a first attempt in flight is not said to be without an answer', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(),
      bread(status: 'purchased'),
    ]);
    await openOrder(tester);
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
    await tester.enterText(byKey('purchase-price'), '16500');
    await tester.tap(byKey('purchase-save'));
    await tester.pump();
    expect(byKey('purchase-dialog-unconfirmed'), findsNothing);
    expect(find.text(l10n(tester).purchaseSave), findsOneWidget);
    expect(find.text(l10n(tester).purchaseAgain), findsNothing);

    shopper
      ..hold = null
      ..actionFailure = const NetworkFailure();
    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('purchase-dialog-unconfirmed'), findsOneWidget);
    expect(find.text(l10n(tester).purchaseAgain), findsOneWidget);
  });

  testWidgets('a purchase without a sure answer keeps its key through a failed '
      'load of the order', (WidgetTester tester) async {
    await openOrder(tester);
    shopper.actionFailure = const NetworkFailure();
    await buy(tester, shopperLineTomato, price: '16500');
    await tapAndSettle(tester, byKey('purchase-cancel'));

    shopper.orderFailure = const NetworkFailure();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(byKey('retry-load'), findsOneWidget);
    shopper.orderFailure = null;
    await tapAndSettle(tester, byKey('retry-load'));

    expect(byKey('purchase-unconfirmed-$shopperLineTomato'), findsOneWidget);
    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(status: 'purchased'),
        bread(),
      ]);
    await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
    await tapAndSettle(tester, byKey('purchase-save'));
    expect(shopper.keys, hasLength(2));
    expect(shopper.keys.first, shopper.keys.last);
  });

  testWidgets('asking about a price needs one, whatever the product chosen '
      'since', (WidgetTester tester) async {
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(),
      bread(
        patch: <String, Object?>{
          'replacement': <String, Object?>{
            ...shopperReplacementJson(),
            'bound': <String, Object?>{
              'customer_unit_price_uzs': 4600,
              'market_price_uzs': 4000,
            },
          },
        },
      ),
    ]);
    await openOrder(tester);
    shopper.actionFailure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'customer_approval_required',
        details: <String, Object?>{'approval_type': 'price_over_tolerance'},
      ),
    );
    await tester.dragUntilVisible(
      byKey('buy-$shopperLineBread'),
      byKey('shopper-order'),
      const Offset(0, -200),
    );
    await buy(tester, shopperLineBread, price: '6000');
    expect(byKey('ask-price'), findsOneWidget);

    // The loaf itself takes no price; the question still needs one.
    await tapAndSettle(tester, byKey('buy-original'));
    await tester.enterText(byKey('purchase-price'), '');
    await tapAndSettle(tester, byKey('ask-price'));

    expect(tester.takeException(), isNull);
    expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
    expect(shopper.actions.where((String a) => a.startsWith('ask-')), isEmpty);

    // Bought as itself after all, the loaf needs no price.
    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(),
        bread(status: 'purchased'),
      ]);
    await tapAndSettle(tester, byKey('purchase-save'));
    expect(
      shopper.actions.last,
      'purchase:$shopperLineBread:2:null:$shopperProductBread',
    );
  });

  testWidgets('a replacement is searched, chosen, and offered with the price '
      'paid, the typo guard judging it by its own price', (
    WidgetTester tester,
  ) async {
    shopper
      ..choices = <ReplacementChoice>[
        ShopperOrdersApi.parseChoice(shopperChoiceJson()),
      ]
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(
          patch: <String, Object?>{'replacement': shopperReplacementJson()},
        ),
        bread(),
      ]);
    await openOrder(tester);

    await tapAndSettle(tester, byKey('replace-$shopperLineTomato'));
    expect(shopper.loads, contains('replacements:$shopperLineTomato::1'));
    await tester.enterText(byKey('replace-search'), 'olcha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(shopper.loads, contains('replacements:$shopperLineTomato:olcha:1'));

    await tapAndSettle(tester, byKey('replacement-$shopperProductCherry'));
    await tester.enterText(byKey('substitute-price'), '47000');
    await tapAndSettle(tester, byKey('substitute-save'));
    await tapAndSettle(tester, byKey('typo-cancel'));
    expect(shopper.actions, isEmpty);

    await tester.enterText(byKey('substitute-price'), '15 000');
    await tester.enterText(byKey('substitute-note'), 'Qizil tugagan');
    await tapAndSettle(tester, byKey('substitute-save'));

    expect(shopper.actions, <String>[
      'substitute:$shopperLineTomato:$shopperProductCherry:15000:Qizil tugagan',
    ]);
    expect(byKey('shopper-order'), findsOneWidget, reason: 'back on the order');
    expect(
      byKey('shopper-line-replacement-$shopperLineTomato'),
      findsOneWidget,
    );
  });

  testWidgets('a completion whose answer was lost, and whose order then cannot '
      'be read, is sent again under its key and reaches the closing screen', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'purchased'),
      bread(status: 'purchased'),
    ]);
    await openOrder(tester);
    // No network: the completion goes unanswered, and loading the order
    // again would fail too.
    shopper
      ..actionFailure = const NetworkFailure()
      ..orderFailure = const NetworkFailure();

    await tapAndSettle(tester, byKey('shopper-complete'));
    await tapAndSettle(tester, byKey('complete-confirm'));
    expect(byKey('complete-unconfirmed'), findsOneWidget);
    expect(byKey('shopper-complete'), findsOneWidget, reason: 'still shown');

    // It went through: the order is the Shopper's no more.
    shopper.details.remove(shopperOrderA);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(byKey('complete-again'), findsOneWidget);
    expect(byKey('retry-load'), findsOneWidget);

    shopper.orderFailure = null;
    await tapAndSettle(tester, byKey('retry-load'));
    expect(byKey('complete-again'), findsOneWidget);
    expect(byKey('shopper-order-gone'), findsNothing);

    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = ShopperOrdersApi.parseOrder(
        <String, Object?>{
          ...shopperOrderJson(
            status: 'delivery_assigned',
            items: <Object?>[
              tomato(status: 'purchased'),
              bread(status: 'purchased'),
            ],
          ),
          'assignment': shopperAssignmentJson(accepted: true, started: true),
          'can_accept': false,
          'can_start': false,
        },
      );
    await tapAndSettle(tester, byKey('complete-again'));

    expect(shopper.keys, hasLength(2));
    expect(shopper.keys.first, shopper.keys.last);
    expect(byKey('shopper-done-title'), findsOneWidget);
  });

  testWidgets('a Shopper who left the order while its completion ran is told '
      'it is done, not taken back to it', (WidgetTester tester) async {
    shopper
      ..details[shopperOrderA] = shopping(<Object?>[
        tomato(status: 'purchased'),
        bread(status: 'purchased'),
      ])
      ..afterAction[shopperOrderA] = ShopperOrdersApi.parseOrder(
        <String, Object?>{
          ...shopperOrderJson(
            status: 'ready_for_delivery',
            items: <Object?>[
              tomato(status: 'purchased'),
              bread(status: 'purchased'),
            ],
          ),
          'assignment': shopperAssignmentJson(accepted: true, started: true),
          'can_accept': false,
          'can_start': false,
        },
      );
    await openOrder(tester);
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tapAndSettle(tester, byKey('shopper-complete'));
    await tester.tap(byKey('complete-confirm'));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    shopper.hold = null;
    hold.complete();
    await tester.pumpAndSettle();

    expect(byKey('shopper-done-title'), findsNothing);
    expect(find.text(l10n(tester).doneTitle('1001')), findsOneWidget);
    expect(find.text(l10n(tester).shellShopper), findsOneWidget);
  });

  testWidgets('the refresh waits while a completion runs', (
    WidgetTester tester,
  ) async {
    shopper
      ..details[shopperOrderA] = shopping(<Object?>[
        tomato(status: 'purchased'),
        bread(status: 'purchased'),
      ])
      ..afterAction[shopperOrderA] = ShopperOrdersApi.parseOrder(
        <String, Object?>{
          ...shopperOrderJson(
            status: 'ready_for_delivery',
            items: <Object?>[
              tomato(status: 'purchased'),
              bread(status: 'purchased'),
            ],
          ),
          'assignment': shopperAssignmentJson(accepted: true, started: true),
          'can_accept': false,
          'can_start': false,
        },
      );
    await openOrder(tester);
    final int loads = shopper.loads
        .where((String load) => load == 'order:$shopperOrderA')
        .length;
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tapAndSettle(tester, byKey('shopper-complete'));
    await tester.tap(byKey('complete-confirm'));
    await tester.pump();
    expect(byKey('complete-unconfirmed'), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    expect(
      shopper.loads.where((String load) => load == 'order:$shopperOrderA'),
      hasLength(loads),
    );

    shopper.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('shopper-done-title'), findsOneWidget);
  });

  testWidgets('the closing screen takes only an order number, and back leads '
      'to the list', (WidgetTester tester) async {
    await openOrder(tester);
    final GoRouter router = GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    );

    router.go('/shopper/done/abc');
    await tester.pumpAndSettle();
    expect(byKey('shopper-done-title'), findsNothing);
    expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);

    router.go('/shopper/done/1001');
    await tester.pumpAndSettle();
    expect(byKey('shopper-done-title'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);
  });

  testWidgets('a replacement offered from its search entered alone leads to '
      'the order; one already authorized points to buy', (
    WidgetTester tester,
  ) async {
    shopper
      ..choices = <ReplacementChoice>[
        ShopperOrdersApi.parseChoice(shopperChoiceJson()),
      ]
      ..actionFailure = const ApiRefusal(
        ApiError(status: 409, code: 'customer_approval_required'),
      );
    await openOrder(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/shopper/orders/$shopperOrderA/items/$shopperLineTomato/replace');
    await tester.pumpAndSettle();

    await tapAndSettle(tester, byKey('replacement-$shopperProductCherry'));
    await tester.enterText(byKey('substitute-price'), '19000');
    await tapAndSettle(tester, byKey('substitute-save'));
    expect(byKey('substitute-use-buy'), findsOneWidget);

    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(
          patch: <String, Object?>{'replacement': shopperReplacementJson()},
        ),
        bread(),
      ]);
    await tester.enterText(byKey('substitute-price'), '15000');
    await tapAndSettle(tester, byKey('substitute-save'));
    expect(byKey('shopper-order'), findsOneWidget);
  });

  testWidgets('completing is confirmed first, then says what to do with the '
      'package', (WidgetTester tester) async {
    shopper
      ..details[shopperOrderA] = shopping(<Object?>[
        tomato(status: 'purchased'),
        bread(status: 'purchased'),
      ])
      ..afterAction[shopperOrderA] = ShopperOrdersApi.parseOrder(
        <String, Object?>{
          ...shopperOrderJson(
            status: 'ready_for_delivery',
            items: <Object?>[
              tomato(status: 'purchased'),
              bread(status: 'purchased'),
            ],
          ),
          'assignment': shopperAssignmentJson(accepted: true, started: true),
          'can_accept': false,
          'can_start': false,
        },
      );
    await openOrder(tester);

    await tapAndSettle(tester, byKey('shopper-complete'));
    await tapAndSettle(tester, byKey('complete-cancel'));
    expect(shopper.actions, isEmpty);

    await tapAndSettle(tester, byKey('shopper-complete'));
    await tapAndSettle(tester, byKey('complete-confirm'));
    expect(shopper.actions, <String>['complete:$shopperOrderA']);
    expect(
      tester.widget<Text>(byKey('shopper-done-title')).data,
      l10n(tester).doneTitle('1001'),
    );
    expect(
      tester.widget<Text>(byKey('shopper-done-label')).data,
      l10n(tester).doneLabel('1001'),
    );

    shopper.rows = <ShopperOrderRow>[];
    await tapAndSettle(tester, byKey('shopper-done-back'));
    expect(byKey('shopper-orders-empty'), findsOneWidget);
  });

  testWidgets('a completion refused for open lines names them; one without a '
      'sure answer is sent again under its key, without asking again', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.actionFailure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'shopping_incomplete',
        details: <String, Object?>{
          'item_ids': <Object?>[shopperLineTomato],
        },
      ),
    );

    await tapAndSettle(tester, byKey('shopper-complete'));
    await tapAndSettle(tester, byKey('complete-confirm'));
    expect(
      tester.widget<Text>(byKey('complete-open-lines')).data,
      l10n(tester).completeIncomplete('Pomidor'),
    );

    shopper.actionFailure = const NetworkFailure();
    await tapAndSettle(tester, byKey('shopper-complete'));
    await tapAndSettle(tester, byKey('complete-confirm'));
    expect(byKey('complete-unconfirmed'), findsOneWidget);

    await tapAndSettle(tester, byKey('shopper-complete'));
    expect(byKey('complete-confirm'), findsNothing, reason: 'asked before');
    expect(shopper.keys, hasLength(3));
    expect(shopper.keys[1], shopper.keys[2]);
    expect(shopper.keys[0], isNot(shopper.keys[1]));
  });

  testWidgets('a phone-wide window with large text fits the purchase, the '
      'replacement search and the closing screen, in both languages', (
    WidgetTester tester,
  ) async {
    shopper
      ..details[shopperOrderA] = shopping(<Object?>[
        tomato(
          patch: <String, Object?>{'replacement': shopperReplacementJson()},
        ),
        bread(),
      ])
      ..choices = <ReplacementChoice>[
        ShopperOrdersApi.parseChoice(shopperChoiceJson()),
      ];
    for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
      await openOrder(
        tester,
        size: const Size(360, 800),
        textScale: 2,
        device: language,
      );
      // A long order builds its lines as they scroll into view.
      await tester.dragUntilVisible(
        byKey('buy-$shopperLineTomato'),
        byKey('shopper-order'),
        const Offset(0, -200),
      );
      await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, byKey('purchase-cancel'));

      await tapAndSettle(tester, byKey('replace-$shopperLineTomato'));
      await tapAndSettle(tester, byKey('replacement-$shopperProductCherry'));
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, byKey('substitute-cancel'));

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/shopper/done/1001');
      await tester.pumpAndSettle();
      expect(byKey('shopper-done-label'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
