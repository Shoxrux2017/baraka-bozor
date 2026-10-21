import 'dart:async';

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/shopper/presentation/shopper_line_card.dart';
import 'package:baraka_bozor/features/shopper/presentation/shopper_status_card.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/formatting/order_dates.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/language_menu.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/shopper/data/shopper_orders_api.dart';
import 'package:baraka_bozor/features/shopper/domain/shopper_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The Shopper's area (`docs/09` sections 28 and 29, `DL-69`) through the
/// real router, session, controllers and screens: the list and an order,
/// accept and start, the call to the Customer, the refresh while shown, and
/// the menu that keeps Customer mode reachable.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeShopperOrdersRepository shopper;
  late FakePhoneCalls phone;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String money(int amount) => MoneyFormat.uzs(amount, AppLanguage.uz);

  int count(String load) =>
      shopper.loads.where((String each) => each == load).length;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(id: 's', role: UserRole.shopper);
    shopper = FakeShopperOrdersRepository(
      rows: <ShopperOrderRow>[
        ShopperOrdersApi.parseRow(shopperRowJson()),
        ShopperOrdersApi.parseRow(
          shopperRowJson(
            id: shopperOrderB,
            number: 1002,
            status: 'shopping',
            accepted: true,
            open: 1,
          ),
        ),
      ],
      details: <String, ShopperOrder>{shopperOrderA: shopperOrder()},
    );
    phone = FakePhoneCalls();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(420, 1600),
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
        phoneCalls: phone,
        device: device,
        clock: () => DateTime.utc(2026, 9, 27, 9),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the Shopper lands on their orders, the longest-waiting first', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final AppLocalizations words = l10n(tester);

    final DateTime now = DateTime.utc(2026, 9, 27, 9);
    final DateTime assigned = DateTime.utc(2026, 9, 27, 7, 5);

    expect(find.text(words.myOrders), findsOneWidget);
    expect(
      tester.getTopLeft(byKey('shopper-order-$shopperOrderA')).dy,
      lessThan(tester.getTopLeft(byKey('shopper-order-$shopperOrderB')).dy),
    );
    final Finder a = byKey('shopper-order-$shopperOrderA');
    final Finder b = byKey('shopper-order-$shopperOrderB');
    Finder within(Finder card, String text) =>
        find.descendant(of: card, matching: find.text(text));
    expect(within(a, words.shopperChipNew), findsOneWidget);
    expect(within(a, words.orderItemCount(2)), findsOneWidget);
    expect(
      within(a, words.shopperAssigned(orderAtLower(words, assigned, now))),
      findsOneWidget,
    );
    expect(within(a, words.shopperOpenToAccept), findsOneWidget);
    expect(
      within(b, OrderLabels.status(words, OrderStatus.shopping)),
      findsOneWidget,
    );
    expect(within(b, words.shopperOpenOf(1, 2)), findsOneWidget);
    expect(within(a, words.shopperDeliveryWish('Kechqurun')), findsOneWidget);

    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    expect(byKey('shopper-order'), findsOneWidget);
    expect(find.text(words.boardOrderNumber('1001')), findsOneWidget);
  });

  testWidgets('no orders says so', (WidgetTester tester) async {
    shopper.rows = <ShopperOrderRow>[];
    await open(tester);

    expect(byKey('shopper-orders-empty'), findsOneWidget);
    final Finder empty = byKey('shopper-orders-empty');
    expect(
      find.descendant(
        of: empty,
        matching: find.text(l10n(tester).shopperEmptyTitle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: empty,
        matching: find.text(l10n(tester).shopperOrdersEmpty),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an accepted order waits for the market', (
    WidgetTester tester,
  ) async {
    shopper.rows = <ShopperOrderRow>[
      ShopperOrdersApi.parseRow(shopperRowJson(accepted: true)),
    ];
    await open(tester);
    final AppLocalizations words = l10n(tester);
    final Finder card = byKey('shopper-order-$shopperOrderA');
    Finder within(String text) =>
        find.descendant(of: card, matching: find.text(text));

    expect(within(words.shopperChipAccepted), findsOneWidget);
    expect(
      within(
        words.shopperAccepted(
          orderAtLower(
            words,
            DateTime.utc(2026, 9, 27, 7, 6),
            DateTime.utc(2026, 9, 27, 9),
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(within(words.shopperStartAtMarket), findsOneWidget);
  });

  testWidgets('a delivery wish shows on the card', (WidgetTester tester) async {
    shopper.rows = <ShopperOrderRow>[
      ShopperOrdersApi.parseRow(
        shopperRowJson()..['delivery_time_note'] = 'после 18:00',
      ),
    ];
    await open(tester);

    expect(
      find.descendant(
        of: byKey('shopper-order-$shopperOrderA'),
        matching: find.text(l10n(tester).shopperDeliveryWish('после 18:00')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a line bought so cheaply that its total rounds to nothing is '
      'shown', (WidgetTester tester) async {
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: <Object?>[
        shopperLineJson(
          status: 'purchased',
          patch: <String, Object?>{
            'purchase': <String, Object?>{
              'product_id': shopperProductTomato,
              'purchased_quantity': '0.400',
              'billable_quantity': '0.400',
              'actual_market_price_uzs': 1,
              'billable_unit_price_uzs': 1,
              'line_total_uzs': 0,
            },
          },
        ),
      ],
    );
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));

    expect(byKey('shopper-line-bought-$shopperLineTomato'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Map<String, Object?> lineWith(
    String id,
    String status, {
    bool bread = false,
  }) => shopperLineJson(
    bread: bread,
    status: status,
    patch: <String, Object?>{'id': '0192f0a0-0000-7000-8000-00000000e00$id'},
  );

  /// The text of the first [Text] at or under the widget keyed [key].
  String shown(WidgetTester tester, String key) {
    final Text widget = tester.widget<Text>(
      find
          .descendant(
            of: byKey(key),
            matching: find.byType(Text),
            matchRoot: true,
          )
          .first,
    );
    return widget.textSpan?.toPlainText() ?? widget.data!;
  }

  Finder inKey(String key, String text) =>
      find.descendant(of: byKey(key), matching: find.text(text));

  Future<AppLocalizations> openShopping(
    WidgetTester tester,
    List<Object?> items, {
    Size size = const Size(420, 1800),
  }) async {
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: items,
    );
    await open(tester, size: size);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    return l10n(tester);
  }

  Map<String, Object?> asked(String type, {String id = shopperLineTomato}) =>
      shopperAskedLineJson(type)..['id'] = id;

  testWidgets('an order shows each line: what to buy, how far its price may '
      'go, and what became of it', (WidgetTester tester) async {
    shopper.details[shopperOrderA] = shopperOrder(
      items: <Object?>[
        shopperLineJson(),
        shopperLineJson(
          bread: true,
          patch: <String, Object?>{
            'substitution_policy': 'contact_before_substitution',
          },
        ),
        shopperLineJson(
          bread: true,
          patch: <String, Object?>{
            'id': '0192f0a0-0000-7000-8000-00000000e009',
            'substitution_policy': 'remove_if_unavailable',
          },
        ),
      ],
    );
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final AppLocalizations words = l10n(tester);

    expect(find.byType(ShopperLineRow), findsNWidgets(3));
    final Finder tomato = byKey('shopper-line-$shopperLineTomato');
    Finder within(Finder row, String text) =>
        find.descendant(of: row, matching: find.text(text));
    expect(within(tomato, 'Pomidor'), findsOneWidget);
    expect(
      within(tomato, words.shopperMarketPer(money(16000), words.unitKg)),
      findsOneWidget,
    );
    expect(
      within(tomato, words.shopperClientNote('Qizilini oling')),
      findsOneWidget,
    );
    expect(
      within(
        tomato,
        OrderLabels.substitution(words, SubstitutionPolicy.allowSimilar),
      ),
      findsOneWidget,
    );
    expect(within(tomato, '2 ${words.unitKg}'), findsOneWidget);
    expect(
      find.descendant(of: tomato, matching: find.byIcon(Icons.swap_horiz)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.call), findsWidgets);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(byKey('buy-$shopperLineTomato'), findsNothing);
  });

  testWidgets('while shopping the lines stand in three groups', (
    WidgetTester tester,
  ) async {
    final AppLocalizations words = await openShopping(tester, <Object?>[
      lineWith('1', 'pending'),
      asked('price_over_tolerance', id: '0192f0a0-0000-7000-8000-00000000e002'),
      lineWith('3', 'purchased', bread: true),
      lineWith('4', 'removed', bread: true),
    ]);

    double top(String key) => tester.getTopLeft(byKey(key)).dy;
    expect(top('shopper-group-buy'), lessThan(top('shopper-group-waiting')));
    expect(top('shopper-group-waiting'), lessThan(top('shopper-group-done')));
    expect(inKey('shopper-group-buy', words.shopperGroupToBuy), findsOneWidget);
    expect(inKey('shopper-group-buy', '1'), findsOneWidget);
    expect(
      inKey('shopper-group-waiting', words.shopperGroupWaiting),
      findsOneWidget,
    );
    expect(inKey('shopper-group-waiting', '1'), findsOneWidget);
    expect(inKey('shopper-group-done', words.shopperGroupDone), findsOneWidget);
    expect(inKey('shopper-group-done', '2'), findsOneWidget);

    // A group with nothing in it has no heading.
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: <Object?>[lineWith('3', 'purchased', bread: true)],
    );
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(byKey('shopper-group-buy'), findsNothing);
    expect(byKey('shopper-group-waiting'), findsNothing);
    expect(byKey('shopper-group-done'), findsOneWidget);
  });

  testWidgets('a line to buy says how far its price may go', (
    WidgetTester tester,
  ) async {
    final AppLocalizations words = await openShopping(tester, <Object?>[
      shopperLineJson(),
      shopperLineJson(bread: true),
    ]);

    expect(
      shown(tester, 'shopper-line-limit-$shopperLineTomato'),
      words.shopperBoundPer(money(18400), words.unitKg),
    );
    expect(byKey('shopper-line-limit-$shopperLineBread'), findsNothing);
    expect(
      find.descendant(
        of: byKey('shopper-line-$shopperLineTomato'),
        matching: find.text('2 ${words.unitKg}'),
      ),
      findsOneWidget,
    );
    expect(byKey('buy-$shopperLineTomato'), findsOneWidget);
  });

  testWidgets('an agreed smaller quantity is the one to buy', (
    WidgetTester tester,
  ) async {
    final AppLocalizations words = await openShopping(tester, <Object?>[
      shopperLineJson(
        patch: <String, Object?>{
          'quantity': '3.000',
          'approved_quantity_cap': '2.000',
        },
      ),
    ]);
    final Finder card = byKey('shopper-line-$shopperLineTomato');
    final String capped = '2 ${words.unitKg}';

    // The chip reads the cap; the note names it beside what was ordered.
    expect(
      find.descendant(of: card, matching: find.text(capped)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(
          words.shopperCapAgreed(capped, '3 ${words.unitKg}'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(words.shopperCapBuy(capped)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an authorized replacement shows in its own box', (
    WidgetTester tester,
  ) async {
    final AppLocalizations words = await openShopping(tester, <Object?>[
      shopperLineJson(
        patch: <String, Object?>{'replacement': shopperReplacementJson()},
      ),
      shopperLineJson(
        bread: true,
        patch: <String, Object?>{
          'replacement': shopperReplacementJson(resolution: 'approved'),
        },
      ),
    ]);
    final String own = 'shopper-line-replacement-$shopperLineTomato';
    final String agreed = 'shopper-line-replacement-$shopperLineBread';

    expect(inKey(own, words.itemReplacedWith('Olcha pomidor')), findsOneWidget);
    expect(inKey(own, words.shopperReplacementAutomatic), findsOneWidget);
    expect(
      inKey(own, words.shopperReplacementPrices(money(15500), money(18400))),
      findsOneWidget,
    );
    expect(inKey(agreed, words.shopperReplacementApproved), findsOneWidget);
    expect(byKey('shopper-line-limit-$shopperLineTomato'), findsNothing);
  });

  testWidgets('a waiting line says what was asked and until when', (
    WidgetTester tester,
  ) async {
    const String third = '0192f0a0-0000-7000-8000-00000000e005';
    final AppLocalizations words = await openShopping(tester, <Object?>[
      asked('price_over_tolerance'),
      asked('substitution', id: shopperLineBread),
      asked('reduced_quantity', id: third),
    ]);

    expect(
      shown(tester, 'shopper-line-question-$shopperLineTomato'),
      words.shopperAskedPrice('13:00'),
    );
    expect(
      shown(tester, 'shopper-line-question-$shopperLineBread'),
      words.shopperAskedSubstitution('13:00'),
    );
    expect(
      shown(tester, 'shopper-line-question-$third'),
      words.shopperAskedQuantity('13:00'),
    );
    expect(find.text(words.shopperWaitBuyOthers), findsNWidgets(3));
    expect(byKey('buy-$shopperLineTomato'), findsNothing);
    expect(byKey('unavailable-$shopperLineTomato'), findsNothing);
  });

  testWidgets('a question the Customer let lapse waits for the Operator', (
    WidgetTester tester,
  ) async {
    final AppLocalizations words = await openShopping(tester, <Object?>[
      shopperLineJson(
        status: 'awaiting_customer',
        patch: <String, Object?>{'pending_approval': null},
      ),
    ]);

    expect(
      shown(tester, 'shopper-line-question-$shopperLineTomato'),
      words.shopperQuestionExpired,
    );
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    expect(byKey('buy-$shopperLineTomato'), findsNothing);
  });

  testWidgets('a done line says what was bought or why it went', (
    WidgetTester tester,
  ) async {
    const String replaced = '0192f0a0-0000-7000-8000-00000000e006';
    const String gone = '0192f0a0-0000-7000-8000-00000000e007';
    const String fixed = '0192f0a0-0000-7000-8000-00000000e008';
    final AppLocalizations words = await openShopping(tester, <Object?>[
      shopperLineJson(status: 'purchased'),
      shopperLineJson(
        status: 'purchased',
        patch: <String, Object?>{
          'id': replaced,
          'replacement': shopperReplacementJson(),
          'purchase': <String, Object?>{
            'product_id': shopperProductCherry,
            'purchased_quantity': '2.100',
            'billable_quantity': '2.100',
            'actual_market_price_uzs': 15500,
            'billable_unit_price_uzs': 17825,
            'line_total_uzs': 37433,
          },
        },
      ),
      shopperLineJson(
        bread: true,
        status: 'removed',
        patch: <String, Object?>{'id': gone},
      ),
      shopperLineJson(
        bread: true,
        status: 'purchased',
        patch: <String, Object?>{'id': fixed},
      ),
    ]);

    expect(
      shown(tester, 'shopper-line-bought-$shopperLineTomato'),
      words.shopperBoughtAt('2 ${words.unitKg}', money(16500)),
    );
    expect(find.text(words.lineTagBought), findsNWidgets(2));
    expect(
      shown(tester, 'shopper-line-bought-$replaced'),
      words.shopperBoughtInstead(
        'Pomidor',
        '2,1 ${words.unitKg}',
        money(15500),
      ),
    );
    expect(
      find.descendant(
        of: byKey('shopper-line-$replaced'),
        matching: find.text('Olcha pomidor'),
      ),
      findsOneWidget,
    );
    expect(find.text(words.shopperTagReplaced), findsOneWidget);
    expect(
      shown(tester, 'shopper-line-bought-$fixed'),
      words.itemBought('2 ${words.unitPiece}'),
    );
    expect(
      inKey(
        'shopper-line-status-$gone',
        words.shopperTagRemoved(
          OrderLabels.removedReason(words, ItemRemovedReason.unavailable),
        ),
      ),
      findsOneWidget,
    );
    expect(inKey('shopper-line-$gone', '1 ${words.unitPiece}'), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: byKey('shopper-line-$gone'),
              matching: find.text('Non'),
            ),
          )
          .style!
          .decoration,
      TextDecoration.lineThrough,
    );
    expect(
      find.descendant(
        of: byKey('shopper-line-$gone'),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('the shopping page holds at the extremes '
        '(${language.languageCode})', (WidgetTester tester) async {
      final String wish = 'x' * 160;
      final String note = 'y' * 300;
      String id(int n) =>
          '0192f0a0-0000-7000-8000-0000000f${n.toString().padLeft(4, '0')}';
      final List<Object?> items = <Object?>[
        for (int n = 0; n < 12; n++)
          shopperLineJson(
            bread: n.isOdd,
            patch: <String, Object?>{
              'id': id(n),
              'customer_note': note,
              'market_price_uzs': 99999999,
              if (n.isEven)
                'bound': <String, Object?>{
                  'customer_unit_price_uzs': 99999999,
                  'market_price_uzs': 99999999,
                },
              if (n == 0)
                'replacement': shopperReplacementJson(resolution: 'approved'),
              if (n == 1) 'approved_quantity_cap': '1',
              if (n == 1) 'quantity': '2',
            },
          ),
        for (int n = 12; n < 15; n++) asked('price_over_tolerance', id: id(n)),
        shopperLineJson(
          status: 'awaiting_customer',
          patch: <String, Object?>{'id': id(15), 'pending_approval': null},
        ),
        for (int n = 16; n < 30; n++)
          shopperLineJson(
            status: n.isEven ? 'purchased' : 'removed',
            patch: <String, Object?>{'id': id(n)},
          ),
      ];
      shopper.details[shopperOrderA] = ShopperOrdersApi.parseOrder(
        shopperOrderJson(status: 'shopping', items: items)
          ..['delivery_time_note'] = wish,
      );
      await open(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        device: language,
      );
      await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
      expect(tester.takeException(), isNull);
      await tester.drag(byKey('shopper-order'), const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  List<Color> bar(WidgetTester tester) => tester
      .widget<SegmentBar>(
        find.descendant(
          of: byKey('shopper-order-status'),
          matching: find.byType(SegmentBar),
        ),
      )
      .segments;

  Finder inStatus(String text) => find.descendant(
    of: byKey('shopper-order-status'),
    matching: find.text(text),
  );

  testWidgets('a new order is reviewed and accepted', (
    WidgetTester tester,
  ) async {
    shopper.afterAction[shopperOrderA] = shopperOrder(accepted: true);
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final AppLocalizations words = l10n(tester);

    expect(inStatus(words.shopperStatusNew), findsOneWidget);
    expect(inStatus(words.shopperStatusNewHint), findsOneWidget);
    expect(inStatus(words.shopperStepAssigned), findsOneWidget);
    expect(inStatus(words.shopperStepAccepted), findsOneWidget);
    expect(inStatus(words.shopperStepShopping), findsOneWidget);
    expect(inStatus(words.shopperStepDone), findsOneWidget);
    expect(
      inStatus(TashkentTime.time(DateTime.utc(2026, 9, 27, 7, 5))),
      findsOneWidget,
    );
    final List<Color> segments = bar(tester);
    expect(segments, hasLength(4));
    expect(segments.where((Color c) => c == KitColors.primary), hasLength(1));
    expect(find.text(words.checkoutItems(2)), findsOneWidget);
    expect(find.text(words.shopperPhoneLater), findsOneWidget);
    expect(byKey('call-customer'), findsNothing);
    expect(find.text(words.shopperDeliveryWish('Kechqurun')), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('shopper-accept'),
        matching: find.text(words.shopperAccept),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('shopper-accept'));
    expect(shopper.actions, <String>['accept:$shopperOrderA']);
    expect(byKey('shopper-accept'), findsNothing);
  });

  testWidgets('an accepted order is started at the market', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopperOrder(accepted: true);
    shopper.afterAction[shopperOrderA] = shopperOrder(status: 'shopping');
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final AppLocalizations words = l10n(tester);

    expect(inStatus(words.shopperStatusAccepted), findsOneWidget);
    expect(inStatus(words.shopperStartAtMarket), findsOneWidget);
    expect(
      bar(tester).where((Color c) => c == KitColors.primary),
      hasLength(2),
    );
    expect(byKey('shopper-accept'), findsNothing);
    expect(
      find.descendant(
        of: byKey('shopper-start'),
        matching: find.text(words.shopperStart),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('shopper-start'));
    expect(shopper.actions, <String>['start:$shopperOrderA']);
    expect(byKey('shopper-start'), findsNothing);
  });

  testWidgets('while shopping the Customer is one tap away', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopperOrder(status: 'shopping');
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final AppLocalizations words = l10n(tester);
    final Finder card = byKey('call-customer');

    expect(
      find.descendant(of: card, matching: find.text(words.shopperCallCustomer)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('+998 90 111 22 33')),
      findsOneWidget,
    );
    expect(find.text(words.shopperPhoneLater), findsNothing);

    await tapAndSettle(tester, card);
    expect(phone.calls, <String>['+998901112233']);
    expect(find.text(words.callFailed('+998 90 111 22 33')), findsNothing);

    // A phone that cannot place the call says so, with the number.
    phone.opens = false;
    await tapAndSettle(tester, card);
    expect(find.text(words.callFailed('+998 90 111 22 33')), findsOneWidget);
  });

  testWidgets('the shopping card counts the lines', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: <Object?>[
        lineWith('1', 'pending'),
        lineWith('2', 'pending', bread: true),
        shopperAskedLineJson('price_over_tolerance')
          ..['id'] = '0192f0a0-0000-7000-8000-00000000e003',
        lineWith('4', 'purchased'),
        lineWith('5', 'removed', bread: true),
      ],
    );
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final AppLocalizations words = l10n(tester);
    final DateTime started = DateTime.utc(2026, 9, 27, 7, 7);

    expect(inStatus(words.shopperStatusShopping), findsOneWidget);
    expect(
      inStatus(
        words.shopperShoppingHint(
          orderAtLower(words, started, DateTime.utc(2026, 9, 27, 9)),
          3,
          5,
        ),
      ),
      findsOneWidget,
    );
    expect(bar(tester), <Color>[
      KitColors.primary,
      KitColors.primary,
      KitColors.warning,
      KitColors.line,
      KitColors.line,
    ]);
    expect(inStatus(words.shopperLegendDone(2)), findsOneWidget);
    expect(inStatus(words.shopperLegendWaiting(1)), findsOneWidget);
    expect(inStatus(words.shopperLegendToBuy(2)), findsOneWidget);

    // A count of zero is left out of the legend.
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: <Object?>[lineWith('1', 'pending'), lineWith('4', 'purchased')],
    );
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(inStatus(words.shopperLegendDone(1)), findsOneWidget);
    expect(inStatus(words.shopperLegendToBuy(1)), findsOneWidget);
    expect(inStatus(words.shopperLegendWaiting(0)), findsNothing);
  });

  testWidgets('the completion is held while lines are open', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: <Object?>[
        lineWith('1', 'pending'),
        lineWith('2', 'pending', bread: true),
        lineWith('3', 'purchased'),
        shopperAskedLineJson('price_over_tolerance')
          ..['id'] = '0192f0a0-0000-7000-8000-00000000e004',
      ],
    );
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));

    expect(find.text(l10n(tester).shopperResolveFirst(3)), findsOneWidget);
    expect(
      tester.widget<FilledButton>(byKey('shopper-complete')).onPressed,
      isNull,
    );
  });

  testWidgets('all resolved, the shopping completes', (
    WidgetTester tester,
  ) async {
    shopper.details[shopperOrderA] = shopperOrder(
      status: 'shopping',
      items: <Object?>[
        lineWith('1', 'purchased'),
        lineWith('2', 'purchased', bread: true),
        lineWith('3', 'removed'),
      ],
    );
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final AppLocalizations words = l10n(tester);

    expect(inStatus(words.shopperStatusResolved), findsOneWidget);
    expect(inStatus(words.shopperResolvedHint(2, 1)), findsOneWidget);
    expect(bar(tester), everyElement(KitColors.primary));
    expect(find.textContaining(words.shopperResolveFirst(0)), findsNothing);
    expect(
      tester.widget<FilledButton>(byKey('shopper-complete')).onPressed,
      isNotNull,
    );

    await tapAndSettle(tester, byKey('shopper-complete'));
    final Finder sheet = byKey('complete-sheet');
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet(words.completeTitle), findsOneWidget);
    expect(inSheet(words.shopperCompleteBought), findsOneWidget);
    expect(inSheet(words.orderItemCount(2)), findsOneWidget);
    expect(inSheet(words.shopperCompleteRemoved), findsOneWidget);
    expect(inSheet(words.orderItemCount(1)), findsOneWidget);
    expect(inSheet(words.completeExplained), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('complete-confirm'),
        matching: find.text(words.completeConfirm),
      ),
      findsOneWidget,
    );
    expect(shopper.actions, isEmpty);
  });

  testWidgets('back on the list, an accepted order is shown as it now is', (
    WidgetTester tester,
  ) async {
    shopper.afterAction[shopperOrderA] = shopperOrder(accepted: true);
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final int before = count('orders:1');

    await tapAndSettle(tester, byKey('shopper-accept'));
    await tapAndSettle(tester, find.byType(BackButton));

    expect(count('orders:1'), greaterThan(before));
  });

  testWidgets('the buttons stay usable while the order refreshes itself', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final Completer<void> refresh = Completer<void>();
    shopper.holdOrder = refresh;

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(count('order:$shopperOrderA'), 2, reason: 'the refresh runs');
    expect(
      tester.widget<FilledButton>(byKey('shopper-accept')).onPressed,
      isNotNull,
    );

    shopper.holdOrder = null;
    refresh.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the list pages, and a page a refresh emptied leads back', (
    WidgetTester tester,
  ) async {
    final ShopperOrderRow first = shopper.rows.first;
    final ShopperOrderRow second = shopper.rows.last;
    shopper
      ..pages = <int, List<ShopperOrderRow>>{
        1: <ShopperOrderRow>[first],
        2: <ShopperOrderRow>[second],
      }
      ..lastPage = 2;
    await open(tester);

    await tapAndSettle(tester, byKey('next-page'));
    expect(shopper.loads, contains('orders:2'));
    expect(byKey('shopper-order-$shopperOrderB'), findsOneWidget);

    // The order on page 2 is handed over; the next refresh finds it empty.
    shopper
      ..pages = <int, List<ShopperOrderRow>>{
        1: <ShopperOrderRow>[first],
      }
      ..lastPage = 1;
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(byKey('shopper-page-empty'), findsOneWidget);
    expect(byKey('shopper-orders-empty'), findsNothing);

    await tapAndSettle(tester, byKey('previous-page'));
    expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);
  });

  testWidgets('a refusal is said and the order loaded again', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    shopper
      ..actionFailure = const ApiRefusal(
        ApiError(status: 409, code: 'order_state_conflict'),
      )
      ..loads.clear();

    await tapAndSettle(tester, byKey('shopper-accept'));

    expect(find.text(l10n(tester).errorOrderStateConflict), findsOneWidget);
    expect(shopper.loads, contains('order:$shopperOrderA'));
  });

  testWidgets('one action at a time; once it is answered, the next is '
      'offered even while a refresh runs', (WidgetTester tester) async {
    shopper.afterAction[shopperOrderA] = shopperOrder(accepted: true);
    await open(tester);
    await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
    final Completer<void> hold = Completer<void>();
    shopper.hold = hold;

    await tester.tap(byKey('shopper-accept'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(byKey('shopper-accept')).onPressed,
      isNull,
      reason: 'the acceptance runs',
    );
    await tester.tap(byKey('shopper-accept'), warnIfMissed: false);
    shopper.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(shopper.actions, <String>['accept:$shopperOrderA']);

    // A refresh held after the action does not hold the start.
    final Completer<void> refresh = Completer<void>();
    shopper.holdOrder = refresh;
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(byKey('shopper-start')).onPressed,
      isNotNull,
    );
    shopper.holdOrder = null;
    refresh.complete();
    await tester.pumpAndSettle();
  });

  group('the refresh while shown (DL-54 (15))', () {
    testWidgets('the list and the order ask again every ten seconds, and the '
        'list waits while an order is opened over it', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(count('orders:1'), 1);

      await tester.pump(const Duration(seconds: 9));
      expect(count('orders:1'), 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(count('orders:1'), 2);

      await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
      final int list = count('orders:1');
      expect(count('order:$shopperOrderA'), 1);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(count('order:$shopperOrderA'), 3);
      expect(count('orders:1'), list, reason: 'the list is not shown');
    });

    testWidgets('a refresh slower than ten seconds is not started again', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final Completer<void> slow = Completer<void>();
      shopper.hold = slow;

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(count('orders:1'), 2);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(count('orders:1'), 2, reason: 'the running load is left alone');

      shopper.hold = null;
      slow.complete();
      await tester.pumpAndSettle();
      expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);
    });

    testWidgets('the retry of a failed list or order shows it loading', (
      WidgetTester tester,
    ) async {
      await open(tester);
      shopper.listFailure = const NetworkFailure();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      shopper.listFailure = null;
      Completer<void> hold = Completer<void>();
      shopper.hold = hold;

      await tester.tap(byKey('retry-load'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n(tester).errorNetwork), findsNothing);
      shopper.hold = null;
      hold.complete();
      await tester.pumpAndSettle();

      await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
      shopper.orderFailure = const NetworkFailure();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
      shopper.orderFailure = null;
      hold = Completer<void>();
      shopper.hold = hold;

      await tester.tap(byKey('retry-load'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n(tester).errorNetwork), findsNothing);
      shopper.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'a refresh that fails stops, says so, and waits for the retry',
      (WidgetTester tester) async {
        await open(tester);
        shopper.listFailure = const NetworkFailure();

        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(count('orders:1'), 2);
        expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

        await tester.pump(const Duration(seconds: 60));
        await tester.pumpAndSettle();
        expect(count('orders:1'), 2, reason: 'a refresh is not a retry');

        shopper.listFailure = null;
        await tapAndSettle(tester, byKey('retry-load'));
        expect(count('orders:1'), 3);
        expect(byKey('shopper-order-$shopperOrderA'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        expect(count('orders:1'), 4, reason: 'the refresh comes back');
      },
    );
  });

  testWidgets('the app bar holds one menu; the menu holds Customer mode and '
      'the way out', (WidgetTester tester) async {
    // The customer session opened with the code that signed in.
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
    await open(tester, size: const Size(360, 800));
    final AppLocalizations words = l10n(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(words.myOrders),
      ),
      findsOneWidget,
    );
    expect(find.byType(LanguageMenuButton), findsNothing);
    expect(byKey('logout-button'), findsNothing);
    await tapAndSettle(tester, byKey('staff-menu'));
    expect(find.text(words.switchToCustomer), findsOneWidget);
    await tapAndSettle(tester, byKey('logout-button'));

    expect(auth.calls, contains('logout:staff'));
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the list holds at 320x640 with text x2 (${language.languageCode})',
      (WidgetTester tester) async {
        shopper.rows = <ShopperOrderRow>[
          ShopperOrdersApi.parseRow(
            shopperRowJson()..['delivery_time_note'] = 'после 18:00',
          ),
          ShopperOrdersApi.parseRow(
            shopperRowJson(id: shopperOrderB, number: 1002, accepted: true),
          ),
          ShopperOrdersApi.parseRow(
            shopperRowJson(
              id: '0192f0a0-0000-7000-8000-00000000d003',
              number: 1003,
              status: 'shopping',
              accepted: true,
              open: 1,
            ),
          ),
        ];
        tokens.tokens[SessionSlot.customer] = 'c';
        auth.identities[SessionSlot.customer] = user(id: 'c');
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: language,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(byKey('shopper-orders'), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tapAndSettle(tester, byKey('staff-menu'));
        expect(byKey('staff-menu-sheet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('the order page holds at 320x640 with text x2 '
        '(${language.languageCode})', (WidgetTester tester) async {
      final Map<String, ShopperOrder> stages = <String, ShopperOrder>{
        'assigned': shopperOrder(),
        'accepted': shopperOrder(accepted: true),
        'open lines': shopperOrder(
          status: 'shopping',
          items: <Object?>[
            lineWith('1', 'pending'),
            lineWith('2', 'pending', bread: true),
            shopperAskedLineJson('price_over_tolerance')
              ..['id'] = '0192f0a0-0000-7000-8000-00000000e003',
            lineWith('4', 'purchased'),
          ],
        ),
        'resolved': shopperOrder(
          status: 'shopping',
          items: <Object?>[
            lineWith('1', 'purchased'),
            lineWith('2', 'removed', bread: true),
          ],
        ),
      };
      for (final MapEntry<String, ShopperOrder> stage in stages.entries) {
        shopper.details[shopperOrderA] = stage.value;
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: language,
        );
        await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
        expect(tester.takeException(), isNull, reason: stage.key);
        await tester.drag(byKey('shopper-order'), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: stage.key);
        if (stage.key == 'resolved') {
          await tapAndSettle(tester, byKey('shopper-complete'));
          expect(byKey('complete-sheet'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'the sheet');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets('a phone-wide window with large text fits the list and an order '
      'in both languages', (WidgetTester tester) async {
    shopper.details[shopperOrderA] = shopperOrder(status: 'shopping');
    for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
      await open(
        tester,
        size: const Size(360, 800),
        textScale: 2,
        device: language,
      );
      expect(tester.takeException(), isNull);
      await tapAndSettle(tester, byKey('shopper-order-$shopperOrderA'));
      await tester.drag(byKey('shopper-order'), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The next language starts from a fresh app, not this one's route.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
