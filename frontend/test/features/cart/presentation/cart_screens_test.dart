import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
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
    testWidgets('a kg product takes a decimal quantity, a note and the rule', (
      WidgetTester tester,
    ) async {
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct, quantity: '1.500'),
      ]);
      await open(tester, at: '/customer/products/$tomatoProduct');

      expect(byKey('quantity-increase'), findsNothing, reason: 'no stepper');
      await tester.enterText(byKey('line-quantity'), '1,5');
      await tester.enterText(byKey('line-note'), '  Qizilini oling ');
      await tapAndSettle(tester, byKey('add-to-cart'));

      final NewCartLine sent = cart.added.single;
      expect(sent.productId, tomatoProduct);
      expect(sent.quantity, '1.5');
      expect(sent.customerNote, 'Qizilini oling');
      expect(sent.substitutionPolicy, SubstitutionPolicy.allowSimilar);
      expect(find.text(l10n(tester).cartAdded), findsOneWidget);
      expect(
        find.descendant(of: byKey('open-cart'), matching: find.text('1')),
        findsOneWidget,
        reason: 'the badge counts the lines the server answered',
      );
    });

    testWidgets(
      'a piece product steps whole numbers and refuses what the API would',
      (WidgetTester tester) async {
        cart.answer = cartOf(<Map<String, Object?>>[
          cartLineJson(
            id: breadLine,
            productId: breadProduct,
            unit: 'piece',
            quantity: '3',
          ),
        ]);
        await open(tester, at: '/customer/products/$breadProduct');

        await tapAndSettle(tester, byKey('quantity-increase'));
        await tapAndSettle(tester, byKey('quantity-increase'));
        expect(find.text('3'), findsOneWidget);

        await tester.enterText(byKey('line-quantity'), '0');
        await tapAndSettle(tester, byKey('add-to-cart'));
        expect(find.text(l10n(tester).cartQuantityWhole), findsOneWidget);
        expect(cart.added, isEmpty);

        await tester.enterText(byKey('line-quantity'), '3');
        await tester.tap(byKey('line-substitution'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(l10n(tester).substitutionRemoveIfUnavailable).last,
        );
        await tester.pumpAndSettle();
        await tapAndSettle(tester, byKey('add-to-cart'));

        expect(cart.added.single.quantity, '3');
        expect(
          cart.added.single.substitutionPolicy,
          SubstitutionPolicy.removeIfUnavailable,
        );
      },
    );

    testWidgets('a product already in the cart opens its line there', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct),
      ]);
      await open(tester, at: '/customer/products/$tomatoProduct');
      cart.failure = const ApiRefusal(
        ApiError(
          status: 409,
          code: 'cart_item_already_exists',
          details: <String, Object?>{'cart_item_id': tomatoLine},
        ),
      );

      await tapAndSettle(tester, byKey('add-to-cart'));

      expect(find.text(l10n(tester).cartTitle), findsOneWidget);
      expect(byKey('line-editor'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
        '1.500',
      );
    });

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
        expect(find.text('1.500 ${words.unitKg}'), findsOneWidget);
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
        expect(find.text('2.000 ${l10n(tester).unitKg}'), findsOneWidget);
      },
    );

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
