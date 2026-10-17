import 'package:dio/dio.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/storage/token_store.dart';
import '../domain/cart.dart';

/// The data source for `docs/09-api-contracts.md` section 17, on the
/// Customer session, with its strict parsing. Every answer is the whole
/// cart, held to the change it answers (`DL-27` (6)).
class CartApi {
  CartApi(this._dio);

  final Dio _dio;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  Future<Cart> cart() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/customer/cart',
      options: _customer,
    );
    return parseCart(ApiEnvelope.unwrap(response.data));
  }

  Future<Cart> add(NewCartLine line) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/cart/items',
      data: <String, Object?>{
        'product_id': line.productId,
        'quantity': line.quantity,
        'customer_note': line.customerNote,
        'substitution_policy': line.substitutionPolicy.code,
      },
      options: _customer,
    );
    return _expect(
      parseCart(ApiEnvelope.unwrap(response.data)),
      (Cart cart) => cart.lines.any(
        (CartLine added) =>
            added.productId == line.productId &&
            QuantityRules.thousandths(added.quantity) ==
                QuantityRules.thousandths(line.quantity),
      ),
    );
  }

  Future<Cart> change(String lineId, CartLinePatch patch) async {
    final Response<dynamic> response = await _dio.patch<dynamic>(
      '/customer/cart/items/${Uri.encodeComponent(lineId)}',
      data: <String, Object?>{
        if (patch.quantity != null) 'quantity': patch.quantity,
        if (patch.noteChanged) 'customer_note': patch.customerNote,
        if (patch.substitutionPolicy != null)
          'substitution_policy': patch.substitutionPolicy!.code,
      },
      options: _customer,
    );
    return _expect(parseCart(ApiEnvelope.unwrap(response.data)), (Cart cart) {
      final CartLine? line = cart.line(lineId);
      return line != null &&
          (patch.quantity == null ||
              QuantityRules.thousandths(line.quantity) ==
                  QuantityRules.thousandths(patch.quantity!)) &&
          (!patch.noteChanged || line.customerNote == patch.customerNote) &&
          (patch.substitutionPolicy == null ||
              line.substitutionPolicy == patch.substitutionPolicy);
    });
  }

  Future<Cart> remove(String lineId) async {
    final Response<dynamic> response = await _dio.delete<dynamic>(
      '/customer/cart/items/${Uri.encodeComponent(lineId)}',
      options: _customer,
    );
    return _expect(
      parseCart(ApiEnvelope.unwrap(response.data)),
      (Cart cart) => cart.line(lineId) == null,
    );
  }

  static Cart _expect(Cart cart, bool Function(Cart cart) holds) {
    if (!holds(cart)) {
      throw const FormatException('the cart does not show the change');
    }
    return cart;
  }

  /// A quantity as the API answers it: a whole number, or three decimals
  /// (`docs/09` section 17).
  static final RegExp _quantity = RegExp(r'^\d{1,4}(\.\d{3})?$');

  /// The whole cart, held to its contract.
  static Cart parseCart(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'cart');
    final Object? items = json.member('items');
    if (items is! List<dynamic>) {
      throw const FormatException('items is not a list');
    }
    final List<CartLine> lines = items.map(parseLine).toList(growable: false);
    if (json.integer('item_count') != lines.length) {
      throw const FormatException('item_count is not the number of lines');
    }
    final int subtotal = json.integer('estimated_subtotal_uzs');
    if (subtotal < 0) {
      throw const FormatException('the subtotal is negative');
    }
    final int? serviceFee = json.nullableInteger('service_fee_uzs');
    final String? kind = json.nullableString('service_fee_kind');
    final int? deliveryFee = json.nullableInteger('delivery_fee_uzs');
    final int? total = json.nullableInteger('estimated_total_uzs');
    final int? minimum = json.nullableInteger('minimum_order_uzs');
    final int? shortfall = json.nullableInteger('minimum_order_shortfall_uzs');
    if ((serviceFee == null) != (kind == null)) {
      throw const FormatException('the service fee and its kind go together');
    }
    if (kind != null && kind != 'final' && kind != 'estimate') {
      throw FormatException('service_fee_kind is not known: $kind');
    }
    if ((total != null) != (serviceFee != null && deliveryFee != null)) {
      throw const FormatException('the total needs both fees, and only them');
    }
    if ((shortfall == null) != (minimum == null)) {
      throw const FormatException('the minimum and its shortfall go together');
    }
    if (<int?>[
      serviceFee,
      deliveryFee,
      total,
      minimum,
      shortfall,
    ].any((int? amount) => amount != null && amount < 0)) {
      throw const FormatException('a charge is negative');
    }
    if (shortfall != null && minimum != null && shortfall > minimum) {
      throw const FormatException('the shortfall is more than the minimum');
    }
    return Cart(
      id: json.uuid('id'),
      lines: lines,
      estimatedSubtotalUzs: subtotal,
      serviceFeeUzs: serviceFee,
      serviceFeeIsEstimate: kind == 'estimate',
      deliveryFeeUzs: deliveryFee,
      estimatedTotalUzs: total,
      minimumOrderUzs: minimum,
      minimumShortfallUzs: shortfall,
    );
  }

  /// One line: its prices are `null` exactly when it is not available.
  static CartLine parseLine(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'cart line');
    final String quantity = json.string('quantity');
    if (!_quantity.hasMatch(quantity) ||
        QuantityRules.thousandths(quantity) == 0) {
      throw FormatException('quantity is not in its form: $quantity');
    }
    final CartLine line = CartLine(
      id: json.uuid('id'),
      productId: json.uuid('product_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      unit: json.choice('unit_code', UnitCode.tryParse),
      priceMode: json.choice('price_mode', PriceMode.tryParse),
      imageUrl: json.nullableString('image_url'),
      quantity: quantity,
      customerNote: json.nullableString('customer_note'),
      substitutionPolicy: json.choice(
        'substitution_policy',
        SubstitutionPolicy.tryParse,
      ),
      isAvailable: json.boolean('is_available'),
      customerUnitPriceUzs: json.nullableInteger('customer_unit_price_uzs'),
      estimatedLineTotalUzs: json.nullableInteger('estimated_line_total_uzs'),
    );
    final bool priced =
        line.customerUnitPriceUzs != null && line.estimatedLineTotalUzs != null;
    final bool unpriced =
        line.customerUnitPriceUzs == null && line.estimatedLineTotalUzs == null;
    if (line.isAvailable ? !priced : !unpriced) {
      throw const FormatException('a line is priced exactly when available');
    }
    if ((line.customerUnitPriceUzs ?? 1) < 1 ||
        (line.estimatedLineTotalUzs ?? 0) < 0) {
      throw const FormatException('a price is out of range');
    }
    return line;
  }
}

class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(this._api);

  final CartApi _api;

  @override
  Future<Cart> cart() => guardApiCall(_api.cart);

  @override
  Future<Cart> add(NewCartLine line) => guardApiCall(() => _api.add(line));

  @override
  Future<Cart> change(String lineId, CartLinePatch patch) =>
      guardApiCall(() => _api.change(lineId, patch));

  @override
  Future<Cart> remove(String lineId) => guardApiCall(() => _api.remove(lineId));
}
