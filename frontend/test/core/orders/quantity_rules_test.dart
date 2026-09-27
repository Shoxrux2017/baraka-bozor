import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/orders/quantity_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The quantity rules of `DL-37` (6) as the client checks them.
void main() {
  test(
    'a unit that takes a fraction takes up to four digits and three decimals',
    () {
      for (final UnitCode unit in <UnitCode>[
        UnitCode.kg,
        UnitCode.liter,
        UnitCode.meter,
      ]) {
        expect(unit.takesFraction, isTrue, reason: '$unit');
        expect(QuantityRules.normalize(unit, '1.5'), '1.5');
        expect(QuantityRules.normalize(unit, ' 1,250 '), '1.250');
        expect(QuantityRules.normalize(unit, '9999.999'), '9999.999');
        expect(QuantityRules.normalize(unit, '2'), '2');
        for (final String refused in <String>[
          '0',
          '0.000',
          '1.2345',
          '10000',
          '-1',
          '1e3',
          '',
          '.5',
          '1.',
        ]) {
          expect(
            QuantityRules.normalize(unit, refused),
            isNull,
            reason: refused,
          );
        }
      }
    },
  );

  test('every other unit takes a whole number from 1 to 9999', () {
    for (final UnitCode unit in <UnitCode>[
      UnitCode.gram,
      UnitCode.piece,
      UnitCode.package,
      UnitCode.box,
      UnitCode.bundle,
    ]) {
      expect(unit.takesFraction, isFalse, reason: '$unit');
      expect(QuantityRules.normalize(unit, '3'), '3');
      expect(QuantityRules.normalize(unit, '9999'), '9999');
      for (final String refused in <String>['0', '1.5', '1,0', '10000', '']) {
        expect(QuantityRules.normalize(unit, refused), isNull, reason: refused);
      }
    }
  });

  test('amounts compare in thousandths, not as text', () {
    expect(QuantityRules.thousandths('1.5'), 1500);
    expect(QuantityRules.thousandths('1.500'), 1500);
    expect(QuantityRules.thousandths('2'), 2000);
    expect(QuantityRules.thousandths('0.001'), 1);
  });
}
