import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/widgets/product_image.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/presentation/catalog_paths.dart';
import 'package:baraka_bozor/features/catalog/presentation/kit_product_card.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_cart_repository.dart';
import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

/// A non-breaking space, as the quantity and its unit are joined.
final String _nb = String.fromCharCode(0xA0);

String _qty(String number, String unit) => '$number$_nb$unit';

void main() {
  late FakeCartRepository cart;
  late FakeFavoritesRepository favorites;
  String? opened;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> show(
    WidgetTester tester,
    CatalogProduct product, {
    Locale locale = const Locale('ru'),
    KitCardSize size = KitCardSize.regular,
    double? imageHeight,
    bool available = true,
    double width = 161,
  }) async {
    opened = null;
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: KitProductCard(
                  product: product,
                  size: size,
                  imageHeight: imageHeight,
                  available: available,
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/customer/products/:product',
          builder: (BuildContext context, GoRouterState state) {
            opened = state.uri.path;
            return const Scaffold(body: Text('product page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int count, Object error) => null,
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          cartRepositoryProvider.overrideWithValue(cart),
          favoritesRepositoryProvider.overrideWithValue(favorites),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, Object?> lineOf(
    CatalogProduct product,
    String quantity,
    String id,
  ) => cartLineJson(
    id: id,
    productId: product.id,
    unit: product.unitCode == UnitCode.kg ? 'kg' : 'piece',
    quantity: product.unitCode == UnitCode.kg
        ? double.parse(quantity).toStringAsFixed(3)
        : quantity,
  );

  String quantityShown(WidgetTester tester, String id) =>
      tester.widget<Text>(byKey('step-qty-$id')).data!;

  setUp(() {
    cart = FakeCartRepository();
    favorites = FakeFavoritesRepository();
  });

  final CatalogProduct tomato = catalogProduct(
    id: '0192f0a0-0000-7000-8000-0000000000a1',
    customerUnitPriceUzs: 12000,
  );
  final CatalogProduct bread = catalogProduct(
    id: '0192f0a0-0000-7000-8000-0000000000a2',
    nameRu: 'Хлеб',
    unitCode: UnitCode.piece,
    customerUnitPriceUzs: 4000,
  );

  testWidgets('shows the name, the approximate price and the unit', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato);
    expect(find.text('Помидор'), findsOneWidget);
    expect(
      find.text('≈ ${MoneyFormat.uzs(12000, AppLanguage.ru)}'),
      findsOneWidget,
    );
    expect(find.text('за кг'), findsOneWidget);
    expect(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'), findsOneWidget);
    expect(find.byTooltip('Добавить'), findsOneWidget);
    expect(find.text('Добавить'), findsNothing);
  });

  testWidgets('the unit and the plus are on one row', (
    WidgetTester tester,
  ) async {
    for (final KitCardSize size in KitCardSize.values) {
      await show(tester, tomato, size: size);
      final double unit = tester.getCenter(find.text('за кг')).dy;
      final double plus = tester
          .getCenter(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'))
          .dy;
      expect((unit - plus).abs(), lessThanOrEqualTo(2), reason: '$size');
      expect(
        tester.getCenter(find.text('за кг')).dx,
        lessThan(
          tester
              .getCenter(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'))
              .dx,
        ),
        reason: 'the unit is at the left',
      );
    }
  });

  testWidgets('in the cart the row is the stepper and shows no separate unit', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
      ]),
    );
    await show(tester, tomato);
    expect(
      byKey('step-qty-0192f0a0-0000-7000-8000-0000000000a1'),
      findsOneWidget,
    );
    expect(find.text('за кг'), findsNothing);
  });

  testWidgets('the picture is smaller than its well and the tap area of the '
      'plus is at least 40 square', (WidgetTester tester) async {
    for (final KitCardSize size in KitCardSize.values) {
      await show(tester, tomato, size: size);
      final Size picture = tester.getSize(find.byType(ProductImage));
      final double well = size == KitCardSize.compact ? 84 : 112;
      expect(picture.height, lessThanOrEqualTo(0.75 * well), reason: '$size');
      expect(picture.height, greaterThan(0));
    }
  });

  testWidgets('a tap just outside the plus still adds, and opens nothing', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato, size: KitCardSize.compact);
    final Finder plus = byKey('add-0192f0a0-0000-7000-8000-0000000000a1');
    expect(tester.getSize(plus).width, 32);
    await tester.tapAt(tester.getCenter(plus) + const Offset(-18, 0));
    await tester.pumpAndSettle();
    expect(cart.added, hasLength(1));
    expect(opened, isNull);
  });

  testWidgets('shows the Uzbek name and unit line in Uzbek', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato, locale: const Locale('uz'));
    expect(find.text('Pomidor'), findsOneWidget);
    expect(find.text('kg uchun'), findsOneWidget);
    expect(find.byTooltip("Qo'shish"), findsOneWidget);
  });

  testWidgets('one tap adds one unit, allowing similar, with no note', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato);
    await tester.tap(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'));
    await tester.pumpAndSettle();

    final NewCartLine sent = cart.added.single;
    expect(sent.productId, '0192f0a0-0000-7000-8000-0000000000a1');
    expect(sent.quantity, '1');
    expect(sent.customerNote, isNull);
    expect(sent.substitutionPolicy, SubstitutionPolicy.allowSimilar);
  });

  testWidgets('after the add the card shows the stepper at 1 kg', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato);
    cart.answer = cartOf(<Map<String, Object?>>[
      lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
    ]);
    await tester.tap(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'));
    await tester.pumpAndSettle();

    expect(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'), findsNothing);
    expect(
      quantityShown(tester, '0192f0a0-0000-7000-8000-0000000000a1'),
      _qty('1', 'кг'),
    );
  });

  testWidgets('a product in the cart shows its stepper at once', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        lineOf(tomato, '1.500', '0192f0a0-0000-7000-8000-0000000000b1'),
      ]),
    );
    await show(tester, tomato);
    expect(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'), findsNothing);
    expect(
      quantityShown(tester, '0192f0a0-0000-7000-8000-0000000000a1'),
      _qty('1,5', 'кг'),
    );
  });

  testWidgets('plus changes the line by a step', (WidgetTester tester) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
      ]),
    );
    await show(tester, tomato);
    cart.answer = cartOf(<Map<String, Object?>>[
      lineOf(tomato, '1.5', '0192f0a0-0000-7000-8000-0000000000b1'),
    ]);
    await tester.tap(byKey('step-plus-0192f0a0-0000-7000-8000-0000000000a1'));
    await tester.pumpAndSettle();

    expect(cart.calls, contains('change:0192f0a0-0000-7000-8000-0000000000b1'));
    expect(cart.patches.single.quantity, '1.5');
    expect(
      quantityShown(tester, '0192f0a0-0000-7000-8000-0000000000a1'),
      _qty('1,5', 'кг'),
    );
  });

  testWidgets('minus changes the line by a step', (WidgetTester tester) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
      ]),
    );
    await show(tester, tomato);
    cart.answer = cartOf(<Map<String, Object?>>[
      lineOf(tomato, '0.5', '0192f0a0-0000-7000-8000-0000000000b1'),
    ]);
    await tester.tap(byKey('step-minus-0192f0a0-0000-7000-8000-0000000000a1'));
    await tester.pumpAndSettle();

    expect(cart.patches.single.quantity, '0.5');
  });

  testWidgets('minus at one piece removes the line', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        lineOf(bread, '1', '0192f0a0-0000-7000-8000-0000000000b2'),
      ]),
    );
    await show(tester, bread);
    cart.answer = cartOf(<Map<String, Object?>>[]);
    await tester.tap(byKey('step-minus-0192f0a0-0000-7000-8000-0000000000a2'));
    await tester.pumpAndSettle();

    expect(cart.calls, contains('remove:0192f0a0-0000-7000-8000-0000000000b2'));
    expect(byKey('add-0192f0a0-0000-7000-8000-0000000000a2'), findsOneWidget);
    expect(
      byKey('step-qty-0192f0a0-0000-7000-8000-0000000000a2'),
      findsNothing,
    );
  });

  testWidgets('while a change is pending both step buttons are disabled', (
    WidgetTester tester,
  ) async {
    cart = FakeCartRepository(
      cart: cartOf(<Map<String, Object?>>[
        lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
      ]),
    );
    await show(tester, tomato);
    final Completer<void> hold = Completer<void>();
    cart.hold = hold;
    await tester.tap(byKey('step-plus-0192f0a0-0000-7000-8000-0000000000a1'));
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(
            byKey('step-plus-0192f0a0-0000-7000-8000-0000000000a1'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            byKey('step-minus-0192f0a0-0000-7000-8000-0000000000a1'),
          )
          .onPressed,
      isNull,
    );
    expect(cart.patches, hasLength(1));

    hold.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            byKey('step-plus-0192f0a0-0000-7000-8000-0000000000a1'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a line that already exists is shown as the stepper', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato);
    cart.current = cartOf(<Map<String, Object?>>[
      lineOf(tomato, '2', '0192f0a0-0000-7000-8000-0000000000b1'),
    ]);
    cart.failure = const ApiRefusal(
      ApiError(
        status: 409,
        code: 'cart_item_already_exists',
        details: <String, Object?>{
          'cart_item_id': '0192f0a0-0000-7000-8000-0000000000b1',
        },
      ),
    );
    await tester.tap(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'));
    await tester.pumpAndSettle();

    expect(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'), findsNothing);
    expect(
      quantityShown(tester, '0192f0a0-0000-7000-8000-0000000000a1'),
      _qty('2', 'кг'),
    );
  });

  group('the heart', () {
    testWidgets('fills at once and stays when the server agrees', (
      WidgetTester tester,
    ) async {
      await show(tester, tomato);
      expect(find.byIcon(Icons.favorite), findsNothing);
      await tester.tap(byKey('heart-0192f0a0-0000-7000-8000-0000000000a1'));
      await tester.pump();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.pumpAndSettle();
      expect(favorites.changes, <String>[
        'add:0192f0a0-0000-7000-8000-0000000000a1',
      ]);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('goes back and says so when the server refuses', (
      WidgetTester tester,
    ) async {
      await show(tester, tomato);
      favorites.nextFailure = const UnexpectedFailure();
      await tester.tap(byKey('heart-0192f0a0-0000-7000-8000-0000000000a1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(
        find.text('Не удалось сохранить. Попробуйте ещё раз'),
        findsOneWidget,
      );
    });

    testWidgets('a second tap while the first is on its way is ignored', (
      WidgetTester tester,
    ) async {
      await show(tester, tomato);
      final Completer<void> hold = Completer<void>();
      favorites.hold = hold;
      await tester.tap(byKey('heart-0192f0a0-0000-7000-8000-0000000000a1'));
      await tester.pump();
      await tester.tap(byKey('heart-0192f0a0-0000-7000-8000-0000000000a1'));
      await tester.pump();
      expect(favorites.changes, <String>[
        'add:0192f0a0-0000-7000-8000-0000000000a1',
      ]);

      hold.complete();
      await tester.pumpAndSettle();
      expect(favorites.changes, <String>[
        'add:0192f0a0-0000-7000-8000-0000000000a1',
      ]);
      await tester.tap(byKey('heart-0192f0a0-0000-7000-8000-0000000000a1'));
      await tester.pumpAndSettle();
      expect(favorites.changes, <String>[
        'add:0192f0a0-0000-7000-8000-0000000000a1',
        'remove:0192f0a0-0000-7000-8000-0000000000a1',
      ]);
    });

    testWidgets('a favourite is filled from the start', (
      WidgetTester tester,
    ) async {
      await show(tester, catalogProduct(isFavorite: true));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  group('taps on the controls never open the product', () {
    final String id = '0192f0a0-0000-7000-8000-0000000000a1';

    testWidgets('step buttons while a change is pending', (
      WidgetTester tester,
    ) async {
      cart = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[
          lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
        ]),
      );
      await show(tester, tomato);
      final Completer<void> hold = Completer<void>();
      cart.hold = hold;
      await tester.tap(byKey('step-plus-$id'));
      await tester.pump();
      await tester.tap(byKey('step-plus-$id'));
      await tester.tap(byKey('step-minus-$id'));
      await tester.pumpAndSettle();
      expect(opened, isNull);
      expect(find.text('product page'), findsNothing);
      expect(cart.patches, hasLength(1));
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the add button while the add is pending', (
      WidgetTester tester,
    ) async {
      await show(tester, tomato);
      final Completer<void> hold = Completer<void>();
      cart.hold = hold;
      await tester.tap(byKey('add-$id'));
      await tester.pump();
      await tester.tap(byKey('add-$id'));
      await tester.pumpAndSettle();
      expect(opened, isNull);
      expect(cart.added, hasLength(1));
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the heart while its toggle is pending', (
      WidgetTester tester,
    ) async {
      await show(tester, tomato);
      final Completer<void> hold = Completer<void>();
      favorites.hold = hold;
      await tester.tap(byKey('heart-$id'));
      await tester.pump();
      await tester.tap(byKey('heart-$id'));
      await tester.pumpAndSettle();
      expect(opened, isNull);
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the quantity between the step buttons', (
      WidgetTester tester,
    ) async {
      cart = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[
          lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
        ]),
      );
      await show(tester, tomato);
      await tester.tap(byKey('step-qty-$id'));
      await tester.pumpAndSettle();
      expect(opened, isNull);
    });
  });

  testWidgets('a product that is not sold shows no add button', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato, available: false);
    expect(
      byKey('unavailable-0192f0a0-0000-7000-8000-0000000000a1'),
      findsOneWidget,
    );
    expect(find.text('Нет в продаже'), findsOneWidget);
    expect(byKey('add-0192f0a0-0000-7000-8000-0000000000a1'), findsNothing);
  });

  testWidgets('tapping the card opens the product', (
    WidgetTester tester,
  ) async {
    await show(tester, tomato);
    await tester.tap(find.text('Помидор'));
    await tester.pumpAndSettle();
    expect(
      opened,
      CatalogPaths.product('0192f0a0-0000-7000-8000-0000000000a1'),
    );
  });

  group('TalkBack', () {
    testWidgets('a card alone exposes the card, the heart and the add', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await show(tester, tomato);

      expect(find.semantics.byAction(SemanticsAction.tap), findsNWidgets(3));
      handle.dispose();
    });

    testWidgets('in the cart it exposes the card, the heart, minus and plus', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      cart = FakeCartRepository(
        cart: cartOf(<Map<String, Object?>>[
          lineOf(tomato, '1', '0192f0a0-0000-7000-8000-0000000000b1'),
        ]),
      );
      await show(tester, tomato);

      expect(find.semantics.byAction(SemanticsAction.tap), findsNWidgets(4));
      handle.dispose();
    });
  });

  group('the picture keeps clear of the heart', () {
    const String id = '0192f0a0-0000-7000-8000-0000000000a1';
    for (final (String name, KitCardSize size, double? well, double cardWidth)
        in <(String, KitCardSize, double?, double)>[
          ('compact 320', KitCardSize.compact, 84, 119),
          ('compact 375', KitCardSize.compact, 84, 119),
          ('home 320', KitCardSize.regular, 112, 150),
          ('home 375', KitCardSize.regular, 112, 150),
          ('grid 320', KitCardSize.regular, 150, 144),
          ('grid 375', KitCardSize.regular, 150, 171),
        ]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets('$name text x$scale', (WidgetTester tester) async {
          final double screen = name.endsWith('320') ? 320 : 375;
          tester.view.physicalSize = Size(screen, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await show(
            tester,
            tomato,
            size: size,
            imageHeight: well,
            width: cardWidth,
          );

          final Rect picture = tester.getRect(byKey('picture-$id'));
          final Rect glyph = tester.getRect(
            find.descendant(
              of: byKey('heart-$id'),
              matching: find.byType(Icon),
            ),
          );
          expect(picture.shortestSide, greaterThan(0));
          expect(
            picture.overlaps(glyph.inflate(2)),
            isFalse,
            reason: '$picture $glyph',
          );
          if (well != 150) {
            final double side = picture.width;
            expect(side, closeTo(0.7 * well!, 0.01), reason: 'full side');
          }
        });
      }
    }
  });

  group('on a small screen at twice the text size', () {
    final CatalogProduct longName = catalogProduct(
      id: '0192f0a0-0000-7000-8000-0000000000a3',
      nameUz: 'Juda uzun nomli mahsulot ' * 3,
      nameRu: 'Очень длинное название товара для проверки ' * 2,
      customerUnitPriceUzs: 1234567,
    );

    for (final KitCardSize size in KitCardSize.values) {
      for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
        for (final (bool inCart, bool available) in <(bool, bool)>[
          (false, true),
          (true, true),
          (false, false),
        ]) {
          testWidgets('$size ${locale.languageCode} inCart=$inCart '
              'available=$available', (WidgetTester tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            if (inCart) {
              cart = FakeCartRepository(
                cart: cartOf(<Map<String, Object?>>[
                  lineOf(
                    longName,
                    '1234.5',
                    '0192f0a0-0000-7000-8000-0000000000b3',
                  ),
                ]),
              );
            }
            await show(
              tester,
              longName,
              locale: locale,
              size: size,
              available: available,
              width: size == KitCardSize.compact ? 119 : 150,
            );
            expect(tester.takeException(), isNull);
            expect(
              byKey('product-card-0192f0a0-0000-7000-8000-0000000000a3'),
              findsOneWidget,
            );
          });
        }
      }
    }
  });
}
