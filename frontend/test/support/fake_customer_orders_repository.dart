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
  'image_url': null,
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
  'agreed': null,
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
              'image_url': 'https://cdn.example/cherry.webp',
            }
          : null,
      'request_note': 'Qizili qolmadi',
      'expires_at': '2026-09-28T08:00:00Z',
      'estimate_if_approved_uzs': 25300,
      'change_if_approved_uzs': 5300,
      'change_if_rejected_uzs': -20000,
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
  String? cancellationNote,
  String? cancellationRequest,
  bool canRequestCancellation = false,
  Map<String, Object?>? payment,
  Map<String, Object?>? courier,
  String? supportPhone,
  Map<String, Object?>? rating,
  bool canRate = false,
  String requestReason = 'Kerak emas',
  Map<String, Object?>? totals,
  Map<String, Object?>? address,
  Map<String, Object?>? timestamps,
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
    'rating': rating,
    'can_rate': canRate,
    'courier': courier,
    'support_phone': supportPhone,
    'cancellation_request': cancellationRequest == null
        ? null
        : <String, Object?>{
            'id': '0192f0a0-0000-7000-8000-00000000cc01',
            'status': cancellationRequest,
            'reason': requestReason,
            'created_at': '2026-09-28T08:00:00Z',
            'resolved_at': cancellationRequest == 'pending'
                ? null
                : '2026-09-28T08:30:00Z',
          },
    'items': items,
    'totals':
        totals ??
        (cancelled
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
              }),
    'address': <String, Object?>{
      'latitude': '41.311081',
      'longitude': '69.240562',
      'street': 'Amir Temur',
      'house': '12',
      'apartment': '34',
      'landmark': null,
      'delivery_note': null,
      ...?address,
    },
    'cancellation_reason_code': cancelled
        ? (cancellationReason ?? 'customer_cancelled')
        : null,
    'cancellation_note': cancellationNote,
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
      ...?timestamps,
    },
  };
}

Map<String, Object?> orderSummaryJson({
  String id = orderOne,
  int number = 1001,
  String status = 'new',
  int waiting = 0,
  String? courierPhone,
  String? imageUrl,
  int? ratingStars,
  bool canRate = false,
  int itemCount = 2,
  String street = 'Amir Temur',
  String house = '12',
  int? totalUzs,
  String totalKind = 'estimate',
  String createdAt = '2026-09-28T07:00:00Z',
  List<String>? deadlines,
  int? previewCount,
  List<Map<String, Object?>>? previewLines,
}) {
  final int count = previewCount ?? itemCount;
  final List<Map<String, Object?>> shown =
      previewLines ??
      <Map<String, Object?>>[
        for (final (String, String) names in const <(String, String)>[
          ('Pomidor', 'Помидоры'),
          ('Sut', 'Молоко домашнее'),
          ('Non', 'Лепёшка'),
          ('Tuxum', 'Яйца домашние'),
        ].take(count < 4 ? count : 4))
          <String, Object?>{
            'name_uz': names.$1,
            'name_ru': names.$2,
            'image_url': null,
          },
      ];
  return <String, Object?>{
    'id': id,
    'order_number': number,
    'status': status,
    'payment_method': 'cash',
    'item_count': itemCount,
    'pending_approval_count': waiting,
    'total_uzs': status == 'cancelled' ? null : (totalUzs ?? 55600),
    'total_kind': status == 'cancelled' ? 'none' : totalKind,
    'address': <String, Object?>{'street': street, 'house': house},
    'courier_phone': courierPhone,
    'image_url': imageUrl,
    'rating_stars': ratingStars,
    'can_rate': canRate,
    'created_at': createdAt,
    'pending_approval_expires_at':
        deadlines ?? List<String>.filled(waiting, '2026-09-28T07:10:00Z'),
    'preview': <String, Object?>{'line_count': count, 'lines': shown},
  };
}

