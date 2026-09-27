/// The board's answers as `docs/09-api-contracts.md` section 38 gives
/// them, for the data-source tests and the fake repository.
library;

const String orderA = '0192f0a0-0000-7000-8000-00000000000a';
const String orderB = '0192f0a0-0000-7000-8000-00000000000b';
const String customerId = '0192f0a0-0000-7000-8000-0000000000c1';
const String shopperId = '0192f0a0-0000-7000-8000-0000000000d1';
const String otherShopperId = '0192f0a0-0000-7000-8000-0000000000d2';
const String operatorId = '0192f0a0-0000-7000-8000-0000000000e1';
const String itemId = '0192f0a0-0000-7000-8000-0000000000f1';
const String productId = '0192f0a0-0000-7000-8000-0000000000f2';
const String assignmentId = '0192f0a0-0000-7000-8000-0000000000a1';
const String historyId = '0192f0a0-0000-7000-8000-0000000000b1';

Map<String, Object?> rowJson({
  String id = orderA,
  int number = 1001,
  String status = 'shopping_assigned',
  String paymentMethod = 'cash',
  String createdAt = '2026-09-27T07:00:00Z',
  int? totalUzs = 75200,
  String totalKind = 'estimate',
  String? shopper = shopperId,
  bool selfOrder = false,
}) => <String, Object?>{
  'id': id,
  'order_number': number,
  'created_at': createdAt,
  'status': status,
  'payment_method': paymentMethod,
  'customer': <String, Object?>{
    'full_name': 'Aziza Karimova',
    'phone': '+998901112233',
  },
  'item_count': 3,
  'total_uzs': totalUzs,
  'total_kind': totalKind,
  'shopper': shopper == null
      ? null
      : <String, Object?>{'id': shopper, 'full_name': 'Sardor Yusupov'},
  'is_self_order': selfOrder,
};

Map<String, Object?> pageJson(
  List<Object?> items, {
  int page = 1,
  int lastPage = 1,
}) => <String, Object?>{
  'data': items,
  'meta': <String, Object?>{
    'pagination': <String, int>{
      'page': page,
      'per_page': 20,
      'total': items.length,
      'last_page': lastPage,
    },
  },
};

Map<String, Object?> summaryJson({int attention = 1}) => <String, Object?>{
  'day': '2026-09-27',
  'open_by_status': <String, int>{
    'new': 2,
    'shopping_assigned': 1,
    'shopping': 0,
    'final_payment_pending': 0,
    'ready_for_delivery': 0,
    'delivery_assigned': 0,
    'on_the_way': 0,
  },
  'completed_today': 4,
  'cancelled_today': 1,
  'sales_today_uzs': 480000,
  'attention_count': attention,
};

Map<String, Object?> attentionJson({
  String order = orderA,
  int number = 1001,
}) => <String, Object?>{
  'type': 'self_order',
  'order_id': order,
  'order_number': number,
  'since': '2026-09-27T07:05:00Z',
  'shopper': <String, Object?>{'id': shopperId, 'full_name': 'Sardor Yusupov'},
};

Map<String, Object?> shopperJson({
  String id = shopperId,
  String fullName = 'Sardor Yusupov',
}) => <String, Object?>{
  'id': id,
  'full_name': fullName,
  'phone': '+998907654321',
  'current_assignment_count': 1,
};

Map<String, Object?> itemJson({
  String status = 'pending',
  String? removedReason,
}) => <String, Object?>{
  'id': itemId,
  'product_id': productId,
  'name_uz': 'Pomidor',
  'name_ru': 'Помидоры',
  'unit_code': 'kg',
  'price_mode': 'estimate',
  'quantity': '3.000',
  'customer_note': 'Qizilini oling',
  'substitution_policy': 'allow_similar_substitution',
  'status': status,
  'market_price_uzs': 16000,
  'customer_unit_price_uzs': 18400,
  'markup_percent': '15.00',
  'line_total_uzs': removedReason == null ? 55200 : 0,
  'removed_reason_code': removedReason,
};

Map<String, Object?> assignmentJson({
  String id = assignmentId,
  String shopper = shopperId,
  bool selfOrder = false,
  String? endedAt,
  String? endedReason,
}) => <String, Object?>{
  'id': id,
  'shopper': <String, Object?>{
    'id': shopper,
    'full_name': 'Sardor Yusupov',
    'phone': '+998907654321',
  },
  'assigned_by': <String, Object?>{'id': operatorId, 'full_name': 'Olim'},
  'is_self_order': selfOrder,
  'assigned_at': '2026-09-27T07:05:00Z',
  'accepted_at': null,
  'started_at': null,
  'completed_at': null,
  'ended_at': endedAt,
  'ended_reason': endedReason,
};

Map<String, Object?> historyJson({
  String event = 'shopper_assigned',
  Object? details = const <String, Object?>{
    'assignment_id': assignmentId,
    'shopper_id': shopperId,
    'is_self_order': false,
  },
  String actorType = 'user',
  bool withActor = true,
}) => <String, Object?>{
  'id': historyId,
  'event_type': event,
  'from_status': 'new',
  'to_status': 'shopping_assigned',
  'actor_type': actorType,
  'actor': withActor
      ? <String, Object?>{
          'id': operatorId,
          'role': 'operator',
          'full_name': 'Olim',
        }
      : null,
  'reason_code': null,
  'note': null,
  'details': details,
  'created_at': '2026-09-27T07:05:00Z',
};

Map<String, Object?> orderJson({
  String id = orderA,
  String status = 'shopping_assigned',
  List<Object?>? items,
  Map<String, Object?>? totals,
  List<Object?>? assignments,
  List<Object?>? history,
  String? cancellationReason,
}) => <String, Object?>{
  'id': id,
  'order_number': 1001,
  'status': status,
  'payment_method': 'cash',
  'delivery_time_note': 'Kechqurun',
  'customer': <String, Object?>{
    'id': customerId,
    'full_name': 'Aziza Karimova',
    'phone': '+998901112233',
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
  'items': items ?? <Object?>[itemJson()],
  'totals':
      totals ??
      <String, Object?>{
        'merchandise_subtotal_uzs': 55200,
        'service_fee_uzs': 5000,
        'delivery_fee_uzs': 15000,
        'total_uzs': 75200,
        'total_kind': 'estimate',
      },
  'shopper_assignments': assignments ?? <Object?>[assignmentJson()],
  'courier_assignments': <Object?>[],
  'approvals': <Object?>[],
  'payment': null,
  'refunds': <Object?>[],
  'history': history ?? <Object?>[historyJson()],
  'cancellation_reason_code': cancellationReason,
  'timestamps': <String, Object?>{
    'created_at': '2026-09-27T07:00:00Z',
    'shopping_started_at': null,
    'shopping_completed_at': null,
    'ready_for_delivery_at': null,
    'on_the_way_at': null,
    'completed_at': null,
    'cancelled_at': status == 'cancelled' ? '2026-09-27T08:00:00Z' : null,
  },
};
