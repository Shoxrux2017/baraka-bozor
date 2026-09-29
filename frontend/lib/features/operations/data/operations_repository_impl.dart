import '../../../core/network/api_call.dart';
import '../../../core/network/paged.dart';
import '../domain/board.dart';
import '../domain/operations_repository.dart';
import 'operations_api.dart';

class OperationsRepositoryImpl implements OperationsRepository {
  OperationsRepositoryImpl(this._api);

  final OperationsApi _api;

  @override
  Future<Paged<BoardRow>> orders(BoardQuery query) =>
      guardApiCall(() => _api.orders(query));

  @override
  Future<BoardOrder> order(String id) => guardApiCall(() => _api.order(id));

  @override
  Future<BoardSummary> summary() => guardApiCall(_api.summary);

  @override
  Future<List<AttentionItem>> attention() => guardApiCall(_api.attention);

  @override
  Future<List<StaffChoice>> shoppers() => guardApiCall(_api.shoppers);

  @override
  Future<BoardOrder> assignShopper(String orderId, String shopperId) =>
      guardApiCall(() => _api.assignShopper(orderId, shopperId));

  @override
  Future<BoardOrder> reassignShopper(
    String orderId,
    String shopperId,
    String replacesAssignmentId,
  ) => guardApiCall(
    () => _api.reassignShopper(orderId, shopperId, replacesAssignmentId),
  );

  @override
  Future<List<StaffChoice>> couriers() => guardApiCall(_api.couriers);

  @override
  Future<BoardOrder> assignCourier(String orderId, String courierId) =>
      guardApiCall(() => _api.assignCourier(orderId, courierId));

  @override
  Future<BoardOrder> reassignCourier(
    String orderId,
    String courierId,
    String replacesAssignmentId,
  ) => guardApiCall(
    () => _api.reassignCourier(orderId, courierId, replacesAssignmentId),
  );

  @override
  Future<BoardOrder> resolveExpiredApproval(
    String orderId,
    String approvalId,
    String? note,
  ) => guardApiCall(
    () => _api.resolveExpiredApproval(orderId, approvalId, note),
  );

  @override
  Future<BoardOrder> decideCancellationRequest(
    String orderId,
    String requestId,
    CancellationDecision decision,
    String? note,
  ) => guardApiCall(
    () => _api.decideCancellationRequest(orderId, requestId, decision, note),
  );

  @override
  Future<BoardOrder> cancelAfterFailedDelivery(String orderId, String? note) =>
      guardApiCall(() => _api.cancelAfterFailedDelivery(orderId, note));

  @override
  Future<BoardOrder> correctPrice(
    String orderId,
    String itemId,
    int actualMarketPriceUzs,
    String reason,
  ) => guardApiCall(
    () => _api.correctPrice(orderId, itemId, actualMarketPriceUzs, reason),
  );
}
