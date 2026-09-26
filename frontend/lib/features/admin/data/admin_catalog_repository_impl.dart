import '../../../core/network/api_call.dart';
import '../../../core/network/paged.dart';
import '../domain/admin_catalog.dart';
import '../domain/admin_catalog_repository.dart';
import 'admin_catalog_api.dart';

class AdminCatalogRepositoryImpl implements AdminCatalogRepository {
  AdminCatalogRepositoryImpl(this._api);

  final AdminCatalogApi _api;

  @override
  Future<Paged<AdminCategory>> categories(
    CategoryQuery query, {
    int perPage = 20,
  }) => guardApiCall(() => _api.categories(query, perPage: perPage));

  @override
  Future<AdminCategory> createCategory(CategoryDraft draft) =>
      guardApiCall(() => _api.createCategory(draft));

  @override
  Future<AdminCategory> updateCategory(
    AdminCategory category,
    CategoryDraft draft,
  ) => guardApiCall(() => _api.updateCategory(category, draft));

  @override
  Future<AdminCategory> archiveCategory(String id) =>
      guardApiCall(() => _api.archiveCategory(id));

  @override
  Future<AdminCategory> restoreCategory(String id) =>
      guardApiCall(() => _api.restoreCategory(id));

  @override
  Future<Paged<AdminProduct>> products(ProductQuery query) =>
      guardApiCall(() => _api.products(query));

  @override
  Future<AdminProduct> product(String id) =>
      guardApiCall(() => _api.product(id));

  @override
  Future<AdminProduct> createProduct(ProductDraft draft) =>
      guardApiCall(() => _api.createProduct(draft));

  @override
  Future<AdminProduct> updateProduct(
    AdminProduct product,
    ProductDraft draft,
  ) => guardApiCall(() => _api.updateProduct(product, draft));

  @override
  Future<AdminProduct> archiveProduct(String id) =>
      guardApiCall(() => _api.archiveProduct(id));

  @override
  Future<AdminProduct> restoreProduct(String id) =>
      guardApiCall(() => _api.restoreProduct(id));

  @override
  Future<AdminProduct> uploadImage(String productId, PickedImage image) =>
      guardApiCall(() => _api.uploadImage(productId, image));

  @override
  Future<AdminProduct> removeImage(String productId) =>
      guardApiCall(() => _api.removeImage(productId));
}
