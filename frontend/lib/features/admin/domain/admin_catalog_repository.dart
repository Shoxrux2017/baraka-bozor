import '../../../core/network/paged.dart';
import 'admin_catalog.dart';

/// The catalog operations of the panel (`docs/09-api-contracts.md`
/// sections 15 and 16), on the staff session. Every method throws an
/// `ApiFailure`.
abstract interface class AdminCatalogRepository {
  Future<Paged<AdminCategory>> categories(
    CategoryQuery query, {
    int perPage = 20,
  });

  Future<AdminCategory> createCategory(CategoryDraft draft);

  /// Saves what [draft] changed from [category], the entry the form showed.
  Future<AdminCategory> updateCategory(
    AdminCategory category,
    CategoryDraft draft,
  );

  Future<AdminCategory> archiveCategory(String id);

  Future<AdminCategory> restoreCategory(String id);

  Future<Paged<AdminProduct>> products(ProductQuery query);

  Future<AdminProduct> product(String id);

  Future<AdminProduct> createProduct(ProductDraft draft);

  /// Saves what [draft] changed from [product], the entry the form showed.
  Future<AdminProduct> updateProduct(AdminProduct product, ProductDraft draft);

  Future<AdminProduct> archiveProduct(String id);

  Future<AdminProduct> restoreProduct(String id);

  Future<AdminProduct> uploadImage(String productId, PickedImage image);

  Future<AdminProduct> removeImage(String productId);
}
