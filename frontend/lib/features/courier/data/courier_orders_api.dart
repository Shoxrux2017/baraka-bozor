import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/storage/token_store.dart';
import '../domain/courier_orders.dart';

/// The data source for `docs/09-api-contracts.md` sections 36 and 37, on the
/// staff session, with its strict parsing. An answer is held to the request
/// it answers (`DL-27` (6)): the order acted on, showing the action done.
class CourierOrdersApi {
  CourierOrdersApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);

  Future<Paged<CourierOrder>> orders(int page) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/courier/orders',
      queryParameters: <String, Object>{'page': page},
      options: _staff,
    );
    final Paged<CourierOrder> orders = Paged.parse(response.data, parseOrder);
    // The list holds the Courier's current assignments only.
    if (orders.page != page ||
        orders.items.any((CourierOrder order) => !order.held)) {
      throw const FormatException('a list off the contract');
    }
    return orders;
  }

  Future<CourierOrder> order(String id) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      _path(id),
      options: _staff,
    );
    return _held(response, id);
  }

  Future<CourierOrder> accept(String id) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${_path(id)}/accept',
      options: _staff,
    );
    final CourierOrder order = _held(response, id);
    if (order.assignment.acceptedAt == null) {
      throw const FormatException('the order does not show the acceptance');
    }
    return order;
  }

  Future<CourierOrder> start(String id) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${_path(id)}/start',
      options: _staff,
    );
    final CourierOrder order = _held(response, id);
    if (order.status != OrderStatus.onTheWay ||
        order.assignment.deliveryStartedAt == null) {
      throw const FormatException('the order does not show the start');
    }
    return order;
  }

  Future<CourierOrder> delivered(
    String id,
    int? cashReceivedUzs,
    String idempotencyKey,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${_path(id)}/delivered',
      data: <String, Object?>{'cash_received_uzs': ?cashReceivedUzs},
      options: _staff.copyWith(
        headers: <String, Object?>{'Idempotency-Key': idempotencyKey},
      ),
    );
    // Completed, through the assignment the delivery ended (`DL-64` (3));
    // the parser holds an order in that state to the ended form.
    final CourierOrder order = _theOrder(response, id);
    if (order.status != OrderStatus.completed) {
      throw const FormatException('the order does not show the delivery');
    }
    return order;
  }

  Future<CourierOrder> notDelivered(
    String id,
    DeliveryFailureReason reason,
    String? note,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${_path(id)}/not-delivered',
      data: <String, Object?>{'reason_code': reason.code, 'note': ?note},
      options: _staff,
    );
    // Back with an Operator, through the assignment the failure ended; a
    // repeat answers the order as it is now, which an Operator may have
    // cancelled since (`DL-64` (3), `DL-65` (3)). The parser holds an order
    // in either state to the ended form.
    final CourierOrder order = _theOrder(response, id);
    if (!_afterFailure.contains(order.status)) {
      throw const FormatException('the order does not show the failure');
    }
    return order;
  }

  static String _path(String id) =>
      '/courier/orders/${Uri.encodeComponent(id)}';

  static const Set<OrderStatus> _afterFailure = <OrderStatus>{
    OrderStatus.readyForDelivery,
    OrderStatus.cancelled,
  };

  /// The order an answer holds, which must be the one asked about; the API
  /// answers ids in lower case, whatever case the address had.
  static CourierOrder _theOrder(Response<dynamic> response, String id) {
    final CourierOrder order = parseOrder(ApiEnvelope.unwrap(response.data));
    if (order.id != id.toLowerCase()) {
      throw const FormatException('another order than the one asked for');
    }
    return order;
  }

  /// The order a read, an acceptance or a start answers: one the Courier
  /// still holds.
  static CourierOrder _held(Response<dynamic> response, String id) {
    final CourierOrder order = _theOrder(response, id);
    if (!order.held) {
      throw const FormatException('the order is not the Courier\'s');
    }
    return order;
  }

  static final RegExp _phone = RegExp(r'^\+998\d{9}$');
  static final RegExp _latitude = RegExp(r'^-?\d{1,2}\.\d{6}$');
  static final RegExp _longitude = RegExp(r'^-?\d{1,3}\.\d{6}$');

  /// The states an order is in while a Courier holds it (`docs/09` section
  /// 36).
  static const Set<OrderStatus> _holding = <OrderStatus>{
    OrderStatus.deliveryAssigned,
    OrderStatus.onTheWay,
  };

  static String _phoneOf(JsonFields json, String key) {
    final String phone = json.string(key);
    if (!_phone.hasMatch(phone)) {
      throw FormatException('$key is not a phone');
    }
    return phone;
  }

  static Recipient _recipient(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'recipient');
    return Recipient(
      fullName: json.string('full_name'),
      phone: _phoneOf(json, 'phone'),
    );
  }

  static DeliveryAddress _address(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'address');
    final String latitude = json.string('latitude');
    final String longitude = json.string('longitude');
    if (!_latitude.hasMatch(latitude) ||
        !_longitude.hasMatch(longitude) ||
        double.parse(latitude).abs() > 90 ||
        double.parse(longitude).abs() > 180) {
      throw const FormatException('coordinates off the contract');
    }
    return DeliveryAddress(
      latitude: latitude,
      longitude: longitude,
      street: json.string('street'),
      house: json.string('house'),
      apartment: json.nullableString('apartment'),
      landmark: json.nullableString('landmark'),
    );
  }

  static CourierAssignment _assignment(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'assignment');
    final CourierAssignment assignment = CourierAssignment(
      id: json.uuid('id'),
      assignedAt: json.instant('assigned_at'),
      acceptedAt: json.nullableInstant('accepted_at'),
      deliveryStartedAt: json.nullableInstant('delivery_started_at'),
      delayAt: json.nullableInstant('delay_at'),
    );
    // The start follows the acceptance, and sets the delay with it
    // (`docs/08` section 17).
    if ((assignment.deliveryStartedAt != null &&
            assignment.acceptedAt == null) ||
        (assignment.deliveryStartedAt != null) !=
            (assignment.delayAt != null)) {
      throw const FormatException('an assignment off the contract');
    }
    return assignment;
  }

  /// A delivery, in the list and alone, and the answer of every action.
  static CourierOrder parseOrder(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'courier order');
    final int number = json.integer('order_number');
    if (number < 1) {
      throw const FormatException('order_number is not an order number');
    }
    final Object? recipient = json.member('recipient');
    final Object? address = json.member('address');
    final PaymentMethod method = json.choice(
      'payment_method',
      PaymentMethod.tryParse,
    );
    final int? amount = json.nullableInteger('amount_to_collect_uzs');
    final bool shopper = json.has('shopper_phone');
    final CourierOrder order = CourierOrder(
      id: json.uuid('id'),
      orderNumber: number,
      status: json.choice('status', OrderStatus.tryParse),
      recipient: recipient == null ? null : _recipient(recipient),
      address: address == null ? null : _address(address),
      deliveryNote: json.nullableString('delivery_note'),
      deliveryTimeNote: json.nullableString('delivery_time_note'),
      paymentMethod: method,
      amountToCollectUzs: amount,
      cancellationRequestPending: json.boolean('cancellation_request_pending'),
      assignment: _assignment(json.member('assignment')),
      canAccept: json.boolean('can_accept'),
      canStart: json.boolean('can_start'),
      shopperPhone: shopper && json.member('shopper_phone') != null
          ? _phoneOf(json, 'shopper_phone')
          : null,
    );
    final CourierAssignment assignment = order.assignment;
    // What the server offers follows from the assignment, as its resource
    // computes it (`docs/09` section 36).
    final bool canStart =
        assignment.acceptedAt != null &&
        assignment.deliveryStartedAt == null &&
        order.status == OrderStatus.deliveryAssigned &&
        !order.cancellationRequestPending;
    // Held, the order says who, where and when, in a state a Courier holds
    // it in; once the assignment ended, the outcome only (`DL-64` (7)).
    final bool ended =
        order.recipient == null &&
        order.address == null &&
        order.deliveryNote == null &&
        order.deliveryTimeNote == null &&
        !shopper;
    if ((order.recipient == null) != (order.address == null) ||
        (order.held && !_holding.contains(order.status)) ||
        (!order.held && !ended) ||
        (method == PaymentMethod.cash) != (amount != null) ||
        (amount != null && amount < 1) ||
        order.canAccept != (assignment.acceptedAt == null) ||
        order.canStart != canStart) {
      throw const FormatException('an order off the contract');
    }
    return order;
  }
}

class CourierOrdersRepositoryImpl implements CourierOrdersRepository {
  CourierOrdersRepositoryImpl(this._api);

  final CourierOrdersApi _api;

  @override
  Future<Paged<CourierOrder>> orders(int page) =>
      guardApiCall(() => _api.orders(page));

  @override
  Future<CourierOrder> order(String id) => guardApiCall(() => _api.order(id));

  @override
  Future<CourierOrder> accept(String id) => guardApiCall(() => _api.accept(id));

  @override
  Future<CourierOrder> start(String id) => guardApiCall(() => _api.start(id));

  @override
  Future<CourierOrder> delivered(
    String id,
    int? cashReceivedUzs,
    String idempotencyKey,
  ) => guardApiCall(() => _api.delivered(id, cashReceivedUzs, idempotencyKey));

  @override
  Future<CourierOrder> notDelivered(
    String id,
    DeliveryFailureReason reason,
    String? note,
  ) => guardApiCall(() => _api.notDelivered(id, reason, note));
}
