import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';

const String orderOne = '0192f0a0-0000-7000-8000-00000000c001';
const String lineTomato = '0192f0a0-0000-7000-8000-00000000c011';
const String lineBread = '0192f0a0-0000-7000-8000-00000000c012';
const String lineMilk = '0192f0a0-0000-7000-8000-00000000c013';
const String productTomato = '0192f0a0-0000-7000-8000-00000000c021';
const String productBread = '0192f0a0-0000-7000-8000-00000000c022';
const String productMilk = '0192f0a0-0000-7000-8000-00000000c023';
const String approvalOne = '0192f0a0-0000-7000-8000-00000000c031';

/// An order line as `docs/09` section 20 answers it.
Map<String, Object?> orderLineJson({
  String id = lineTomato,
  String productId = productTomato,
  String unit = 'kg',
  String quantity = '1.500',
  String status = 'pending',
  String? removedReason,
  String? note,
  Map<String, Object?>? patch,
}) => <String, Object?>{
  'id': id,
  'product_id': productId,
  'name_uz': unit == 'kg' ? 'Pomidor' : 'Non',
  'name_ru': unit == 'kg' ? 'Помидоры' : 'Хлеб',
  'unit_code': unit,
  'price_mode': unit == 'kg' ? 'estimate' : 'fixed',
  'quantity': quantity,
  'customer_note': note,
  'substitution_policy': 'allow_similar_substitution',
  'status': status,
  'customer_unit_price_uzs': unit == 'kg' ? 18400 : 4000,
  'line_total_uzs': switch (status) {
    'removed' => 0,
    // 1.500 kg at 18 975, rounded half up.
    'purchased' => unit == 'kg' ? 28463 : 8000,
    _ => unit == 'kg' ? 27600 : 8000,
  },
  'billable_quantity': switch (status) {
    'removed' => '0',
    'purchased' => quantity,
    _ => null,
  },
  'removed_reason_code': removedReason,
  'billable_unit_price_uzs': status == 'purchased'
      ? (unit == 'kg' ? 18975 : 4000)
      : null,
  'replacement': null,
  'pending_approval': null,
  ...?patch,
};

/// The tomato line waiting on a question of [type]: a higher price, a
/// replacement, or a smaller quantity.
Map<String, Object?> questionLineJson(String type) => orderLineJson(
  status: 'awaiting_customer',
  patch: <String, Object?>{
    'pending_approval': <String, Object?>{
      'id': approvalOne,
      'type': type,
      'proposed_customer_unit_price_uzs': type == 'reduced_quantity'
          ? null
          : 21850,
      'proposed_quantity': type == 'reduced_quantity' ? '1.000' : null,
      'replacement': type == 'substitution'
          ? <String, Object?>{
              'name_uz': 'Olcha pomidor',
              'name_ru': 'Помидоры черри',
              'customer_unit_price_uzs': 21850,
            }
          : null,
      'request_note': 'Qizili qolmadi',
      'expires_at': '2026-09-28T08:00:00Z',
    },
  },
);

/// The Customer's order as `docs/09` section 20 answers it.
Map<String, Object?> customerOrderJson({
  String id = orderOne,
  String status = 'new',
  bool changeable = true,
  List<Object?>? lines,
  String? note = 'Kechqurun',
  String? cancellationReason,
  String? cancellationRequest,
  bool canRequestCancellation = false,
  Map<String, Object?>? payment,
}) {
  final bool cancelled = status == 'cancelled';
  final List<Object?> items =
      lines ??
      <Object?>[
        orderLineJson(),
        orderLineJson(
          id: lineBread,
          productId: productBread,
          unit: 'piece',
          quantity: '2',
        ),
      ];
  return <String, Object?>{
    'id': id,
    'order_number': 1001,
    'status': status,
    'payment_method': 'cash',
    'delivery_time_note': note,
    'pending_approval_count': items
        .where(
          (Object? line) =>
              (line! as Map<String, Object?>)['pending_approval'] != null,
        )
        .length,
    'can_edit': changeable,
    'can_cancel_directly': changeable,
    'can_request_cancellation': canRequestCancellation,
    'cancellation_request': cancellationRequest == null
        ? null
        : <String, Object?>{
            'id': '0192f0a0-0000-7000-8000-00000000cc01',
            'status': cancellationRequest,
            'reason': 'Kerak emas',
            'created_at': '2026-09-28T08:00:00Z',
            'resolved_at': cancellationRequest == 'pending'
                ? null
                : '2026-09-28T08:30:00Z',
          },
    'items': items,
    'totals': cancelled
        ? <String, Object?>{
            'merchandise_subtotal_uzs': null,
            'service_fee_uzs': null,
            'delivery_fee_uzs': null,
            'total_uzs': null,
            'total_kind': 'none',
          }
        : <String, Object?>{
            'merchandise_subtotal_uzs': 35600,
            'service_fee_uzs': 5000,
            'delivery_fee_uzs': 15000,
            'total_uzs': 55600,
            'total_kind': 'estimate',
          },
    'address': <String, Object?>{
      'latitude': '41.311081',
      'longitude': '69.240562',
      'street': 'Amir Temur',
      'house': '12',
      'apartment': '34',
      'landmark': null,
      'delivery_note': null,
    },
    'cancellation_reason_code': cancelled
        ? (cancellationReason ?? 'customer_cancelled')
        : null,
    'payment': payment,
    'refunds': <Object?>[],
    'timestamps': <String, Object?>{
      'created_at': '2026-09-28T07:00:00Z',
      'shopping_started_at': null,
      'shopping_completed_at': null,
      'ready_for_delivery_at': null,
      'on_the_way_at': null,
      'completed_at': null,
      'cancelled_at': cancelled ? '2026-09-28T08:00:00Z' : null,
    },
  };
}

