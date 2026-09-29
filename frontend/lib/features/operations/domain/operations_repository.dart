import '../../../core/network/paged.dart';
import 'board.dart';

/// The board of the Operator and the Admin (`docs/09-api-contracts.md`
/// sections 38 and 39), on the staff session. Every method throws an
/// `ApiFailure`.
abstract interface class OperationsRepository {
  Future<Paged<BoardRow>> orders(BoardQuery query);

  Future<BoardOrder> order(String id);

  Future<BoardSummary> summary();

  Future<List<AttentionItem>> attention();

  /// The active Shoppers, at most one page of 100 (`DL-45` (1)).
  Future<List<StaffChoice>> shoppers();

  /// Assigns [shopperId] to the `new` order [orderId].
  Future<BoardOrder> assignShopper(String orderId, String shopperId);

  /// Replaces the assignment [replacesAssignmentId] — the one the Operator
  /// saw — with [shopperId] (`DL-45` (8)).
  Future<BoardOrder> reassignShopper(
    String orderId,
    String shopperId,
    String replacesAssignmentId,
  );

  /// The active Couriers, at most one page of 100 (`DL-62` (2)).
  Future<List<StaffChoice>> couriers();

  /// Assigns [courierId] to the `ready_for_delivery` order [orderId].
  Future<BoardOrder> assignCourier(String orderId, String courierId);

  /// Replaces the Courier assignment [replacesAssignmentId] with [courierId]
  /// (`DL-54` (10)).
  Future<BoardOrder> reassignCourier(
    String orderId,
    String courierId,
    String replacesAssignmentId,
  );
}
