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
  Future<List<ShopperChoice>> shoppers() => guardApiCall(_api.shoppers);
}
