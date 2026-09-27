import 'package:dio/dio.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/storage/token_store.dart';
import '../domain/checkout.dart';

/// The data source for `docs/09-api-contracts.md` sections 18 and 19, on
/// the Customer session, with its strict parsing. A preview is held to the
/// request it answers (`DL-27` (6)).
class CheckoutApi {
  CheckoutApi(this._dio);

  final Dio _dio;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  Future<CheckoutPreview> preview(CheckoutRequest request) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/checkout/preview',
      data: <String, Object?>{
        'address_id': request.addressId,
        'payment_method': request.paymentMethod.code,
        'delivery_time_note': request.deliveryTimeNote,
      },
      options: _customer,
    );
    final CheckoutPreview preview = parsePreview(
      ApiEnvelope.unwrap(response.data),
    );
    if (preview.paymentMethod != request.paymentMethod ||
        preview.deliveryTimeNote != request.deliveryTimeNote) {
      throw const FormatException('the preview is of another checkout');
    }
    return preview;
  }

  Future<PlacedOrder> place(String token, String idempotencyKey) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/orders',
      data: <String, String>{'checkout_token': token},
      options: _customer.copyWith(
        headers: <String, Object?>{'Idempotency-Key': idempotencyKey},
      ),
    );
    return parsePlaced(ApiEnvelope.unwrap(response.data));
  }

  static final RegExp _quantity = RegExp(r'^\d{1,4}(\.\d{3})?$');
  static final RegExp _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static int _amount(JsonFields json, String key) {
    final int value = json.integer(key);
    if (value < 0) {
      throw FormatException('$key is negative');
    }
    return value;
  }

  /// The preview, held to its contract: lines with their prices, the
  /// amounts, a kind that is `estimate` or `final`, the hours and the token.
  static CheckoutPreview parsePreview(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'checkout preview');
    final Object? rawLines = json.member('lines');
    if (rawLines is! List<dynamic> || rawLines.isEmpty) {
      throw const FormatException('a preview has lines');
    }
    final TotalKind kind = json.choice('total_kind', TotalKind.tryParse);
    if (kind == TotalKind.none) {
      throw const FormatException('a preview total is estimate or final');
    }
    final String? opensAt = json.nullableString('opens_at');
    if (opensAt != null && !_time.hasMatch(opensAt)) {
      throw FormatException('opens_at is not HH:MM: $opensAt');
    }
    final bool outside = json.boolean('outside_working_hours');
    if (outside && opensAt == null) {
      throw const FormatException('closed hours without an opening time');
    }
    return CheckoutPreview(
      lines: rawLines.map(_line).toList(growable: false),
      merchandiseSubtotalUzs: _amount(json, 'merchandise_subtotal_uzs'),
      serviceFeeUzs: _amount(json, 'service_fee_uzs'),
      deliveryFeeUzs: _amount(json, 'delivery_fee_uzs'),
      totalUzs: _amount(json, 'total_uzs'),
      totalKind: kind,
      paymentMethod: json.choice('payment_method', PaymentMethod.tryParse),
      deliveryTimeNote: json.nullableString('delivery_time_note'),
      outsideWorkingHours: outside,
      opensAt: opensAt,
      token: json.string('checkout_token'),
      tokenExpiresAt: json.instant('checkout_token_expires_at'),
    );
  }

  static PreviewLine _line(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'preview line');
    final String quantity = json.string('quantity');
    if (!_quantity.hasMatch(quantity) ||
        QuantityRules.thousandths(quantity) == 0) {
      throw FormatException('quantity is not in its form: $quantity');
    }
    final int price = json.integer('customer_unit_price_uzs');
    if (price < 1) {
      throw const FormatException('a price is above zero');
    }
    return PreviewLine(
      cartItemId: json.uuid('cart_item_id'),
      productId: json.uuid('product_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      unit: json.choice('unit_code', UnitCode.tryParse),
      quantity: quantity,
      priceMode: json.choice('price_mode', PriceMode.tryParse),
      customerUnitPriceUzs: price,
      lineTotalUzs: _amount(json, 'line_total_uzs'),
    );
  }

  /// The order a confirmation placed: its id, number and total.
  static PlacedOrder parsePlaced(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'order');
    final JsonFields totals = JsonFields.of(json.member('totals'), 'totals');
    final int number = json.integer('order_number');
    if (number < 1) {
      throw const FormatException('order_number is not an order number');
    }
    final TotalKind kind = totals.choice('total_kind', TotalKind.tryParse);
    if (kind == TotalKind.none) {
      throw const FormatException('a placed order owes its total');
    }
    return PlacedOrder(
      id: json.uuid('id'),
      orderNumber: number,
      totalUzs: _amount(totals, 'total_uzs'),
      totalKind: kind,
    );
  }
}

class CheckoutRepositoryImpl implements CheckoutRepository {
  CheckoutRepositoryImpl(this._api);

  final CheckoutApi _api;

  @override
  Future<CheckoutPreview> preview(CheckoutRequest request) =>
      guardApiCall(() => _api.preview(request));

  @override
  Future<PlacedOrder> place(String token, String idempotencyKey) =>
      guardApiCall(() => _api.place(token, idempotencyKey));
}
