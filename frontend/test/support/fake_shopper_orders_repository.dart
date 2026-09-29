import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
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

/// A product of the replacement search: cherry tomatoes at 15 500.
Map<String, Object?> shopperChoiceJson({
  String id = shopperProductCherry,
  int price = 15500,
}) => <String, Object?>{
  'id': id,
  'name_uz': 'Olcha pomidor',
  'name_ru': 'Помидоры черри',
  'unit_code': 'kg',
  'price_mode': 'estimate',
  'market_price_uzs': price,
  'image_url': null,
};

/// The authorized replacement of the tomato line: cherry tomatoes at
/// 15 500, bound at 18 400 on the market.
Map<String, Object?> shopperReplacementJson({
  String resolution = 'automatic',
}) => <String, Object?>{
  'product_id': shopperProductCherry,
  'name_uz': 'Olcha pomidor',
  'name_ru': 'Помидоры черри',
  'market_price_uzs': 15500,
  'substitution_resolution': resolution,
  'bound': <String, Object?>{
    'customer_unit_price_uzs': 21160,
    'market_price_uzs': 18400,
  },
};

/// The tomato line waiting for the Customer's answer to a question of
/// [type].
Map<String, Object?> shopperAskedLineJson(String type) => shopperLineJson(
  status: 'awaiting_customer',
  patch: <String, Object?>{
    'pending_approval': <String, Object?>{
      'id': shopperQuestion,
      'type': type,
      'expires_at': '2026-09-27T08:00:00Z',
    },
  },
);

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

  /// When set, the rows of each page, [lastPage] the last; otherwise
  /// [rows] are the one page.
  Map<int, List<ShopperOrderRow>>? pages;
  int lastPage = 1;

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
    final Map<int, List<ShopperOrderRow>>? pages = this.pages;
    final List<ShopperOrderRow> items = pages == null
        ? (page == 1 ? rows : <ShopperOrderRow>[])
        : pages[page] ?? <ShopperOrderRow>[];
    return Paged<ShopperOrderRow>(
      items: items,
      page: page,
      perPage: 20,
      total: items.length,
      lastPage: pages == null ? 1 : lastPage,
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

  /// The replacement choices the search answers, whatever it asks.
  List<ReplacementChoice> choices = <ReplacementChoice>[];

  /// The keys each purchase and completion was sent with, in order.
  final List<String> keys = <String>[];

  @override
  Future<ShopperOrder> purchase(
    String orderId,
    String itemId,
    PurchaseEntry entry,
    String idempotencyKey,
  ) {
    keys.add(idempotencyKey);
    return _act(
      orderId,
      'purchase:$itemId:${entry.quantity}:${entry.actualMarketPriceUzs}:'
      '${entry.productId}',
    );
  }

  @override
  Future<ShopperOrder> markUnavailable(
    String orderId,
    String itemId,
    String? note,
  ) => _act(orderId, 'unavailable:$itemId:$note');

  @override
  Future<ShopperOrder> askAboutPrice(
    String orderId,
    String itemId,
    int actualMarketPriceUzs,
    String? productId,
    String? note,
  ) =>
      _act(orderId, 'ask-price:$itemId:$actualMarketPriceUzs:$productId:$note');

  @override
  Future<ShopperOrder> substitute(
    String orderId,
    String itemId,
    String replacementId,
    int actualMarketPriceUzs,
    String? note,
  ) => _act(
    orderId,
    'substitute:$itemId:$replacementId:$actualMarketPriceUzs:$note',
  );

  @override
  Future<ShopperOrder> askAboutQuantity(
    String orderId,
    String itemId,
    String quantity,
    String? note,
  ) => _act(orderId, 'ask-quantity:$itemId:$quantity:$note');

  @override
  Future<Paged<ReplacementChoice>> replacements(
    String orderId,
    String itemId,
    String search,
    int page,
  ) async {
    loads.add('replacements:$itemId:$search:$page');
    await _held();
    return Paged<ReplacementChoice>(
      items: choices,
      page: page,
      perPage: 20,
      total: choices.length,
      lastPage: 1,
    );
  }

  @override
  Future<ShopperOrder> complete(String orderId, String idempotencyKey) {
    keys.add(idempotencyKey);
    return _act(orderId, 'complete:$orderId');
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
    // An order the answer shows done shopping, or no longer the Shopper's,
    // is theirs to read no more: loading it again finds nothing, as the
    // server's does.
    if (order.assignment == null ||
        (order.status != OrderStatus.shoppingAssigned &&
            order.status != OrderStatus.shopping)) {
      details.remove(id);
    } else {
      details[id] = order;
    }
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
