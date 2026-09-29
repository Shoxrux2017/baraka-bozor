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
import '../domain/customer_orders.dart';

/// The data source for `docs/09-api-contracts.md` sections 20 to 23, on
/// the Customer session, with its strict parsing. An answer is held to the
/// request it answers (`DL-27` (6)).
class CustomerOrdersApi {
  CustomerOrdersApi(this._dio);

  final Dio _dio;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  Future<Paged<OrderSummary>> orders(int page) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/customer/orders',
      queryParameters: <String, Object>{'page': page},
      options: _customer,
    );
    final Paged<OrderSummary> orders = Paged.parse(response.data, parseSummary);
    if (orders.page != page) {
      throw const FormatException('another page than the one asked for');
    }
    return orders;
  }

  Future<CustomerOrder> order(String id) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      _path(id),
      options: _customer,
    );
    return _theOrder(response, id);
  }

  Future<CustomerOrder> edit(
    String id,
    List<OrderEditLine> lines,
    String? deliveryTimeNote,
  ) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '${_path(id)}/items',
      data: <String, Object?>{
        'items': <Map<String, Object?>>[
          for (final OrderEditLine line in lines)
            <String, Object?>{
              'product_id': line.productId,
              'quantity': line.quantity,
              'customer_note': line.customerNote,
              'substitution_policy': line.substitutionPolicy.code,
            },
        ],
        'delivery_time_note': deliveryTimeNote,
      },
      options: _customer,
    );
    final CustomerOrder order = _theOrder(response, id);
    if (order.deliveryTimeNote != deliveryTimeNote ||
        order.openLines.length != lines.length) {
      throw const FormatException('the order does not show the edit');
    }
    return order;
  }

  Future<CustomerOrder> cancel(
    String id,
    String? reason,
    String idempotencyKey,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${_path(id)}/cancel',
      data: <String, Object?>{'reason': ?reason},
      options: _customer.copyWith(
        headers: <String, Object?>{'Idempotency-Key': idempotencyKey},
      ),
    );
    final CustomerOrder order = _theOrder(response, id);
    // From shopping on, the cancel files a request an Operator decides
    // (`DL-65` (1)): the order goes on, carrying it. A replay answers the
    // order as it is now, whose request may be decided since.
    if (order.status != OrderStatus.cancelled &&
        order.cancellationRequest == null) {
      throw const FormatException('the order is neither cancelled nor asked');
    }
    return order;
  }

  Future<CustomerApproval> decide(
    String orderId,
    String approvalId,
    ApprovalDecision decision,
    String idempotencyKey,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/approvals/${Uri.encodeComponent(approvalId)}/decision',
      data: <String, String>{'decision': decision.code},
      options: _customer.copyWith(
        headers: <String, Object?>{'Idempotency-Key': idempotencyKey},
      ),
    );
    final CustomerApproval approval = parseApproval(
      ApiEnvelope.unwrap(response.data),
    );
    // The question asked about, on the order shown, answered as asked; a
    // replay under the same key answers it so too (`docs/09` section 48).
    final ApprovalStatus decided = switch (decision) {
      ApprovalDecision.approve => ApprovalStatus.approved,
      ApprovalDecision.reject => ApprovalStatus.rejected,
    };
    if (approval.id != approvalId.toLowerCase() ||
        approval.orderId != orderId.toLowerCase() ||
        approval.status != decided) {
      throw const FormatException('the answer does not show the decision');
    }
    return approval;
  }

  static String _path(String id) =>
      '/customer/orders/${Uri.encodeComponent(id)}';

  static CustomerOrder _theOrder(Response<dynamic> response, String id) {
    final CustomerOrder order = parseOrder(ApiEnvelope.unwrap(response.data));
    // The API answers ids in lower case, whatever case the address had.
    if (order.id != id.toLowerCase()) {
      throw const FormatException('another order than the one asked for');
    }
    return order;
  }

  static final RegExp _quantity = RegExp(r'^\d{1,4}(\.\d{3})?$');

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

  static int _number(JsonFields json) {
    final int number = json.integer('order_number');
    if (number < 1) {
      throw const FormatException('order_number is not an order number');
    }
    return number;
  }

  /// One order of the list.
  static OrderSummary parseSummary(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'order summary');
    final OrderSummary summary = OrderSummary(
      id: json.uuid('id'),
      orderNumber: _number(json),
      status: json.choice('status', OrderStatus.tryParse),
      paymentMethod: json.choice('payment_method', PaymentMethod.tryParse),
      itemCount: _amount(json, 'item_count'),
      pendingApprovalCount: _amount(json, 'pending_approval_count'),
      totalUzs: _nullableAmount(json, 'total_uzs'),
      totalKind: json.choice('total_kind', TotalKind.tryParse),
      createdAt: json.instant('created_at'),
    );
    if ((summary.totalUzs == null) != (summary.totalKind == TotalKind.none)) {
      throw const FormatException('a total is null exactly when none is due');
    }
    return summary;
  }

  /// The whole order.
  static CustomerOrder parseOrder(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'order');
    final JsonFields totals = JsonFields.of(json.member('totals'), 'totals');
    final JsonFields address = JsonFields.of(json.member('address'), 'address');
    final JsonFields timestamps = JsonFields.of(
      json.member('timestamps'),
      'timestamps',
    );
    final Object? rawLines = json.member('items');
    if (rawLines is! List<dynamic>) {
      throw const FormatException('items is not a list');
    }
    final String? reason = json.nullableString('cancellation_reason_code');
    final Object? request = json.member('cancellation_request');
    final Object? payment = json.member('payment');

    final CustomerOrder order = CustomerOrder(
      id: json.uuid('id'),
      orderNumber: _number(json),
      status: json.choice('status', OrderStatus.tryParse),
      paymentMethod: json.choice('payment_method', PaymentMethod.tryParse),
      deliveryTimeNote: json.nullableString('delivery_time_note'),
      canEdit: json.boolean('can_edit'),
      canCancelDirectly: json.boolean('can_cancel_directly'),
      canRequestCancellation: json.boolean('can_request_cancellation'),
      pendingApprovalCount: _amount(json, 'pending_approval_count'),
      lines: rawLines.map(_line).toList(growable: false),
      merchandiseSubtotalUzs: _nullableAmount(
        totals,
        'merchandise_subtotal_uzs',
      ),
      serviceFeeUzs: _nullableAmount(totals, 'service_fee_uzs'),
      deliveryFeeUzs: _nullableAmount(totals, 'delivery_fee_uzs'),
      totalUzs: _nullableAmount(totals, 'total_uzs'),
      totalKind: totals.choice('total_kind', TotalKind.tryParse),
      address: OrderAddress(
        street: address.string('street'),
        house: address.string('house'),
        apartment: address.nullableString('apartment'),
        landmark: address.nullableString('landmark'),
        deliveryNote: address.nullableString('delivery_note'),
      ),
      cancellationReason: reason == null
          ? null
          : json.choice(
              'cancellation_reason_code',
              CancellationReason.tryParse,
            ),
      cancellationRequest: request == null ? null : _request(request),
      payment: payment == null ? null : _payment(payment),
      createdAt: timestamps.instant('created_at'),
    );
    final bool none = order.totalKind == TotalKind.none;
    for (final int? amount in <int?>[
      order.merchandiseSubtotalUzs,
      order.serviceFeeUzs,
      order.deliveryFeeUzs,
      order.totalUzs,
    ]) {
      if ((amount == null) != none) {
        throw const FormatException('amounts are null exactly when none');
      }
    }
    if ((order.status == OrderStatus.cancelled) !=
        (order.cancellationReason != null)) {
      throw const FormatException('a cancelled order has its reason');
    }
    // One open question at most per line, and the count is theirs.
    if (order.pendingApprovalCount !=
        order.lines
            .where((CustomerOrderLine line) => line.question != null)
            .length) {
      throw const FormatException('the open questions are counted as shown');
    }
    return order;
  }

  static CustomerCancellationRequest _request(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'cancellation request');
    final CustomerCancellationRequest request = CustomerCancellationRequest(
      id: json.uuid('id'),
      status: json.choice('status', CancellationRequestStatus.tryParse),
      reason: json.string('reason'),
      createdAt: json.instant('created_at'),
      resolvedAt: json.nullableInstant('resolved_at'),
    );
    if ((request.status == CancellationRequestStatus.pending) !=
        (request.resolvedAt == null)) {
      throw const FormatException('a request is resolved once not pending');
    }
    return request;
  }

  static CustomerPayment _payment(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'payment');
    final CustomerPayment payment = CustomerPayment(
      method: json.choice('method', PaymentMethod.tryParse),
      status: json.choice('status', PaymentStatus.tryParse),
      amountUzs: _amount(json, 'amount_uzs'),
      paidAt: json.nullableInstant('paid_at'),
    );
    // Paid exactly when it has its instant; cash is only ever paid, taken
    // at the door (`docs/08` section 19).
    if ((payment.status == PaymentStatus.paid) != (payment.paidAt != null) ||
        (payment.method == PaymentMethod.cash &&
            payment.status != PaymentStatus.paid)) {
      throw const FormatException('a payment off the contract');
    }
    return payment;
  }

  /// A question as the decision answers it (`docs/09` section 23).
  static CustomerApproval parseApproval(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'approval');
    return CustomerApproval(
      id: json.uuid('id'),
      orderId: json.uuid('order_id'),
      type: json.choice('type', ApprovalType.tryParse),
      status: json.choice('status', ApprovalStatus.tryParse),
    );
  }

  static final RegExp _billed = RegExp(r'^\d{1,4}(\.\d{3})?$');

  static ProductNames? _names(Object? raw, String what) {
    if (raw == null) {
      return null;
    }
    final JsonFields json = JsonFields.of(raw, what);
    return ProductNames(
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
    );
  }

  static CustomerQuestion _question(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'pending approval');
    final String? proposed = json.nullableString('proposed_quantity');
    if (proposed != null &&
        (!_quantity.hasMatch(proposed) ||
            QuantityRules.thousandths(proposed) == 0)) {
      throw FormatException('proposed_quantity is not in its form: $proposed');
    }
    final Object? replacement = json.member('replacement');
    final CustomerQuestion question = CustomerQuestion(
      id: json.uuid('id'),
      type: json.choice('type', ApprovalType.tryParse),
      proposedCustomerUnitPriceUzs: _nullableAmount(
        json,
        'proposed_customer_unit_price_uzs',
      ),
      proposedQuantity: proposed,
      replacement: _names(replacement, 'replacement'),
      requestNote: json.nullableString('request_note'),
      expiresAt: json.instant('expires_at'),
    );
    // The proposal each type carries, as the table holds it (`docs/08`
    // section 15); a replacement carries the proposed price as its own, so
    // a quantity question, which proposes no price, has none.
    if (replacement != null &&
        JsonFields.of(
              replacement,
              'replacement',
            ).integer('customer_unit_price_uzs') !=
            question.proposedCustomerUnitPriceUzs) {
      throw const FormatException('a replacement at another price');
    }
    final bool price = question.proposedCustomerUnitPriceUzs != null;
    final bool proposal = switch (question.type) {
      ApprovalType.priceOverTolerance =>
        price && question.proposedQuantity == null,
      ApprovalType.substitution =>
        price &&
            question.replacement != null &&
            question.proposedQuantity == null,
      ApprovalType.reducedQuantity =>
        question.proposedQuantity != null && !price,
    };
    if (!proposal) {
      throw const FormatException('a question off the contract');
    }
    return question;
  }

  static CustomerOrderLine _line(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'order line');
    final String quantity = json.string('quantity');
    if (!_quantity.hasMatch(quantity) ||
        QuantityRules.thousandths(quantity) == 0) {
      throw FormatException('quantity is not in its form: $quantity');
    }
    final String? removed = json.nullableString('removed_reason_code');
    final String? billed = json.nullableString('billable_quantity');
    if (billed != null && !_billed.hasMatch(billed)) {
      throw FormatException('billable_quantity is not in its form: $billed');
    }
    final Object? question = json.member('pending_approval');
    final CustomerOrderLine line = CustomerOrderLine(
      id: json.uuid('id'),
      productId: json.uuid('product_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      unit: json.choice('unit_code', UnitCode.tryParse),
      priceMode: json.choice('price_mode', PriceMode.tryParse),
      quantity: quantity,
      customerNote: json.nullableString('customer_note'),
      substitutionPolicy: json.choice(
        'substitution_policy',
        SubstitutionPolicy.tryParse,
      ),
      status: json.choice('status', OrderItemStatus.tryParse),
      customerUnitPriceUzs: _amount(json, 'customer_unit_price_uzs'),
      lineTotalUzs: _amount(json, 'line_total_uzs'),
      removedReason: removed == null
          ? null
          : json.choice('removed_reason_code', ItemRemovedReason.tryParse),
      billableQuantity: billed,
      billableUnitPriceUzs: _nullableAmount(json, 'billable_unit_price_uzs'),
      replacement: _names(json.member('replacement'), 'replacement'),
      question: question == null ? null : _question(question),
    );
    final bool open =
        line.status == OrderItemStatus.pending ||
        line.status == OrderItemStatus.awaitingCustomer;
    final bool bought = line.status == OrderItemStatus.purchased;
    // As the resource writes a line (`docs/09` section 20): billed nothing
    // while open, billed at its price once bought, nothing replaced once
    // removed, and a question only on a line waiting for the Customer.
    if (line.removed != (line.removedReason != null) ||
        open != (line.billableQuantity == null) ||
        bought != (line.billableUnitPriceUzs != null) ||
        (bought && QuantityRules.thousandths(line.billableQuantity!) == 0) ||
        (line.removed && line.replacement != null) ||
        (line.question != null &&
            line.status != OrderItemStatus.awaitingCustomer)) {
      throw const FormatException('a line off the contract');
    }
    return line;
  }
}

class CustomerOrdersRepositoryImpl implements CustomerOrdersRepository {
  CustomerOrdersRepositoryImpl(this._api);

  final CustomerOrdersApi _api;

  @override
  Future<Paged<OrderSummary>> orders(int page) =>
      guardApiCall(() => _api.orders(page));

  @override
  Future<CustomerOrder> order(String id) => guardApiCall(() => _api.order(id));

  @override
  Future<CustomerOrder> edit(
    String id,
    List<OrderEditLine> lines,
    String? deliveryTimeNote,
  ) => guardApiCall(() => _api.edit(id, lines, deliveryTimeNote));

  @override
  Future<CustomerApproval> decide(
    String orderId,
    String approvalId,
    ApprovalDecision decision,
    String idempotencyKey,
  ) => guardApiCall(
    () => _api.decide(orderId, approvalId, decision, idempotencyKey),
  );

  @override
  Future<CustomerOrder> cancel(
    String id,
    String? reason,
    String idempotencyKey,
  ) => guardApiCall(() => _api.cancel(id, reason, idempotencyKey));
}
