import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/features/orders/data/customer_orders_api.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';

const String orderOne = '0192f0a0-0000-7000-8000-00000000c001';
const String lineTomato = '0192f0a0-0000-7000-8000-00000000c011';
const String lineBread = '0192f0a0-0000-7000-8000-00000000c012';
const String lineMilk = '0192f0a0-0000-7000-8000-00000000c013';
const String productTomato = '0192f0a0-0000-7000-8000-00000000c021';
const String productBread = '0192f0a0-0000-7000-8000-00000000c022';
const String productMilk = '0192f0a0-0000-7000-8000-00000000c023';

/// An order line as `docs/09` section 20 answers it.
Map<String, Object?> orderLineJson({
  String id = lineTomato,
  String productId = productTomato,
  String unit = 'kg',
  String quantity = '1.500',
  String status = 'pending',
  String? removedReason,
  String? note,
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
  'line_total_uzs': status == 'removed' ? 0 : (unit == 'kg' ? 27600 : 8000),
  'billable_quantity': status == 'removed' ? '0' : null,
  'removed_reason_code': removedReason,
};

/// The Customer's order as `docs/09` section 20 answers it.
Map<String, Object?> customerOrderJson({
  String id = orderOne,
  String status = 'new',
  bool changeable = true,
  List<Object?>? lines,
  String? note = 'Kechqurun',
  String? cancellationReason,
}) {
  final bool cancelled = status == 'cancelled';
  return <String, Object?>{
    'id': id,
    'order_number': 1001,
    'status': status,
    'payment_method': 'cash',
    'delivery_time_note': note,
    'pending_approval_count': 0,
    'can_edit': changeable,
    'can_cancel_directly': changeable,
    'can_request_cancellation': false,
    'items':
        lines ??
        <Object?>[
          orderLineJson(),
          orderLineJson(
            id: lineBread,
            productId: productBread,
            unit: 'piece',
            quantity: '2',
          ),
        ],
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
    'payment': null,
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
}) => <String, Object?>{
  'id': id,
  'order_number': number,
  'status': status,
  'payment_method': 'cash',
  'item_count': 2,
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
}
