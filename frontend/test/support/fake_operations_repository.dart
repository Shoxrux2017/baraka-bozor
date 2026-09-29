import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:baraka_bozor/features/operations/domain/operations_repository.dart';

import 'operations_json.dart';

/// The board in memory: its rows filtered like the API, one order's detail
/// by id, the summary, the attention list and the Shoppers, all built from
/// the contract's JSON through the real parser. Every query and load is
/// recorded; [hold], when set, holds every answer until it completes.
class FakeOperationsRepository implements OperationsRepository {
  FakeOperationsRepository({
    List<BoardRow>? rows,
    Map<String, BoardOrder>? details,
    BoardSummary? summary,
    List<AttentionItem>? attention,
    List<StaffChoice>? shopperList,
    List<StaffChoice>? courierList,
  }) : rows =
           rows ??
           <BoardRow>[
             OperationsApi.parseRow(rowJson()),
             OperationsApi.parseRow(
               rowJson(
                 id: orderB,
                 number: 1002,
                 status: 'new',
                 shopper: null,
                 totalKind: 'final',
                 totalUzs: 40000,
               ),
             ),
           ],
       details =
           details ??
           <String, BoardOrder>{orderA: OperationsApi.parseOrder(orderJson())},
       summaryAnswer = summary ?? OperationsApi.parseSummary(summaryJson()),
       attentionAnswer =
           attention ??
           <AttentionItem>[OperationsApi.parseAttention(attentionJson())],
       shopperList =
           shopperList ??
           <StaffChoice>[OperationsApi.parseStaff(shopperJson())],
       courierList =
           courierList ??
           <StaffChoice>[OperationsApi.parseStaff(courierChoiceJson())];

  List<BoardRow> rows;
  Map<String, BoardOrder> details;
  BoardSummary summaryAnswer;
  List<AttentionItem> attentionAnswer;
  List<StaffChoice> shopperList;
  List<StaffChoice> courierList;

  final List<BoardQuery> queries = <BoardQuery>[];
  final List<String> loads = <String>[];

  /// When set, every answer waits for it.
  Completer<void>? hold;

  /// When set, the board's page fails with it.
  ApiFailure? pageFailure;

  /// When set, an order's detail waits for it, and nothing else does.
  Completer<void>? holdOrder;

  /// When set, the Shopper list fails with it.
  ApiFailure? shoppersFailure;

  /// When set, the Courier list fails with it.
  ApiFailure? couriersFailure;

  /// Every assignment asked for: `assign:<order>:<shopper>` or
  /// `reassign:<order>:<shopper>:<replaced assignment>`, and for a Courier
  /// `assign-courier:…` and `reassign-courier:…` alike.
  final List<String> changes = <String>[];

  /// The order each assignment answers with, which also becomes the order's
  /// detail from then on.
  final Map<String, BoardOrder> afterAssignment = <String, BoardOrder>{};

  /// When set, an assignment fails with it.
  ApiFailure? assignmentFailure;

  /// Every action on an order asked for, as
  /// `remove-expired:<order>:<approval>:<note>`,
  /// `decide:<order>:<request>:<decision>:<note>`,
  /// `cancel-failed:<order>:<note>` or
  /// `correct:<order>:<item>:<price>:<reason>`.
  final List<String> actions = <String>[];

  /// The order each action answers, which also becomes the order's detail
  /// from then on.
  final Map<String, BoardOrder> afterAction = <String, BoardOrder>{};

  /// When set, an action fails with it.
  ApiFailure? actionFailure;

  Future<void> _held() async {
    final Completer<void>? hold = this.hold;
    if (hold != null) {
      await hold.future;
    }
  }

