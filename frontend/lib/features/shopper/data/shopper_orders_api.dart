import 'package:dio/dio.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/storage/token_store.dart';
import '../domain/shopper_orders.dart';

/// The data source for `docs/09-api-contracts.md` sections 28 and 29, on
/// the staff session, with its strict parsing. An answer is held to the
/// request it answers (`DL-27` (6)).
class ShopperOrdersApi {
  ShopperOrdersApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);

  Future<Paged<ShopperOrderRow>> orders(int page) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/shopper/orders',
      queryParameters: <String, Object>{'page': page},
      options: _staff,
    );
    final Paged<ShopperOrderRow> orders = Paged.parse(response.data, parseRow);
    if (orders.page != page) {
      throw const FormatException('another page than the one asked for');
    }
    return orders;
  }

  Future<ShopperOrder> order(String id) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      _path(id),
      options: _staff,
    );
    return _theOrder(response, id);
  }

  Future<ShopperOrder> accept(String id) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${_path(id)}/accept',
      options: _staff,
    );
    final ShopperOrder order = _theOrder(response, id);
    if (order.assignment?.acceptedAt == null) {
      throw const FormatException('the order does not show the acceptance');
    }
    return order;
  }

  Future<ShopperOrder> start(String id) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${_path(id)}/start',
      options: _staff,
    );
    final ShopperOrder order = _theOrder(response, id);
    if (order.status != OrderStatus.shopping ||
        order.assignment?.startedAt == null) {
      throw const FormatException('the order does not show the start');
    }
    return order;
  }

  static String _path(String id) =>
      '/shopper/orders/${Uri.encodeComponent(id)}';

  /// The order an answer holds, which must be the one asked about; the API
  /// answers ids in lower case, whatever case the address had.
  static ShopperOrder _theOrder(Response<dynamic> response, String id) {
    final ShopperOrder order = parseOrder(ApiEnvelope.unwrap(response.data));
    if (order.id != id.toLowerCase()) {
      throw const FormatException('another order than the one asked for');
    }
    return order;
  }

  static final RegExp _fractional = RegExp(r'^\d{1,4}\.\d{3}$');
  static final RegExp _whole = RegExp(r'^\d{1,4}$');
  static final RegExp _phone = RegExp(r'^\+998\d{9}$');

  /// The states an order is in while a Shopper holds it (`DL-54` (3)).
  static const Set<OrderStatus> _held = <OrderStatus>{
    OrderStatus.shoppingAssigned,
    OrderStatus.shopping,
  };

  static int _amount(JsonFields json, String key) {
    final int value = json.integer(key);
    if (value < 0) {
      throw FormatException('$key is negative');
    }
    return value;
  }

  static int _number(JsonFields json) {
    final int number = json.integer('order_number');
    if (number < 1) {
      throw const FormatException('order_number is not an order number');
    }
    return number;
  }

  /// A price per unit or a total, which the tables hold above zero.
  static int _price(JsonFields json, String key) {
    final int value = json.integer(key);
    if (value < 1) {
      throw FormatException('$key is not a price');
    }
    return value;
  }

  static int? _nullablePrice(JsonFields json, String key) =>
      json.member(key) == null ? null : _price(json, key);

  /// A quantity of [unit] as the server writes it: three decimals for a
  /// unit that takes fractions, a whole number for the others, above zero.
  static String _quantityOf(JsonFields json, String key, UnitCode unit) {
    final String quantity = json.string(key);
    final RegExp shape = unit.takesFraction ? _fractional : _whole;
    if (!shape.hasMatch(quantity) || QuantityRules.thousandths(quantity) == 0) {
      throw FormatException('$key is not a quantity of ${unit.code}');
    }
    return quantity;
  }

  static ShopperAssignment _assignment(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'assignment');
    final ShopperAssignment assignment = ShopperAssignment(
      id: json.uuid('id'),
      assignedAt: json.instant('assigned_at'),
      acceptedAt: json.nullableInstant('accepted_at'),
      startedAt: json.nullableInstant('started_at'),
    );
    if (assignment.startedAt != null && assignment.acceptedAt == null) {
      throw const FormatException('shopping starts after the acceptance');
    }
    return assignment;
  }

  static PriceBound _bound(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'bound');
    return PriceBound(
      customerUnitPriceUzs: _price(json, 'customer_unit_price_uzs'),
      marketPriceUzs: _price(json, 'market_price_uzs'),
    );
  }

  /// One row of the Shopper's list.
  static ShopperOrderRow parseRow(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'shopper order row');
    final ShopperOrderRow row = ShopperOrderRow(
      id: json.uuid('id'),
      orderNumber: _number(json),
      status: json.choice('status', OrderStatus.tryParse),
      itemCount: _amount(json, 'item_count'),
      openItemCount: _amount(json, 'open_item_count'),
      deliveryTimeNote: json.nullableString('delivery_time_note'),
      assignment: _assignment(json.member('assignment')),
    );
    if (!_held.contains(row.status) || row.openItemCount > row.itemCount) {
      throw const FormatException('a row off the contract');
    }
    return row;
  }

  /// The whole order.
  static ShopperOrder parseOrder(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'shopper order');
    final Object? rawLines = json.member('items');
    if (rawLines is! List<dynamic>) {
      throw const FormatException('items is not a list');
    }
    final Object? assignment = json.member('assignment');
    final String? phone = json.nullableString('customer_phone');
    final ShopperOrder order = ShopperOrder(
      id: json.uuid('id'),
      orderNumber: _number(json),
      status: json.choice('status', OrderStatus.tryParse),
      deliveryTimeNote: json.nullableString('delivery_time_note'),
      customerPhone: phone,
      assignment: assignment == null ? null : _assignment(assignment),
      canAccept: json.boolean('can_accept'),
      canStart: json.boolean('can_start'),
      items: rawLines.map(_line).toList(growable: false),
    );
    final ShopperAssignment? held = order.assignment;
    // What the server offers follows from the assignment, as its resource
    // computes it (`docs/09` section 28).
    final bool canAccept = held != null && held.acceptedAt == null;
    final bool canStart =
        held != null &&
        held.acceptedAt != null &&
        held.startedAt == null &&
        order.status == OrderStatus.shoppingAssigned;
    if ((order.status == OrderStatus.shopping) != (phone != null) ||
        (phone != null && !_phone.hasMatch(phone)) ||
        order.canAccept != canAccept ||
        order.canStart != canStart) {
      throw const FormatException('an order off the contract');
    }
    return order;
  }

  static ShopperLine _line(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'line');
    final UnitCode unit = json.choice('unit_code', UnitCode.tryParse);
    final String? cap = json.member('approved_quantity_cap') == null
        ? null
        : _quantityOf(json, 'approved_quantity_cap', unit);
    final String? removed = json.nullableString('removed_reason_code');
    final Object? bound = json.member('bound');
    final Object? replacement = json.member('replacement');
    final Object? purchase = json.member('purchase');
    final Object? question = json.member('pending_approval');
    final ShopperLine line = ShopperLine(
      id: json.uuid('id'),
      productId: json.uuid('product_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      unit: unit,
      priceMode: json.choice('price_mode', PriceMode.tryParse),
      quantity: _quantityOf(json, 'quantity', unit),
      approvedQuantityCap: cap,
      customerNote: json.nullableString('customer_note'),
      substitutionPolicy: json.choice(
        'substitution_policy',
        SubstitutionPolicy.tryParse,
      ),
      status: json.choice('status', OrderItemStatus.tryParse),
      marketPriceUzs: _price(json, 'market_price_uzs'),
      customerUnitPriceUzs: _price(json, 'customer_unit_price_uzs'),
      bound: bound == null ? null : _bound(bound),
      replacement: replacement == null ? null : _replacement(replacement),
      purchase: purchase == null ? null : _purchase(purchase, unit),
      removedReason: removed == null
          ? null
          : json.choice('removed_reason_code', ItemRemovedReason.tryParse),
      openQuestion: question == null ? null : _question(question),
    );
    final bool bought = line.status == OrderItemStatus.purchased;
    final bool gone = line.status == OrderItemStatus.removed;
    // As the resource and the tables hold a line (`docs/09` section 28):
    // a fixed line has no bound and an estimate has one; the purchase names
    // the product bought — the replacement, when there is one.
    if (bought != (line.purchase != null) ||
        gone != (line.removedReason != null) ||
        (gone && line.replacement != null) ||
        (line.openQuestion != null &&
            line.status != OrderItemStatus.awaitingCustomer) ||
        (line.priceMode == PriceMode.fixed) != (line.bound == null) ||
        (line.purchase != null &&
            line.purchase!.productId !=
                (line.replacement?.productId ?? line.productId))) {
      throw const FormatException('a line off the contract');
    }
    return line;
  }

  static ShopperReplacement _replacement(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'replacement');
    return ShopperReplacement(
      productId: json.uuid('product_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      marketPriceUzs: _price(json, 'market_price_uzs'),
      resolution: json.choice(
        'substitution_resolution',
        SubstitutionResolution.tryParse,
      ),
      bound: _bound(json.member('bound')),
    );
  }

  static ShopperPurchase _purchase(Object? raw, UnitCode unit) {
    final JsonFields json = JsonFields.of(raw, 'purchase');
    return ShopperPurchase(
      productId: json.uuid('product_id'),
      purchasedQuantity: _quantityOf(json, 'purchased_quantity', unit),
      billableQuantity: _quantityOf(json, 'billable_quantity', unit),
      actualMarketPriceUzs: _nullablePrice(json, 'actual_market_price_uzs'),
      billableUnitPriceUzs: _price(json, 'billable_unit_price_uzs'),
      // A tiny quantity at a price of one sum rounds to nothing, which the
      // table allows (`order_items_prices_check`).
      lineTotalUzs: _amount(json, 'line_total_uzs'),
    );
  }

  static OpenQuestion _question(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'pending approval');
    return OpenQuestion(
      id: json.uuid('id'),
      type: json.choice('type', ApprovalType.tryParse),
      expiresAt: json.instant('expires_at'),
    );
  }
}

class ShopperOrdersRepositoryImpl implements ShopperOrdersRepository {
  ShopperOrdersRepositoryImpl(this._api);

  final ShopperOrdersApi _api;

  @override
  Future<Paged<ShopperOrderRow>> orders(int page) =>
      guardApiCall(() => _api.orders(page));

  @override
  Future<ShopperOrder> order(String id) => guardApiCall(() => _api.order(id));

  @override
  Future<ShopperOrder> accept(String id) => guardApiCall(() => _api.accept(id));

  @override
  Future<ShopperOrder> start(String id) => guardApiCall(() => _api.start(id));
}
