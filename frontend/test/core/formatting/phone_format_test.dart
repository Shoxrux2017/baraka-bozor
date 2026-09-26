import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders a phone as docs/07 section 27 shows it', () {
    expect(formatPhone('+998901234567'), '+998 90 123 45 67');
  });

  test('leaves anything that is not such a phone alone', () {
    expect(formatPhone('+7 999'), '+7 999');
    expect(formatPhone('+99890123456'), '+99890123456');
    expect(formatPhone('+9989012345ab'), '+9989012345ab');
    expect(formatPhone(''), '');
  });

  test('builds the E.164 phone from nine national digits only', () {
    expect(phoneFromNationalDigits('901234567'), '+998901234567');
    expect(phoneFromNationalDigits('90123456'), isNull);
    expect(phoneFromNationalDigits('9012345678'), isNull);
    expect(phoneFromNationalDigits('90 123 45'), isNull);
    expect(phoneFromNationalDigits(''), isNull);
  });
}
