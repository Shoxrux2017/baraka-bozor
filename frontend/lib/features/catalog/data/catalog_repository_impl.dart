import '../../../core/network/api_call.dart';
import '../../../core/network/paged.dart';
import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';
import 'catalog_api.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._api);

  final CatalogApi _api;

  @override
  Future<List<CatalogCategory>> categories() => guardApiCall(_api.categories);

  @override
  Future<Paged<CatalogProduct>> products(
    ProductListQuery query, {
    required int page,
  }) => guardApiCall(() => _api.products(query, page: page));

  @override
  Future<CatalogProduct> product(String id) =>
      guardApiCall(() => _api.product(id));
}
