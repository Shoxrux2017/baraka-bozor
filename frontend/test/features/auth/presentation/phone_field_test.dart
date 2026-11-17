import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/auth/presentation/phone_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final NationalPhoneDigitsFormatter formatter = NationalPhoneDigitsFormatter();

  String format(String typed) => formatter
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: typed))
      .text;

  test('groups the typed digits as 90 123 45 67 while they are typed', () {
    expect(format('9'), '9');
    expect(format('90'), '90');
    expect(format('900'), '90 0');
    expect(format('900000031'), '90 000 00 31');
    expect(format('901234567'), '90 123 45 67');
  });

  test('drops everything that is not a digit', () {
    expect(format('90 123 45 67'), '90 123 45 67');
    expect(format('(90) 123-45-67'), '90 123 45 67');
  });

  test('a pasted full number loses its country code rather than its tail', () {
    expect(format('+998 90 123 45 67'), '90 123 45 67');
    expect(format('998901234567'), '90 123 45 67');
    expect(format('+998901234567'), '90 123 45 67');
  });

  test('anything longer than nine digits is cut', () {
    expect(format('9012345678'), '90 123 45 67');
    expect(format('+7 999 123 45 67 89'), '79 991 23 45');
  });

  test('leaves the value untouched when nothing had to change', () {
    const TextEditingValue value = TextEditingValue(
      text: '90 12',
      selection: TextSelection.collapsed(offset: 2),
    );

    expect(
      identical(
        formatter.formatEditUpdate(TextEditingValue.empty, value),
        value,
      ),
      isTrue,
      reason: 'the cursor stays where the person put it',
    );
  });

  test('typing in the middle keeps the cursor after the typed digit', () {
    final TextEditingValue result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '90 123',
        selection: TextSelection.collapsed(offset: 2),
      ),
      const TextEditingValue(
        text: '905 123',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );

    expect(result.text, '90 512 3');
    expect(result.selection.baseOffset, 4, reason: 'after the 5, past the gap');
  });

  test('a backspace over the gap removes the digit before it', () {
    final TextEditingValue result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '90 123',
        selection: TextSelection.collapsed(offset: 3),
      ),
      const TextEditingValue(
        text: '90123',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );

    expect(result.text, '91 23');
    expect(result.selection.baseOffset, 1);
  });

  group('the field itself', () {
    Future<TextEditingController> pump(
      WidgetTester tester, {
      String? label,
      bool clearable = false,
      bool strong = false,
      bool validate = true,
    }) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Form(
              child: PhoneField(
                controller: controller,
                label: label,
                clearable: clearable,
                strong: strong,
                validate: validate,
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('offers both telephone autofill hints', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).autofillHints,
        <String>[
          AutofillHints.telephoneNumber,
          AutofillHints.telephoneNumberNational,
        ],
      );
    });

    testWidgets('without a label it stays the plain staff field', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = await pump(tester);
      controller.text = '90';
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('phone-clear')), findsNothing);
      expect(find.text('Номер телефона'), findsNothing);
    });

    testWidgets('a clearable field shows the × only while it has text', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = await pump(
        tester,
        label: 'Номер телефона',
        clearable: true,
        strong: true,
        validate: false,
      );
      final Finder clear = find.byKey(const ValueKey<String>('phone-clear'));
      expect(clear, findsNothing);

      controller.text = '90';
      await tester.pump();
      expect(clear, findsOneWidget);

      await tester.tap(clear);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(clear, findsNothing);
    });

    testWidgets('validate off lets a short number pass the form', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = await pump(
        tester,
        validate: false,
      );
      controller.text = '90';
      await tester.pump();

      expect(
        Form.of(tester.element(find.byType(PhoneField))).validate(),
        isTrue,
      );
    });

    testWidgets('validate on refuses a short number', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = await pump(tester);
      controller.text = '90';
      await tester.pump();

      expect(
        Form.of(tester.element(find.byType(PhoneField))).validate(),
        isFalse,
      );
    });
  });
}
