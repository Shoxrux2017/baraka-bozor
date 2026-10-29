import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_summary_bar.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_grid.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

/// A text scaler as Android 14 and later apply it: small sizes grow more than
/// large ones (2.0 at 12 px and below, 1.5 at 20 px and above).
class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) {
    final double factor = fontSize <= 12
        ? 2.0
        : fontSize >= 20
        ? 1.5
        : 2.0 - 0.5 * (fontSize - 12) / 8;
    return fontSize * factor;
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => 2;

  @override
  bool operator ==(Object other) => other is _NonlinearScaler;

  @override
  int get hashCode => 17;
}

void main() {
  late FakeCartRepository cart;
  late FakeFavoritesRepository favorites;
  late FakeCatalogRepository catalog;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  const String idA = '0192f0a0-0000-7000-8000-0000000000a1';
  const String idB = '0192f0a0-0000-7000-8000-0000000000a2';
  const String idL = '0192f0a0-0000-7000-8000-0000000000a3';
  const String lineA = '0192f0a0-0000-7000-8000-0000000000b1';
  const String lineB = '0192f0a0-0000-7000-8000-0000000000b2';
  const String lineL = '0192f0a0-0000-7000-8000-0000000000b3';
  final CatalogProduct bread = catalogProduct(
    id: idA,
    nameRu: 'Хлеб',
    unitCode: UnitCode.piece,
  );
  final CatalogProduct milk = catalogProduct(
    id: idB,
    nameRu: 'Молоко',
    unitCode: UnitCode.piece,
  );

  Map<String, Object?> pieceLine(String id, String productId) =>
      cartLineJson(id: id, productId: productId, unit: 'piece', quantity: '1');

  setUp(() {
    cart = FakeCartRepository();
    favorites = FakeFavoritesRepository();
    catalog = FakeCatalogRepository();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('ru'),
    TextScaler? scaler,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          cartRepositoryProvider.overrideWithValue(cart),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          catalogRepositoryProvider.overrideWithValue(catalog),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? home) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: scaler ?? MediaQuery.textScalerOf(context)),
            child: home!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a nonlinear text scale (Android 14 and later)', () {
    final CatalogProduct longName = catalogProduct(
      id: idL,
      nameUz: 'Juda uzun nomli mahsulot ' * 3,
      nameRu: 'Очень длинное название товара для проверки ' * 2,
      customerUnitPriceUzs: 1234567,
    );

    for (final KitCardSize size in KitCardSize.values) {
      for (final bool inCart in <bool>[false, true]) {
        testWidgets('$size fits the extent asked for, inCart=$inCart', (
          WidgetTester tester,
        ) async {
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          if (inCart) {
            cart = FakeCartRepository(
              cart: cartOf(<Map<String, Object?>>[
                cartLineJson(id: lineL, productId: idL, quantity: '1234.500'),
              ]),
            );
          }
          const TextScaler scaler = _NonlinearScaler();
          final double imageHeight = size == KitCardSize.compact ? 84 : 112;
          final double extent = kitCardExtent(
            scaler,
            size: size,
            imageHeight: imageHeight,
          );
          await pump(
            tester,
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: size == KitCardSize.compact ? 119 : 150,
                height: extent,
                child: KitProductCard(
                  product: longName,
                  size: size,
                  imageHeight: imageHeight,
                ),
              ),
            ),
            scaler: scaler,
          );

          expect(tester.takeException(), isNull);
          final Rect card = tester.getRect(byKey('product-card-$idL'));
          final Finder control = inCart
              ? byKey('step-plus-$idL')
              : byKey('add-$idL');
          expect(
            tester.getRect(control).bottom,
            lessThanOrEqualTo(card.bottom),
            reason: 'the control stays inside the card',
          );
        });
      }
    }
  });

  group('the extent leaves no empty band', () {
    final CatalogProduct twoLines = catalogProduct(
      id: idL,
      nameRu: 'Очень длинное название товара для проверки ' * 2,
      customerUnitPriceUzs: 12075,
    );

    for (final KitCardSize size in KitCardSize.values) {
      testWidgets('$size, two-line name, text scale 1', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final double imageHeight = size == KitCardSize.compact ? 84 : 112;
        final double extent = kitCardExtent(
          TextScaler.noScaling,
          size: size,
          imageHeight: imageHeight,
        );
        await pump(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size == KitCardSize.compact ? 119 : 150,
              height: extent,
              child: KitProductCard(
                product: twoLines,
                size: size,
                imageHeight: imageHeight,
              ),
            ),
          ),
        );

        final Rect card = tester.getRect(byKey('product-card-$idL'));
        final Rect name = tester.getRect(find.text(twoLines.nameRu));
        final Rect price = tester.getRect(find.textContaining('≈'));
        final double rowTop = tester.getCenter(byKey('add-$idL')).dy - 22;
        expect(name.top - card.top, closeTo(8 + imageHeight + 8, 2));
        expect(price.top - name.bottom, closeTo(4, 2));
        expect(rowTop - price.bottom, closeTo(8, 2), reason: 'no band');
        expect(card.bottom - (rowTop + 44), closeTo(8, 2));
      });
    }
  });

  testWidgets('a change that answers after the card is gone raises nothing', (
    WidgetTester tester,
  ) async {
    await pump(tester, KitProductCard(product: bread));
    final Completer<void> hold = Completer<void>();
    cart.hold = hold;
    cart.failure = const UnexpectedFailure();
    await tester.tap(byKey('add-$idA'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    hold.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('every grid card is keyed by its product', (
    WidgetTester tester,
  ) async {
    catalog.productRows = <CatalogProduct>[bread, milk];
    await pump(tester, const KitProductGrid(query: ProductListQuery()));
    final List<Key?> keys = tester
        .widgetList<KitProductCard>(find.byType(KitProductCard))
        .map((KitProductCard c) => c.key)
        .toList();
    expect(keys, <Key>[ValueKey<String>(idA), ValueKey<String>(idB)]);
  });

  testWidgets('two cards can each remove their line at the same time', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        pieceLine(lineA, idA),
        pieceLine(lineB, idB),
      ]),
    );
    await pump(
      tester,
      Row(
        children: <Widget>[
          Expanded(child: KitProductCard(product: bread)),
          Expanded(child: KitProductCard(product: milk)),
        ],
      ),
    );
    final Completer<void> hold = Completer<void>();
    cart.hold = hold;
    await tester.tap(byKey('step-minus-$idA'));
    await tester.pump();
    await tester.tap(byKey('step-minus-$idB'));
    await tester.pump();
    cart.answer = cartOf(<Map<String, Object?>>[]);
    hold.complete();
    await tester.pumpAndSettle();

    expect(cart.calls.where((String c) => c.startsWith('remove:')), <String>[
      'remove:$lineA',
      'remove:$lineB',
    ], reason: 'neither removal is dropped');
  });

  group('a full favourites list', () {
    for (final (Locale, String) say in <(Locale, String)>[
      (const Locale('ru'), 'В избранном уже 500 товаров — уберите лишние'),
      (const Locale('uz'), "Sevimlilar to'ldi: 500 tadan ko'p bo'lmaydi"),
    ]) {
      testWidgets('is said as such (${say.$1.languageCode})', (
        WidgetTester tester,
      ) async {
        await pump(tester, KitProductCard(product: bread), locale: say.$1);
        favorites.nextFailure = const ApiRefusal(
          ApiError(status: 409, code: 'favorites_full'),
        );
        await tester.tap(byKey('heart-$idA'));
        await tester.pumpAndSettle();

        expect(find.text(say.$2), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsNothing, reason: 'undone');
      });
    }

    testWidgets('another refusal keeps the generic text', (
      WidgetTester tester,
    ) async {
      await pump(tester, KitProductCard(product: bread));
      favorites.nextFailure = const ApiRefusal(
        ApiError(status: 404, code: 'resource_not_found'),
      );
      await tester.tap(byKey('heart-$idA'));
      await tester.pumpAndSettle();

      expect(
        find.text('Не удалось сохранить. Попробуйте ещё раз'),
        findsOneWidget,
      );
    });
  });

  group('a favourite no longer sold', () {
    TextStyle? style(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style;

    testWidgets('has a faded picture and muted name and price', (
      WidgetTester tester,
    ) async {
      await pump(tester, KitProductCard(product: bread, available: false));

      expect(tester.widget<Opacity>(byKey('picture-$idA')).opacity, 0.45);
      expect(style(tester, 'Хлеб')?.color, KitColors.muted);
      final Text price = tester
          .widgetList<Text>(find.textContaining('≈'))
          .single;
      expect(price.style?.color, KitColors.muted);
    });

    testWidgets('a product on sale keeps its full colours', (
      WidgetTester tester,
    ) async {
      await pump(tester, KitProductCard(product: bread));

      expect(tester.widget<Opacity>(byKey('picture-$idA')).opacity, 1);
      expect(style(tester, 'Хлеб')?.color, KitColors.ink);
    });
  });

  group('the cart bar reserves its real height', () {
    for (final double scale in <double>[1, 2]) {
      for (final double inset in <double>[0, 48]) {
        testWidgets('at text x$scale with a bottom inset of $inset', (
          WidgetTester tester,
        ) async {
          cart = FakeCartRepository(
            cart: cartOf(<Map<String, Object?>>[pieceLine(lineA, idA)]),
          );
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(bottom: inset);
          addTearDown(tester.view.reset);
          late double reserved;
          await pump(
            tester,
            Stack(
              children: <Widget>[
                Builder(
                  builder: (BuildContext context) {
                    reserved = CartSummaryBar.reserved(context);
                    return const SizedBox.expand();
                  },
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CartSummaryBar(),
                ),
              ],
            ),
            scaler: TextScaler.linear(scale),
          );

          expect(tester.takeException(), isNull);
          final Rect bar = tester.getRect(
            find
                .descendant(
                  of: find.byType(CartSummaryBar),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect(
            reserved,
            greaterThanOrEqualTo(bar.height - 0.5),
            reason: 'the last row is never under the bar',
          );
        });
      }
    }
  });
}
