import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/paged.dart';
import '../../../core/state/mutation_state.dart';
import '../data/admin_catalog_api.dart';
import '../data/admin_catalog_repository_impl.dart';
import '../domain/admin_catalog.dart';
import '../domain/admin_catalog_repository.dart';
import 'admin_providers.dart';
import 'product_image_picker.dart';

final Provider<AdminCatalogRepository> adminCatalogRepositoryProvider =
    Provider<AdminCatalogRepository>(
      (Ref ref) => AdminCatalogRepositoryImpl(
        AdminCatalogApi(ref.watch(apiClientProvider)),
      ),
    );

/// What the category list shows: the page and whether archived entries are
/// included. Kept apart from the page itself, so a change of query starts a
/// new load and a load for an older query is simply discarded.
class CategoryQueryController extends Notifier<CategoryQuery> {
  @override
  CategoryQuery build() {
    ref.watch(staffAccountProvider);
    return const CategoryQuery();
  }

  void includeArchived(bool include) =>
      state = CategoryQuery(includeArchived: include);

  void goToPage(int page) => state = state.copyWith(page: page);
}

final NotifierProvider<CategoryQueryController, CategoryQuery>
categoryQueryProvider =
    NotifierProvider.autoDispose<CategoryQueryController, CategoryQuery>(
      CategoryQueryController.new,
    );

/// The category page for the current query.
final FutureProvider<Paged<AdminCategory>> categoryPageProvider =
    FutureProvider.autoDispose<Paged<AdminCategory>>((Ref ref) {
      ref.watch(staffAccountProvider);
      return ref
          .watch(adminCatalogRepositoryProvider)
          .categories(ref.watch(categoryQueryProvider));
    });

/// Every category, archived ones included, for the product list's filter
/// and the product form: at most one page of 100, which the assumed catalog
/// size (interview 2.4) never exceeds.
final FutureProvider<List<AdminCategory>> categoryOptionsProvider =
    FutureProvider.autoDispose<List<AdminCategory>>((Ref ref) async {
      ref.watch(staffAccountProvider);
      final Paged<AdminCategory> page = await ref
          .watch(adminCatalogRepositoryProvider)
          .categories(const CategoryQuery(includeArchived: true), perPage: 100);
      return page.items;
    });

/// What the product list shows: page, archived entries, category, search.
class ProductQueryController extends Notifier<ProductQuery> {
  @override
  ProductQuery build() {
    ref.watch(staffAccountProvider);
    return const ProductQuery();
  }

  void includeArchived(bool include) => state = ProductQuery(
    includeArchived: include,
    categoryId: state.categoryId,
    search: state.search,
  );

  void filterByCategory(String? categoryId) => state = ProductQuery(
    includeArchived: state.includeArchived,
    categoryId: categoryId,
    search: state.search,
  );

  void search(String text) => state = ProductQuery(
    includeArchived: state.includeArchived,
    categoryId: state.categoryId,
    search: text.trim(),
  );

  void goToPage(int page) => state = ProductQuery(
    page: page,
    includeArchived: state.includeArchived,
    categoryId: state.categoryId,
    search: state.search,
  );
}

final NotifierProvider<ProductQueryController, ProductQuery>
productQueryProvider =
    NotifierProvider.autoDispose<ProductQueryController, ProductQuery>(
      ProductQueryController.new,
    );

/// The product page for the current query.
final FutureProvider<Paged<AdminProduct>> productPageProvider =
    FutureProvider.autoDispose<Paged<AdminProduct>>((Ref ref) {
      ref.watch(staffAccountProvider);
      return ref
          .watch(adminCatalogRepositoryProvider)
          .products(ref.watch(productQueryProvider));
    });

/// One product for its edit page.
final FutureProviderFamily<AdminProduct, String> productProvider =
    FutureProvider.autoDispose.family<AdminProduct, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(staffAccountProvider);
      return ref.watch(adminCatalogRepositoryProvider).product(id);
    });

/// Every catalog change the panel makes: a category or product saved,
/// archived or restored, an image uploaded or removed. One runs at a time;
/// a success reloads what the change touched rather than patching a
/// paginated list (`frontend/AGENTS.md` section 11).
class CatalogChangeController extends MutationNotifier {
  AdminCatalogRepository get _catalog =>
      ref.read(adminCatalogRepositoryProvider);

  Future<AdminCategory?> saveCategory(String? id, CategoryDraft draft) =>
      _category(
        () => id == null
            ? _catalog.createCategory(draft)
            : _catalog.updateCategory(id, draft),
      );

  Future<AdminCategory?> archiveCategory(String id) =>
      _category(() => _catalog.archiveCategory(id));

  Future<AdminCategory?> restoreCategory(String id) =>
      _category(() => _catalog.restoreCategory(id));

  Future<AdminProduct?> saveProduct(String? id, ProductDraft draft) => _product(
    () => id == null
        ? _catalog.createProduct(draft)
        : _catalog.updateProduct(id, draft),
  );

  Future<AdminProduct?> archiveProduct(String id) =>
      _product(() => _catalog.archiveProduct(id));

  Future<AdminProduct?> restoreProduct(String id) =>
      _product(() => _catalog.restoreProduct(id));

  Future<AdminProduct?> uploadImage(String productId, PickedImage image) =>
      _product(() => _catalog.uploadImage(productId, image));

  Future<AdminProduct?> removeImage(String productId) =>
      _product(() => _catalog.removeImage(productId));

  Future<AdminCategory?> _category(
    Future<AdminCategory> Function() change,
  ) async {
    AdminCategory? result;
    final bool done = await run(() async {
      result = await change();
      if (ref.mounted) {
        ref
          ..invalidate(categoryPageProvider)
          ..invalidate(categoryOptionsProvider);
      }
    });
    return done ? result : null;
  }

  Future<AdminProduct?> _product(Future<AdminProduct> Function() change) async {
    AdminProduct? result;
    final bool done = await run(() async {
      result = await change();
      if (ref.mounted) {
        ref
          ..invalidate(productPageProvider)
          ..invalidate(productProvider(result!.id));
      }
    });
    return done ? result : null;
  }
}

final NotifierProvider<CatalogChangeController, MutationState>
catalogChangeControllerProvider =
    NotifierProvider.autoDispose<CatalogChangeController, MutationState>(
      CatalogChangeController.new,
    );

/// Where the panel gets an image from: the browser's file dialog in the
/// build, a fake in tests.
final Provider<ProductImagePicker> productImagePickerProvider =
    Provider<ProductImagePicker>((Ref ref) => const DialogProductImagePicker());
