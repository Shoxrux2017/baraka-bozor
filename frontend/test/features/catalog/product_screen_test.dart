import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_paths.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_screen.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/category_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/product_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';
import '../../support/in_memory_stores.dart';

/// The product screen (drawing 18, 18b) through the real router, against a
/// catalog, a cart and favourites in memory.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCatalogRepository catalog;
  late FakeCartRepository cart;
  late FakeFavoritesRepository favorites;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  String approx(int amount) => '≈ ${MoneyFormat.uzs(amount, AppLanguage.ru)}';

  String quantityShown(WidgetTester tester) =>
      tester.widget<Text>(byKey('product-qty')).data!;

  String sumShown(WidgetTester tester) =>
      tester.widget<Text>(byKey('product-sum')).data!;

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(byKey(key)).onPressed != null;

  bool radioChosen(WidgetTester tester, String code) =>
      tester
          .widget<RadioGroup<SubstitutionPolicy>>(
            find.byType(RadioGroup<SubstitutionPolicy>),
          )
          .groupValue
          ?.code ==
      code;

  bool iconEnabled(WidgetTester tester, String key) =>
      tester.widget<IconButton>(byKey(key)).onPressed != null;

  /// A product of the first category: the tomato of the cart fixtures unless
  /// another [id] is given.
  CatalogProduct item({
    String id = tomatoProduct,
    String categoryId = 'c-1',
    String nameUz = 'Pomidor',
    String nameRu = 'Помидор',
    String? descriptionUz,
    String? descriptionRu,
    UnitCode unitCode = UnitCode.kg,
    PriceMode priceMode = PriceMode.estimate,
    int customerUnitPriceUzs = 18400,
  }) => catalogProduct(
    id: id,
    categoryId: categoryId,
    nameUz: nameUz,
    nameRu: nameRu,
    descriptionUz: descriptionUz,
    descriptionRu: descriptionRu,
    unitCode: unitCode,
    priceMode: priceMode,
    customerUnitPriceUzs: customerUnitPriceUzs,
  );

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    catalog = FakeCatalogRepository(
      categories: <CatalogCategory>[catalogCategory()],
      products: <CatalogProduct>[
        item(customerUnitPriceUzs: 12075),
        item(
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
    favorites = FakeFavoritesRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    String id = tomatoProduct,
    Size size = const Size(400, 1400),
    double textScale = 1,
    Locale device = const Locale('ru'),
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
        favorites: favorites,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push('/customer/products/$id');
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('the layout', () {
    testWidgets('the app bar has the back arrow, the title and the heart', (
      WidgetTester tester,
    ) async {
      await open(tester);

      final Finder bar = find.byType(AppBar);
      expect(
        find.descendant(of: bar, matching: find.text('О товаре')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(BackButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: byKey('product-heart')),
        findsOneWidget,
      );
      expect(byKey('open-cart'), findsNothing);
    });

    testWidgets('the heart fills at once, and a refusal restores it', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.byIcon(Icons.favorite), findsNothing);

      await tester.tap(byKey('product-heart'));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.pumpAndSettle();
      expect(favorites.changes, <String>['add:$tomatoProduct']);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(byKey('product-heart'));
      await tester.pumpAndSettle();
      favorites.nextFailure = const UnexpectedFailure();
      await tester.tap(byKey('product-heart'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.text(l10n(tester).favoriteFailed), findsOneWidget);
    });

    testWidgets('the name, the price, the unit and the estimate panel', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(byKey('product-name'), findsOneWidget);
      expect(find.text('Помидор'), findsOneWidget);
      expect(find.text('Pomidor'), findsNothing, reason: 'no second name');
      expect(tester.widget<Text>(byKey('product-price')).data, approx(12075));
      expect(find.text('за кг'), findsOneWidget);
      expect(find.text(l10n(tester).catalogEstimateExplain), findsOneWidget);
    });

    testWidgets('a fixed price product has no estimate panel', (
      WidgetTester tester,
    ) async {
      await open(tester, id: breadProduct);

      expect(find.text(l10n(tester).catalogEstimateExplain), findsNothing);
    });

    testWidgets('a long description folds and reads on', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[
        item(descriptionRu: List<String>.filled(40, 'Сочные томаты').join(' ')),
      ];
      await open(tester);

      expect(byKey('product-more'), findsOneWidget);
      expect(tester.widget<Text>(byKey('product-description')).maxLines, 3);

      await tester.tap(byKey('product-more'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(byKey('product-description')).maxLines, null);
      expect(find.text('Свернуть'), findsOneWidget);

      await tester.tap(byKey('product-more'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(byKey('product-description')).maxLines, 3);
    });

    testWidgets('a description just over three lines at text x2 reads on', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[
        item(descriptionRu: List<String>.filled(14, 'Сочные томаты').join(' ')),
      ];
      await open(tester, size: const Size(320, 1400), textScale: 2);

      final Finder text = byKey('product-description');
      final RenderParagraph painted = tester.renderObject<RenderParagraph>(
        text,
      );
      // The folded text really is cut, so the way to read on must show.
      expect(painted.didExceedMaxLines, isTrue);
      expect(byKey('product-more'), findsOneWidget);
    });

    testWidgets('a short description has no reading on, none has no text', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[
        item(descriptionRu: 'Сочные'),
        item(id: breadProduct),
      ];
      await open(tester);
      expect(find.text('Сочные'), findsOneWidget);
      expect(byKey('product-more'), findsNothing);

      GoRouter.of(anywhere(tester)).push('/customer/products/$breadProduct');
      await tester.pumpAndSettle();
      expect(byKey('product-description'), findsNothing);
    });

    testWidgets('the rule starts at allow similar and the note counts', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Если товара не будет'), findsOneWidget);
      expect(byKey('line-substitution'), findsOneWidget);
      for (final SubstitutionPolicy option in SubstitutionPolicy.values) {
        expect(byKey('substitution-${option.code}'), findsOneWidget);
      }
      expect(radioChosen(tester, 'allow_similar_substitution'), isTrue);
      expect(find.text('0 / 300'), findsOneWidget);
      expect(find.text('Например: покрепче, не перезрелые'), findsOneWidget);

      await tester.enterText(byKey('line-note'), 'Покрепче');
      await tester.pump();
      expect(find.text('8 / 300'), findsOneWidget);
    });
  });

  group('the bar', () {
    testWidgets('starts at one kilo, and the minus stops at the step', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(quantityShown(tester), '1 кг');
      expect(iconEnabled(tester, 'product-plus'), isTrue);
      expect(sumShown(tester), approx(12075));

      await tester.tap(byKey('product-minus'));
      await tester.pumpAndSettle();
      expect(quantityShown(tester), '0,5 кг');
      expect(iconEnabled(tester, 'product-minus'), isFalse);
    });

    testWidgets('plus steps by half a kilo and previews the sum', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      expect(quantityShown(tester), '1,5 кг');
      expect(sumShown(tester), approx(18113));
      expect(iconEnabled(tester, 'product-minus'), isTrue);

      await tester.tap(byKey('product-minus'));
      await tester.pumpAndSettle();
      expect(quantityShown(tester), '1 кг');
    });

    testWidgets('a piece product steps by one', (WidgetTester tester) async {
      await open(tester, id: breadProduct);

      expect(quantityShown(tester), '1 шт.');
      expect(iconEnabled(tester, 'product-minus'), isFalse);
      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      expect(quantityShown(tester), '2 шт.');
      expect(sumShown(tester), approx(8000));
    });

    testWidgets('the plus stops at 9 999', (WidgetTester tester) async {
      final List<String> asked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            bottomNavigationBar: ProductBar(
              product: item(unitCode: UnitCode.piece),
              quantity: '9999',
              onQuantity: asked.add,
              actionKey: const ValueKey<String>('add-to-cart'),
              actionLabel: 'В корзину',
              onAction: () {},
              busy: false,
            ),
          ),
        ),
      );

      await tester.tap(byKey('product-plus'));
      await tester.pump();

      expect(asked.every((String q) => q == '9999'), isTrue);
    });

    testWidgets('add sends the quantity, the trimmed note and the rule', (
      WidgetTester tester,
    ) async {
      await open(tester);
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct, quantity: '1.500'),
      ]);

      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('line-note'), '  Покрепче ');
      await tester.ensureVisible(
        byKey('substitution-contact_before_substitution'),
      );
      await tester.tap(byKey('substitution-contact_before_substitution'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();

      final NewCartLine sent = cart.added.single;
      expect(sent.productId, tomatoProduct);
      expect(sent.quantity, '1.5');
      expect(sent.customerNote, 'Покрепче');
      expect(sent.substitutionPolicy, SubstitutionPolicy.contactBefore);
      expect(find.text(l10n(tester).cartAdded), findsOneWidget);
      expect(find.text(l10n(tester).cartOpen), findsOneWidget);
    });

    testWidgets('an empty note is sent as no note', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.enterText(byKey('line-note'), '   ');
      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();

      expect(cart.added.single.customerNote, isNull);
      expect(cart.added.single.quantity, '1');
    });

    testWidgets('while the add is in flight the stepper, rule and note wait', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final Completer<void> hold = Completer<void>();
      cart.hold = hold;

      await tester.tap(byKey('add-to-cart'));
      await tester.pump();
      expect(iconEnabled(tester, 'product-plus'), isFalse);
      expect(iconEnabled(tester, 'product-minus'), isFalse);
      await tester.tap(byKey('product-qty'));
      await tester.pump();
      expect(byKey('quantity-done'), findsNothing);
      await tester.ensureVisible(
        byKey('substitution-contact_before_substitution'),
      );
      await tester.tap(byKey('substitution-contact_before_substitution'));
      await tester.pump();
      expect(radioChosen(tester, 'allow_similar_substitution'), isTrue);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: byKey('line-note'),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );

      cart.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(iconEnabled(tester, 'product-plus'), isTrue);
    });

    for (final double scale in <double>[1, 2]) {
      testWidgets('at 320 wide and text x$scale the exact quantity keeps its '
          'size', (WidgetTester tester) async {
        await open(tester, size: const Size(320, 640), textScale: scale);
        await tester.tap(byKey('product-qty'));
        await tester.pumpAndSettle();
        await tester.enterText(byKey('line-quantity'), '1,25');
        await tester.tap(byKey('quantity-done'));
        await tester.pumpAndSettle();

        expect(quantityShown(tester), '1,25 кг');
        expect(
          find.ancestor(
            of: byKey('product-qty'),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          byKey('product-qty'),
        );
        final TextPainter wanted = TextPainter(
          text: TextSpan(
            text: '1,25 кг',
            style: tester
                .widget<Text>(byKey('product-qty'))
                .style
                ?.copyWith(fontFamily: 'Montserrat'),
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout();
        expect(paragraph.size.width, greaterThanOrEqualTo(wanted.width - 1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'while the add is in flight the button waits and ignores taps',
      (WidgetTester tester) async {
        await open(tester);
        final Completer<void> hold = Completer<void>();
        cart.hold = hold;

        await tester.tap(byKey('add-to-cart'));
        await tester.pump();
        expect(
          find.descendant(
            of: byKey('add-to-cart'),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        await tester.tap(byKey('add-to-cart'));
        await tester.pump();

        cart.hold = null;
        hold.complete();
        await tester.pumpAndSettle();
        expect(cart.added, hasLength(1));
      },
    );

    testWidgets('with the cart still loading the button is disabled', (
      WidgetTester tester,
    ) async {
      final Completer<void> hold = Completer<void>();
      cart.hold = hold;
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: auth,
          catalog: catalog,
          cart: cart,
          favorites: favorites,
          device: const Locale('ru'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      GoRouter.of(anywhere(tester)).push('/customer/products/$tomatoProduct');
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(byKey('add-to-cart'), findsOneWidget);
      expect(enabled(tester, 'add-to-cart'), isFalse);

      hold.complete();
      await tester.pumpAndSettle();
      expect(enabled(tester, 'add-to-cart'), isTrue);
    });

    testWidgets('a note over 300 characters is refused, as the server counts', (
      WidgetTester tester,
    ) async {
      await open(tester);

      // 151 flags: 151 marks to the eye, 302 code points to the server.
      await tester.enterText(
        byKey('line-note'),
        List<String>.filled(151, '\u{1F1FA}\u{1F1FF}').join(),
      );
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
      expect(cart.added, isEmpty);

      // 300 tomatoes: 300 code points, 600 UTF-16 units: within the limit.
      final String tomatoes = List<String>.filled(300, '\u{1F345}').join();
      await tester.enterText(byKey('line-note'), tomatoes);
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(cart.added.single.customerNote, tomatoes);

      // A trailing zero-width space is trimmed by the server, not counted.
      await tester.enterText(byKey('line-note'), '$tomatoes​');
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(cart.added, hasLength(2), reason: 'sent, not refused');
      expect(cart.added.last.customerNote, tomatoes);
    });

    testWidgets('what the Customer set survives scrolling the page', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[
        item(
          descriptionRu: List<String>.filled(
            600,
            'Очень вкусные помидоры.',
          ).join(' '),
        ),
      ];
      await open(tester, size: const Size(360, 640));
      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();

      final Finder page = find
          .descendant(
            of: find.byType(Scaffold).last,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        byKey('line-note'),
        600,
        scrollable: page,
      );
      await tester.enterText(byKey('line-note'), 'Покрепче');
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

      expect(
        tester.widget<TextFormField>(byKey('line-note')).controller!.text,
        'Покрепче',
      );
      expect(quantityShown(tester), '1,5 кг');
      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();
      expect(cart.added.single.quantity, '1.5');
      expect(
        cart.added.single.substitutionPolicy,
        SubstitutionPolicy.removeIfUnavailable,
      );
    });

    testWidgets('a full cart and a product gone have their own words', (
      WidgetTester tester,
    ) async {
      await open(tester);

      cart.failure = const ApiRefusal(ApiError(status: 409, code: 'cart_full'));
      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).errorCartFull), findsOneWidget);

      cart.failure = const ApiRefusal(
        ApiError(status: 409, code: 'product_unavailable'),
      );
      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).errorProductUnavailable), findsOneWidget);
    });

    testWidgets(
      'a product already in the cart refreshes the cart and adds no second line',
      (WidgetTester tester) async {
        await open(tester);
        // Another device put the product in the cart after this one looked.
        cart.current = cartOf(<Map<String, Object?>>[
          cartLineJson(
            productId: tomatoProduct,
            quantity: '2.000',
            note: 'Покрепче',
            policy: 'contact_before_substitution',
          ),
        ]);
        cart.calls.clear();
        cart.failure = const ApiRefusal(
          ApiError(
            status: 409,
            code: 'cart_item_already_exists',
            details: <String, Object?>{'cart_item_id': tomatoLine},
          ),
        );

        await tester.tap(byKey('add-to-cart'));
        await tester.pumpAndSettle();

        expect(cart.added, hasLength(1), reason: 'the one that was refused');
        expect(
          cart.calls,
          contains('cart'),
          reason: 'the cart was asked again',
        );
        expect(find.byType(CartScreen), findsNothing);
        expect(find.text(l10n(tester).cartAdded), findsNothing);
        expect(find.text(l10n(tester).productAlreadyInCart), findsOneWidget);
        expect(byKey('add-to-cart'), findsNothing);
        expect(byKey('save-line'), findsOneWidget);
        expect(quantityShown(tester), '2 кг');
        expect(
          tester.widget<TextFormField>(byKey('line-note')).controller!.text,
          'Покрепче',
        );
        expect(cart.added, hasLength(1), reason: 'no second add');
      },
    );

    testWidgets(
      'the snackbar opens the cart, also after the product was left',
      (WidgetTester tester) async {
        await open(tester);
        cart.answer = cartOf(<Map<String, Object?>>[
          cartLineJson(productId: tomatoProduct),
        ]);
        await tester.tap(byKey('add-to-cart'));
        await tester.pumpAndSettle();

        GoRouter.of(anywhere(tester)).pop();
        await tester.pump();
        await tester.tap(find.text(l10n(tester).cartOpen));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(CartScreen), findsOneWidget);
      },
    );

    testWidgets('a second notice replaces the first rather than queueing', (
      WidgetTester tester,
    ) async {
      await open(tester);
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct, quantity: '1.000'),
      ]);
      // Frame by frame, so the notice's timer starts as it would.
      Future<void> wait(Duration time) async {
        for (int i = 0; i < time.inMilliseconds ~/ 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.tap(byKey('add-to-cart'));
      await wait(const Duration(seconds: 1));

      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct, quantity: '1.000'),
        cartLineJson(id: breadLine, productId: breadProduct, unit: 'piece'),
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

    testWidgets('the notice stays behind when the Customer goes to checkout', (
      WidgetTester tester,
    ) async {
      await open(tester);
      cart.answer = cartOf(<Map<String, Object?>>[
        cartLineJson(productId: tomatoProduct),
      ]);
      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();
      // The Customer reaches the cart by another way than the notice's
      // action, which would dismiss the notice itself.
      GoRouter.of(anywhere(tester)).push(CartPaths.cart);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n(tester).cartAdded), findsOneWidget);

      await tester.tap(byKey('go-to-checkout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n(tester).cartAdded), findsNothing);
    });

    testWidgets(
      'an answer that arrives after the Customer left the product navigates nowhere',
      (WidgetTester tester) async {
        await open(tester);
        cart.current = cartOf(<Map<String, Object?>>[
          cartLineJson(productId: tomatoProduct),
        ]);
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
        // The Customer leaves the product while the add is on its way.
        GoRouter.of(anywhere(tester)).pop();
        await tester.pump();
        cart.hold = null;
        hold.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CartScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('more in the category', () {
    setUp(() {
      catalog.productRows = <CatalogProduct>[
        item(),
        for (int i = 2; i <= 7; i++)
          item(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
        item(id: 'q-1', categoryId: 'c-9', nameUz: 'Boshqa', nameRu: 'Чужой'),
        item(
          id: 'q-2',
          categoryId: 'c-9',
          nameUz: 'Boshqa 2',
          nameRu: 'Чужой 2',
        ),
      ];
    });

    testWidgets('shows up to four other products of the category', (
      WidgetTester tester,
    ) async {
      await open(tester);

      final Finder more = byKey('more-in-category');
      expect(more, findsOneWidget);
      expect(
        find.descendant(of: more, matching: find.text('Ещё в «Овощи»')),
        findsOneWidget,
      );
      for (final String id in <String>['p-2', 'p-3', 'p-4', 'p-5']) {
        expect(
          find.descendant(of: more, matching: byKey('product-card-$id')),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: more,
          matching: byKey('product-card-$tomatoProduct'),
        ),
        findsNothing,
        reason: 'never the product itself',
      );
      expect(
        find.descendant(of: more, matching: byKey('product-card-p-6')),
        findsNothing,
      );
      expect(
        find.descendant(of: more, matching: byKey('product-card-q-1')),
        findsNothing,
      );
    });

    testWidgets('a category missing from the list uses the generic header', (
      WidgetTester tester,
    ) async {
      await open(tester, id: 'q-1');

      expect(
        find.descendant(
          of: byKey('more-in-category'),
          matching: find.text('Ещё из этой категории'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('more-in-category'),
          matching: byKey('product-card-q-2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"all" opens the category', (WidgetTester tester) async {
      await open(tester);

      await tapAndSettle(tester, byKey('more-all'));

      expect(find.byType(CategoryScreen), findsOneWidget);
    });

    testWidgets('is absent when the category has nothing else', (
      WidgetTester tester,
    ) async {
      catalog.productRows = <CatalogProduct>[item()];
      await open(tester);

      expect(byKey('more-in-category'), findsNothing);
    });

    testWidgets('is absent when its list fails', (WidgetTester tester) async {
      await open(tester, id: tomatoProduct);
      GoRouter.of(anywhere(tester)).pop();
      await tester.pumpAndSettle();
      catalog.nextFailure = const NetworkFailure();
      GoRouter.of(anywhere(tester)).push('/customer/products/p-2');
      await tester.pumpAndSettle();

      expect(byKey('product-name'), findsOneWidget);
      expect(byKey('more-in-category'), findsNothing);
    });
  });

  group('a product that is gone', () {
    testWidgets('a 404 says so and leads to the catalog, with no retry', (
      WidgetTester tester,
    ) async {
      await open(tester, id: 'p-404');

      expect(byKey('product-gone'), findsOneWidget);
      expect(find.text('Товара больше нет в продаже'), findsOneWidget);
      expect(
        find.text(
          'Его убрали из каталога. Похожие товары можно найти в категориях.',
        ),
        findsOneWidget,
      );
      expect(byKey('retry-load'), findsNothing);
      expect(byKey('add-to-cart'), findsNothing);

      await tester.tap(byKey('product-gone-action'));
      await tester.pumpAndSettle();
      expect(byKey('product-gone'), findsNothing);
    });

    testWidgets('another failure offers the retry', (
      WidgetTester tester,
    ) async {
      catalog.productFailure = const NetworkFailure();
      await open(tester);

      expect(byKey('product-gone'), findsNothing);
      expect(byKey('retry-load'), findsOneWidget);

      await tester.tap(byKey('retry-load'));
      await tester.pumpAndSettle();
      expect(byKey('product-name'), findsOneWidget);
    });
  });

  group('a product already in the cart', () {
    CartLine lineOf(Cart cart) => cart.lines.single;

    Cart tomatoInCart({
      String quantity = '2.000',
      String? note = 'Покрепче',
      String policy = 'contact_before_substitution',
    }) => cartOf(<Map<String, Object?>>[
      cartLineJson(
        quantity: quantity,
        note: note,
        policy: policy,
        price: 21850,
        total: 43700,
      ),
    ]);

    Future<void> refreshCart(WidgetTester tester) async {
      final ProviderContainer container = ProviderScope.containerOf(
        anywhere(tester),
      );
      final String account = container.read(customerAccountProvider)!;
      await container.read(cartProvider(account).notifier).refresh();
      await tester.pumpAndSettle();
    }

    String chipShown(WidgetTester tester) =>
        tester.widget<Text>(byKey('product-in-cart')).data!;

    testWidgets('opens with the line, and "Сохранить" waits for a change', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);

      expect(chipShown(tester), 'В корзине: 2 кг');
      expect(quantityShown(tester), '2 кг');
      expect(sumShown(tester), approx(24150));
      expect(radioChosen(tester, 'contact_before_substitution'), isTrue);
      expect(
        tester.widget<TextFormField>(byKey('line-note')).controller!.text,
        'Покрепче',
      );
      expect(byKey('add-to-cart'), findsNothing);
      expect(find.text('Сохранить'), findsOneWidget);
      expect(enabled(tester, 'save-line'), isFalse);
    });

    testWidgets('a changed quantity, note or rule enables it', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);

      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'save-line'), isTrue);
      await tester.tap(byKey('product-minus'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'save-line'), isFalse, reason: 'back to the line');

      await tester.enterText(byKey('line-note'), 'Помягче');
      await tester.pumpAndSettle();
      expect(enabled(tester, 'save-line'), isTrue);
      await tester.enterText(byKey('line-note'), 'Покрепче');
      await tester.pumpAndSettle();
      expect(enabled(tester, 'save-line'), isFalse);

      await tapAndSettle(tester, byKey('substitution-remove_if_unavailable'));
      expect(enabled(tester, 'save-line'), isTrue);
    });

    testWidgets('saving sends the difference, says so and disables again', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      final CartLine line = lineOf(cart.current);

      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('line-note'), '  Помягче ');
      await tapAndSettle(tester, byKey('substitution-remove_if_unavailable'));
      cart.answer = tomatoInCart(
        quantity: '2.500',
        note: 'Помягче',
        policy: 'remove_if_unavailable',
      );
      await tapAndSettle(tester, byKey('save-line'));

      final CartLinePatch expected = CartLinePatch.between(
        line,
        quantity: '2.5',
        customerNote: 'Помягче',
        substitutionPolicy: SubstitutionPolicy.removeIfUnavailable,
      );
      final CartLinePatch sent = cart.patches.single;
      expect(sent.quantity, expected.quantity);
      expect(sent.noteChanged, expected.noteChanged);
      expect(sent.customerNote, expected.customerNote);
      expect(sent.substitutionPolicy, expected.substitutionPolicy);
      expect(cart.calls, contains('change:$tomatoLine'));
      expect(find.text(l10n(tester).cartLineSaved), findsOneWidget);
      expect(enabled(tester, 'save-line'), isFalse);
      expect(quantityShown(tester), '2,5 кг');
      expect(chipShown(tester), 'В корзине: 2,5 кг');
      expect(cart.added, isEmpty);
    });

    testWidgets('a piece line that kept decimals disables the stepper only', (
      WidgetTester tester,
    ) async {
      cart.current = cartOf(<Map<String, Object?>>[
        cartLineJson(
          id: breadLine,
          productId: breadProduct,
          unit: 'piece',
          quantity: '1.500',
        ),
      ]);
      await open(tester, id: breadProduct);

      expect(iconEnabled(tester, 'product-plus'), isFalse);
      expect(iconEnabled(tester, 'product-minus'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.tap(byKey('product-qty'));
      await tester.pumpAndSettle();
      expect(byKey('quantity-done'), findsOneWidget);
    });

    testWidgets('a note over 300 characters is not saved', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);

      await tester.enterText(
        byKey('line-note'),
        List<String>.filled(301, 'а').join(),
      );
      await tapAndSettle(tester, byKey('save-line'));

      expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
      expect(cart.patches, isEmpty);
    });

    testWidgets('a failed save keeps the edit and does not claim success', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();

      cart.failure = const UnexpectedFailure();
      await tapAndSettle(tester, byKey('save-line'));

      expect(find.text(l10n(tester).cartLineSaved), findsNothing);
      expect(quantityShown(tester), '2,5 кг');
      expect(enabled(tester, 'save-line'), isTrue);
    });

    testWidgets('a successful add turns the screen into the in-cart state', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      cart.answer = tomatoInCart(
        quantity: '1.500',
        note: null,
        policy: 'allow_similar_substitution',
      );
      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).cartAdded), findsOneWidget);
      expect(byKey('add-to-cart'), findsNothing);
      expect(byKey('save-line'), findsOneWidget);
      expect(enabled(tester, 'save-line'), isFalse);
      expect(chipShown(tester), 'В корзине: 1,5 кг');
      expect(cart.added, hasLength(1));
    });

    testWidgets('a line removed elsewhere turns it back to a new add', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      expect(byKey('save-line'), findsOneWidget);

      cart.current = cartOf(<Map<String, Object?>>[]);
      await refreshCart(tester);

      expect(byKey('save-line'), findsNothing);
      expect(byKey('product-in-cart'), findsNothing);
      expect(enabled(tester, 'add-to-cart'), isTrue);
      expect(quantityShown(tester), '1 кг');
      expect(radioChosen(tester, 'allow_similar_substitution'), isTrue);
      expect(
        tester.widget<TextFormField>(byKey('line-note')).controller!.text,
        isEmpty,
      );
    });

    testWidgets('a refresh that leaves the line alone keeps the edits', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      await tester.tap(byKey('product-plus'));
      await tester.enterText(byKey('line-note'), 'Помягче');
      await tester.pumpAndSettle();

      await refreshCart(tester);

      expect(quantityShown(tester), '2,5 кг');
      expect(
        tester.widget<TextFormField>(byKey('line-note')).controller!.text,
        'Помягче',
      );
      expect(enabled(tester, 'save-line'), isTrue);
    });

    testWidgets('a line changed elsewhere is shown when nothing is edited', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);

      cart.current = tomatoInCart(quantity: '3.000', note: null);
      await refreshCart(tester);

      expect(quantityShown(tester), '3 кг');
      expect(
        tester.widget<TextFormField>(byKey('line-note')).controller!.text,
        isEmpty,
      );
      expect(enabled(tester, 'save-line'), isFalse);
    });

    testWidgets('a line changed elsewhere does not overwrite an edit', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();

      cart.current = tomatoInCart(quantity: '3.000');
      await refreshCart(tester);

      expect(quantityShown(tester), '2,5 кг', reason: 'the edit stays');
      expect(enabled(tester, 'save-line'), isTrue);
    });
  });

  group('an exact quantity', () {
    testWidgets('the sheet takes 1,25 and the stepper goes on from it', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(byKey('product-qty'));
      await tester.pumpAndSettle();
      expect(byKey('quantity-done'), findsOneWidget);
      await tester.enterText(byKey('line-quantity'), '1,25');
      await tester.tap(byKey('quantity-done'));
      await tester.pumpAndSettle();

      expect(byKey('quantity-done'), findsNothing);
      expect(quantityShown(tester), '1,25 кг');
      await tester.tap(byKey('product-plus'));
      await tester.pumpAndSettle();
      expect(quantityShown(tester), '1,75 кг');
      await tester.tap(byKey('product-minus'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('product-minus'));
      await tester.pumpAndSettle();
      expect(quantityShown(tester), '0,75 кг');
    });

    for (final String bad in <String>['0', 'abc']) {
      testWidgets('"$bad" keeps the sheet open and the quantity as it was', (
        WidgetTester tester,
      ) async {
        await open(tester);

        await tester.tap(byKey('product-qty'));
        await tester.pumpAndSettle();
        await tester.enterText(byKey('line-quantity'), bad);
        await tester.tap(byKey('quantity-done'));
        await tester.pumpAndSettle();

        expect(find.text(l10n(tester).cartQuantityFraction), findsOneWidget);
        expect(byKey('quantity-done'), findsOneWidget);
        expect(cart.added, isEmpty);
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();
        expect(quantityShown(tester), '1 кг');
      });
    }

    testWidgets(
      'a piece product takes no fraction and refuses what is not whole',
      (WidgetTester tester) async {
        await open(tester, id: breadProduct);

        await tester.tap(byKey('product-qty'));
        await tester.pumpAndSettle();
        // The field keeps the comma out, so 1,5 can only be typed as 15.
        await tester.enterText(byKey('line-quantity'), '1,5');
        expect(
          tester.widget<TextFormField>(byKey('line-quantity')).controller!.text,
          '15',
        );
        await tester.enterText(byKey('line-quantity'), '0');
        await tester.tap(byKey('quantity-done'));
        await tester.pumpAndSettle();

        expect(find.text(l10n(tester).cartQuantityWhole), findsOneWidget);
        expect(byKey('quantity-done'), findsOneWidget);
        expect(cart.added, isEmpty);
      },
    );

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets('the sheet fits a phone-size window with large text '
          '(${device.languageCode})', (WidgetTester tester) async {
        cart.current = cartOf(<Map<String, Object?>>[cartLineJson()]);
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );

        expect(byKey('product-in-cart'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(byKey('product-qty'));
        await tester.pumpAndSettle();
        expect(byKey('quantity-done'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'a phone-size window with large text and the longest content fits '
      '(${device.languageCode})',
      (WidgetTester tester) async {
        String exactly(String unit, int length) =>
            List<String>.filled(length, unit).join().substring(0, length);
        catalog.productRows = <CatalogProduct>[
          item(
            nameUz: exactly('Pomidor pushti ', 60),
            nameRu: exactly('Помидор розовый ', 60),
            descriptionUz: exactly('Juda mazali pomidor ', 2000),
            descriptionRu: exactly('Очень вкусный помидор ', 2000),
          ),
          item(id: breadProduct, nameUz: 'Mahsulot 2', nameRu: 'Товар 2'),
        ];
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );

        expect(byKey('product-name'), findsOneWidget);
        expect(byKey('add-to-cart'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(byKey('product-more'));
        await tester.pumpAndSettle();
        await tester.tap(byKey('product-more'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          byKey('line-note'),
          400,
          scrollable: find
              .descendant(
                of: find.byType(Scaffold).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