  @override
  Future<Paged<BoardRow>> orders(BoardQuery query) async {
    queries.add(query);
    loads.add('orders');
    await _held();
    if (pageFailure != null) {
      throw pageFailure!;
    }
    final List<BoardRow> matching = rows
        .where(
          (BoardRow row) =>
              (query.status == null || row.status == query.status) &&
              (query.paymentMethod == null ||
                  row.paymentMethod == query.paymentMethod) &&
              (query.shopperId == null || row.shopper?.id == query.shopperId) &&
              (query.courierId == null || row.courier?.id == query.courierId) &&
              (!query.selfOrdersOnly || row.isSelfOrder) &&
              (!query.awaitingCustomerOnly || row.pendingApprovalCount > 0),
        )
        .toList();
    return Paged<BoardRow>(
      items: matching,
      page: query.page,
      perPage: 20,
      total: matching.length,
      lastPage: 1,
    );
  }

  @override
  Future<BoardOrder> order(String id) async {
    loads.add('order:$id');
    await _held();
    final Completer<void>? holdOrder = this.holdOrder;
    if (holdOrder != null) {
      await holdOrder.future;
    }
    final BoardOrder? order = details[id];
    if (order == null) {
      throw const ApiRefusal(ApiError(status: 404, code: 'resource_not_found'));
    }
    return order;
  }

  @override
  Future<BoardSummary> summary() async {
    loads.add('summary');
    await _held();
    return summaryAnswer;
  }

  @override
  Future<List<AttentionItem>> attention() async {
    loads.add('attention');
    await _held();
    return attentionAnswer;
  }

  @override
  Future<List<StaffChoice>> shoppers() async {
    loads.add('shoppers');
    await _held();
    if (shoppersFailure != null) {
      throw shoppersFailure!;
    }
    return shopperList;
  }

  @override
  Future<BoardOrder> assignShopper(String orderId, String shopperId) =>
      _assign(orderId, 'assign:$orderId:$shopperId');

  @override
  Future<BoardOrder> reassignShopper(
    String orderId,
    String shopperId,
    String replacesAssignmentId,
  ) => _assign(orderId, 'reassign:$orderId:$shopperId:$replacesAssignmentId');

  @override
  Future<List<StaffChoice>> couriers() async {
    loads.add('couriers');
    await _held();
    if (couriersFailure != null) {
      throw couriersFailure!;
    }
    return courierList;
  }

  @override
  Future<BoardOrder> assignCourier(String orderId, String courierId) =>
      _assign(orderId, 'assign-courier:$orderId:$courierId');

  @override
  Future<BoardOrder> reassignCourier(
    String orderId,
    String courierId,
    String replacesAssignmentId,
  ) => _assign(
    orderId,
    'reassign-courier:$orderId:$courierId:$replacesAssignmentId',
  );

  @override
  Future<BoardOrder> resolveExpiredApproval(
    String orderId,
    String approvalId,
    String? note,
  ) => _act(orderId, 'remove-expired:$orderId:$approvalId:$note');

  @override
  Future<BoardOrder> decideCancellationRequest(
    String orderId,
    String requestId,
    CancellationDecision decision,
    String? note,
  ) => _act(orderId, 'decide:$orderId:$requestId:${decision.code}:$note');

  @override
  Future<BoardOrder> cancelAfterFailedDelivery(String orderId, String? note) =>
      _act(orderId, 'cancel-failed:$orderId:$note');

  @override
  Future<BoardOrder> correctPrice(
    String orderId,
    String itemId,
    int actualMarketPriceUzs,
    String reason,
  ) => _act(orderId, 'correct:$orderId:$itemId:$actualMarketPriceUzs:$reason');

  Future<BoardOrder> _act(String orderId, String action) async {
    actions.add(action);
    await _held();
    if (actionFailure != null) {
      throw actionFailure!;
    }
    final BoardOrder order = afterAction[orderId]!;
    details[orderId] = order;
    return order;
  }

  Future<BoardOrder> _assign(String orderId, String change) async {
    changes.add(change);
    await _held();
    if (assignmentFailure != null) {
      throw assignmentFailure!;
    }
    final BoardOrder order = afterAssignment[orderId]!;
    details[orderId] = order;
    return order;
  }
}
