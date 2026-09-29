import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/platform/map_links.dart';
import 'package:baraka_bozor/features/courier/data/courier_orders_api.dart';
import 'package:baraka_bozor/features/courier/domain/courier_orders.dart';

const String courierOrderA = '0192f0a0-0000-7000-8000-00000000e001';
const String courierOrderB = '0192f0a0-0000-7000-8000-00000000e002';
const String courierAssignment = '0192f0a0-0000-7000-8000-00000000e011';

/// The Courier's assignment, assigned at 09:00 and, as asked, accepted at
/// 09:05 and set off at 09:10, late after 10:10.
Map<String, Object?> courierAssignmentJson({
  bool accepted = false,
  bool started = false,
}) => <String, Object?>{
  'id': courierAssignment,
  'assigned_at': '2026-09-28T09:00:00Z',
  'accepted_at': accepted || started ? '2026-09-28T09:05:00Z' : null,
  'delivery_started_at': started ? '2026-09-28T09:10:00Z' : null,
  'delay_at': started ? '2026-09-28T10:10:00Z' : null,
};

/// A delivery as `docs/09` section 36 answers it: to Dilnoza at Amir Temur
/// 12, cash 55 600. [status] `delivery_assigned` holds it unaccepted unless
/// [accepted]; `on_the_way` has it set off. [ended] is how every answer of
/// delivered and not delivered reads (`DL-64` (7)); [shopperPhone], when
/// given, is there as without a handoff point.
Map<String, Object?> courierOrderJson({
  String id = courierOrderA,
  int number = 1001,
  String status = 'delivery_assigned',
  bool accepted = false,
  bool pending = false,
  bool cash = true,
  bool ended = false,
  Object? shopperPhone = _absent,
}) {
  // An outcome needs a delivery that set off.
  final bool started = status == 'on_the_way' || ended;
  final bool isAccepted = accepted || started;
  final bool held = !ended;
  return <String, Object?>{
    'id': id,
    'order_number': number,
    'status': status,
    'recipient': held
        ? <String, Object?>{
            'full_name': 'Dilnoza Karimova',
            'phone': '+998901234567',
          }
        : null,
    'address': held
        ? <String, Object?>{
            'latitude': '41.311081',
            'longitude': '69.240562',
            'street': 'Amir Temur',
            'house': '12',
            'apartment': '34',
            'landmark': 'Maktab qarshisida',
          }
        : null,
    'delivery_note': held ? 'Podyezdda qo\'ng\'iroq qiling' : null,
    'delivery_time_note': held ? 'Kechqurun' : null,
    'payment_method': cash ? 'cash' : 'online',
    'amount_to_collect_uzs': cash ? 55600 : null,
    'cancellation_request_pending': pending,
    'assignment': courierAssignmentJson(accepted: isAccepted, started: started),
    'can_accept': !isAccepted,
    'can_start':
        isAccepted && !started && status == 'delivery_assigned' && !pending,
    if (!identical(shopperPhone, _absent) && held)
      'shopper_phone': shopperPhone,
  };
}

const Object _absent = Object();

CourierOrder courierOrder({
  String id = courierOrderA,
  int number = 1001,
  String status = 'delivery_assigned',
  bool accepted = false,
  bool pending = false,
  bool cash = true,
  bool ended = false,
  Object? shopperPhone = _absent,
}) => CourierOrdersApi.parseOrder(
  courierOrderJson(
    id: id,
    number: number,
    status: status,
    accepted: accepted,
    pending: pending,
    cash: cash,
    ended: ended,
    shopperPhone: shopperPhone,
  ),
);

/// The Courier's deliveries in memory, from the contract's JSON through the
/// real parser. Every load and action is recorded; [hold], when set, holds
/// every answer.
class FakeCourierOrdersRepository implements CourierOrdersRepository {
  FakeCourierOrdersRepository({Map<String, CourierOrder>? details})
    : details = details ?? <String, CourierOrder>{};

  /// The deliveries the Courier holds, by id; the list shows them in order.
  Map<String, CourierOrder> details;

  final List<String> loads = <String>[];

  /// `accept:<order>`, `start:<order>`, `delivered:<order>:<cash>` and
  /// `not-delivered:<order>:<reason>:<note>`.
  final List<String> actions = <String>[];

  /// The key each handover was sent with, in order.
  final List<String> keys = <String>[];

  /// The order each action answers. An answer that ended the assignment
  /// takes the order off the Courier's list, as the server's does.
  final Map<String, CourierOrder> afterAction = <String, CourierOrder>{};

  Completer<void>? hold;
  ApiFailure? listFailure;
  ApiFailure? orderFailure;

  /// Every action fails with it until the test clears it.
  ApiFailure? actionFailure;

  Future<void> _held() async {
    final Completer<void>? hold = this.hold;
    if (hold != null) {
      await hold.future;
    }
  }

  @override
  Future<Paged<CourierOrder>> orders(int page) async {
    loads.add('orders:$page');
    await _held();
    if (listFailure != null) {
      throw listFailure!;
    }
    final List<CourierOrder> items = page == 1
        ? details.values.toList()
        : <CourierOrder>[];
    return Paged<CourierOrder>(
      items: items,
      page: page,
      perPage: 20,
      total: items.length,
      lastPage: 1,
    );
  }

  @override
  Future<CourierOrder> order(String id) async {
    loads.add('order:$id');
    await _held();
    if (orderFailure != null) {
      throw orderFailure!;
    }
    final CourierOrder? order = details[id];
    if (order == null) {
      throw const ApiRefusal(ApiError(status: 404, code: 'resource_not_found'));
    }
    return order;
  }

  @override
  Future<CourierOrder> accept(String id) => _act(id, 'accept:$id');

  @override
  Future<CourierOrder> start(String id) => _act(id, 'start:$id');

  @override
  Future<CourierOrder> delivered(
    String id,
    int? cashReceivedUzs,
    String idempotencyKey,
  ) {
    keys.add(idempotencyKey);
    return _act(id, 'delivered:$id:$cashReceivedUzs');
  }

  @override
  Future<CourierOrder> notDelivered(
    String id,
    DeliveryFailureReason reason,
    String? note,
  ) => _act(id, 'not-delivered:$id:${reason.code}:$note');

  Future<CourierOrder> _act(String id, String action) async {
    actions.add(action);
    await _held();
    if (actionFailure != null) {
      throw actionFailure!;
    }
    final CourierOrder order = afterAction[id]!;
    if (order.held) {
      details[id] = order;
    } else {
      details.remove(id);
    }
    return order;
  }
}

/// A map app that records each point and answers [opens].
class FakeMapLinks implements MapLinks {
  final List<String> opened = <String>[];
  bool opens = true;

  @override
  Future<bool> open(String latitude, String longitude) async {
    opened.add('$latitude,$longitude');
    return opens;
  }
}
