import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/checkout/data/checkout_api.dart';
import 'package:baraka_bozor/features/checkout/domain/checkout.dart';

import 'fake_cart_repository.dart';

const String placedOrderId = '0192f0a0-0000-7000-8000-00000000fe01';

/// A preview as `docs/09` section 18 answers it.
Map<String, Object?> previewJson({
  String paymentMethod = 'cash',
  String? note,
  String totalKind = 'estimate',
  bool outside = false,
  String? opensAt = '08:00',
  String token = 'token-1',
}) => <String, Object?>{
  'lines': <Object?>[
    <String, Object?>{
      'cart_item_id': tomatoLine,
      'product_id': tomatoProduct,
      'name_uz': 'Pomidor',
      'name_ru': 'Помидоры',
      'unit_code': 'kg',
      'quantity': '1.500',
      'price_mode': 'estimate',
      'customer_unit_price_uzs': 18400,
      'line_total_uzs': 27600,
    },
  ],
  'merchandise_subtotal_uzs': 27600,
  'service_fee_uzs': 5000,
  'delivery_fee_uzs': 15000,
  'total_uzs': 47600,
  'total_kind': totalKind,
  'payment_method': paymentMethod,
  'delivery_time_note': note,
  'outside_working_hours': outside,
  'opens_at': opensAt,
  'checkout_token': token,
  'checkout_token_expires_at': '2026-09-28T07:05:00Z',
};

/// The order a confirmation answers with, as far as the checkout reads it.
Map<String, Object?> placedJson({int number = 1001}) => <String, Object?>{
  'id': placedOrderId,
  'order_number': number,
  'status': 'new',
  'totals': <String, Object?>{
    'merchandise_subtotal_uzs': 27600,
    'service_fee_uzs': 5000,
    'delivery_fee_uzs': 15000,
    'total_uzs': 47600,
    'total_kind': 'estimate',
  },
};

/// The checkout in memory. Every preview answers a new token; a failure
/// set for the next preview or placement answers once.
class FakeCheckoutRepository implements CheckoutRepository {
  final List<CheckoutRequest> previews = <CheckoutRequest>[];

  /// Every placement: the token and the key it was sent under.
  final List<(String, String)> placements = <(String, String)>[];

  ApiFailure? previewFailure;
  ApiFailure? placeFailure;

  /// When set, a placement answers with this order instead.
  Map<String, Object?>? placedAnswer;
  bool outsideHours = false;
  Completer<void>? hold;

  /// When set, a preview — and only a preview — waits for it.
  Completer<void>? previewHold;

  @override
  Future<CheckoutPreview> preview(CheckoutRequest request) async {
    previews.add(request);
    await hold?.future;
    await previewHold?.future;
    final ApiFailure? failure = previewFailure;
    if (failure != null) {
      previewFailure = null;
      throw failure;
    }
    return CheckoutApi.parsePreview(
      previewJson(
        note: request.deliveryTimeNote,
        outside: outsideHours,
        token: 'token-${previews.length}',
      ),
    );
  }

  @override
  Future<PlacedOrder> place(String token, String idempotencyKey) async {
    placements.add((token, idempotencyKey));
    await hold?.future;
    final ApiFailure? failure = placeFailure;
    if (failure != null) {
      placeFailure = null;
      throw failure;
    }
    return CheckoutApi.parsePlaced(placedAnswer ?? placedJson());
  }
}