/// The edit preview as `docs/09` section 21 answers it (`DL-132`): the
/// defaults are the sums of [customerOrderJson], unchanged.
Map<String, Object?> editPreviewJson({
  int merchandise = 35600,
  int serviceFee = 5000,
  int deliveryFee = 15000,
  int? total,
  String kind = 'estimate',
  int before = 55600,
  int? change,
  int? minimum = 30000,
  int shortfall = 0,
}) {
  final int sum = total ?? merchandise + serviceFee + deliveryFee;
  return <String, Object?>{
    'merchandise_subtotal_uzs': merchandise,
    'service_fee_uzs': serviceFee,
    'delivery_fee_uzs': deliveryFee,
    'total_uzs': sum,
    'total_kind': kind,
    'total_before_uzs': before,
    'total_change_uzs': change ?? sum - before,
    'minimum_order_uzs': minimum,
    'minimum_order_shortfall_uzs': shortfall,
  };
}

/// The Customer's orders in memory. A change answers with [answer] when set
/// (a test decides what the server says), or fails once with [failure]; an
/// order's load fails once with [loadFailure].
class FakeCustomerOrdersRepository implements CustomerOrdersRepository {
  FakeCustomerOrdersRepository({List<Map<String, Object?>>? orders})
    : rows = orders ?? <Map<String, Object?>>[customerOrderJson()];

  /// The list's page size: the list is cut into pages of it, with a true
  /// `total` and `lastPage`.
  int perPage = 20;

  /// A tab's next list load fails with its failure, once (`DL-131`).
  final Map<OrdersTab, ApiFailure> listFailures = <OrdersTab, ApiFailure>{};

  List<Map<String, Object?>> rows;
  Map<String, Object?>? answer;
  ApiFailure? failure;
  ApiFailure? loadFailure;

  /// Holds an order's load back until the test completes it.
  Completer<void>? loadHold;

  /// Holds the order page's detail reads only, not the answers of the
  /// mutations, until the test completes it.
  Completer<void>? holdOrder;
  Completer<void>? hold;

  /// Holds the list's loads only, until the test completes it.
  Completer<void>? holdList;

  /// Holds the past tab's loads only, until the test completes it.
  Completer<void>? holdPast;

  final List<String> loads = <String>[];
  final List<(String, List<OrderEditLine>, String?)> edits =
      <(String, List<OrderEditLine>, String?)>[];
  final List<(String, String?, String)> cancels = <(String, String?, String)>[];

  /// The approvals list's rows (`docs/09` section 23), as the server sends
  /// them.
  List<Map<String, Object?>> pendingRows = <Map<String, Object?>>[];

  /// When set, the pending questions' load fails with it.
  ApiFailure? pendingFailure;

  /// What a reorder answers (`added_items` and the other three lists), or
  /// an empty result when not set.
  Map<String, Object?>? reorderAnswer;

  /// When set, the next reorder fails with it.
  ApiFailure? reorderFailure;

  /// Every reorder sent: the order and its key.
  final List<(String, String)> reorders = <(String, String)>[];

  /// Every rating sent: the order, the stars, the reason codes, the comment.
  final List<(String, int, List<String>, String?)> ratings =
      <(String, int, List<String>, String?)>[];

