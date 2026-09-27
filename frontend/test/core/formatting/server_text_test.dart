import 'package:baraka_bozor/core/formatting/server_text.dart';
import 'package:baraka_bozor/core/orders/quantity_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text is trimmed of what Laravel trims, and only at its ends', () {
    expect(trimLikeServer('  Qizilini  '), 'Qizilini');
    expect(
      trimLikeServer('\u200B\u200E\uFEFF Qizilini \u00A0\u3164'),
      'Qizilini',
    );
    expect(trimLikeServer('Qizil\u200Bini'), 'Qizil\u200Bini');
    expect(trimLikeServer('\u{1D159}x\u{E0020}'), 'x');
    expect(trimLikeServer(' \t\n'), isEmpty);
  });

  test('a quantity reads with the decimal comma and no trailing zeros', () {
    expect(QuantityRules.display('1.500'), '1,5');
    expect(QuantityRules.display('2.000'), '2');
    expect(QuantityRules.display('0.125'), '0,125');
    expect(QuantityRules.display('10.050'), '10,05');
    expect(QuantityRules.display('3'), '3');
    expect(QuantityRules.display('30'), '30');
  });
}
