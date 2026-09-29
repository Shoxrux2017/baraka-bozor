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
const String courierId = '0192f0a0-0000-7000-8000-0000000000c7';
const String otherCourierId = '0192f0a0-0000-7000-8000-0000000000c8';
const String courierAssignmentId = '0192f0a0-0000-7000-8000-0000000000a7';
const String approvalId = '0192f0a0-0000-7000-8000-0000000000a9';
const String requestId = '0192f0a0-0000-7000-8000-0000000000aa';
const String paymentId = '0192f0a0-0000-7000-8000-0000000000ab';
const String replacementId = '0192f0a0-0000-7000-8000-0000000000f3';

Map<String, Object?> rowJson({
  String id = orderA,
  int number = 1001,
  String status = 'shopping_assigned',
  String paymentMethod = 'cash',
  String createdAt = '2026-09-27T07:00:00Z',
  int? totalUzs = 75200,
  String totalKind = 'estimate',
  String? shopper = shopperId,
  String? courier,
  bool selfOrder = false,
  int pendingApprovals = 0,
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
  'pending_approval_count': pendingApprovals,
  'total_uzs': totalUzs,
  'total_kind': totalKind,
  'shopper': shopper == null
      ? null
      : <String, Object?>{'id': shopper, 'full_name': 'Sardor Yusupov'},
  'courier': courier == null
      ? null
      : <String, Object?>{'id': courier, 'full_name': 'Kamol Karimov'},
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
  'courier': null,
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

Map<String, Object?> courierChoiceJson({
  String id = courierId,
  String fullName = 'Kamol Karimov',
}) => <String, Object?>{
  'id': id,
  'full_name': fullName,
  'phone': '+998905554433',
  'current_assignment_count': 2,
};

Map<String, Object?> courierAssignmentJson({
  String id = courierAssignmentId,
  String courier = courierId,
  String fullName = 'Kamol Karimov',
  bool selfOrder = false,
  String? acceptedAt,
  String? startedAt,
  String? endedAt,
  String? endedReason,
  String? failedReason,
  String? failedNote,
}) => <String, Object?>{
  'id': id,
  'courier': <String, Object?>{
    'id': courier,
    'full_name': fullName,
    'phone': '+998905554433',
  },
  'assigned_by': <String, Object?>{'id': operatorId, 'full_name': 'Olim'},
  'is_self_order': selfOrder,
  'assigned_at': '2026-09-27T09:00:00Z',
  'accepted_at': acceptedAt,
  'delivery_started_at': startedAt,
  'delay_at': startedAt == null ? null : '2026-09-27T10:30:00Z',
  'completed_at': endedReason == 'completed' ? endedAt : null,
  'ended_at': endedAt,
  'ended_reason': endedReason,
  'failed_reason_code': failedReason,
  'failed_note': failedNote,
};

/// A line as the board's order shows it. A bought line is billed from the
/// price paid: 3 kg at 16 000, billed at 18 400, unless [purchase] says
/// otherwise.
Map<String, Object?> itemJson({
  String status = 'pending',
  String? removedReason,
  String priceMode = 'estimate',
  Map<String, Object?>? purchase,
  bool replaced = false,
}) => <String, Object?>{
  'id': itemId,
  'product_id': productId,
  'name_uz': 'Pomidor',
  'name_ru': 'Помидоры',
  'unit_code': 'kg',
  'price_mode': priceMode,
  'quantity': '3.000',
  'customer_note': 'Qizilini oling',
  'substitution_policy': 'allow_similar_substitution',
  'status': status,
  'market_price_uzs': 16000,
  'customer_unit_price_uzs': 18400,
  'markup_percent': '15.00',
  'line_total_uzs': removedReason == null ? 55200 : 0,
  'removed_reason_code': removedReason,
  'purchased_quantity': status == 'purchased' ? '3.000' : null,
  'billable_quantity': switch (status) {
    'purchased' => '3.000',
    'removed' => '0.000',
    _ => null,
  },
  'actual_market_price_uzs': status == 'purchased' ? 16000 : null,
  'billable_unit_price_uzs': status == 'purchased' ? 18400 : null,
  'replacement': replaced
      ? <String, Object?>{
          'product_id': replacementId,
          'name_uz': 'Olcha pomidor',
          'name_ru': 'Помидоры черри',
          'substitution_resolution': 'automatic',
        }
      : null,
  ...?purchase,
};

/// A question to the Customer about the line of [itemJson]; a price
/// question unless [type] says otherwise, pending unless [status] does.
Map<String, Object?> approvalJson({
  String id = approvalId,
  String type = 'price_over_tolerance',
  String status = 'pending',
  String? resolution,
  bool resolved = false,
}) => <String, Object?>{
  'id': id,
  'item_id': itemId,
  'type': type,
  'status': status,
  'proposed_customer_unit_price_uzs': type == 'reduced_quantity' ? null : 25300,
  'proposed_actual_market_price_uzs': type == 'reduced_quantity' ? null : 22000,
  'proposed_quantity': type == 'reduced_quantity' ? '2.000' : null,
  'replacement': type == 'substitution'
      ? <String, Object?>{
          'product_id': replacementId,
          'name_uz': 'Olcha pomidor',
          'name_ru': 'Помидоры черри',
        }
      : null,
  'request_note': 'Narx oshgan',
  'requested_by': <String, Object?>{
    'id': shopperId,
    'full_name': 'Sardor Yusupov',
  },
  'attention_at': '2026-09-27T07:40:00Z',
  'expires_at': '2026-09-27T08:00:00Z',
  'resolution': resolution,
  'resolved_by': resolved
      ? <String, Object?>{'id': operatorId, 'full_name': 'Olim'}
      : null,
  'resolved_at': resolved || status == 'cancelled'
      ? '2026-09-27T08:05:00Z'
      : null,
  'created_at': '2026-09-27T07:30:00Z',
};

/// The Customer's request to cancel, pending unless [status] says otherwise.
Map<String, Object?> cancellationRequestJson({
  String id = requestId,
  String status = 'pending',
  String? note,
}) => <String, Object?>{
  'id': id,
  'origin': 'customer',
  'status': status,
  'reason': 'Rejalar o\'zgardi',
  'requested_by': <String, Object?>{
    'id': customerId,
    'full_name': 'Aziza Karimova',
  },
  'created_at': '2026-09-27T07:45:00Z',
  'resolved_by': status == 'approved' || status == 'rejected'
      ? <String, Object?>{'id': operatorId, 'full_name': 'Olim'}
      : null,
  'resolved_at': status == 'pending' ? null : '2026-09-27T07:50:00Z',
  'resolution_note': note,
};

/// The cash the Courier took for the order.
Map<String, Object?> paymentJson() => <String, Object?>{
  'id': paymentId,
  'method': 'cash',
  'provider': null,
  'status': 'paid',
  'amount_uzs': 75200,
  'paid_at': '2026-09-27T11:00:00Z',
  'recorded_by': <String, Object?>{
    'id': courierId,
    'full_name': 'Kamol Karimov',
  },
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
  List<Object?>? courierAssignments,
  List<Object?>? approvals,
  List<Object?>? cancellationRequests,
  Map<String, Object?>? payment,
  String paymentMethod = 'cash',
  List<Object?>? history,
  String? cancellationReason,
}) => <String, Object?>{
  'id': id,
  'order_number': 1001,
  'status': status,
  'payment_method': paymentMethod,
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
  'courier_assignments': courierAssignments ?? <Object?>[],
  'approvals': approvals ?? <Object?>[],
  'cancellation_requests': cancellationRequests ?? <Object?>[],
  'payment': payment,
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