  /// When set, the next rating fails with it.
  ApiFailure? rateFailure;

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
    return _read(id);
  }

  /// When set, the list shows these summaries (as `orderSummaryJson` builds
  /// them) instead of one per row, still split by tab.
  List<Map<String, Object?>>? summaries;

  static bool _isPast(String status) =>
      status == 'completed' || status == 'cancelled';

  @override
  Future<Paged<OrderSummary>> orders(OrdersTab tab, int page) async {
    loads.add('orders:${tab.code}:$page');
    await holdList?.future;
    if (tab == OrdersTab.past) {
      await holdPast?.future;
    }
    final ApiFailure? listFailure = listFailures.remove(tab);
    if (listFailure != null) {
      throw listFailure;
    }
    final List<Map<String, Object?>> all =
        summaries ??
        <Map<String, Object?>>[
          for (final Map<String, Object?> row in rows)
            orderSummaryJson(
              id: row['id']! as String,
              status: row['status']! as String,
              waiting: row['pending_approval_count']! as int,
            ),
        ];
    final List<OrderSummary> items = <OrderSummary>[
      for (final Map<String, Object?> json in all)
        if (_isPast(json['status']! as String) == (tab == OrdersTab.past))
          CustomerOrdersApi.parseSummary(json),
    ];
    final int pages = items.isEmpty
        ? 1
        : (items.length + perPage - 1) ~/ perPage;
    return Paged<OrderSummary>(
      items: <OrderSummary>[...items.skip((page - 1) * perPage).take(perPage)],
      page: page,
      perPage: perPage,
      total: items.length,
      lastPage: pages,
    );
  }

  @override
  Future<CustomerOrder> order(String id) async {
    await holdOrder?.future;
    return _read(id);
  }

  Future<CustomerOrder> _read(String id) async {
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

  /// What a preview answers (its json), by order and lines; the order row's
  /// own sums, unchanged, when not set.
  Map<String, Object?> Function(String id, List<OrderEditLine> lines)? previews;

  /// The next preview fails with it, once.
  ApiFailure? previewFailure;

  /// Holds the previews back until the test completes it.
  Completer<void>? holdPreview;

  /// Every preview asked: the order and the lines.
  final List<(String, List<OrderEditLine>)> previewCalls =
      <(String, List<OrderEditLine>)>[];

  @override
  Future<OrderEditPreview> previewEdit(
    String id,
    List<OrderEditLine> lines,
  ) async {
    previewCalls.add((id, lines));
    await holdPreview?.future;
    final ApiFailure? failed = previewFailure;
    if (failed != null) {
      previewFailure = null;
      throw failed;
    }
    final Map<String, Object?> Function(String, List<OrderEditLine>)? custom =
        previews;
    if (custom != null) {
      return CustomerOrdersApi.parsePreview(custom(id, lines));
    }
    for (final Map<String, Object?> row in rows) {
      if (row['id'] == id) {
        return OrderEditPreview.ofOrder(CustomerOrdersApi.parseOrder(row));
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

  @override
  Future<ReorderResult> reorder(String orderId, String idempotencyKey) async {
    reorders.add((orderId, idempotencyKey));
    await hold?.future;
    final ApiFailure? failure = reorderFailure;
    if (failure != null) {
      reorderFailure = null;
      throw failure;
    }
    final Map<String, Object?> answer =
        reorderAnswer ??
        <String, Object?>{
          'added_items': <Object?>[],
          'skipped_existing_items': <Object?>[],
          'unavailable_items': <Object?>[],
          'cart_full_items': <Object?>[],
        };
    return CustomerOrdersApi.parseReorder(answer);
  }

  @override
  Future<CustomerOrder> rate(
    String orderId,
    int stars,
    List<RatingReason> reasons,
    String? comment,
  ) async {
    ratings.add((
      orderId,
      stars,
      <String>[for (final RatingReason reason in reasons) reason.code],
      comment,
    ));
    await hold?.future;
    final ApiFailure? failure = rateFailure;
    if (failure != null) {
      rateFailure = null;
      throw failure;
    }
    return _read(orderId);
  }

  @override
  Future<List<PendingQuestion>> pendingQuestions() async {
    loads.add('pending');
    final ApiFailure? failure = pendingFailure;
    if (failure != null) {
      throw failure;
    }
    return <PendingQuestion>[
      for (final Map<String, Object?> row in pendingRows)
        PendingQuestion(
          approvalId: row['id']! as String,
          orderId: row['order_id']! as String,
          orderNumber: row['order_number']! as int,
          expiresAt: DateTime.parse(row['expires_at']! as String),
        ),
    ];
  }
}
