import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
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
/// new load and a load for an older query is simply discarded. It outlives
/// the screen — the Admin who opens an entry and comes back finds the list as
/// they left it — and starts over for another account.
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
    NotifierProvider<CategoryQueryController, CategoryQuery>(
      CategoryQueryController.new,
    );

/// The category page for the current query.
final FutureProvider<Paged<AdminCategory>> categoryPageProvider =
    FutureProvider.autoDispose<Paged<AdminCategory>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<Paged<AdminCategory>>().future;
      }
      return ref
          .watch(adminCatalogRepositoryProvider)
          .categories(ref.watch(categoryQueryProvider));
    });

/// Every category, archived ones included, for the product list's filter
/// and the product form: at most one page of 100, which the assumed catalog
/// size (interview 2.4) never exceeds.
final FutureProvider<List<AdminCategory>> categoryOptionsProvider =
    FutureProvider.autoDispose<List<AdminCategory>>((Ref ref) async {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<List<AdminCategory>>().future;
      }
      final Paged<AdminCategory> page = await ref
          .watch(adminCatalogRepositoryProvider)
          .categories(const CategoryQuery(includeArchived: true), perPage: 100);
      return page.items;
    });

/// What the product list shows: page, archived entries, category, search —
/// kept like the category list's, so a product opened from page 2 of a
/// search goes back to page 2 of that search.
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

  /// Searches for [text], trimmed and cut to what the server takes: the
  /// field counts what the Admin sees, the server counts code points.
  void search(String text) => state = ProductQuery(
    includeArchived: state.includeArchived,
    categoryId: state.categoryId,
    search: String.fromCharCodes(
      text.trim().runes.take(ProductQuery.searchMaxLength),
    ).trim(),
  );

  void goToPage(int page) => state = ProductQuery(
    page: page,
    includeArchived: state.includeArchived,
    categoryId: state.categoryId,
    search: state.search,
  );
}

final NotifierProvider<ProductQueryController, ProductQuery>
productQueryProvider = NotifierProvider<ProductQueryController, ProductQuery>(
  ProductQueryController.new,
);

/// The product page for the current query.
final FutureProvider<Paged<AdminProduct>> productPageProvider =
    FutureProvider.autoDispose<Paged<AdminProduct>>((Ref ref) {
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<Paged<AdminProduct>>().future;
      }
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
      if (ref.watch(staffAccountProvider) == null) {
        return Completer<AdminProduct>().future;
      }
      return ref.watch(adminCatalogRepositoryProvider).product(id);
    });

/// The base of every catalog change. One surface — a list's row actions, a
/// category dialog, a product form, a product image — has a controller of
/// its own, so a failure is shown where it happened and nowhere else, and a
/// surface that is left takes its pending change with it
/// (`frontend/AGENTS.md` sections 4 and 5).
///
/// After the change, [perform] reloads what it touched: on success, and also
/// after a conflict or an uncertain outcome, when the screen may be showing a
/// state the server no longer has (`docs/09` section 50) — but not after a
/// refused field, which the form still holds. An answer that arrives for
/// another account counts as cancelled.
abstract class CatalogMutation extends MutationNotifier {
  @override
  MutationState build() {
    ref.watch(staffAccountProvider);
    return super.build();
  }

  AdminCatalogRepository get catalog =>
      ref.read(adminCatalogRepositoryProvider);

  Future<T?> perform<T>(
    Future<T> Function() change, {
    required void Function(T? result) reload,
  }) async {
    final String? account = ref.read(staffAccountProvider);
    bool current() => ref.mounted && ref.read(staffAccountProvider) == account;

    T? result;
    final bool done = await run(() async {
      try {
        result = await change();
      } on ApiFailure catch (failure) {
        final bool mayBeStale = failure is! ApiRefusal || failure.status == 409;
        if (mayBeStale && current()) {
          reload(null);
        }
        rethrow;
      }
      if (!current()) {
        throw const CancelledFailure();
      }
      reload(result);
    });
    return done ? result : null;
  }
}

