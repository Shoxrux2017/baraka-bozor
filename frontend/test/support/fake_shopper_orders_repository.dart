import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/platform/phone_calls.dart';
import 'package:baraka_bozor/features/shopper/data/shopper_orders_api.dart';
import 'package:baraka_bozor/features/shopper/domain/shopper_orders.dart';

const String shopperOrderA = '0192f0a0-0000-7000-8000-00000000d001';
const String shopperOrderB = '0192f0a0-0000-7000-8000-00000000d002';
const String shopperAssignment = '0192f0a0-0000-7000-8000-00000000d011';
const String shopperLineTomato = '0192f0a0-0000-7000-8000-00000000d021';
const String shopperLineBread = '0192f0a0-0000-7000-8000-00000000d022';
const String shopperProductTomato = '0192f0a0-0000-7000-8000-00000000d031';
const String shopperProductBread = '0192f0a0-0000-7000-8000-00000000d032';
const String shopperProductCherry = '0192f0a0-0000-7000-8000-00000000d033';
const String shopperQuestion = '0192f0a0-0000-7000-8000-00000000d041';

/// The Shopper's assignment, assigned at 07:05 and, as asked, accepted at
/// 07:06 and started at 07:07.
Map<String, Object?> shopperAssignmentJson({
  bool accepted = false,
  bool started = false,
}) => <String, Object?>{
  'id': shopperAssignment,
  'assigned_at': '2026-09-27T07:05:00Z',
  'accepted_at': accepted || started ? '2026-09-27T07:06:00Z' : null,
  'started_at': started ? '2026-09-27T07:07:00Z' : null,
};

/// A row of the Shopper's list as `docs/09` section 28 answers it.
Map<String, Object?> shopperRowJson({
  String id = shopperOrderA,
  int number = 1001,
  String status = 'shopping_assigned',
  bool accepted = false,
  int items = 2,
  int open = 2,
}) => <String, Object?>{
  'id': id,
  'order_number': number,
  'status': status,
  'item_count': items,
  'open_item_count': open,
  'delivery_time_note': 'Kechqurun',
  'assignment': shopperAssignmentJson(
    accepted: accepted,
    started: status == 'shopping',
  ),
};

/// A line as the Shopper sees it: tomatoes, 2 kg, an estimate at 16 000 with
/// a bound of 18 400 on the market; or [bread], a fixed loaf.
Map<String, Object?> shopperLineJson({
  bool bread = false,
  String status = 'pending',
  Map<String, Object?>? patch,
}) => <String, Object?>{
  'id': bread ? shopperLineBread : shopperLineTomato,
  'product_id': bread ? shopperProductBread : shopperProductTomato,
  'name_uz': bread ? 'Non' : 'Pomidor',
  'name_ru': bread ? 'Хлеб' : 'Помидоры',
  'unit_code': bread ? 'piece' : 'kg',
  'price_mode': bread ? 'fixed' : 'estimate',
  'quantity': bread ? '2' : '2.000',
  'approved_quantity_cap': null,
  'customer_note': bread ? null : 'Qizilini oling',
  'substitution_policy': 'allow_similar_substitution',
  'status': status,
  'market_price_uzs': bread ? 4000 : 16000,
  'customer_unit_price_uzs': bread ? 4000 : 18400,
  'bound': bread
      ? null
      : <String, Object?>{
          'customer_unit_price_uzs': 21160,
          'market_price_uzs': 18400,
        },
  'replacement': null,
  'purchase': status == 'purchased'
      ? <String, Object?>{
          'product_id': bread ? shopperProductBread : shopperProductTomato,
          'purchased_quantity': bread ? '2' : '2.000',
          'billable_quantity': bread ? '2' : '2.000',
          'actual_market_price_uzs': bread ? null : 16500,
          'billable_unit_price_uzs': bread ? 4000 : 18975,
          'line_total_uzs': bread ? 8000 : 37950,
        }
      : null,
  'removed_reason_code': status == 'removed' ? 'unavailable' : null,
  'pending_approval': null,
  ...?patch,
};

