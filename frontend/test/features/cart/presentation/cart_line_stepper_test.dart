import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_line_stepper.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
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

  Widget stepper({bool atMinimum = false, double? width}) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: CartLineStepper(
          id: 'x',
          quantityText: '1 кг',
          busy: false,
          canStep: true,
          atMinimum: atMinimum,
          width: width ?? CartLineStepper.defaultWidth,
          onMinus: () {},
          onPlus: () {},
          onQuantity: () {},
        ),
      ),
    ),
  );

  testWidgets('at the smallest step its minus is a red bin', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(stepper(atMinimum: true));

    final IconButton minus = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('line-minus-x')),
    );
    expect(minus.color, KitColors.danger);
    expect((minus.icon as Icon).icon, Icons.delete_outline);
  });

  testWidgets('it is 132 wide unless given a width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(stepper());
    expect(tester.getSize(find.byType(CartLineStepper)).width, 132);

    await tester.pumpWidget(stepper(width: 180));
    expect(tester.getSize(find.byType(CartLineStepper)).width, 180);
  });
}
