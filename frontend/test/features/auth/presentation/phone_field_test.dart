import 'package:baraka_bozor/features/auth/presentation/phone_field.dart';
import 'package:flutter/services.dart';
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
}