/// The order as `docs/09` section 28 answers it: assigned and not accepted
/// unless [accepted], or [status] `shopping` with the Customer's phone.
Map<String, Object?> shopperOrderJson({
  String id = shopperOrderA,
  String status = 'shopping_assigned',
  bool accepted = false,
  List<Object?>? items,
}) {
  final bool shopping = status == 'shopping';
  final bool isAccepted = accepted || shopping;
  return <String, Object?>{
    'id': id,
    'order_number': 1001,
    'status': status,
    'delivery_time_note': 'Kechqurun',
    'customer_phone': shopping ? '+998901112233' : null,
    'assignment': shopperAssignmentJson(
      accepted: isAccepted,
      started: shopping,
    ),
    'can_accept': !isAccepted,
    'can_start': isAccepted && !shopping,
    'items':
        items ?? <Object?>[shopperLineJson(), shopperLineJson(bread: true)],
  };
}

ShopperOrder shopperOrder({
  String id = shopperOrderA,
  String status = 'shopping_assigned',
  bool accepted = false,
  List<Object?>? items,
}) => ShopperOrdersApi.parseOrder(
  shopperOrderJson(id: id, status: status, accepted: accepted, items: items),
);

/// The Shopper's orders in memory, from the contract's JSON through the
/// real parser. Every load and action is recorded; [hold], when set, holds
/// every answer, and [holdOrder] an order's alone.
class FakeShopperOrdersRepository implements ShopperOrdersRepository {
  FakeShopperOrdersRepository({
    List<ShopperOrderRow>? rows,
    Map<String, ShopperOrder>? details,
  }) : rows = rows ?? <ShopperOrderRow>[],
       details = details ?? <String, ShopperOrder>{};

  List<ShopperOrderRow> rows;
  Map<String, ShopperOrder> details;

  final List<String> loads = <String>[];

  /// `accept:<order>` and `start:<order>`.
  final List<String> actions = <String>[];

  /// The order each action answers, which also becomes its detail.
  final Map<String, ShopperOrder> afterAction = <String, ShopperOrder>{};

  Completer<void>? hold;
  Completer<void>? holdOrder;
  ApiFailure? listFailure;
  ApiFailure? orderFailure;
  ApiFailure? actionFailure;

  Future<void> _held() async {
    final Completer<void>? hold = this.hold;
    if (hold != null) {
      await hold.future;
    }
  }

  @override
  Future<Paged<ShopperOrderRow>> orders(int page) async {
    loads.add('orders:$page');
    await _held();
    if (listFailure != null) {
      throw listFailure!;
    }
    return Paged<ShopperOrderRow>(
      items: rows,
      page: page,
      perPage: 20,
      total: rows.length,
      lastPage: 1,
    );
  }

  @override
  Future<ShopperOrder> order(String id) async {
    loads.add('order:$id');
    await _held();
    final Completer<void>? holdOrder = this.holdOrder;
    if (holdOrder != null) {
      await holdOrder.future;
    }
    if (orderFailure != null) {
      throw orderFailure!;
    }
    final ShopperOrder? order = details[id];
    if (order == null) {
      throw const ApiRefusal(ApiError(status: 404, code: 'resource_not_found'));
    }
    return order;
  }

  @override
  Future<ShopperOrder> accept(String id) => _act(id, 'accept:$id');

  @override
  Future<ShopperOrder> start(String id) => _act(id, 'start:$id');

  Future<ShopperOrder> _act(String id, String action) async {
    actions.add(action);
    await _held();
    if (actionFailure != null) {
      throw actionFailure!;
    }
    final ShopperOrder order = afterAction[id]!;
    details[id] = order;
    return order;
  }
}

/// A dialer that records each number and answers [opens].
class FakePhoneCalls implements PhoneCalls {
  final List<String> calls = <String>[];
  bool opens = true;

  @override
  Future<bool> call(String phone) async {
    calls.add(phone);
    return opens;
  }
}
