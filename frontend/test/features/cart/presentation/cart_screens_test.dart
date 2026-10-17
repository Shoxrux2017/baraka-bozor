import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/failure_text.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_screen.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';

/// The cart of `docs/09` section 17 through the real router, catalog and
/// cart screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
  late FakeCartRepository cart;
  late FakeAddressesRepository addresses;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    catalog = FakeCatalogRepository(
      categories: <CatalogCategory>[catalogCategory()],
      products: <CatalogProduct>[
        catalogProduct(id: tomatoProduct),
        catalogProduct(
          id: breadProduct,
          nameUz: 'Non',
          nameRu: 'Хлеб',
          unitCode: UnitCode.piece,
          priceMode: PriceMode.fixed,
          customerUnitPriceUzs: 4000,
        ),
      ],
    );
    cart = FakeCartRepository();
    addresses = FakeAddressesRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    String? at,
    Size size = const Size(800, 1600),
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
        cart: cart,
        addresses: addresses,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    if (at != null) {
      GoRouter.of(anywhere(tester)).push(at);
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('adding from the product screen', () {
    testWidgets(
      'a kg product is added with a stepped quantity, a note and the rule',
      (WidgetTester tester) async {
        await open(tester, at: '/customer/products/$tomatoProduct');
        cart.answer = cartOf(<Map<String, Object?>>[
          cartLineJson(productId: tomatoProduct, quantity: '1.500'),
        ]);

        await tester.tap(byKey('product-plus'));
        await tester.pumpAndSettle();
        await tester.enterText(byKey('line-note'), '  Qizilini oling ');
        await tapAndSettle(tester, byKey('add-to-cart'));

        final NewCartLine sent = cart.added.single;
        expect(sent.productId, tomatoProduct);
        expect(sent.quantity, '1.5');
        expect(sent.customerNote, 'Qizilini oling');
        expect(sent.substitutionPolicy, SubstitutionPolicy.allowSimilar);
        expect(find.text(l10n(tester).cartAdded), findsOneWidget);

        // The notice goes by itself, action or not.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text(l10n(tester).cartAdded), findsNothing);

        // The cart holds the line the server answered.
        GoRouter.of(anywhere(tester)).push('/customer/cart');
        await tester.pumpAndSettle();
        expect(find.byType(CartScreen), findsOneWidget);
        expect(find.text('Pomidor'), findsOneWidget);
      },
    );

    testWidgets('a piece product steps whole numbers, from one', (
      WidgetTester tester,
    ) async {
      await open(tester, at: '/customer/products/$breadProduct');
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '3',
        ),
      ]);

      expect(
        tester.widget<IconButton>(byKey('product-minus')).onPressed,
        isNull,
        reason: 'one piece is the least',
      );
      await tapAndSettle(tester, byKey('product-plus'));
      await tapAndSettle(tester, byKey('product-plus'));
      expect(find.text('3 dona'), findsOneWidget);

      await tester.ensureVisible(byKey('line-substitution'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('substitution-remove_if_unavailable'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, byKey('add-to-cart'));

      expect(cart.added.single.quantity, '3');
      expect(
        cart.added.single.substitutionPolicy,
        SubstitutionPolicy.removeIfUnavailable,
      );
    });

    testWidgets(
      'a product already in the cart refreshes the cart and makes no second line',
      (WidgetTester tester) async {
        cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
        await open(tester, at: '/customer/products/$breadProduct');
        // Another device put the bread in the cart after this one looked.
        cart.current = cartOf(<Map<String, Object?>>[
          cartLineJson(),
          cartLineJson(
            id: breadLine,
            productId: breadProduct,
            unit: 'piece',
            quantity: '2',
          ),
        ]);
        cart.calls.clear();
        cart.failure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'cart_item_already_exists',
            details: <String, Object?>{'cart_item_id': breadLine},
          ),
        );

        await tapAndSettle(tester, byKey('add-to-cart'));

        expect(cart.added, hasLength(1), reason: 'only the refused add');
        expect(cart.calls, contains('cart'), reason: 'asked for again');
        expect(find.byType(CartScreen), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text(l10n(tester).cartAdded), findsNothing);
      },
    );

    testWidgets('a second notice replaces the first rather than queueing', (
      WidgetTester tester,
    ) async {
      await open(tester, at: '/customer/products/$tomatoProduct');
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct, quantity: '1.500'),
      ]);
      await tester.tap(byKey('product-plus'));
      await tester.pump();
      // Frame by frame, so the notice's timer starts as it would.
      Future<void> wait(Duration time) async {
        for (int i = 0; i < time.inMilliseconds ~/ 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.tap(byKey('add-to-cart'));
      await wait(const Duration(seconds: 1));

      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct, quantity: '1.500'),
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '1',
        ),
      ]);
      GoRouter.of(anywhere(tester)).push('/customer/products/$breadProduct');
      await wait(const Duration(milliseconds: 500));
      await tester.tap(byKey('add-to-cart'));
      await wait(const Duration(seconds: 1));
      expect(find.text(l10n(tester).cartAdded), findsOneWidget);

      // Queued, the second would only show once the first had gone, at about
      // four and a half seconds in, and stay until about nine.
      await wait(const Duration(seconds: 4));
      expect(find.text(l10n(tester).cartAdded), findsNothing);
    });

    testWidgets(
      'the notice stays behind when the Customer goes to the checkout',
      (WidgetTester tester) async {
        await open(tester, at: '/customer/products/$tomatoProduct');
        cart.answer = cartOf(<Map<String, Object?>>[
          cartLineJson(productId: tomatoProduct, quantity: '1.500'),
        ]);
        await tester.tap(byKey('product-plus'));
        await tester.pump();
        await tapAndSettle(tester, byKey('add-to-cart'));
        // By the router: the notice's own action would dismiss the notice.
        GoRouter.of(anywhere(tester)).push('/customer/cart');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(l10n(tester).cartAdded), findsOneWidget);

        await tester.tap(byKey('go-to-checkout'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(l10n(tester).cartAdded), findsNothing);
      },
    );

    testWidgets(
      'an answer that arrives after the Customer left the product navigates nowhere',
      (WidgetTester tester) async {
        await open(tester, at: '/customer/products/$tomatoProduct');
        cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
        final Completer<void> hold = Completer<void>();
        cart
          ..hold = hold
          ..failure = const ApiRefusal(
            ApiError(
              status: 409,
              code: 'cart_item_already_exists',
              details: <String, Object?>{'cart_item_id': tomatoLine},
            ),
          );

        await tester.tap(byKey('add-to-cart'));
        await tester.pump();
        // The Customer opens the cart while the add is on its way.
        GoRouter.of(anywhere(tester)).push('/customer/cart');
        await tester.pump();
        cart.hold = null;
        hold.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CartScreen), findsOneWidget, reason: 'not a second');
        expect(find.byType(BottomSheet), findsNothing);
      },
    );

    testWidgets(
      "the snackbar's way to the cart works after the product was left",
      (WidgetTester tester) async {
        await open(tester, at: '/customer/products/$tomatoProduct');
        cart.answer = cartOf(<Map<String, Object?>>[
          cartLineJson(productId: tomatoProduct),
        ]);
        await tapAndSettle(tester, byKey('add-to-cart'));

        GoRouter.of(anywhere(tester)).pop();
        await tester.pump();
        await tester.tap(find.text(l10n(tester).cartOpen));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CartScreen), findsOneWidget);
      },
    );

    testWidgets('what the Customer set survives scrolling the page', (
      WidgetTester tester,
    ) async {
      catalog = FakeCatalogRepository(
        categories: <CatalogCategory>[catalogCategory()],
        products: <CatalogProduct>[
          catalogProduct(
            id: tomatoProduct,
            descriptionUz: List<String>.filled(
              600,
              'Juda mazali pomidor.',
            ).join(' '),
          ),
        ],
      );
      await open(
        tester,
        at: '/customer/products/$tomatoProduct',
        size: const Size(360, 640),
      );

      // The page's own scroll view, not a text field's.
      final Finder page = find
          .descendant(
            of: find.byType(SingleChildScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        byKey('line-note'),
        600,
        scrollable: page,
      );
      await tester.enterText(byKey('line-note'), 'Qizilini oling');
      await tester.ensureVisible(byKey('substitution-remove_if_unavailable'));
      await tester.tap(byKey('substitution-remove_if_unavailable'));
      await tester.pumpAndSettle();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.drag(page, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        byKey('line-note'),
        600,
        scrollable: page,
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(byKey('line-note')).controller!.text,
        'Qizilini oling',
      );
      expect(
        tester.widget<Text>(byKey('product-qty')).data,
        '1,5 kg',
        reason: 'the bar is not part of the scrolling page',
      );
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(cart.added.single.quantity, '1.5');
      expect(
        cart.added.single.substitutionPolicy,
        SubstitutionPolicy.removeIfUnavailable,
      );
    });

    testWidgets(
      'a note is counted as the server counts it and trimmed as it trims',
      (WidgetTester tester) async {
        await open(tester, at: '/customer/products/$tomatoProduct');

        // 151 flags: 151 marks to the eye, 302 code points to the server.
        await tester.enterText(
          byKey('line-note'),
          List<String>.filled(151, '\u{1F1FA}\u{1F1FF}').join(),
        );
        await tapAndSettle(tester, byKey('add-to-cart'));
        expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
        expect(cart.added, isEmpty);

        // 300 tomatoes: 300 code points, 600 UTF-16 units \u2014 within the limit.
        final String tomatoes = List<String>.filled(300, '\u{1F345}').join();
        await tester.enterText(byKey('line-note'), tomatoes);
        await tapAndSettle(tester, byKey('add-to-cart'));
        expect(cart.added.single.customerNote, tomatoes);

        // A trailing zero-width space is trimmed by the server, not counted.
        await tester.enterText(byKey('line-note'), '$tomatoes\u200B');
        await tapAndSettle(tester, byKey('add-to-cart'));
        expect(cart.added, hasLength(2), reason: 'sent, not refused');
        expect(cart.added.last.customerNote, tomatoes);

        await tester.enterText(byKey('line-note'), '\u200B Qizilini \u200E');
        await tapAndSettle(tester, byKey('add-to-cart'));
        expect(cart.added.last.customerNote, 'Qizilini');
      },
    );

    testWidgets('a full cart and a product gone have their own words', (
      WidgetTester tester,
    ) async {
      await open(tester, at: '/customer/products/$tomatoProduct');

      cart.failure = const ApiRefusal(ApiError(status: 409, code: 'cart_full'));
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(find.text(l10n(tester).errorCartFull), findsOneWidget);

      cart.failure = const ApiRefusal(
        ApiError(status: 409, code: 'product_unavailable'),
      );
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(find.text(l10n(tester).errorProductUnavailable), findsOneWidget);
    });
  });

  group('the cart screen', () {
    testWidgets('shows the lines as the server priced them', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(),
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '2',
          available: false,
        ),
      ], subtotal: 99999);
      await open(tester, at: '/customer/cart');
      final AppLocalizations words = l10n(tester);

      expect(byKey('cart-line-$tomatoLine'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('line-qty-$tomatoLine'),
          matching: find.text('1,5 ${words.unitKg}'),
        ),
        findsOneWidget,
        reason: 'with the decimal comma, without trailing zeros',
      );
      expect(
        tester.widget<Text>(byKey('line-sum-$tomatoLine')).data,
        words.cartLineEstimate(MoneyFormat.uzs(27600, AppLanguage.uz)),
      );
      expect(
        find.text(
          words.cartUnitPrice(
            words.unitKg,
            MoneyFormat.uzs(18400, AppLanguage.uz),
          ),
        ),
        findsOneWidget,
      );
      expect(byKey('cart-line-unavailable-$breadLine'), findsOneWidget);
      expect(byKey('remove-line-$breadLine'), findsOneWidget);
      expect(
        byKey('cart-line-$breadLine'),
        findsNothing,
        reason: 'an unavailable line is removed, not opened',
      );
      expect(find.text(words.cartUnavailableHint), findsOneWidget);
      expect(
        tester.widget<Text>(byKey('cart-subtotal')).data,
        words.cartLineEstimate(MoneyFormat.uzs(99999, AppLanguage.uz)),
        reason: 'the client never sums money',
      );
    });

    testWidgets('a step sends only the quantity', (WidgetTester tester) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson(note: 'Eski')]);
      await open(tester, at: '/customer/cart');
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(quantity: '2.000', total: 36800, note: 'Eski'),
      ]);

      await tapAndSettle(tester, byKey('line-plus-$tomatoLine'));

      final CartLinePatch patch = cart.patches.single;
      expect(patch.quantity, '2');
      expect(patch.noteChanged, isFalse);
      expect(patch.substitutionPolicy, isNull);
      expect(
        find.descendant(
          of: byKey('line-qty-$tomatoLine'),
          matching: find.text('2 ${l10n(tester).unitKg}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("a line's buttons wait while its change runs", (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');
      bool active(String key) =>
          (tester.widget(byKey(key)) is IconButton
              ? tester.widget<IconButton>(byKey(key)).onPressed
              : tester.widget<InkWell>(byKey(key)).onTap) !=
          null;
      expect(active('line-minus-$tomatoLine'), isTrue);
      expect(active('line-plus-$tomatoLine'), isTrue);
      expect(active('line-qty-$tomatoLine'), isTrue);

      final Completer<void> hold = Completer<void>();
      cart
        ..hold = hold
        ..answer = cartOf(<Map<String, Object?>>[
          cartLineJson(quantity: '2.000', total: 36800),
        ]);
      await tester.tap(byKey('line-plus-$tomatoLine'));
      await tester.pump();

      expect(active('line-minus-$tomatoLine'), isFalse);
      expect(active('line-plus-$tomatoLine'), isFalse);
      expect(active('line-qty-$tomatoLine'), isFalse);

      cart.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(
        active('line-plus-$tomatoLine'),
        isTrue,
        reason: 'with the answer',
      );
    });

    testWidgets('two quick taps send one change', (WidgetTester tester) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');
      final Completer<void> hold = Completer<void>();
      cart.hold = hold;

      await tester.tap(byKey('line-plus-$tomatoLine'));
      await tester.pump();
      await tester.tap(byKey('line-plus-$tomatoLine'), warnIfMissed: false);
      await tester.pump();

      expect(cart.patches, hasLength(1));
      cart.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a whole-unit line that kept its decimals is set anew', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(unit: 'piece', quantity: '1.500'),
      ]);
      await open(tester, at: '/customer/cart');

      expect(
        tester.widget<IconButton>(byKey('line-minus-$tomatoLine')).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(byKey('line-plus-$tomatoLine')).onPressed,
        isNull,
      );

      await tapAndSettle(tester, byKey('line-qty-$tomatoLine'));
      expect(
        tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
        isEmpty,
      );
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(unit: 'piece', quantity: '2'),
      ]);
      await tester.enterText(byKey('line-quantity'), '2');
      await tapAndSettle(tester, byKey('quantity-done'));

      expect(cart.patches.single.quantity, '2');
    });

    testWidgets('minus at the smallest step asks first', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '1',
          priceMode: 'fixed',
          price: 4000,
          total: 4000,
        ),
      ]);
      await open(tester, at: '/customer/cart');

      await tapAndSettle(tester, byKey('line-minus-$breadLine'));
      expect(find.text(l10n(tester).cartRemoveTitle), findsOneWidget);
      await tapAndSettle(tester, byKey('remove-cancel'));
      expect(cart.calls.where((String c) => c.startsWith('remove')), isEmpty);
      expect(byKey('remove-confirm'), findsNothing);

      cart.answer = cartOf(<Map<String, Object?>>[]);
      await tapAndSettle(tester, byKey('line-minus-$breadLine'));
      await tapAndSettle(tester, byKey('remove-confirm'));
      expect(cart.calls.last, 'remove:$breadLine');
    });

    testWidgets('minus above the step changes the quantity', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '2',
          priceMode: 'fixed',
          price: 4000,
          total: 8000,
        ),
      ]);
      await open(tester, at: '/customer/cart');

      await tapAndSettle(tester, byKey('line-minus-$breadLine'));

      expect(cart.patches.single.quantity, '1');
      expect(find.text(l10n(tester).cartRemoveTitle), findsNothing);
    });

    testWidgets('the quantity opens the exact-amount sheet', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(quantity: '2.250', total: 41400),
      ]);

      await tapAndSettle(tester, byKey('line-qty-$tomatoLine'));
      await tester.enterText(byKey('line-quantity'), '2,25');
      await tapAndSettle(tester, byKey('quantity-done'));

      expect(cart.patches.single.quantity, '2.25');
    });

    testWidgets('an available line opens its product', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');

      await tapAndSettle(tester, byKey('cart-line-$tomatoLine'));

      expect(
        GoRouter.of(anywhere(tester))
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        '/customer/products/$tomatoProduct',
      );
    });

    testWidgets('the rule and the note show only when set', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');
      expect(byKey('line-rule-$tomatoLine'), findsNothing);
      expect(byKey('line-note-$tomatoLine'), findsNothing);

      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(policy: 'contact_before_substitution', note: 'без вмятин'),
      ]);
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      GoRouter.of(anywhere(tester)).push('/customer/cart');
      await tester.pumpAndSettle();

      expect(byKey('line-rule-$tomatoLine'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('line-note-$tomatoLine'),
          matching: find.text('без вмятин'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a step on a line gone elsewhere reloads the cart', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '1',
          priceMode: 'fixed',
          price: 4000,
          total: 4000,
        ),
      ]);
      await open(tester, at: '/customer/cart');
      const ApiRefusal gone = ApiRefusal(
        ApiError(status: 404, code: 'not_found'),
      );

      cart
        ..calls.clear()
        ..failure = gone;
      await tapAndSettle(tester, byKey('line-plus-$breadLine'));
      expect(
        find.text(failureText(l10n(tester), gone)!),
        findsOneWidget,
        reason: 'said, not crashed',
      );
      expect(cart.calls, contains('cart'), reason: 'asked for again');
      expect(tester.takeException(), isNull);

      cart
        ..calls.clear()
        ..failure = gone;
      await tapAndSettle(tester, byKey('line-minus-$breadLine'));
      await tapAndSettle(tester, byKey('remove-confirm'));
      expect(byKey('remove-confirm'), findsNothing, reason: 'no sheet stays');
      expect(cart.calls, contains('cart'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cart is asked for again whenever it opens', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final int before = cart.calls.where((String c) => c == 'cart').length;

      await tapAndSettle(tester, byKey('open-cart'));

      expect(
        cart.calls.where((String c) => c == 'cart').length,
        greaterThan(before),
      );
    });

    testWidgets('the cart shows the active mode while two sessions exist', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      await open(tester);
      await tapAndSettle(tester, byKey('staff-menu'));
      await tapAndSettle(tester, byKey('switch-to-customer-button'));

      await tapAndSettle(tester, byKey('open-cart'));

      expect(find.byType(CartScreen), findsOneWidget);
      expect(byKey('active-mode'), findsOneWidget);
    });

    testWidgets('a line no longer sold is removed at once, and an empty cart '
        'says so', (WidgetTester tester) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '2',
          available: false,
        ),
      ]);
      await open(tester, at: '/customer/cart');

      cart.answer = cartOf(<Map<String, Object?>>[]);
      await tapAndSettle(tester, byKey('remove-line-$breadLine'));

      expect(cart.calls, contains('remove:$breadLine'));
      expect(byKey('remove-confirm'), findsNothing, reason: 'no sheet');
      expect(byKey('cart-empty'), findsOneWidget);
      expect(find.text(l10n(tester).cartEmptyTitle), findsOneWidget);

      await tapAndSettle(tester, byKey('cart-to-catalog'));
      expect(
        GoRouter.of(anywhere(tester))
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        '/customer',
      );
    });

    testWidgets('the cart opens from the catalog home and counts its lines', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(),
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '2',
        ),
      ]);
      await open(tester);

      expect(
        find.descendant(of: byKey('open-cart'), matching: find.text('2')),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('open-cart'));
      expect(byKey('cart-lines'), findsOneWidget);
    });
  });

  group("the cart's amounts, minimum, add-more, address and footer", () {
    String sum(int amount) => MoneyFormat.uzs(amount, AppLanguage.uz);

    bool checkoutActive(WidgetTester tester) =>
        tester.widget<FilledButton>(byKey('go-to-checkout')).onPressed != null;

    String path(WidgetTester tester) =>
        GoRouter.of(anywhere(tester))
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation;

    testWidgets("the amounts are the server's", (WidgetTester tester) async {
      cart.current = cartOf(
        <Map<String, Object?>>[cartLineJson(total: 61410)],
        subtotal: 61410,
        serviceFee: 3000,
        deliveryFee: 12000,
        total: 76410,
      );
      await open(tester, at: '/customer/cart');
      final AppLocalizations words = l10n(tester);

      String shown(String key) => tester.widget<Text>(byKey(key)).data!;
      expect(shown('cart-subtotal'), '≈ ${sum(61410)}');
      expect(shown('cart-delivery'), sum(12000));
      expect(shown('cart-service-fee'), sum(3000));
      expect(shown('cart-total'), '≈ ${sum(76410)}');
      expect(byKey('cart-estimate-note'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('go-to-checkout'),
          matching: find.text('≈ ${sum(76410)}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('go-to-checkout'),
          matching: find.text(words.checkoutGo),
        ),
        findsOneWidget,
      );

      cart.current = cartOf(
        <Map<String, Object?>>[cartLineJson(total: 61410)],
        subtotal: 61410,
        serviceFee: 1380,
        serviceFeeKind: 'estimate',
        deliveryFee: 12000,
      );
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      GoRouter.of(anywhere(tester)).push('/customer/cart');
      await tester.pumpAndSettle();
      expect(shown('cart-service-fee'), '≈ ${sum(1380)}');
    });

    testWidgets('unset settings hide their rows and keep checkout open', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');

      expect(byKey('cart-subtotal'), findsOneWidget);
      expect(byKey('cart-delivery'), findsNothing);
      expect(byKey('cart-service-fee'), findsNothing);
      expect(byKey('cart-total'), findsNothing);
      expect(byKey('cart-minimum'), findsNothing);
      expect(byKey('cart-why'), findsNothing);
      expect(
        find.descendant(
          of: byKey('go-to-checkout'),
          matching: find.text(l10n(tester).checkoutGo),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('go-to-checkout'),
          matching: find.textContaining('≈'),
        ),
        findsNothing,
      );
      expect(checkoutActive(tester), isTrue);

      await tapAndSettle(tester, byKey('go-to-checkout'));
      expect(path(tester), '/customer/checkout');
    });

    testWidgets('a short subtotal shows the minimum and closes checkout', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(
        <Map<String, Object?>>[cartLineJson(total: 14835)],
        subtotal: 14835,
        minimum: 50000,
        shortfall: 35165,
      );
      await open(tester, at: '/customer/cart');
      final AppLocalizations words = l10n(tester);

      expect(
        find.descendant(
          of: byKey('cart-minimum'),
          matching: find.text(words.cartMinimumShort('≈ ${sum(35165)}')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('cart-minimum'),
          matching: find.text(words.cartMinimumRule(sum(50000))),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<LinearProgressIndicator>(byKey('cart-minimum-bar')).value,
        (50000 - 35165) / 50000,
      );
      expect(
        tester.widget<Text>(byKey('cart-why')).data,
        words.cartWhyMinimum(sum(50000)),
      );
      expect(checkoutActive(tester), isFalse);
    });

    testWidgets('the answer that reaches the minimum opens checkout', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(
        <Map<String, Object?>>[cartLineJson(total: 14835)],
        subtotal: 14835,
        minimum: 50000,
        shortfall: 35165,
      );
      await open(tester, at: '/customer/cart');
      expect(checkoutActive(tester), isFalse);

      cart.answer = cartOf(
        <Map<String, Object?>>[cartLineJson(quantity: '3.000', total: 55200)],
        subtotal: 55200,
        minimum: 50000,
        shortfall: 0,
      );
      await tapAndSettle(tester, byKey('line-plus-$tomatoLine'));

      expect(byKey('cart-minimum'), findsNothing);
      expect(byKey('cart-why'), findsNothing);
      expect(checkoutActive(tester), isTrue);
    });

    testWidgets('a line no longer sold closes checkout with its reason', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(),
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '2',
          available: false,
        ),
      ]);
      await open(tester, at: '/customer/cart');

      expect(
        tester.widget<Text>(byKey('cart-why')).data,
        l10n(tester).cartWhyUnavailable,
      );
      expect(checkoutActive(tester), isFalse);
    });

    testWidgets('Добавьте к заказу leaves out what is in the cart', (
      WidgetTester tester,
    ) async {
      const String third = '0192f0a0-0000-7000-8000-00000000cb03';
      catalog = FakeCatalogRepository(
        categories: <CatalogCategory>[catalogCategory()],
        products: <CatalogProduct>[
          catalogProduct(id: tomatoProduct),
          catalogProduct(
            id: breadProduct,
            nameUz: 'Non',
            unitCode: UnitCode.piece,
          ),
          catalogProduct(id: third, nameUz: 'Olma'),
        ],
      )..featuredIds = <String>{tomatoProduct, breadProduct, third};
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');

      Finder card(String id) =>
          find.descendant(of: byKey('cart-add-more'), matching: byKey(id));
      expect(card(tomatoProduct), findsNothing);
      expect(card(breadProduct), findsOneWidget);
      expect(card(third), findsOneWidget);
      expect(find.text(l10n(tester).cartAddMoreTitle), findsOneWidget);
      expect(byKey('open-recommended'), findsNothing, reason: 'no "Все"');

      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(),
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '1',
        ),
      ]);
      await tapAndSettle(tester, byKey('add-$breadProduct'));

      expect(cart.added.single.productId, breadProduct);
      expect(card(breadProduct), findsNothing);
      expect(card(third), findsOneWidget);

      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(),
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '1',
        ),
        cartLineJson(
          id: '0192f0a0-0000-7000-8000-00000000ca13',
          productId: third,
        ),
      ]);
      await tapAndSettle(tester, byKey('add-$third'));
      expect(byKey('cart-add-more'), findsNothing);
    });

    testWidgets('the address card shows and changes the delivery address', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');
      await tester.ensureVisible(byKey('cart-address'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: byKey('cart-address'),
          matching: find.textContaining('Uy'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('cart-address'),
          matching: find.text('Amir Temur, 12'),
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, byKey('cart-address-change'));
      expect(byKey('delivery-address-sheet'), findsOneWidget);
    });

    testWidgets('with no address the card offers to add one', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[];
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');
      await tester.ensureVisible(byKey('cart-address'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: byKey('cart-address'),
          matching: find.text(l10n(tester).deliveryAddressAdd),
        ),
        findsOneWidget,
      );
      expect(byKey('cart-address-change'), findsNothing);
    });
  });

  group('the cart button', () {
    testWidgets('on a section the cart summary bar is announced once and '
        'opens the cart', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/categories/c-1');

      expect(byKey('cart-summary'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^1$')),
        findsNothing,
        reason: 'the count is not announced on its own',
      );
      expect(
        find.bySemanticsLabel(RegExp(l10n(tester).cartSummaryOpen)),
        findsOneWidget,
        reason: 'the bar is announced once, in words',
      );

      await tapAndSettle(tester, byKey('cart-summary'));
      expect(byKey('cart-lines'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('keeps the count it knew when a reload fails', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester);
      cart.failure = const NetworkFailure();

      await tapAndSettle(tester, byKey('open-cart'));
      expect(byKey('retry-load'), findsOneWidget);
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: byKey('open-cart'), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets("the cart screen's retry shows progress", (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester);
      cart.failure = const NetworkFailure();
      await tapAndSettle(tester, byKey('open-cart'));
      expect(byKey('retry-load'), findsOneWidget);

      final Completer<void> hold = Completer<void>();
      cart.hold = hold;
      await tester.tap(byKey('retry-load'));
      await tester.pump();

      expect(byKey('retry-load'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      cart.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('cart-line-$tomatoLine'), findsOneWidget);
    });
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the product screen and the cart fit a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        cart.current = cartOf(<Map<String, Object?>>[
          cartLineJson(note: 'Qizilini, pishganini oling'),
        ]);
        await open(
          tester,
          at: '/customer/products/$breadProduct',
          size: const Size(360, 2400),
          textScale: 2,
          device: language,
        );
        expect(tester.takeException(), isNull);

        GoRouter.of(anywhere(tester)).push('/customer/cart');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('line-qty-$tomatoLine'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the cart lines, the empty cart and the remove sheet hold at 320 wide '
      'with large text (${language.languageCode})',
      (WidgetTester tester) async {
        cart.current = cartOf(<Map<String, Object?>>[
          cartLineJson(
            quantity: '9999.999',
            total: 99999999,
            note: List<String>.filled(300, 'n').join(),
            policy: 'contact_before_substitution',
          ),
          cartLineJson(
            id: breadLine,
            productId: breadProduct,
            unit: 'piece',
            quantity: '1',
            priceMode: 'fixed',
            price: 4000,
            total: 4000,
          ),
          cartLineJson(
            id: '0192f0a0-0000-7000-8000-00000000ca13',
            productId: '0192f0a0-0000-7000-8000-00000000cb03',
            unit: 'piece',
            quantity: '2',
            available: false,
          ),
        ]);
        await open(
          tester,
          at: '/customer/cart',
          size: const Size(320, 640),
          textScale: 2,
          device: language,
        );
        expect(tester.takeException(), isNull);

        // The lines no longer all fit above the footer: scroll to the second.
        await tester.scrollUntilVisible(
          byKey('line-minus-$breadLine'),
          200,
          scrollable: find.descendant(
            of: byKey('cart-lines'),
            matching: find.byType(Scrollable),
          ),
        );
        await tapAndSettle(tester, byKey('line-minus-$breadLine'));
        expect(byKey('remove-confirm'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('remove-cancel'));

        cart.answer = cartOf(<Map<String, Object?>>[]);
        // The lines no longer all fit above the footer: scroll to the last.
        await tester.scrollUntilVisible(
          byKey('remove-line-0192f0a0-0000-7000-8000-00000000ca13'),
          200,
          scrollable: find.descendant(
            of: byKey('cart-lines'),
            matching: find.byType(Scrollable),
          ),
        );
        await tapAndSettle(
          tester,
          byKey('remove-line-0192f0a0-0000-7000-8000-00000000ca13'),
        );
        expect(byKey('cart-empty'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the cart holds at the extremes (${language.languageCode})', (
      WidgetTester tester,
    ) async {
      // The empty cart, the unavailable line and the short cart each hold.
      for (final Cart next in <Cart>[
        cartOf(<Map<String, Object?>>[]),
        cartOf(
          <Map<String, Object?>>[
            cartLineJson(),
            cartLineJson(
              id: breadLine,
              productId: breadProduct,
              unit: 'piece',
              quantity: '2',
              available: false,
            ),
          ],
          serviceFee: 3000,
          deliveryFee: 12000,
        ),
        cartOf(
          <Map<String, Object?>>[cartLineJson(total: 14835)],
          subtotal: 14835,
          minimum: 50000,
          shortfall: 35165,
        ),
        cartOf(
          <Map<String, Object?>>[
            cartLineJson(
              name: List<String>.filled(60, 'N').join(),
              quantity: '9999.999',
              total: 99999999,
              note: List<String>.filled(300, 'n').join(),
              policy: 'contact_before_substitution',
            ),
          ],
          subtotal: 99999999,
          serviceFee: 99999999,
          serviceFeeKind: 'estimate',
          deliveryFee: 99999999,
          total: 99999999,
        ),
      ]) {
        cart.current = next;
        await open(
          tester,
          at: '/customer/cart',
          size: const Size(320, 640),
          textScale: 2,
          device: language,
        );
        expect(tester.takeException(), isNull);
        if (next.lines.isNotEmpty) {
          await tester.drag(byKey('cart-lines'), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}
