import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
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
import '../../../support/in_memory_stores.dart';

/// The cart of `docs/09` section 17 through the real router, catalog and
/// cart screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
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
        expect(byKey('line-editor'), findsNothing);
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
        expect(byKey('line-editor'), findsNothing);
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
    testWidgets(
      'shows the lines and the subtotal as the server computed them',
      (WidgetTester tester) async {
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
          find.text('1,5 ${words.unitKg}'),
          findsOneWidget,
          reason: 'with the decimal comma, without trailing zeros',
        );
        expect(
          find.text(
            words.cartLineEstimate(MoneyFormat.uzs(27600, AppLanguage.uz)),
          ),
          findsOneWidget,
        );
        expect(byKey('cart-line-unavailable-$breadLine'), findsOneWidget);
        expect(find.text(words.cartUnavailableHint), findsOneWidget);
        expect(
          find.text(words.cartSubtotal(MoneyFormat.uzs(99999, AppLanguage.uz))),
          findsOneWidget,
          reason: 'the client never sums money',
        );
        expect(
          tester.widget<ListTile>(byKey('cart-line-$breadLine')).onTap,
          isNull,
          reason: 'an unavailable line is removed, not changed',
        );
      },
    );

    testWidgets(
      'an edit sends only what changed, and nothing when nothing did',
      (WidgetTester tester) async {
        cart.current = cartOf(<Map<String, Object?>>[
          cartLineJson(note: 'Eski'),
        ]);
        await open(tester, at: '/customer/cart');

        await tapAndSettle(tester, byKey('cart-line-$tomatoLine'));
        await tapAndSettle(tester, byKey('save-line'));
        expect(cart.patches, isEmpty);
        expect(byKey('line-editor'), findsNothing, reason: 'closed');

        await tapAndSettle(tester, byKey('cart-line-$tomatoLine'));
        await tester.enterText(byKey('line-quantity'), '2');
        await tester.enterText(byKey('line-note'), '');
        cart.answer = cartOf(<Map<String, Object?>>[
          cartLineJson(quantity: '2.000', total: 36800),
        ]);
        await tapAndSettle(tester, byKey('save-line'));

        final CartLinePatch patch = cart.patches.single;
        expect(patch.quantity, '2');
        expect(patch.noteChanged, isTrue);
        expect(patch.customerNote, isNull);
        expect(patch.substitutionPolicy, isNull);
        expect(byKey('line-editor'), findsNothing);
        expect(find.text('2 ${l10n(tester).unitKg}'), findsOneWidget);
      },
    );

    testWidgets('the editor stays while its change runs', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');
      await tapAndSettle(tester, byKey('cart-line-$tomatoLine'));
      await tester.enterText(byKey('line-quantity'), '2');
      final Completer<void> hold = Completer<void>();
      cart
        ..hold = hold
        ..answer = cartOf(<Map<String, Object?>>[
          cartLineJson(quantity: '2.000', total: 36800),
        ]);

      await tester.tap(byKey('save-line'));
      await tester.pump();
      await tester.drag(byKey('line-editor'), const Offset(0, 600));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        byKey('line-editor'),
        findsOneWidget,
        reason: 'neither a drag nor back closes it',
      );

      cart.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(
        byKey('line-editor'),
        findsNothing,
        reason: 'it closes with the answer',
      );
    });

    testWidgets('a whole-unit line that kept its decimals is set anew', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(unit: 'piece', quantity: '1.500'),
      ]);
      await open(tester, at: '/customer/cart');

      await tapAndSettle(tester, byKey('cart-line-$tomatoLine'));

      expect(
        tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
        isEmpty,
      );
      await tapAndSettle(tester, byKey('save-line'));
      expect(find.text(l10n(tester).cartQuantityWhole), findsOneWidget);
      expect(cart.patches, isEmpty);
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

    testWidgets('a line is removed, and an empty cart says so', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
      await open(tester, at: '/customer/cart');

      cart.answer = cartOf(<Map<String, Object?>>[]);
      await tapAndSettle(tester, byKey('remove-line-$tomatoLine'));

      expect(cart.calls, contains('remove:$tomatoLine'));
      expect(byKey('cart-empty'), findsOneWidget);
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
        await tapAndSettle(tester, byKey('cart-line-$tomatoLine'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
