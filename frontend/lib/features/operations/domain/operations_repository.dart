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
  Future<List<ShopperChoice>> shoppers();
}
