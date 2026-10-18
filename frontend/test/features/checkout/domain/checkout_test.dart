import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/features/checkout/data/checkout_api.dart';
import 'package:baraka_bozor/features/checkout/domain/checkout.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_checkout_repository.dart';

CheckoutPreview preview({
  String token = 'token-1',
  int lineTotal = 27600,
  int total = 47600,
  int deliveryFee = 15000,
  String totalKind = 'estimate',
  bool outside = false,
  String? opensAt = '08:00',
  List<Map<String, Object?>>? lines,
}) => CheckoutApi.parsePreview(
  previewJson(
    token: token,
    lineTotal: lineTotal,
    total: total,
    deliveryFee: deliveryFee,
    totalKind: totalKind,
    outside: outside,
    opensAt: opensAt,
    lines: lines,
  ),
);

Map<String, Object?> line({
  String id = '0192f0a0-0000-7000-8000-0000000000a1',
  String quantity = '1.500',
}) => <String, Object?>{
  'cart_item_id': id,
  'product_id': '0192f0a0-0000-7000-8000-0000000000b1',
  'name_uz': 'Pomidor',
  'name_ru': 'Помидоры',
  'unit_code': 'kg',
  'quantity': quantity,
  'price_mode': 'estimate',
  'customer_unit_price_uzs': 18400,
  'line_total_uzs': 27600,
};

void main() {
  test('requests with the same address, method and wish are equal', () {
    const CheckoutRequest a = CheckoutRequest(
      addressId: 'a1',
      paymentMethod: PaymentMethod.cash,
      deliveryTimeNote: null,
    );
    const CheckoutRequest same = CheckoutRequest(
      addressId: 'a1',
      paymentMethod: PaymentMethod.cash,
      deliveryTimeNote: null,
    );
    const CheckoutRequest otherWish = CheckoutRequest(
      addressId: 'a1',
      paymentMethod: PaymentMethod.cash,
      deliveryTimeNote: 'после 18:00',
    );
    const CheckoutRequest otherAddress = CheckoutRequest(
      addressId: 'a2',
      paymentMethod: PaymentMethod.cash,
      deliveryTimeNote: null,
    );

    expect(a, same);
    expect(a.hashCode, same.hashCode);
    expect(a == otherWish, isFalse);
    expect(a == otherAddress, isFalse);
  });

  test('a new token and expiry is the same offer', () {
    expect(
      preview(token: 'token-1').sameOfferAs(preview(token: 'token-2')),
      isTrue,
    );
  });

  test('a different line total, fee, total, kind, hours or opening time '
      'is another offer', () {
    final CheckoutPreview base = preview();

    expect(base.sameOfferAs(preview(lineTotal: 27700)), isFalse);
    expect(base.sameOfferAs(preview(deliveryFee: 16000)), isFalse);
    expect(base.sameOfferAs(preview(total: 47700)), isFalse);
    expect(base.sameOfferAs(preview(totalKind: 'final')), isFalse);
    expect(base.sameOfferAs(preview(outside: true)), isFalse);
    expect(base.sameOfferAs(preview(opensAt: '09:00')), isFalse);
  });

  test('a different line set is another offer', () {
    final CheckoutPreview one = preview(lines: <Map<String, Object?>>[line()]);
    final CheckoutPreview two = preview(
      lines: <Map<String, Object?>>[
        line(),
        line(id: '0192f0a0-0000-7000-8000-0000000000a2'),
      ],
    );
    final CheckoutPreview moreQuantity = preview(
      lines: <Map<String, Object?>>[line(quantity: '2.000')],
    );

    expect(one.sameOfferAs(two), isFalse);
    expect(one.sameOfferAs(moreQuantity), isFalse);
    expect(
      one.sameOfferAs(preview(lines: <Map<String, Object?>>[line()])),
      isTrue,
    );
  });
}
