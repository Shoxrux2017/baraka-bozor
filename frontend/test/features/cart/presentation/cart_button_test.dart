import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/cart/application/cart_controllers.dart';
import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';

/// The cart button's badge bump (`DL-118`).
void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Map<String, Object?> tomato(String quantity) =>
      cartLineJson(quantity: quantity);

  Map<String, Object?> bread() => cartLineJson(
    id: breadLine,
    productId: breadProduct,
    unit: 'piece',
    quantity: '1',
  );

  Cart cartWith(List<Map<String, Object?>> lines) => cartOf(lines);

  Future<ProviderContainer> open(
    WidgetTester tester,
    Cart first, {
    bool onBrand = false,
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerAccountProvider.overrideWithValue('c'),
          cartRepositoryProvider.overrideWithValue(
            FakeCartRepository(cart: first),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(actions: <Widget>[CartButton(onBrand: onBrand)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  /// The cart the server answers with, shown as a change's answer is.
  Future<void> show(
    WidgetTester tester,
    ProviderContainer container,
    Cart cart,
  ) async {
    container.read(cartProvider('c').notifier).show(cart);
    await tester.pump();
  }

  double scale(WidgetTester tester) =>
      tester.widget<ScaleTransition>(byKey('cart-badge-bump')).scale.value;

  testWidgets('bumps when a product is added', (WidgetTester tester) async {
    final ProviderContainer container = await open(
      tester,
      cartWith(<Map<String, Object?>>[tomato('1.000')]),
    );
    expect(scale(tester), 1);

    await show(
      tester,
      container,
      cartWith(<Map<String, Object?>>[tomato('1.000'), bread()]),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(tester), closeTo(1.3, 0.01));
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(tester), 1);
    expect(tester.widget<Text>(byKey('cart-count')).data, '2');
  });

  testWidgets('bumps when a quantity grows', (WidgetTester tester) async {
    final ProviderContainer container = await open(
      tester,
      cartWith(<Map<String, Object?>>[tomato('1.500')]),
    );

    await show(
      tester,
      container,
      cartWith(<Map<String, Object?>>[tomato('2.000')]),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(tester), closeTo(1.3, 0.01));
    await tester.pump(const Duration(milliseconds: 180));
    expect(scale(tester), 1);
  });

  testWidgets(
    'does not bump on the first load, a removal or a smaller quantity',
    (WidgetTester tester) async {
      final ProviderContainer container = await open(
        tester,
        cartWith(<Map<String, Object?>>[tomato('2.000'), bread()]),
      );
      expect(scale(tester), 1, reason: 'the first load');

      await show(
        tester,
        container,
        cartWith(<Map<String, Object?>>[tomato('1.500'), bread()]),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(tester), 1, reason: 'a smaller quantity');

      await show(
        tester,
        container,
        cartWith(<Map<String, Object?>>[tomato('1.500')]),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(tester), 1, reason: 'a removal');
    },
  );

  testWidgets('does not bump with reduced motion', (WidgetTester tester) async {
    final ProviderContainer container = await open(
      tester,
      cartWith(<Map<String, Object?>>[tomato('1.000')]),
      reducedMotion: true,
    );

    await show(
      tester,
      container,
      cartWith(<Map<String, Object?>>[tomato('1.000'), bread()]),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(tester), 1);
  });

  testWidgets('on the brand green: white bag, white badge, green count', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      cartWith(<Map<String, Object?>>[tomato('1.000')]),
      onBrand: true,
    );

    final Icon bag = tester.widget<Icon>(
      find.descendant(
        of: byKey('open-cart'),
        matching: find.byIcon(Icons.shopping_bag_outlined),
      ),
    );
    expect(bag.color, Colors.white);
    expect(bag.size, 26);
    final Text count = tester.widget<Text>(byKey('cart-count'));
    expect(count.style?.color, KitColors.primaryDark);
    expect(count.style?.fontSize, 11);
    final DecoratedBox badge = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: byKey('cart-count'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final BoxDecoration decoration = badge.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.border, isNull, reason: 'no white ring');
    expect(tester.getSize(byKey('open-cart')), const Size(44, 44));
  });
}
