import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/features/cart/application/card_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kilograms, litres and metres step by half, the rest by one', () {
    expect(CardQuantity.step(UnitCode.kg), '0.5');
    expect(CardQuantity.step(UnitCode.liter), '0.5');
    expect(CardQuantity.step(UnitCode.meter), '0.5');
    expect(CardQuantity.step(UnitCode.piece), '1');
    expect(CardQuantity.step(UnitCode.gram), '1');
    expect(CardQuantity.step(UnitCode.box), '1');
  });

  test('next adds the step', () {
    expect(CardQuantity.next(UnitCode.kg, '1'), '1.5');
    expect(CardQuantity.next(UnitCode.kg, '1.25'), '1.75');
    expect(CardQuantity.next(UnitCode.kg, '1.500'), '2');
    expect(CardQuantity.next(UnitCode.piece, '1'), '2');
  });

  test('next stops at the largest quantity', () {
    expect(CardQuantity.next(UnitCode.piece, '9999'), '9999');
    expect(CardQuantity.next(UnitCode.kg, '9999'), '9999');
    expect(CardQuantity.next(UnitCode.kg, '9998.75'), '9999');
  });

  test('next never takes a quantity past the largest down', () {
    expect(CardQuantity.next(UnitCode.kg, '9999.5'), '9999.5');
    expect(CardQuantity.next(UnitCode.kg, '9999.500'), '9999.500');
    expect(CardQuantity.next(UnitCode.piece, '10000'), '10000');
  });

  test('previous subtracts the step, and removes the line at or below it', () {
    expect(CardQuantity.previous(UnitCode.kg, '1'), '0.5');
    expect(CardQuantity.previous(UnitCode.kg, '1.25'), '0.75');
    expect(CardQuantity.previous(UnitCode.kg, '0.5'), isNull);
    expect(CardQuantity.previous(UnitCode.kg, '0.25'), isNull);
    expect(CardQuantity.previous(UnitCode.piece, '1'), isNull);
    expect(CardQuantity.previous(UnitCode.piece, '3'), '2');
  });
}