Map<String, Object?> orderSummaryJson({
  String id = orderOne,
  int number = 1001,
  String status = 'new',
  int waiting = 0,
}) => <String, Object?>{
  'id': id,
  'order_number': number,
  'status': status,
  'payment_method': 'cash',
  'item_count': 2,
  'pending_approval_count': waiting,
  'total_uzs': status == 'cancelled' ? null : 55600,
  'total_kind': status == 'cancelled' ? 'none' : 'estimate',
  'created_at': '2026-09-28T07:00:00Z',
};

/// The Customer's orders in memory. A change answers with [answer] when set
/// (a test decides what the server says), or fails once with [failure]; an
/// order's load fails once with [loadFailure].
class FakeCustomerOrdersRepository implements CustomerOrdersRepository {
  FakeCustomerOrdersRepository({List<Map<String, Object?>>? orders})
    : rows = orders ?? <Map<String, Object?>>[customerOrderJson()];

  List<Map<String, Object?>> rows;
  Map<String, Object?>? answer;
  ApiFailure? failure;
  ApiFailure? loadFailure;

  /// Holds an order's load back until the test completes it.
  Completer<void>? loadHold;
  Completer<void>? hold;

  final List<String> loads = <String>[];
  final List<(String, List<OrderEditLine>, String?)> edits =
      <(String, List<OrderEditLine>, String?)>[];
  final List<(String, String?, String)> cancels = <(String, String?, String)>[];

  Future<CustomerOrder> _answer(String id) async {
    await hold?.future;
    final ApiFailure? failure = this.failure;
    if (failure != null) {
      this.failure = null;
      throw failure;
    }
    final Map<String, Object?>? next = answer;
    if (next != null) {
      answer = null;
      rows = <Map<String, Object?>>[
        for (final Map<String, Object?> row in rows)
          if (row['id'] == id) next else row,
      ];
    }
    return order(id);
  }

  @override
  Future<Paged<OrderSummary>> orders(int page) async {
    loads.add('orders:$page');
    return Paged<OrderSummary>(
      items: <OrderSummary>[
        for (final Map<String, Object?> row in rows)
          CustomerOrdersApi.parseSummary(
            orderSummaryJson(
              id: row['id']! as String,
              status: row['status']! as String,
              waiting: row['pending_approval_count']! as int,
            ),
          ),
      ],
      page: page,
      perPage: 20,
      total: rows.length,
      lastPage: 1,
    );
  }

  @override
  Future<CustomerOrder> order(String id) async {
    loads.add('order:$id');
    await loadHold?.future;
    final ApiFailure? failure = loadFailure;
    if (failure != null) {
      loadFailure = null;
      throw failure;
    }
    for (final Map<String, Object?> row in rows) {
      if (row['id'] == id) {
        return CustomerOrdersApi.parseOrder(row);
      }
    }
    throw const ApiRefusal(ApiError(status: 404, code: 'resource_not_found'));
  }

  @override
  Future<CustomerOrder> edit(
    String id,
    List<OrderEditLine> lines,
    String? deliveryTimeNote,
  ) {
    edits.add((id, lines, deliveryTimeNote));
    return _answer(id);
  }

  @override
  Future<CustomerOrder> cancel(
    String id,
    String? reason,
    String idempotencyKey,
  ) {
    cancels.add((id, reason, idempotencyKey));
    return _answer(id);
  }

  /// Every decision sent: the question, the decision and its key.
  final List<(String, ApprovalDecision, String)> decisions =
      <(String, ApprovalDecision, String)>[];

  /// When set, every decision fails with it, until the test clears it.
  ApiFailure? decisionFailure;

  /// The order a decision leaves, which becomes the order's row: also when
  /// it is refused, as an expiry stands although the decision is refused.
  Map<String, Object?>? afterDecision;

  @override
  Future<CustomerApproval> decide(
    String orderId,
    String approvalId,
    ApprovalDecision decision,
    String idempotencyKey,
  ) async {
    decisions.add((approvalId, decision, idempotencyKey));
    await hold?.future;
    final Map<String, Object?>? next = afterDecision;
    if (next != null) {
      rows = <Map<String, Object?>>[
        for (final Map<String, Object?> row in rows)
          if (row['id'] == orderId) next else row,
      ];
    }
    final ApiFailure? failure = decisionFailure;
    if (failure != null) {
      throw failure;
    }
    return CustomerApproval(
      id: approvalId,
      orderId: orderId,
      type: ApprovalType.priceOverTolerance,
      status: decision == ApprovalDecision.approve
          ? ApprovalStatus.approved
          : ApprovalStatus.rejected,
    );
  }
}
