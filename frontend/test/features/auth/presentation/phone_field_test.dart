import 'package:baraka_bozor/features/auth/presentation/phone_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final NationalPhoneDigitsFormatter formatter = NationalPhoneDigitsFormatter();

  String format(String typed) => formatter
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: typed))
      .text;

  test('keeps typed digits as they are', () {
    expect(format('9'), '9');
    expect(format('901234567'), '901234567');
  });

  test('drops everything that is not a digit', () {
    expect(format('90 123 45 67'), '901234567');
    expect(format('(90) 123-45-67'), '901234567');
  });

  test('a pasted full number loses its country code rather than its tail', () {
    expect(format('+998 90 123 45 67'), '901234567');
    expect(format('998901234567'), '901234567');
    expect(format('+998901234567'), '901234567');
  });

  test('anything longer than nine digits is cut', () {
    expect(format('9012345678'), '901234567');
    expect(format('+7 999 123 45 67 89'), '799912345');
  });

  test('leaves the value untouched when nothing had to change', () {
    const TextEditingValue value = TextEditingValue(
      text: '9012',
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
}
