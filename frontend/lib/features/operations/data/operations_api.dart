import 'package:dio/dio.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/domain/app_user.dart';
import '../domain/board.dart';

/// The data source for `docs/09-api-contracts.md` sections 38 and 39, on
/// the staff session, with its strict parsing. An answer is held to the
/// request it answers (`DL-27` (6)): a page of other orders than the filters
/// asked for, or another order than the one asked for, is malformed.
class OperationsApi {
  OperationsApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);

  Future<Paged<BoardRow>> orders(BoardQuery query) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/operations/orders',
      queryParameters: queryOf(query),
      options: _staff,
    );
    final Paged<BoardRow> page = Paged.parse(response.data, parseRow);
    if (page.page != query.page ||
        !page.items.every((BoardRow row) => _answers(query, row))) {
      throw const FormatException('the page does not match the filters');
    }
    return page;
  }

  Future<BoardOrder> order(String id) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/operations/orders/${Uri.encodeComponent(id)}',
      options: _staff,
    );
    final BoardOrder order = parseOrder(ApiEnvelope.unwrap(response.data));
    // The API answers ids in lower case, whatever case the address had.
    if (order.id != id.toLowerCase()) {
      throw const FormatException('another order than the one asked for');
    }
    return order;
  }

  Future<BoardSummary> summary() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/operations/summary',
      options: _staff,
    );
    return parseSummary(ApiEnvelope.unwrap(response.data));
  }

  Future<List<AttentionItem>> attention() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/operations/attention',
      options: _staff,
    );
    return Paged.parse(response.data, parseAttention).items;
  }

  Future<List<ShopperChoice>> shoppers() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/operations/shoppers',
      queryParameters: const <String, Object>{'per_page': 100},
      options: _staff,
    );
    return Paged.parse(response.data, parseShopper).items;
  }

  /// `POST /operations/orders/{order}/shopper-assignment` (`docs/09`
  /// section 39).
  Future<BoardOrder> assignShopper(String orderId, String shopperId) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      _assignmentPath(orderId),
      data: <String, String>{'shopper_id': shopperId},
      options: _staff,
    );
    return _assigned(response, orderId, shopperId);
  }

  /// `PUT /operations/orders/{order}/shopper-assignment`, naming the
  /// assignment it replaces (`DL-45` (8)).
  Future<BoardOrder> reassignShopper(
    String orderId,
    String shopperId,
    String replacesAssignmentId,
  ) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      _assignmentPath(orderId),
      data: <String, String>{
        'shopper_id': shopperId,
        'replaces_assignment_id': replacesAssignmentId,
      },
      options: _staff,
    );
    return _assigned(response, orderId, shopperId);
  }

  static String _assignmentPath(String orderId) =>
      '/operations/orders/${Uri.encodeComponent(orderId)}/shopper-assignment';

  /// The order after an assignment: the order asked about, with the Shopper
  /// asked for as its current one.
  static BoardOrder _assigned(
    Response<dynamic> response,
    String orderId,
    String shopperId,
  ) {
    final BoardOrder order = parseOrder(ApiEnvelope.unwrap(response.data));
    if (order.id != orderId.toLowerCase() ||
        order.currentAssignment?.shopper.id != shopperId.toLowerCase()) {
      throw const FormatException('the answer does not show the assignment');
    }
    return order;
  }

  /// The query string of [query]: its page, and each filter that is set.
  static Map<String, Object> queryOf(BoardQuery query) => <String, Object>{
    'page': query.page,
    if (query.status != null) 'status': query.status!.code,
    if (query.shopperId != null) 'shopper_id': query.shopperId!,
    if (query.paymentMethod != null)
      'payment_method': query.paymentMethod!.code,
    if (query.from != null) 'from': dayOf(query.from!),
    if (query.to != null) 'to': dayOf(query.to!),
    if (query.selfOrdersOnly) 'attention': AttentionType.selfOrder.code,
    if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
  };

  /// A calendar day as the API takes it: `YYYY-MM-DD`.
  static String dayOf(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Whether [row] can be an answer to [query]'s filters. The dates and the
  /// search are the server's to judge, and so are the Shopper and the
  /// self-order filters: a row's Shopper is read after its page, so a
  /// reassignment in between is not a malformed answer (`DL-47` (3)).
  static bool _answers(BoardQuery query, BoardRow row) =>
      (query.status == null || row.status == query.status) &&
      (query.paymentMethod == null || row.paymentMethod == query.paymentMethod);

  static final RegExp _phone = RegExp(r'^\+998\d{9}$');
  static final RegExp _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _quantity = RegExp(r'^\d+(\.\d{1,3})?$');
  static final RegExp _percent = RegExp(r'^\d+\.\d{2}$');
  static final RegExp _coordinate = RegExp(r'^-?\d{1,3}\.\d{6}$');

  static String _phoneOf(JsonFields json, String key) {
    final String phone = json.string(key);
    if (!_phone.hasMatch(phone)) {
      throw FormatException('$key is not +998 and nine digits');
    }
    return phone;
  }

  static String _matching(JsonFields json, String key, RegExp shape) {
    final String value = json.string(key);
    if (!shape.hasMatch(value)) {
      throw FormatException('$key is not in its form: $value');
    }
    return value;
  }

  static int _amount(JsonFields json, String key) {
    final int value = json.integer(key);
    if (value < 0) {
      throw FormatException('$key is negative');
    }
    return value;
  }

  static int? _nullableAmount(JsonFields json, String key) {
    final int? value = json.nullableInteger(key);
    if (value != null && value < 0) {
      throw FormatException('$key is negative');
    }
    return value;
  }

  static int _orderNumber(JsonFields json, String key) {
    final int number = json.integer(key);
    if (number < 1) {
      throw FormatException('$key is not an order number');
    }
    return number;
  }

  static PersonRef _person(Object? raw, String what) {
    final JsonFields json = JsonFields.of(raw, what);
    return PersonRef(
      id: json.uuid('id'),
      fullName: json.nullableString('full_name'),
    );
  }

  static List<T> _list<T>(
    JsonFields json,
    String key,
    T Function(Object? raw) item,
  ) {
    final Object? raw = json.member(key);
    if (raw is! List<dynamic>) {
      throw FormatException('$key is not a list');
    }
    return raw.map(item).toList(growable: false);
  }

  /// One row of the board.
  static BoardRow parseRow(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'board row');
    final JsonFields customer = JsonFields.of(
      json.member('customer'),
      'customer',
    );
    final Object? shopper = json.member('shopper');
    final BoardRow row = BoardRow(
      id: json.uuid('id'),
      orderNumber: _orderNumber(json, 'order_number'),
      createdAt: json.instant('created_at'),
      status: json.choice('status', OrderStatus.tryParse),
      paymentMethod: json.choice('payment_method', PaymentMethod.tryParse),
      customerName: customer.string('full_name'),
      customerPhone: _phoneOf(customer, 'phone'),
      itemCount: _amount(json, 'item_count'),
      totalUzs: _nullableAmount(json, 'total_uzs'),
      totalKind: json.choice('total_kind', TotalKind.tryParse),
      shopper: shopper == null ? null : _person(shopper, 'shopper'),
      isSelfOrder: json.boolean('is_self_order'),
    );
    if ((row.totalUzs == null) != (row.totalKind == TotalKind.none)) {
      throw const FormatException('a total is null exactly when it is none');
    }
    return row;
  }

  /// The summary strip, with every open status and nothing else.
  static BoardSummary parseSummary(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'summary');
    final JsonFields open = JsonFields.of(
      json.member('open_by_status'),
      'open_by_status',
    );
    final Object? rawOpen = json.member('open_by_status');
    if (rawOpen is Map<String, dynamic> &&
        rawOpen.length != OrderStatus.open.length) {
      throw const FormatException('open_by_status names other statuses');
    }
    return BoardSummary(
      day: _matching(json, 'day', _day),
      openByStatus: <OrderStatus, int>{
        for (final OrderStatus status in OrderStatus.open)
          status: _amount(open, status.code),
      },
      completedToday: _amount(json, 'completed_today'),
      cancelledToday: _amount(json, 'cancelled_today'),
      salesTodayUzs: _amount(json, 'sales_today_uzs'),
      attentionCount: _amount(json, 'attention_count'),
    );
  }

  /// One attention item.
  static AttentionItem parseAttention(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'attention item');
    final Object? shopper = json.member('shopper');
    final Object? courier = json.member('courier');
    final String code = json.string('type');
    return AttentionItem(
      type: AttentionType.of(code),
      code: code,
      orderId: json.uuid('order_id'),
      orderNumber: _orderNumber(json, 'order_number'),
      since: json.instant('since'),
      shopper: shopper == null ? null : _person(shopper, 'shopper'),
      courier: courier == null ? null : _person(courier, 'courier'),
    );
  }

  /// A Shopper of the picker.
  static ShopperChoice parseShopper(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'shopper');
    return ShopperChoice(
      id: json.uuid('id'),
      fullName: json.nullableString('full_name'),
      phone: _phoneOf(json, 'phone'),
      currentAssignmentCount: _amount(json, 'current_assignment_count'),
    );
  }

  /// The whole order.
  static BoardOrder parseOrder(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'board order');
    final JsonFields customer = JsonFields.of(
      json.member('customer'),
      'customer',
    );
    final JsonFields address = JsonFields.of(json.member('address'), 'address');
    final JsonFields timestamps = JsonFields.of(
      json.member('timestamps'),
      'timestamps',
    );
    final String? reason = json.nullableString('cancellation_reason_code');
    final List<ShopperAssignment> assignments = _list(
      json,
      'shopper_assignments',
      _assignment,
    );
    if (assignments.where((ShopperAssignment a) => a.endedAt == null).length >
        1) {
      throw const FormatException('more than one current assignment');
    }

    return BoardOrder(
      id: json.uuid('id'),
      orderNumber: _orderNumber(json, 'order_number'),
      status: json.choice('status', OrderStatus.tryParse),
      paymentMethod: json.choice('payment_method', PaymentMethod.tryParse),
      deliveryTimeNote: json.nullableString('delivery_time_note'),
      customer: BoardCustomer(
        id: customer.uuid('id'),
        fullName: customer.string('full_name'),
        phone: _phoneOf(customer, 'phone'),
      ),
      address: BoardAddress(
        latitude: _matching(address, 'latitude', _coordinate),
        longitude: _matching(address, 'longitude', _coordinate),
        street: address.string('street'),
        house: address.string('house'),
        apartment: address.nullableString('apartment'),
        landmark: address.nullableString('landmark'),
        deliveryNote: address.nullableString('delivery_note'),
      ),
      items: _list(json, 'items', _item),
      totals: _totals(json.member('totals')),
      shopperAssignments: assignments,
      history: _list(json, 'history', _history),
      cancellationReason: reason == null
          ? null
          : json.choice(
              'cancellation_reason_code',
              CancellationReason.tryParse,
            ),
      createdAt: timestamps.instant('created_at'),
      completedAt: timestamps.nullableInstant('completed_at'),
      cancelledAt: timestamps.nullableInstant('cancelled_at'),
    );
  }

  static BoardItem _item(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'item');
    final String? removed = json.nullableString('removed_reason_code');
    final BoardItem item = BoardItem(
      id: json.uuid('id'),
      productId: json.uuid('product_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      unit: json.choice('unit_code', UnitCode.tryParse),
      priceMode: json.choice('price_mode', PriceMode.tryParse),
      quantity: _matching(json, 'quantity', _quantity),
      customerNote: json.nullableString('customer_note'),
      substitutionPolicy: json.choice(
        'substitution_policy',
        SubstitutionPolicy.tryParse,
      ),
      status: json.choice('status', OrderItemStatus.tryParse),
      marketPriceUzs: _amount(json, 'market_price_uzs'),
      customerUnitPriceUzs: _amount(json, 'customer_unit_price_uzs'),
      markupPercent: _matching(json, 'markup_percent', _percent),
      lineTotalUzs: _amount(json, 'line_total_uzs'),
      removedReason: removed == null
          ? null
          : json.choice('removed_reason_code', ItemRemovedReason.tryParse),
    );
    if ((item.status == OrderItemStatus.removed) !=
        (item.removedReason != null)) {
      throw const FormatException('a removed line has its reason');
    }
    return item;
  }

  static BoardTotals _totals(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'totals');
    final BoardTotals totals = BoardTotals(
      merchandiseSubtotalUzs: _nullableAmount(json, 'merchandise_subtotal_uzs'),
      serviceFeeUzs: _nullableAmount(json, 'service_fee_uzs'),
      deliveryFeeUzs: _nullableAmount(json, 'delivery_fee_uzs'),
      totalUzs: _nullableAmount(json, 'total_uzs'),
      kind: json.choice('total_kind', TotalKind.tryParse),
    );
    final bool none = totals.kind == TotalKind.none;
    for (final int? amount in <int?>[
      totals.merchandiseSubtotalUzs,
      totals.serviceFeeUzs,
      totals.deliveryFeeUzs,
      totals.totalUzs,
    ]) {
      if ((amount == null) != none) {
        throw const FormatException('amounts are null exactly when none');
      }
    }
    return totals;
  }

  static ShopperAssignment _assignment(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'shopper assignment');
    final JsonFields shopper = JsonFields.of(json.member('shopper'), 'shopper');
    final String? endedReason = json.nullableString('ended_reason');
    final ShopperAssignment assignment = ShopperAssignment(
      id: json.uuid('id'),
      shopper: PersonRef(
        id: shopper.uuid('id'),
        fullName: shopper.nullableString('full_name'),
      ),
      shopperPhone: _phoneOf(shopper, 'phone'),
      assignedBy: _person(json.member('assigned_by'), 'assigned_by'),
      isSelfOrder: json.boolean('is_self_order'),
      assignedAt: json.instant('assigned_at'),
      acceptedAt: json.nullableInstant('accepted_at'),
      startedAt: json.nullableInstant('started_at'),
      completedAt: json.nullableInstant('completed_at'),
      endedAt: json.nullableInstant('ended_at'),
      endedReason: endedReason == null
          ? null
          : json.choice('ended_reason', AssignmentEndReason.tryParse),
    );
    if ((assignment.endedAt == null) != (assignment.endedReason == null)) {
      throw const FormatException('an end has its reason');
    }
    return assignment;
  }

  static HistoryEntry _history(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'history entry');
    final HistoryActorType actorType = json.choice(
      'actor_type',
      HistoryActorType.tryParse,
    );
    final Object? rawActor = json.member('actor');
    final String? from = json.nullableString('from_status');
    final String? to = json.nullableString('to_status');
    final String? reason = json.nullableString('reason_code');
    final OrderHistoryEvent event = json.choice(
      'event_type',
      OrderHistoryEvent.tryParse,
    );

    final HistoryActor? actor;
    if (rawActor == null) {
      actor = null;
    } else {
      final JsonFields fields = JsonFields.of(rawActor, 'actor');
      actor = HistoryActor(
        id: fields.uuid('id'),
        role: fields.choice('role', UserRole.tryParse),
        fullName: fields.nullableString('full_name'),
      );
    }
    if ((actorType == HistoryActorType.user) != (actor != null)) {
      throw const FormatException('a user entry names its actor');
    }

    return HistoryEntry(
      id: json.uuid('id'),
      event: event,
      fromStatus: from == null
          ? null
          : json.choice('from_status', OrderStatus.tryParse),
      toStatus: to == null
          ? null
          : json.choice('to_status', OrderStatus.tryParse),
      actorType: actorType,
      actor: actor,
      reason: reason == null
          ? null
          : json.choice('reason_code', CancellationReason.tryParse),
      note: json.nullableString('note'),
      details: _details(event, json.member('details')),
      createdAt: json.instant('created_at'),
    );
  }

  /// The details of the events the board shows them for; any other
  /// event's are not read.
  static HistoryDetails? _details(OrderHistoryEvent event, Object? raw) {
    switch (event) {
      case OrderHistoryEvent.shopperAssigned:
      case OrderHistoryEvent.shopperReassigned:
        final JsonFields json = JsonFields.of(raw, 'assignment details');
        final bool reassigned = event == OrderHistoryEvent.shopperReassigned;
        return AssignmentDetails(
          assignmentId: json.uuid('assignment_id'),
          shopperId: json.uuid('shopper_id'),
          isSelfOrder: json.boolean('is_self_order'),
          previousAssignmentId: reassigned
              ? json.uuid('previous_assignment_id')
              : null,
          previousShopperId: reassigned
              ? json.uuid('previous_shopper_id')
              : null,
        );
      case OrderHistoryEvent.edited:
        final Object? map = raw;
        if (map is! Map<String, dynamic>) {
          throw const FormatException('edit details are not an object');
        }
        final JsonFields json = JsonFields.of(map, 'edit details');
        return EditDetails(
          added: _list(json, 'added', (Object? line) => line).length,
          removed: _list(json, 'removed', (Object? line) => line).length,
          changed: _list(json, 'changed', (Object? line) => line).length,
          deliveryTimeNoteChanged: map.containsKey('delivery_time_note'),
        );
      default:
        return null;
    }
  }
}
