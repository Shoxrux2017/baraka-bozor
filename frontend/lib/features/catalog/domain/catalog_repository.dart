import '../../../core/network/paged.dart';
import 'catalog.dart';

/// The Customer catalog (`docs/09-api-contracts.md` section 14), on the
/// Customer session. Every method throws an `ApiFailure`.
abstract interface class CatalogRepository {
  /// Every category the Customer can open; the catalog is small enough for
  /// one page of 100 (`DL-22` (4)).
  Future<List<CatalogCategory>> categories();

  Future<Paged<CatalogProduct>> products(
    ProductListQuery query, {
    required int page,
  });

  Future<CatalogProduct> product(String id);
}
