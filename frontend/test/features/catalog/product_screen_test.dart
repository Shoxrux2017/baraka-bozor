import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/fold.dart';
import 'package:baraka_bozor/core/widgets/keyboard_done_bar.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_screen.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/category_screen.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/catalog/presentation/product_bar.dart';
import 'package:baraka_bozor/features/catalog/presentation/product_photo.dart';
import 'package:baraka_bozor/features/catalog/presentation/product_screen.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';
import '../../support/in_memory_stores.dart';
import '../../support/paragraphs.dart';

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
    ProductOpening? opening,
    bool push = true,
  }) async {
    await loadMontserrat();
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
    if (!push) {
      return;
    }
    GoRouter.of(anywhere(tester))
        .push('/customer/products/$id', extra: opening);
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder foldOfExplain(WidgetTester tester) => find.ancestor(
    of: find.text(l10n(tester).catalogEstimateExplain),
    matching: find.byType(Fold),
  );

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

    for (final (Locale, String) phrase in <(Locale, String)>[
      (
        const Locale('ru'),
        'Цена примерно ${MoneyFormat.uzs(12075, AppLanguage.ru)} за килограмм',
      ),
      (
        const Locale('uz'),
        'Narxi taxminan ${MoneyFormat.uzs(12075, AppLanguage.uz)}, 1 '
            'kilogramm uchun',
      ),
    ]) {
      testWidgets('the price is one phrase (${phrase.$1.languageCode})', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await open(tester, device: phrase.$1);

        final SemanticsData data = tester
            .getSemantics(byKey('product-price-row'))
            .getSemanticsData();
        expect(data.label, phrase.$2);
        handle.dispose();
      });
    }

    testWidgets('the name, the price, the unit and the estimate panel', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(byKey('product-name'), findsOneWidget);
      expect(find.text('Помидор'), findsOneWidget);
      expect(find.text('Pomidor'), findsNothing, reason: 'no second name');
      expect(tester.widget<Text>(byKey('product-price')).data, approx(12075));
      expect(find.text('за кг'), findsOneWidget);
      expect(find.text(l10n(tester).productEstimateTitle), findsOneWidget);
      expect(find.text(l10n(tester).productEstimatePromise), findsOneWidget);
      expect(find.text(l10n(tester).productEstimateHow), findsOneWidget);
      expect(
        tester.getSize(foldOfExplain(tester)).height,
        0,
        reason: 'the full text stands folded',
      );
    });

    testWidgets('Как считаем opens the full text and closes it', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await open(tester);
      final Finder how = byKey('product-estimate-how');
      expect(tester.getSize(how).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(how).getSemanticsData().flagsCollection.isExpanded,
        Tristate.isFalse,
      );

      await tester.tap(how);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final RotationTransition turn = tester.widget<RotationTransition>(
        find.descendant(of: how, matching: find.byType(RotationTransition)),
      );
      expect(turn.turns.value, 0.5);
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).catalogEstimateExplain), findsOneWidget);
      expect(find.text(l10n(tester).productReadLess), findsOneWidget);
      expect(find.text(l10n(tester).productEstimateHow), findsNothing);
      expect(
        tester.getSemantics(how).getSemanticsData().flagsCollection.isExpanded,
        Tristate.isTrue,
      );

      await tester.tap(how);
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).productEstimateHow), findsOneWidget);
      expect(
        tester.getSize(foldOfExplain(tester)).height,
        0,
        reason: 'folded to nothing',
      );
      handle.dispose();
    });

    testWidgets('with reduced motion the full text stands at once', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester);

      await tester.tap(byKey('product-estimate-how'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n(tester).catalogEstimateExplain), findsOneWidget);
      expect(tester.getSize(foldOfExplain(tester)).height, greaterThan(0));
      expect(find.text(l10n(tester).productReadLess), findsOneWidget);
    });

    testWidgets('a fixed price product has no estimate panel', (
      WidgetTester tester,
    ) async {
      await open(tester, id: breadProduct);

      expect(find.text(l10n(tester).productEstimateTitle), findsNothing);
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
      expect(byKey('product-note-count'), findsNothing);
      expect(find.text('Например: покрепче, не перезрелые'), findsOneWidget);

      await tester.enterText(byKey('line-note'), 'Покрепче');
      await tester.pump();
      expect(byKey('product-note-count'), findsNothing);
    });
  });

  group('the note and its keyboard', () {
    Future<void> openWithKeyboard(
      WidgetTester tester, {
      Size size = const Size(400, 1400),
    }) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await open(tester, size: size);
    }

    FocusNode noteFocus(WidgetTester tester) =>
        tester.widget<TextField>(byKey('line-note')).focusNode!;

    Future<void> focusNote(WidgetTester tester) async {
      noteFocus(tester).requestFocus();
      await tester.pumpAndSettle();
    }

    Finder page(WidgetTester tester) => find
        .descendant(
          of: find.byType(Scaffold).last,
          matching: find.byType(Scrollable),
        )
        .first;

    BorderSide enabledSide(WidgetTester tester) =>
        (tester.widget<TextField>(byKey('line-note')).decoration!.enabledBorder!
                as OutlineInputBorder)
            .borderSide;

    testWidgets('with the keyboard open the note has Готово, and a tap '
        'outside or a drag closes it', (WidgetTester tester) async {
      await openWithKeyboard(tester);
      expect(byKey('keyboard-done'), findsNothing);

      await focusNote(tester);
      expect(byKey('keyboard-done'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(KeyboardDoneBar)).dy,
        lessThanOrEqualTo(1400 - 300),
      );
      expect(l10n(tester).keyboardDone, 'Готово');
      await tester.tap(byKey('keyboard-done'));
      await tester.pumpAndSettle();
      expect(noteFocus(tester).hasFocus, isFalse);
      expect(byKey('keyboard-done'), findsNothing);

      await focusNote(tester);
      await tester.tap(find.byType(ProductPhotoWell).first);
      await tester.pumpAndSettle();
      expect(noteFocus(tester).hasFocus, isFalse);
    });

    testWidgets('a drag of the page closes the keyboard', (
      WidgetTester tester,
    ) async {
      await openWithKeyboard(tester, size: const Size(400, 900));
      await focusNote(tester);
      expect(noteFocus(tester).hasFocus, isTrue);

      await tester.drag(page(tester), const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(noteFocus(tester).hasFocus, isFalse);
    });

    testWidgets(
      'the counter shows from 250 characters and turns red over 300',
      (WidgetTester tester) async {
        await open(tester);
        TextStyle style() =>
            tester.widget<Text>(byKey('product-note-count')).style!;

        await tester.enterText(byKey('line-note'), 'а' * 249);
        await tester.pump();
        expect(byKey('product-note-count'), findsNothing);

        await tester.enterText(byKey('line-note'), 'а' * 250);
        await tester.pump();
        expect(find.text('250 / 300'), findsOneWidget);
        expect(style().color, KitColors.muted);
        expect(style().fontSize, 12);

        await tester.enterText(byKey('line-note'), 'а' * 301);
        await tester.pump();
        expect(find.text('301 / 300'), findsOneWidget);
        expect(style().color, KitColors.danger);
        expect(style().fontWeight, FontWeight.w600);
      },
    );

    testWidgets('the error shows while typing', (WidgetTester tester) async {
      await open(tester);

      expect(byKey('product-note-error'), findsNothing);
      await tester.enterText(byKey('line-note'), 'а' * 301);
      await tester.pump();
      expect(byKey('product-note-error'), findsOneWidget);
      expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
      expect(enabledSide(tester).color, KitColors.danger);
      expect(enabledSide(tester).width, 1.5);

      await tester.enterText(byKey('line-note'), 'а' * 300);
      await tester.pump();
      expect(byKey('product-note-error'), findsNothing);
      expect(enabledSide(tester).style, BorderStyle.none);
    });

    testWidgets('В корзину with an over-long note brings the field into view '
        'and focuses it', (WidgetTester tester) async {
      await open(tester, size: const Size(400, 700));
      await tester.enterText(byKey('line-note'), 'а' * 301);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(page(tester)).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(byKey('line-note')).dy, greaterThan(700));

      await tester.tap(byKey('add-to-cart'));
      await tester.pumpAndSettle();

      expect(cart.added, isEmpty);
      expect(noteFocus(tester).hasFocus, isTrue);
      final double top = tester.getTopLeft(byKey('line-note')).dy;
      expect(top, greaterThan(0));
      expect(top, lessThan(500));
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
              sumUzs: 1000,
              action: ProductBarAction.add,
              onAction: () {},
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
      await tester.pump();
      await tester.pump();
      expect(byKey('product-added'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      final NewCartLine sent = cart.added.single;
      expect(sent.productId, tomatoProduct);
      expect(sent.quantity, '1.5');
      expect(sent.customerNote, 'Покрепче');
      expect(sent.substitutionPolicy, SubstitutionPolicy.contactBefore);
      expect(byKey('open-cart'), findsOneWidget);
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
      expect(tester.widget<TextField>(byKey('line-note')).readOnly, isTrue);

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

    for (final Locale device in const <Locale>[Locale('ru'), Locale('uz')]) {
      testWidgets('at 320 and text x2 the sum is whole and the button full '
          'width (${device.languageCode})', (WidgetTester tester) async {
        await open(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );

        final Finder bar = find.byType(ProductBar);
        expect(byKey('product-side-sum'), findsOneWidget);
        expect(byKey('product-sum'), findsNothing);
        final Rect sum = tester.getRect(byKey('product-side-sum'));
        final Rect barRect = tester.getRect(bar);
        expect(sum.left, greaterThanOrEqualTo(barRect.left + 16 - 0.5));
        expect(sum.right, lessThanOrEqualTo(barRect.right - 16 + 0.5));
        // The amount is whole: nothing cut, every line inside the bar.
        final RenderParagraph amount = tester.renderObject<RenderParagraph>(
          byKey('product-side-amount'),
        );
        expect(amount.didExceedMaxLines, isFalse);
        final String text = tester
            .widget<Text>(byKey('product-side-amount'))
            .data!;
        for (final TextBox box in amount.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )) {
          expect(box.right, lessThanOrEqualTo(amount.size.width + 0.5));
        }
        expect(amount.size.width, lessThanOrEqualTo(320 - 32 + 0.5));

        expect(
          tester.getSize(byKey('add-to-cart')).width,
          closeTo(320 - 32, 0.5),
        );
        expect(byKey('add-to-cart').hitTestable(), findsOneWidget);
        expect(
          find.descendant(of: bar, matching: find.byType(FittedBox)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final double width in <double>[390]) {
      testWidgets('at $width and text x2 the sum stands beside the stepper', (
        WidgetTester tester,
      ) async {
        await open(tester, size: Size(width, 800), textScale: 2);

        // Either inside the button beside the stepper or in the sum block
        // beside it: never pushed below.
        final Finder sum = byKey('product-side-sum').evaluate().isEmpty
            ? byKey('product-sum')
            : byKey('product-side-sum');
        final Rect stepper = tester.getRect(
          find
              .ancestor(
                of: byKey('product-minus'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final Rect shown = tester.getRect(sum);
        expect(shown.left, greaterThanOrEqualTo(stepper.right));
        expect(shown.top, lessThan(stepper.bottom));
        expect(byKey('add-to-cart').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('at 400 and text x1 the button keeps its sum beside the '
        'stepper', (WidgetTester tester) async {
      await open(tester);

      expect(byKey('product-side-sum'), findsNothing);
      expect(byKey('product-sum'), findsOneWidget);
      expect(
        tester.getRect(byKey('add-to-cart')).left,
        greaterThan(tester.getRect(byKey('product-plus')).right),
      );
    });

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
      await tester.pump();
      expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(find.text(l10n(tester).fieldTooLong(300)), findsOneWidget);
      expect(cart.added, isEmpty);

      // 300 tomatoes: 300 code points, 600 UTF-16 units: within the limit.
      final String tomatoes = List<String>.filled(300, '\u{1F345}').join();
      await tester.enterText(byKey('line-note'), tomatoes);
      await tester.pump();
      expect(find.text(l10n(tester).fieldTooLong(300)), findsNothing);
      await tapAndSettle(tester, byKey('add-to-cart'));
      expect(cart.added.single.customerNote, tomatoes);

      // A trailing zero-width space is trimmed by the server, not counted.
      await tester.enterText(byKey('line-note'), '$tomatoes\u200b');
      await tester.pump();
      expect(find.text(l10n(tester).fieldTooLong(300)), findsNothing);
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
        tester.widget<TextField>(byKey('line-note')).controller!.text,
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
        expect(byKey('product-added'), findsNothing);
        expect(byKey('add-to-cart'), findsNothing);
        expect(byKey('open-cart'), findsOneWidget);
        expect(quantityShown(tester), '2 кг');
        expect(
          tester.widget<TextField>(byKey('line-note')).controller!.text,
          'Покрепче',
        );
        expect(cart.added, hasLength(1), reason: 'no second add');
      },
    );

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

  group('the add answers on its button', () {
    final List<MethodCall> platformCalls = <MethodCall>[];

    setUp(() {
      platformCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            platformCalls.add(call);
            return null;
          });
    });

    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    Cart tomatoOne() => cartOf(<Map<String, Object?>>[
      cartLineJson(quantity: '1.000', price: 12075, total: 12075),
    ]);

    Color? fillOf(WidgetTester tester, String key) => tester
        .widget<ButtonStyleButton>(byKey(key))
        .style
        ?.backgroundColor
        ?.resolve(<WidgetState>{});

    testWidgets('adding says Добавляем… on the green button', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final Completer<void> hold = Completer<void>();
      cart.hold = hold;

      await tester.tap(byKey('add-to-cart'));
      await tester.pump();

      expect(
        find.descendant(
          of: byKey('add-to-cart'),
          matching: find.text(l10n(tester).productAdding),
        ),
        findsOneWidget,
      );
      final Finder spinner = find.descendant(
        of: byKey('add-to-cart'),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsOneWidget);
      expect(
        find.ancestor(of: spinner, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(fillOf(tester, 'add-to-cart'), KitColors.primary);
      expect(iconEnabled(tester, 'product-plus'), isFalse);

      cart.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'an added product shows В корзине with a light haptic, then Открыть корзину',
      (WidgetTester tester) async {
        await open(tester);
        cart.answer = tomatoOne();

        await tester.tap(byKey('add-to-cart'));
        await tester.pump();
        await tester.pump();

        expect(
          platformCalls.where(
            (MethodCall c) =>
                c.method == 'HapticFeedback.vibrate' &&
                c.arguments == 'HapticFeedbackType.lightImpact',
          ),
          hasLength(1),
        );
        expect(byKey('product-added'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text(l10n(tester).productAdded), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(
          tester.takeAnnouncements().map(
            (CapturedAccessibilityAnnouncement a) => a.message,
          ),
          <String>[l10n(tester).cartCardAdded('Помидор', '1 кг')],
        );

        await tester.pump(const Duration(milliseconds: 1000));
        expect(byKey('product-added'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(byKey('product-added'), findsNothing);
        expect(byKey('open-cart'), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('open-cart'),
            matching: find.text(l10n(tester).cartOpen),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: byKey('open-cart'),
            matching: find.text('1 кг · ${approx(12075)}'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('the check pops in; with reduced motion it stands at once', (
      WidgetTester tester,
    ) async {
      await open(tester);
      cart.answer = tomatoOne();
      await tester.tap(byKey('add-to-cart'));
      await tester.pump();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 50));
      final double early = tester
          .widget<Opacity>(
            find.descendant(
              of: byKey('product-added'),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(early, lessThan(1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: byKey('product-added'),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        1,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('with reduced motion the check stands at once', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester);
      cart.answer = tomatoOne();

      await tester.tap(byKey('add-to-cart'));
      await tester.pump();
      await tester.pump();

      expect(byKey('product-added'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('product-added'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });

    testWidgets(
      'the in-cart chip folds in after the add and stands still when opened '
      'in the cart',
      (WidgetTester tester) async {
        await open(tester);
        expect(tester.getSize(find.byType(Fold).first).height, 0);
        cart.answer = tomatoOne();

        await tester.tap(byKey('add-to-cart'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final double mid = tester.getSize(find.byType(Fold).first).height;
        expect(mid, greaterThan(0));
        await tester.pumpAndSettle();
        final double full = tester.getSize(find.byType(Fold).first).height;
        expect(mid, lessThan(full));
        expect(byKey('product-in-cart'), findsOneWidget);
      },
    );

    testWidgets(
      'the chip is whole at the first frame when opened in the cart',
      (WidgetTester tester) async {
        cart.current = tomatoOne();
        await open(tester, push: false);
        GoRouter.of(anywhere(tester)).push('/customer/products/$tomatoProduct');
        await tester.pumpAndSettle();

        expect(byKey('product-in-cart'), findsOneWidget);
        expect(tester.getSize(find.byType(Fold).first).height, greaterThan(0));
      },
    );

    testWidgets('Открыть корзину opens the cart', (WidgetTester tester) async {
      cart.current = tomatoOne();
      await open(tester);

      await tester.tap(byKey('open-cart'));
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
    });
  });

  group('a product already in the cart', () {
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

    Finder mark(String field) => byKey('product-save-mark-$field');

    Future<void> refreshOnly(WidgetTester tester) async {
      final ProviderContainer container = ProviderScope.containerOf(
        anywhere(tester),
      );
      final String account = container.read(customerAccountProvider)!;
      await container.read(cartProvider(account).notifier).refresh();
      await tester.pump();
    }

    testWidgets('opens with the line and Открыть корзину', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);

      expect(chipShown(tester), 'В корзине: 2 кг');
      expect(quantityShown(tester), '2 кг');
      expect(sumShown(tester), '2 кг · ${approx(43700)}');
      expect(radioChosen(tester, 'contact_before_substitution'), isTrue);
      expect(
        tester.widget<TextField>(byKey('line-note')).controller!.text,
        'Покрепче',
      );
      expect(byKey('add-to-cart'), findsNothing);
      expect(byKey('open-cart'), findsOneWidget);
      expect(find.text('Сохранить'), findsNothing);
      expect(mark('quantity'), findsNothing);
    });

    testWidgets('a step in the cart is sent by itself', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      final Completer<void> hold = Completer<void>();

      await tester.tap(byKey('product-plus'));
      await tester.pump();
      expect(quantityShown(tester), '2,5 кг');
      cart.hold = hold;
      cart.answer = tomatoInCart(quantity: '2.500');
      await tester.pump(const Duration(milliseconds: 400));
      expect(cart.patches, isEmpty);
      expect(mark('quantity'), findsOneWidget);
      expect(find.text('Сохраняем…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(cart.patches.single.quantity, '2.5');
      expect(find.text('Сохраняем…'), findsOneWidget);

      hold.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Сохранено'), findsOneWidget);
      expect(find.text('Сохраняем…'), findsNothing);
      expect(chipShown(tester), 'В корзине: 2,5 кг');

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(mark('quantity'), findsNothing);
    });

    testWidgets('a rule is saved at once', (WidgetTester tester) async {
      cart.current = tomatoInCart();
      await open(tester);
      cart.answer = tomatoInCart(policy: 'remove_if_unavailable');

      await tester.tap(byKey('substitution-remove_if_unavailable'));
      await tester.pump();

      final CartLinePatch sent = cart.patches.single;
      expect(sent.substitutionPolicy, SubstitutionPolicy.removeIfUnavailable);
      expect(sent.quantity, isNull);
      await tester.pump(const Duration(milliseconds: 250));
      expect(mark('policy'), findsOneWidget);
      expect(find.text('Сохранено'), findsOneWidget);
      expect(radioChosen(tester, 'remove_if_unavailable'), isTrue);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(mark('policy'), findsNothing);
    });

    testWidgets(
      'a note is saved a second after the last key, and when the field closes',
      (WidgetTester tester) async {
        cart.current = tomatoInCart();
        await open(tester);

        await tester.enterText(byKey('line-note'), '  Помягче ');
        cart.answer = tomatoInCart(note: 'Помягче');
        await tester.pump(const Duration(milliseconds: 900));
        expect(cart.patches, isEmpty);
        await tester.pump(const Duration(milliseconds: 150));
        final CartLinePatch first = cart.patches.single;
        expect(first.noteChanged, isTrue);
        expect(first.customerNote, 'Помягче');
        await tester.pump(const Duration(milliseconds: 250));
        expect(mark('note'), findsOneWidget);
        expect(find.text('Сохранено'), findsOneWidget);

        await tester.enterText(byKey('line-note'), 'Совсем мягкие');
        cart.answer = tomatoInCart(note: 'Совсем мягкие');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        expect(cart.patches, hasLength(2));
        expect(cart.patches.last.customerNote, 'Совсем мягкие');
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('leaving at once still saves the note and the step', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);

      await tester.enterText(byKey('line-note'), 'Помягче');
      await tester.tap(byKey('product-plus'));
      await tester.pump(const Duration(milliseconds: 100));
      cart.answer = tomatoInCart(quantity: '2.500', note: 'Помягче');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(
        cart.patches.any((CartLinePatch p) => p.quantity == '2.5'),
        isTrue,
      );
      expect(
        cart.patches.any((CartLinePatch p) => p.customerNote == 'Помягче'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an over-long note is not sent', (WidgetTester tester) async {
      cart.current = tomatoInCart();
      await open(tester);

      await tester.enterText(
        byKey('line-note'),
        List<String>.filled(301, 'а').join(),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(cart.patches, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed save says so and shows no Сохранено', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);

      await tester.tap(byKey('product-plus'));
      cart.failure = const UnexpectedFailure();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Сохранено'), findsNothing);
      expect(mark('quantity'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets(
      'a failed note save keeps the text and sends it again when the screen goes',
      (WidgetTester tester) async {
        cart.current = tomatoInCart();
        await open(tester);

        await tester.enterText(byKey('line-note'), 'Помягче');
        cart.failure = const UnexpectedFailure();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(cart.patches, hasLength(1));

        expect(
          tester.widget<TextField>(byKey('line-note')).controller!.text,
          'Помягче',
        );
        await tester.pump(const Duration(seconds: 7));

        cart.answer = tomatoInCart(note: 'Помягче');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        expect(cart.patches, hasLength(2));
        expect(cart.patches.last.customerNote, 'Помягче');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a cart answer does not undo a rule still on its way', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      final Completer<void> hold = Completer<void>();
      cart.hold = hold;

      await tester.tap(byKey('substitution-remove_if_unavailable'));
      await tester.pump();
      cart.hold = null;
      cart.current = tomatoInCart();
      await refreshOnly(tester);

      expect(radioChosen(tester, 'remove_if_unavailable'), isTrue);
      cart.current = tomatoInCart(policy: 'remove_if_unavailable');
      hold.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(radioChosen(tester, 'remove_if_unavailable'), isTrue);
    });

    testWidgets('at the smallest step the minus is a bin that removes with '
        'Вернуть', (WidgetTester tester) async {
      cart.current = tomatoInCart(quantity: '0.500');
      await open(tester);

      expect(
        find.descendant(
          of: byKey('product-minus'),
          matching: find.byIcon(Icons.delete_outline),
        ),
        findsOneWidget,
      );
      cart.answer = cartOf(<Map<String, Object?>>[]);
      await tester.tap(byKey('product-minus'));
      await tester.pumpAndSettle();

      expect(cart.calls, contains('remove:$tomatoLine'));
      expect(
        find.text(l10n(tester).cartLineRemoved('Помидор')),
        findsOneWidget,
      );

      cart.answer = tomatoInCart(quantity: '0.500');
      await tester.tap(find.text(l10n(tester).undoAction));
      await tester.pumpAndSettle();

      final NewCartLine again = cart.added.single;
      expect(again.quantity, '0.5');
      expect(again.customerNote, 'Покрепче');
      expect(again.substitutionPolicy, SubstitutionPolicy.contactBefore);
    });

    testWidgets('out of the cart the minus at the smallest step stays '
        'inactive', (WidgetTester tester) async {
      await open(tester);

      await tester.tap(byKey('product-minus'));
      await tester.pumpAndSettle();

      expect(quantityShown(tester), '0,5 кг');
      expect(iconEnabled(tester, 'product-minus'), isFalse);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
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
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(byKey('add-to-cart'), findsNothing);
      expect(byKey('open-cart'), findsOneWidget);
      expect(chipShown(tester), 'В корзине: 1,5 кг');
      expect(cart.added, hasLength(1));
    });

    testWidgets('a line removed elsewhere turns it back to a new add', (
      WidgetTester tester,
    ) async {
      cart.current = tomatoInCart();
      await open(tester);
      expect(byKey('open-cart'), findsOneWidget);

      cart.current = cartOf(<Map<String, Object?>>[]);
      await refreshCart(tester);

      expect(byKey('open-cart'), findsNothing);
      expect(byKey('product-in-cart'), findsNothing);
      expect(enabled(tester, 'add-to-cart'), isTrue);
      expect(quantityShown(tester), '1 кг');
      expect(radioChosen(tester, 'allow_similar_substitution'), isTrue);
      expect(
        tester.widget<TextField>(byKey('line-note')).controller!.text,
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
      await tester.pump();

      await refreshOnly(tester);

      expect(quantityShown(tester), '2,5 кг');
      expect(
        tester.widget<TextField>(byKey('line-note')).controller!.text,
        'Помягче',
      );
      await tester.pump(const Duration(seconds: 2));
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
        tester.widget<TextField>(byKey('line-note')).controller!.text,
        isEmpty,
      );
    });

    testWidgets('a line changed elsewhere does not overwrite the note being '
        'typed', (WidgetTester tester) async {
      cart.current = tomatoInCart();
      await open(tester);
      await tester.enterText(byKey('line-note'), 'Помягче');
      await tester.pump();

      cart.current = tomatoInCart(quantity: '3.000', note: 'Со стороны');
      await refreshOnly(tester);

      expect(quantityShown(tester), '3 кг');
      expect(
        tester.widget<TextField>(byKey('line-note')).controller!.text,
        'Помягче',
        reason: 'the note being typed stays',
      );
      await tester.pump(const Duration(seconds: 2));
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

    // The field keeps letters out, so "abc" is an empty field, which asks for
    // a quantity rather than naming an error; too many decimals are typed.
    for (final String bad in <String>['0', '1,2345']) {
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

  group('opening from a card', () {
    ProductOpening cardOf(CatalogProduct product) =>
        ProductOpening(product: product, heroTag: Object());

    Finder spinner() => find.byType(CircularProgressIndicator);

    double fadeOpacity(WidgetTester tester) =>
        tester.widget<FadeTransition>(byKey('product-page-fade')).opacity.value;

    /// Taps the home card of the tomato and leaves the route running.
    Future<void> tapHomeCard(WidgetTester tester) async {
      catalog.featuredIds = <String>{tomatoProduct};
      await open(tester, push: false);
      await tester.tap(
        find
            .descendant(
              of: byKey('product-card-$tomatoProduct'),
              matching: find.text('Помидор'),
            )
            .first,
      );
      await tester.pump();
    }

    testWidgets(
      "opened from a card it shows the card's product at once, the heart and the bar too",
      (WidgetTester tester) async {
        catalog.productHold = Completer<void>();
        await open(tester, opening: cardOf(item()));

        expect(byKey('product-name'), findsOneWidget);
        expect(byKey('product-price'), findsOneWidget);
        expect(byKey('product-heart'), findsOneWidget);
        expect(byKey('add-to-cart'), findsOneWidget);
        expect(spinner(), findsNothing);
        catalog.productHold!.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets("the server's answer replaces the card's figures", (
      WidgetTester tester,
    ) async {
      catalog.productHold = Completer<void>();
      catalog.productRows = <CatalogProduct>[item(customerUnitPriceUzs: 13000)];
      await open(tester, opening: cardOf(item(customerUnitPriceUzs: 12075)));
      expect(tester.widget<Text>(byKey('product-price')).data, approx(12075));

      catalog.productHold!.complete();
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(byKey('product-price')).data, approx(13000));
    });

    testWidgets("a 404 after the card's data shows the product gone", (
      WidgetTester tester,
    ) async {
      catalog.productHold = Completer<void>();
      catalog.productRows = <CatalogProduct>[];
      await open(tester, opening: cardOf(item()));
      expect(byKey('product-name'), findsOneWidget);

      catalog.productHold!.complete();
      await tester.pumpAndSettle();

      expect(byKey('product-gone'), findsOneWidget);
      expect(byKey('product-name'), findsNothing);
      expect(byKey('add-to-cart'), findsNothing);
    });

    testWidgets("another failure keeps the card's page quietly", (
      WidgetTester tester,
    ) async {
      catalog.productHold = Completer<void>();
      catalog.productFailure = const NetworkFailure();
      await open(tester, opening: cardOf(item()));

      catalog.productHold!.complete();
      await tester.pumpAndSettle();

      expect(byKey('retry-load'), findsNothing);
      expect(byKey('product-name'), findsOneWidget);
      expect(byKey('add-to-cart'), findsOneWidget);
    });

    testWidgets('the photo flies from the card', (WidgetTester tester) async {
      await tapHomeCard(tester);
      await tester.pump(const Duration(milliseconds: 150));

      expect(byKey('product-photo-flight'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(byKey('product-photo-flight'), findsNothing);
      expect(find.byType(ProductPhotoWell), findsOneWidget);
    });

    testWidgets('the page fades up after the photo', (
      WidgetTester tester,
    ) async {
      await open(tester, push: false);
      GoRouter.of(anywhere(tester))
          .push('/customer/products/$tomatoProduct', extra: cardOf(item()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fadeOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 390));
      expect(fadeOpacity(tester), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('with reduced motion nothing flies or fades', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      catalog.productRows = <CatalogProduct>[item()];
      await open(tester, push: false);
      GoRouter.of(anywhere(tester))
          .push('/customer/products/$tomatoProduct', extra: cardOf(item()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.descendant(
          of: find.byType(ProductScreen),
          matching: find.byType(Hero),
        ),
        findsNothing,
      );
      expect(byKey('product-page-fade'), findsNothing);
      expect(byKey('product-name'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('one product twice on a screen opens without a hero clash', (
      WidgetTester tester,
    ) async {
      final CatalogProduct tomato = item();
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: Column(
                children: <Widget>[
                  for (int i = 0; i < 2; i++)
                    SizedBox(
                      width: 161,
                      child: KitProductCard(product: tomato),
                    ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/customer/products/:product',
            builder: (BuildContext context, GoRouterState state) =>
                ProductScreen(
                  productId: state.pathParameters['product']!,
                  opening: state.extra as ProductOpening?,
                ),
          ),
        ],
      );
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (int count, Object error) => null,
          overrides: [
            customerAccountProvider.overrideWithValue('c'),
            catalogRepositoryProvider.overrideWithValue(catalog),
            cartRepositoryProvider.overrideWithValue(cart),
            favoritesRepositoryProvider.overrideWithValue(favorites),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Помидор').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(byKey('product-name'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(byKey('product-name'), findsNothing);
    });
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
