import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_line_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('its buttons are 44 square', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: CartLineStepper(
              id: 'x',
              quantityText: '1 кг',
              busy: false,
              canStep: true,
              onMinus: () {},
              onPlus: () {},
              onQuantity: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey<String>('line-minus-x'))),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('line-plus-x'))),
      const Size(44, 44),
    );
  });
}
