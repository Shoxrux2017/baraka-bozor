import 'package:baraka_bozor/features/cart/domain/cart.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cart_repository.dart';

void main() {
  Cart cartWith(List<Map<String, Object?>> lines) => cartOf(lines);

  Map<String, Object?> tomato(String quantity) =>
      cartLineJson(quantity: quantity);

  Map<String, Object?> bread({String quantity = '1'}) => cartLineJson(
    id: breadLine,
    productId: breadProduct,
    unit: 'piece',
    quantity: quantity,
  );

  group('Cart.grewFrom', () {
    test('grows with a new product or more of one', () {
      final Cart before = cartWith(<Map<String, Object?>>[tomato('1.500')]);

      expect(
        cartWith(<Map<String, Object?>>[tomato('1.500'), bread()])
            .grewFrom(before),
        isTrue,
        reason: 'a product the cart did not hold',
      );
      expect(
        cartWith(<Map<String, Object?>>[tomato('2.000')]).grewFrom(before),
        isTrue,
        reason: '1.5 to 2',
      );
      expect(
        cartWith(<Map<String, Object?>>[tomato('1.501')]).grewFrom(before),
        isTrue,
      );
    });

    test('does not grow with less, a removal or another cart', () {
      final Cart before = cartWith(<Map<String, Object?>>[
        tomato('2.000'),
        bread(),
      ]);

      expect(
        cartWith(<Map<String, Object?>>[tomato('1.500'), bread()])
            .grewFrom(before),
        isFalse,
        reason: '2 to 1.5',
      );
      expect(
        cartWith(<Map<String, Object?>>[tomato('2.000')]).grewFrom(before),
        isFalse,
        reason: 'a removal',
      );
      expect(before.grewFrom(before), isFalse, reason: 'the same cart');
      expect(
        cartWith(<Map<String, Object?>>[tomato('2.000'), bread()])
            .grewFrom(before),
        isFalse,
        reason: '2 is 2.000',
      );

      final Cart other = CartForTest.withId(before, 'another');
      expect(
        cartWith(<Map<String, Object?>>[tomato('9.000'), bread()])
            .grewFrom(other),
        isFalse,
        reason: 'a cart with another id',
      );
    });
  });
}

/// [cart] under another id.
extension CartForTest on Cart {
  static Cart withId(Cart cart, String id) => Cart(
    id: id,
    lines: cart.lines,
    estimatedSubtotalUzs: cart.estimatedSubtotalUzs,
    serviceFeeUzs: cart.serviceFeeUzs,
    serviceFeeIsEstimate: cart.serviceFeeIsEstimate,
    deliveryFeeUzs: cart.deliveryFeeUzs,
    estimatedTotalUzs: cart.estimatedTotalUzs,
    minimumOrderUzs: cart.minimumOrderUzs,
    minimumShortfallUzs: cart.minimumShortfallUzs,
  );
}
