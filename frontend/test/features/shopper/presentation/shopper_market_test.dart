import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_empty_state.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
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

  /// The amber outline of a refused field (`KitColors.warning`).
  bool outlinedAmber(WidgetTester tester, String field) {
    final InputDecoration decoration = tester
        .widget<InputDecorator>(
          find.descendant(
            of: byKey(field),
            matching: find.byType(InputDecorator),
          ),
        )
        .decoration;
    final InputBorder? border = decoration.enabledBorder;
    return border is OutlineInputBorder &&
        border.borderSide.color == KitColors.warning;
  }

  const ApiRefusal priceRefusal = ApiRefusal(
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
    expect(
      find.descendant(
        of: byKey('unavailable-$shopperLineTomato'),
        matching: find.text(l10n(tester).lineUnavailable),
      ),
      findsOneWidget,
    );
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
    shopper
      ..details[shopperOrderA] = shopping(<Object?>[
        tomato(
          patch: <String, Object?>{'image_url': 'https://example.test/t.webp'},
        ),
        bread(),
      ])
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(status: 'purchased'),
        bread(),
      ]);
    await openOrder(tester);

    await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
    final AppLocalizations words = l10n(tester);
    final Finder sheet = byKey('purchase-sheet');
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet(words.purchaseSheetTitle), findsOneWidget);
    expect(
      tester
          .widget<ProductImage>(
            find.descendant(of: sheet, matching: find.byType(ProductImage)),
          )
          .url,
      'https://example.test/t.webp',
    );
    expect(inSheet('Pomidor'), findsOneWidget);
    expect(inSheet(words.purchaseNeeded('2 ${words.unitKg}')), findsOneWidget);
    expect(
      inSheet(
        words.purchaseMarketInfo(money(16000), money(18400), words.unitKg),
      ),
      findsOneWidget,
    );
    expect(inSheet(words.purchasePriceFor(words.unitKg)), findsOneWidget);
    expect(byKey('purchase-sheet-close'), findsOneWidget);

    await tapAndSettle(tester, byKey('purchase-save'));
    expect(find.text(words.fieldRequired), findsOneWidget);
    expect(shopper.actions, isEmpty);

    await tester.enterText(byKey('purchase-quantity'), '1,8');
    await tester.enterText(byKey('purchase-price'), '16500');
    await tester.pump();
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
      '16 500',
    );
    await tapAndSettle(tester, byKey('purchase-save'));

    expect(shopper.actions, <String>[
      'purchase:$shopperLineTomato:1.8:16500:$shopperProductTomato',
    ]);
    expect(sheet, findsNothing);
    expect(byKey('shopper-line-bought-$shopperLineTomato'), findsOneWidget);
  });

  testWidgets('buying more than needed says the excess is not billed', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
    final AppLocalizations words = l10n(tester);
    expect(byKey('purchase-excess'), findsNothing);

    await tester.enterText(byKey('purchase-quantity'), '2,1');
    await tester.pump();
    expect(
      tester.widget<Text>(byKey('purchase-excess')).data,
      words.purchaseExcess('2 ${words.unitKg}'),
    );

    await tester.enterText(byKey('purchase-quantity'), '2');
    await tester.pump();
    expect(byKey('purchase-excess'), findsNothing);
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
    expect(find.text(l10n(tester).typoTitle), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      find.text(l10n(tester).typoExplained(money(60000), money(16000))),
      findsOneWidget,
    );
    await tapAndSettle(tester, byKey('typo-cancel'));
    expect(find.text(l10n(tester).typoTitle), findsNothing);
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

    await tapAndSettle(tester, byKey('buy-$shopperLineBread'));
    final AppLocalizations words = l10n(tester);
    expect(find.text(words.purchasePriceOptional), findsOneWidget);
    expect(find.text(words.purchaseMarketOnly(money(4000))), findsOneWidget);
    await tapAndSettle(tester, byKey('purchase-save'));

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

    final AppLocalizations words = l10n(tester);
    expect(
      find.descendant(
        of: byKey('buy-replacement'),
        matching: find.byIcon(Icons.swap_horiz),
      ),
      findsOneWidget,
    );
    expect(byKey('buy-original'), findsOneWidget);
    expect(find.text(words.purchaseWhich('Pomidor')), findsOneWidget);
    expect(
      find.text(
        words.purchaseMarketInfo(money(15500), money(18400), words.unitKg),
      ),
      findsOneWidget,
    );

    // The replacement is named when bought.
    await tester.enterText(byKey('purchase-price'), '15000');
    await tapAndSettle(tester, byKey('purchase-save'));

    // The original's 16 000 makes 47 000 no slip, and it is named.
    await tapAndSettle(tester, byKey('buy-original'));
    expect(
      find.text(
        words.purchaseMarketInfo(money(16000), money(18400), words.unitKg),
      ),
      findsOneWidget,
    );
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
    shopper.actionFailure = priceRefusal;

    await buy(tester, shopperLineTomato, price: '22000');
    final AppLocalizations words = l10n(tester);
    expect(
      tester.widget<Text>(byKey('purchase-needs-customer')).data,
      words.purchaseAboveBound(money(18400)),
    );
    expect(
      tester
          .widget<KitNote>(
            find.ancestor(
              of: byKey('purchase-needs-customer'),
              matching: find.byType(KitNote),
            ),
          )
          .tone,
      KitTone.amber,
    );
    expect(outlinedAmber(tester, 'purchase-price'), isTrue);
    expect(outlinedAmber(tester, 'purchase-quantity'), isFalse);
    // Side by side the price label is short, and the two fields align.
    expect(find.text(words.purchasePriceShort(words.unitKg)), findsOneWidget);
    expect(find.text(words.purchasePriceFor(words.unitKg)), findsNothing);
    expect(
      tester.getBottomLeft(byKey('purchase-price')).dy,
      tester.getBottomLeft(byKey('purchase-quantity')).dy,
    );
    expect(find.text(words.askNotePlaceholder), findsOneWidget);
    expect(find.text('0 / 300'), findsOneWidget);
    expect(byKey('purchase-save'), findsNothing);
    expect(
      find.descendant(
        of: byKey('ask-price'),
        matching: find.text(words.askCustomer),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('purchase-cancel'),
        matching: find.text(words.cancelButton),
      ),
      findsOneWidget,
    );

    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        shopperAskedLineJson('price_over_tolerance'),
        bread(),
      ]);
    await tester.enterText(byKey('ask-note'), ' Narx oshgan ');
    await tester.pump();
    expect(find.text('11 / 300'), findsOneWidget);
    await tapAndSettle(tester, byKey('ask-price'));

    expect(shopper.actions, <String>[
      'purchase:$shopperLineTomato:2:22000:$shopperProductTomato',
      'ask-price:$shopperLineTomato:22000:$shopperProductTomato:Narx oshgan',
    ]);
    expect(byKey('purchase-sheet'), findsNothing);
    expect(byKey('shopper-line-question-$shopperLineTomato'), findsOneWidget);
  });

  testWidgets('a note over the limit is not sent with the question about the '
      'price', (WidgetTester tester) async {
    await openOrder(tester);
    shopper.actionFailure = priceRefusal;
    await buy(tester, shopperLineTomato, price: '22000');
    shopper.actions.clear();

    await tester.enterText(byKey('ask-note'), List.filled(301, 'a').join());
    await tapAndSettle(tester, byKey('ask-price'));

    expect(shopper.actions, isEmpty);
    expect(byKey('ask-price'), findsOneWidget);
    expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
  });

  testWidgets('editing the refused price returns to the purchase', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.actionFailure = priceRefusal;
    await buy(tester, shopperLineTomato, price: '22000');
    expect(byKey('purchase-needs-customer'), findsOneWidget);
    expect(byKey('purchase-save'), findsNothing);

    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(status: 'purchased'),
        bread(),
      ]);
    await tester.enterText(byKey('purchase-price'), '22500');
    await tester.pump();
    expect(byKey('purchase-needs-customer'), findsNothing);
    expect(byKey('ask-price'), findsNothing);
    expect(outlinedAmber(tester, 'purchase-price'), isFalse);
    expect(byKey('purchase-save'), findsOneWidget);

    await tapAndSettle(tester, byKey('purchase-save'));
    expect(shopper.actions, <String>[
      'purchase:$shopperLineTomato:2:22000:$shopperProductTomato',
      'purchase:$shopperLineTomato:2:22500:$shopperProductTomato',
    ]);
    expect(byKey('purchase-sheet'), findsNothing);
  });

  testWidgets('a running purchase holds its sheet', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.afterAction[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'purchased'),
      bread(),
    ]);
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
    await tester.enterText(byKey('purchase-price'), '16500');
    await tester.tap(byKey('purchase-save'));
    await tester.pump();

    await tester.tap(byKey('purchase-sheet-close'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('purchase-sheet'), findsOneWidget, reason: 'the x');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('purchase-sheet'), findsOneWidget, reason: 'back');
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('purchase-sheet'), findsOneWidget, reason: 'the scrim');

    shopper.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('purchase-sheet'), findsNothing);
    expect(shopper.actions, hasLength(1));
    expect(byKey('shopper-line-bought-$shopperLineTomato'), findsOneWidget);
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
      l10n(tester).purchaseBelowQuantity(
        '2 ${l10n(tester).unitKg}',
        '1,5 ${l10n(tester).unitKg}',
      ),
    );
    expect(outlinedAmber(tester, 'purchase-quantity'), isTrue);
    expect(outlinedAmber(tester, 'purchase-price'), isFalse);

    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        shopperAskedLineJson('reduced_quantity'),
        bread(),
      ]);
    await tapAndSettle(tester, byKey('ask-quantity'));

    expect(shopper.actions.last, 'ask-quantity:$shopperLineTomato:1.5:null');
    expect(byKey('purchase-sheet'), findsNothing);
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
    await tapAndSettle(tester, byKey('purchase-sheet-close'));
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
    final AppLocalizations words = l10n(tester);
    final Finder sheet = byKey('unavailable-sheet');
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet(words.unavailableSheetTitle), findsOneWidget);
    expect(inSheet('Pomidor'), findsOneWidget);
    expect(inSheet('2 ${words.unitKg}'), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.byType(ProductImage)),
      findsOneWidget,
    );
    expect(inSheet(words.unavailableExplained('Pomidor')), findsOneWidget);
    expect(inSheet(words.actionNote), findsOneWidget);
    expect(inSheet(words.unavailableNotePlaceholder), findsOneWidget);
    expect(inSheet('0 / 300'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(byKey('unavailable-confirm'))
          .style!
          .backgroundColor!
          .resolve(<WidgetState>{}),
      KitColors.danger,
    );
    expect(
      find.descendant(
        of: byKey('unavailable-confirm'),
        matching: find.text(words.unavailableConfirm),
      ),
      findsOneWidget,
    );
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
    expect(find.text(l10n(tester).myOrders), findsOneWidget);
  });

  testWidgets('an order the last line\'s answer cancelled leaves the list '
      'under it at once', (WidgetTester tester) async {
    shopper.rows.add(
      ShopperOrdersApi.parseRow(
        shopperRowJson(
          id: shopperOrderB,
          number: 1002,
          status: 'shopping',
          accepted: true,
        ),
      ),
    );
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
    shopper.holdList = Completer<void>();
    await tapAndSettle(tester, byKey('unavailable-confirm'));

    expect(byKey('shopper-order'), findsNothing);
    expect(byKey('shopper-order-$shopperOrderA'), findsNothing);
    expect(byKey('shopper-order-$shopperOrderB'), findsOneWidget);
  });

  testWidgets('a line answer that keeps the order keeps its row', (
    WidgetTester tester,
  ) async {
    shopper.afterAction[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'removed'),
      bread(),
    ]);
    await openOrder(tester);

    await tapAndSettle(tester, byKey('unavailable-$shopperLineTomato'));
    shopper.holdList = Completer<void>();
    await tapAndSettle(tester, byKey('unavailable-confirm'));
    expect(byKey('shopper-order'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);
  });

  testWidgets('a running "not found" holds its sheet', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.afterAction[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'removed'),
      bread(),
    ]);
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tapAndSettle(tester, byKey('unavailable-$shopperLineTomato'));
    await tester.tap(byKey('unavailable-confirm'));
    await tester.pump();

    await tester.tap(byKey('unavailable-sheet-close'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('unavailable-sheet'), findsOneWidget, reason: 'the x');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('unavailable-sheet'), findsOneWidget, reason: 'back');
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('unavailable-sheet'), findsOneWidget, reason: 'the scrim');

    shopper.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('unavailable-sheet'), findsNothing);
    expect(shopper.actions, hasLength(1));
  });

  testWidgets('an order that can no longer be read says so, and leads back', (
    WidgetTester tester,
  ) async {
    await openOrder(tester);
    shopper.details.remove(shopperOrderA);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    final Finder gone = byKey('shopper-order-gone');
    expect(gone, findsOneWidget);
    expect(tester.widget(gone), isA<KitEmptyState>());
    final AppLocalizations words = l10n(tester);
    for (final String text in <String>[
      words.shopperOrderGone,
      words.shopperOrderGoneHint,
    ]) {
      expect(
        find.descendant(of: gone, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: byKey('shopper-order-gone-back'),
        matching: find.text(words.doneBack),
      ),
      findsOneWidget,
    );
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
    await tapAndSettle(tester, byKey('purchase-sheet-close'));

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

  testWidgets('the ask state belongs to the product refused'
      '', (WidgetTester tester) async {
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

    // The replacement's price was refused: the original chosen is a
    // purchase, with no question about a product nobody asked about.
    await tapAndSettle(tester, byKey('buy-original'));
    expect(byKey('purchase-save'), findsOneWidget);
    expect(byKey('ask-price'), findsNothing);
    expect(byKey('purchase-needs-customer'), findsNothing);

    // The replacement again, the fields untouched: the question returns,
    // and names the replacement.
    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(),
        shopperAskedLineJson('price_over_tolerance'),
      ]);
    await tapAndSettle(tester, byKey('buy-replacement'));
    expect(byKey('purchase-save'), findsNothing);
    expect(byKey('purchase-needs-customer'), findsOneWidget);
    await tapAndSettle(tester, byKey('ask-price'));
    expect(
      shopper.actions.last,
      'ask-price:$shopperLineBread:6000:$shopperProductCherry:null',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('after a refusal about the replacement the original is bought '
      'without a price', (WidgetTester tester) async {
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

    // Bought as itself after all, the loaf needs no price.
    shopper
      ..actionFailure = null
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(),
        bread(status: 'purchased'),
      ]);
    await tapAndSettle(tester, byKey('buy-original'));
    await tester.enterText(byKey('purchase-price'), '');
    await tapAndSettle(tester, byKey('purchase-save'));

    expect(
      shopper.actions.last,
      'purchase:$shopperLineBread:2:null:$shopperProductBread',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a replacement is searched, chosen, and offered with the price '
      'paid, the typo guard judging it by its own price', (
    WidgetTester tester,
  ) async {
    shopper
      ..choices = <ReplacementChoice>[
        ShopperOrdersApi.parseChoice(
          shopperChoiceJson(imageUrl: 'https://example.test/c.webp'),
        ),
      ]
      ..afterAction[shopperOrderA] = shopping(<Object?>[
        tomato(
          patch: <String, Object?>{'replacement': shopperReplacementJson()},
        ),
        bread(),
      ]);
    await openOrder(tester);

    await tapAndSettle(tester, byKey('replace-$shopperLineTomato'));
    final AppLocalizations words = l10n(tester);
    expect(shopper.loads, contains('replacements:$shopperLineTomato::1'));
    expect(find.text(words.replaceTitle('Pomidor')), findsOneWidget);
    expect(find.text(words.replaceInfoSimilar), findsOneWidget);
    final Finder row = byKey('replacement-$shopperProductCherry');
    expect(
      tester
          .widget<ProductImage>(
            find.descendant(of: row, matching: find.byType(ProductImage)),
          )
          .url,
      'https://example.test/c.webp',
    );
    expect(
      find.descendant(of: row, matching: find.text('Olcha pomidor')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text(words.replacePricePer(money(15500), words.unitKg)),
      ),
      findsOneWidget,
    );
    expect(find.text(words.replaceUnitHint(words.unitKg)), findsOneWidget);
    expect(
      find.text("Bir xil o'lchov birligidagi mahsulotlar: ${words.unitKg}"),
      findsOneWidget,
      reason: 'no doubled period after the unit',
    );
    // One page: no bar saying "page 1 of 1".
    expect(byKey('next-page'), findsNothing);

    await tester.enterText(byKey('replace-search'), 'olcha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(shopper.loads, contains('replacements:$shopperLineTomato:olcha:1'));

    await tapAndSettle(tester, row);
    final Finder sheet = byKey('substitute-sheet');
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet(words.substituteSheetTitle), findsOneWidget);
    expect(
      inSheet(words.substituteInstead('Pomidor', '2 ${words.unitKg}')),
      findsOneWidget,
    );
    expect(inSheet('Olcha pomidor'), findsOneWidget);
    expect(
      inSheet(words.shopperMarketPer(money(15500), words.unitKg)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(ProductImage)),
      findsOneWidget,
    );
    expect(inSheet(words.substitutePriceFor(words.unitKg)), findsOneWidget);
    expect(byKey('substitute-note'), findsOneWidget);
    expect(inSheet(words.askNote), findsOneWidget);
    expect(inSheet(words.substituteInfoSimilar), findsOneWidget);

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

  testWidgets('a line that asks to be contacted first says so in the search '
      'and in the proposal', (WidgetTester tester) async {
    shopper
      ..details[shopperOrderA] = shopping(<Object?>[
        tomato(
          patch: <String, Object?>{
            'substitution_policy': 'contact_before_substitution',
          },
        ),
        bread(),
      ])
      ..choices = <ReplacementChoice>[
        ShopperOrdersApi.parseChoice(shopperChoiceJson()),
      ];
    await openOrder(tester);

    await tapAndSettle(tester, byKey('replace-$shopperLineTomato'));
    final AppLocalizations words = l10n(tester);
    expect(find.text(words.replaceInfoContact), findsOneWidget);
    expect(find.text(words.replaceInfoSimilar), findsNothing);
    await tapAndSettle(tester, byKey('replacement-$shopperProductCherry'));
    expect(find.text(words.substituteInfoContact), findsOneWidget);
    expect(find.text(words.substituteInfoSimilar), findsNothing);
  });

  testWidgets('nothing found offers the way back', (WidgetTester tester) async {
    shopper.choices = <ReplacementChoice>[];
    await openOrder(tester);

    await tapAndSettle(tester, byKey('replace-$shopperLineTomato'));
    final AppLocalizations words = l10n(tester);
    expect(
      tester.widget<KitEmptyState>(byKey('replace-none')).title,
      words.replaceNone,
    );
    expect(find.text(words.replaceNoneHint), findsOneWidget);
  });

  testWidgets('a running proposal holds its sheet', (
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
    await tapAndSettle(tester, byKey('replacement-$shopperProductCherry'));
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tester.enterText(byKey('substitute-price'), '15000');
    await tester.tap(byKey('substitute-save'));
    await tester.pump();

    await tester.tap(byKey('substitute-sheet-close'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('substitute-sheet'), findsOneWidget, reason: 'the x');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('substitute-sheet'), findsOneWidget, reason: 'back');
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 400));
    expect(byKey('substitute-sheet'), findsOneWidget, reason: 'the scrim');

    shopper.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('substitute-sheet'), findsNothing);
    expect(shopper.actions, hasLength(1));
    expect(byKey('shopper-order'), findsOneWidget);
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
    expect(find.text(l10n(tester).myOrders), findsOneWidget);
  });

  testWidgets('a completion that answers after the Shopper left takes the '
      'order off the list at once', (WidgetTester tester) async {
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
    shopper
      ..hold = null
      ..holdList = Completer<void>();
    hold.complete();
    await tester.pumpAndSettle();

    expect(byKey('shopper-order-$shopperOrderA'), findsNothing);
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
    expect(find.byType(AppBar), findsNothing);
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
      l10n(tester).doneLabel,
    );
    expect(find.text(l10n(tester).doneWriteOnBag), findsOneWidget);
    final Text number = tester.widget<Text>(find.text('1001'));
    expect(number.style?.fontSize, 60);
    expect(number.style?.fontWeight, FontWeight.w700);
    expect(
      find.descendant(
        of: byKey('shopper-done-back'),
        matching: find.text(l10n(tester).doneBack),
      ),
      findsOneWidget,
    );

    shopper.rows = <ShopperOrderRow>[];
    await tapAndSettle(tester, byKey('shopper-done-back'));
    expect(byKey('shopper-orders-empty'), findsOneWidget);
  });

  testWidgets('a completion refused for open lines names them; one without a '
      'sure answer is sent again under its key, without asking again', (
    WidgetTester tester,
  ) async {
    // The page the Shopper holds says all is resolved; the server finds a
    // line open (a page older than the server).
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'purchased'),
      bread(status: 'purchased'),
    ]);
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
      byKey('complete-open-lines'),
      findsNothing,
      reason: 'the page held says the named line is bought',
    );

    // The next load shows the named line open: now it is named.
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(),
      bread(status: 'purchased'),
    ]);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(byKey('complete-open-lines')).data,
      l10n(tester).completeIncomplete('Pomidor'),
    );
    expect(
      find.descendant(
        of: byKey('shopper-order-footer'),
        matching: byKey('complete-open-lines'),
      ),
      findsOneWidget,
    );

    // The next load shows it bought: the refusal no longer names it.
    shopper.details[shopperOrderA] = shopping(<Object?>[
      tomato(status: 'purchased'),
      bread(status: 'purchased'),
    ]);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(byKey('complete-open-lines'), findsNothing);

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
      await tapAndSettle(tester, byKey('purchase-sheet-close'));

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

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('the replacement and the closing screen hold at 320x640 with '
        'text x2 (${language.languageCode})', (WidgetTester tester) async {
      shopper
        ..details[shopperOrderA] = shopping(<Object?>[tomato(), bread()])
        ..choices = <ReplacementChoice>[
          ShopperOrdersApi.parseChoice(
            shopperChoiceJson(imageUrl: 'https://example.test/c.webp'),
          ),
        ];
      await openOrder(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        device: language,
      );
      final GoRouter router = GoRouter.of(
        tester.element(find.byType(Scaffold).first),
      );
      const String replace =
          '/shopper/orders/$shopperOrderA/items/$shopperLineTomato/replace';

      router.go(replace);
      await tester.pumpAndSettle();
      // The policy note scrolls with the results.
      await tester.dragUntilVisible(
        byKey('replacement-$shopperProductCherry'),
        byKey('replace-choices'),
        const Offset(0, -100),
      );
      expect(byKey('replacement-$shopperProductCherry'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the search');

      shopper.choices = <ReplacementChoice>[];
      await tester.enterText(byKey('replace-search'), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(byKey('replace-none'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the empty search');

      shopper.choices = <ReplacementChoice>[
        ShopperOrdersApi.parseChoice(shopperChoiceJson()),
      ];
      await tester.enterText(byKey('replace-search'), 'olcha');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        byKey('replacement-$shopperProductCherry'),
        byKey('replace-choices'),
        const Offset(0, -100),
      );
      await tapAndSettle(tester, byKey('replacement-$shopperProductCherry'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(
        byKey('substitute-note'),
        List.filled(300, 'я').join(),
      );
      await tester.pumpAndSettle();
      expect(byKey('substitute-sheet'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the proposal');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      router.go('/shopper/done/1234567890');
      await tester.pumpAndSettle();
      expect(find.text('1234567890'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the closing screen');
    });

    testWidgets('the sheets hold at 320x640 with text x2 '
        '(${language.languageCode})', (WidgetTester tester) async {
      shopper.details[shopperOrderA] = shopping(<Object?>[
        tomato(
          patch: <String, Object?>{'replacement': shopperReplacementJson()},
        ),
        bread(),
      ]);
      await openOrder(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        device: language,
      );
      await tester.dragUntilVisible(
        byKey('buy-$shopperLineTomato'),
        byKey('shopper-order'),
        const Offset(0, -200),
      );

      // The plain purchase, then with the original chosen; the keyboard is
      // up while a sheet is open.
      await tapAndSettle(tester, byKey('buy-$shopperLineTomato'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'plain');
      await tapAndSettle(tester, byKey('buy-original'));
      expect(tester.takeException(), isNull, reason: 'two tabs');

      // The typo guard's modal.
      await tester.enterText(byKey('purchase-price'), '60000');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, byKey('purchase-save'));
      expect(byKey('typo-confirm'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the modal');
      await tapAndSettle(tester, byKey('typo-cancel'));

      // The question, with a note at its limit.
      shopper.actionFailure = priceRefusal;
      await tester.enterText(byKey('purchase-price'), '22000');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, byKey('purchase-save'));
      expect(byKey('ask-price'), findsOneWidget);
      await tester.enterText(byKey('ask-note'), List.filled(300, 'я').join());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'the question');
      await tapAndSettle(tester, byKey('purchase-cancel'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      // The line not found.
      await tapAndSettle(tester, byKey('unavailable-$shopperLineTomato'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(byKey('unavailable-sheet'), findsOneWidget);
      await tester.enterText(byKey('unavailable-note'), 'Qolmagan');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'not found');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
