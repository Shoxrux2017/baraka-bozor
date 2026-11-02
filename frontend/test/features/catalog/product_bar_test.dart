import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/catalog/presentation/product_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

/// The product bar on its own: what a screen reader hears (`DL-122`).
void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pumpBar(
    WidgetTester tester, {
    String quantity = '1',
    int sumUzs = 12075,
    ProductBarAction action = ProductBarAction.add,
    ValueChanged<String>? onQuantity,
    VoidCallback? onRemove,
    Locale locale = const Locale('ru'),
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          bottomNavigationBar: ProductBar(
            product: catalogProduct(
              nameRu: 'Помидор',
              customerUnitPriceUzs: 12075,
            ),
            quantity: quantity,
            sumUzs: sumUzs,
            onQuantity: onQuantity ?? (String _) {},
            action: action,
            onAction: () {},
            onRemove: onRemove,
            onQuantityTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('what the bar says', () {
    testWidgets('the quantity is one adjustable node that names the product', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> steps = <String>[];
      await pumpBar(tester, onQuantity: steps.add);

      final SemanticsNode stepper = tester.getSemantics(
        find.bySemanticsLabel('Количество, Помидор'),
      );
      final SemanticsData data = stepper.getSemanticsData();
      expect(data.label, 'Количество, Помидор');
      expect(data.value, '1 кг');
      expect(data.increasedValue, '1,5 кг');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(stepper.hintOverrides?.onTapHint, 'ввести точное количество');
      // The buttons inside are not separate nodes.
      expect(find.bySemanticsLabel('Уменьшить'), findsNothing);
      expect(find.bySemanticsLabel('Увеличить'), findsNothing);

      tester.semantics.increase(find.semantics.byLabel('Количество, Помидор'));
      expect(steps, <String>['1.5']);
      handle.dispose();
    });

    testWidgets('the decrease at the smallest step in the cart removes', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int removed = 0;
      await pumpBar(
        tester,
        quantity: '0.5',
        action: ProductBarAction.openCart,
        onRemove: () => removed++,
      );

      tester.semantics.decrease(find.semantics.byLabel('Количество, Помидор'));
      expect(removed, 1);
      handle.dispose();
    });

    testWidgets('the button names what it adds', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpBar(tester);

      final String sum = MoneyFormat.uzs(12075, AppLanguage.ru);
      expect(
        find.bySemanticsLabel(
          'Добавить в корзину: Помидор, 1 кг, примерно $sum',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(byKey('add-to-cart'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('adding says Добавляем…, not Сохраняем', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpBar(tester, action: ProductBarAction.adding);

      expect(find.bySemanticsLabel('Добавляем…'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Сохраняем')), findsNothing);
      handle.dispose();
    });

    testWidgets('in the cart it says what the cart holds', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpBar(tester, quantity: '2', action: ProductBarAction.openCart);

      expect(
        find.bySemanticsLabel('Открыть корзину. В корзине 2 кг'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