/// Archive and restore from the category list.
class CategoryListActions extends CatalogMutation {
  Future<void> archive(String id) => perform<AdminCategory>(
    () => catalog.archiveCategory(id),
    reload: _reload,
  );

  Future<void> restore(String id) => perform<AdminCategory>(
    () => catalog.restoreCategory(id),
    reload: _reload,
  );

  void _reload(AdminCategory? _) => ref
    ..invalidate(categoryPageProvider)
    ..invalidate(categoryOptionsProvider);
}

final NotifierProvider<CategoryListActions, MutationState>
categoryListActionsProvider =
    NotifierProvider.autoDispose<CategoryListActions, MutationState>(
      CategoryListActions.new,
    );

/// The category dialog's save.
class CategoryFormController extends CatalogMutation {
  /// Creates a category, or saves what [draft] changed from [category].
  Future<AdminCategory?> save(AdminCategory? category, CategoryDraft draft) =>
      perform(
        () => category == null
            ? catalog.createCategory(draft)
            : catalog.updateCategory(category, draft),
        reload: (AdminCategory? _) => ref
          ..invalidate(categoryPageProvider)
          ..invalidate(categoryOptionsProvider),
      );
}

final NotifierProvider<CategoryFormController, MutationState>
categoryFormControllerProvider =
    NotifierProvider.autoDispose<CategoryFormController, MutationState>(
      CategoryFormController.new,
    );

/// Archive and restore from the product list.
class ProductListActions extends CatalogMutation {
  Future<void> archive(String id) => perform<AdminProduct>(
    () => catalog.archiveProduct(id),
    reload: (AdminProduct? _) => _reload(id),
  );

  Future<void> restore(String id) => perform<AdminProduct>(
    () => catalog.restoreProduct(id),
    reload: (AdminProduct? _) => _reload(id),
  );

  void _reload(String id) => ref
    ..invalidate(productPageProvider)
    ..invalidate(productProvider(id));
}

final NotifierProvider<ProductListActions, MutationState>
productListActionsProvider =
    NotifierProvider.autoDispose<ProductListActions, MutationState>(
      ProductListActions.new,
    );

/// The product form's save.
class ProductFormController extends CatalogMutation {
  /// Creates a product, or saves what [draft] changed from [product].
  Future<AdminProduct?> save(AdminProduct? product, ProductDraft draft) =>
      perform(
        () => product == null
            ? catalog.createProduct(draft)
            : catalog.updateProduct(product, draft),
        reload: (AdminProduct? saved) {
          ref.invalidate(productPageProvider);
          final String? id = saved?.id ?? product?.id;
          if (id != null) {
            ref.invalidate(productProvider(id));
          }
        },
      );
}

final NotifierProvider<ProductFormController, MutationState>
productFormControllerProvider =
    NotifierProvider.autoDispose<ProductFormController, MutationState>(
      ProductFormController.new,
    );

/// The product image card's upload and removal.
class ProductImageController extends CatalogMutation {
  Future<AdminProduct?> upload(String productId, PickedImage image) => perform(
    () => catalog.uploadImage(productId, image),
    reload: (AdminProduct? _) => _reload(productId),
  );

  Future<AdminProduct?> remove(String productId) => perform(
    () => catalog.removeImage(productId),
    reload: (AdminProduct? _) => _reload(productId),
  );

  void _reload(String productId) => ref
    ..invalidate(productPageProvider)
    ..invalidate(productProvider(productId));
}

final NotifierProvider<ProductImageController, MutationState>
productImageControllerProvider =
    NotifierProvider.autoDispose<ProductImageController, MutationState>(
      ProductImageController.new,
    );

/// Where the panel gets an image from: the browser's file dialog in the
/// build, a fake in tests.
final Provider<ProductImagePicker> productImagePickerProvider =
    Provider<ProductImagePicker>((Ref ref) => ProductImagePicker.platform());
