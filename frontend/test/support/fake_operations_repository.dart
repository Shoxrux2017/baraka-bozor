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
    List<ShopperChoice>? shopperList,
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
           <ShopperChoice>[OperationsApi.parseShopper(shopperJson())];

  List<BoardRow> rows;
  Map<String, BoardOrder> details;
  BoardSummary summaryAnswer;
  List<AttentionItem> attentionAnswer;
  List<ShopperChoice> shopperList;

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

  /// Every assignment asked for: `assign:<order>:<shopper>` or
  /// `reassign:<order>:<shopper>:<replaced assignment>`.
  final List<String> changes = <String>[];

  /// The order each assignment answers with, which also becomes the order's
  /// detail from then on.
  final Map<String, BoardOrder> afterAssignment = <String, BoardOrder>{};

  /// When set, an assignment fails with it.
  ApiFailure? assignmentFailure;

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
              (!query.selfOrdersOnly || row.isSelfOrder),
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
  Future<List<ShopperChoice>> shoppers() async {
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
