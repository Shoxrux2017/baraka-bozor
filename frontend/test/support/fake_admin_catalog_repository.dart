import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/features/admin/domain/admin_catalog.dart';
import 'package:baraka_bozor/features/admin/domain/admin_catalog_repository.dart';

final DateTime _at = DateTime.utc(2026, 9, 26, 5);

AdminCategory adminCategory({
  String id = 'c-1',
  String nameUz = 'Sabzavotlar',
  String nameRu = 'Овощи',
  int sortOrder = 0,
  bool isActive = true,
  DateTime? archivedAt,
}) => AdminCategory(
  id: id,
  nameUz: nameUz,
  nameRu: nameRu,
  descriptionUz: null,
  descriptionRu: null,
  sortOrder: sortOrder,
  isActive: archivedAt == null && isActive,
  archivedAt: archivedAt,
  createdAt: _at,
  updatedAt: _at,
);

AdminProduct adminProduct({
  String id = 'p-1',
  String categoryId = 'c-1',
  String nameUz = 'Pomidor',
  String nameRu = 'Помидор',
  UnitCode unitCode = UnitCode.kg,
  PriceMode priceMode = PriceMode.estimate,
  int marketPriceUzs = 16000,
  int customerUnitPriceUzs = 18400,
  String? imageUrl,
  int sortOrder = 0,
  bool isActive = true,
  DateTime? archivedAt,
  DateTime? updatedAt,
}) => AdminProduct(
  id: id,
  categoryId: categoryId,
  nameUz: nameUz,
  nameRu: nameRu,
  descriptionUz: null,
  descriptionRu: null,
  unitCode: unitCode,
  priceMode: priceMode,
  marketPriceUzs: marketPriceUzs,
  customerUnitPriceUzs: customerUnitPriceUzs,
  imageUrl: imageUrl,
  sortOrder: sortOrder,
  isActive: archivedAt == null && isActive,
  archivedAt: archivedAt,
  createdAt: _at,
  updatedAt: updatedAt ?? _at,
);

/// A catalog in memory, paginated like the API: twenty to a page, archived
/// entries only on request, search over both names.
class FakeAdminCatalogRepository implements AdminCatalogRepository {
  FakeAdminCatalogRepository({
    List<AdminCategory>? categories,
    List<AdminProduct>? products,
  }) : categoryRows = categories ?? <AdminCategory>[adminCategory()],
       productRows = products ?? <AdminProduct>[adminProduct()];

  List<AdminCategory> categoryRows;
  List<AdminProduct> productRows;

  final List<ProductQuery> productQueries = <ProductQuery>[];
  final List<(String?, CategoryDraft)> savedCategories =
      <(String?, CategoryDraft)>[];
  final List<(String?, ProductDraft)> savedProducts =
      <(String?, ProductDraft)>[];
  final List<(String, PickedImage)> uploads = <(String, PickedImage)>[];
  final List<String> removedImages = <String>[];
  final List<String> actions = <String>[];

  /// The next change answers this failure instead.
  ApiFailure? changeFailure;

  int _next = 100;

  @override
  Future<Paged<AdminCategory>> categories(
    CategoryQuery query, {
    int perPage = 20,
  }) async => _page(
    categoryRows
        .where(
          (AdminCategory c) => query.includeArchived || c.archivedAt == null,
        )
        .toList(),
    query.page,
    perPage,
  );

  @override
  Future<Paged<AdminProduct>> products(ProductQuery query) async {
    productQueries.add(query);
    final String search = query.search.toLowerCase();
    return _page(
      productRows
          .where(
            (AdminProduct p) =>
                (query.includeArchived || p.archivedAt == null) &&
                (query.categoryId == null ||
                    p.categoryId == query.categoryId) &&
                (search.isEmpty ||
                    p.nameUz.toLowerCase().contains(search) ||
                    p.nameRu.toLowerCase().contains(search)),
          )
          .toList(),
      query.page,
      20,
    );
  }

  @override
  Future<AdminProduct> product(String id) async => productRows.firstWhere(
    (AdminProduct p) => p.id == id,
    orElse: () => throw const ApiRefusal(
      ApiError(status: 404, code: 'resource_not_found'),
    ),
  );

  @override
  Future<AdminCategory> createCategory(CategoryDraft draft) =>
      _saveCategory(null, draft);

  @override
  Future<AdminCategory> updateCategory(String id, CategoryDraft draft) =>
      _saveCategory(id, draft);

  @override
  Future<AdminCategory> archiveCategory(String id) => _category(
    'archive $id',
    id,
    (AdminCategory c) => adminCategory(
      id: c.id,
      nameUz: c.nameUz,
      nameRu: c.nameRu,
      archivedAt: _at,
    ),
  );

  @override
  Future<AdminCategory> restoreCategory(String id) => _category(
    'restore $id',
    id,
    (AdminCategory c) =>
        adminCategory(id: c.id, nameUz: c.nameUz, nameRu: c.nameRu),
  );

  @override
  Future<AdminProduct> createProduct(ProductDraft draft) =>
      _saveProduct(null, draft);

  @override
  Future<AdminProduct> updateProduct(String id, ProductDraft draft) =>
      _saveProduct(id, draft);

  @override
  Future<AdminProduct> archiveProduct(String id) => _product(
    'archive $id',
    id,
    (AdminProduct p) => adminProduct(
      id: p.id,
      nameUz: p.nameUz,
      nameRu: p.nameRu,
      archivedAt: _at,
    ),
  );

  @override
  Future<AdminProduct> restoreProduct(String id) => _product(
    'restore $id',
    id,
    (AdminProduct p) =>
        adminProduct(id: p.id, nameUz: p.nameUz, nameRu: p.nameRu),
  );

  @override
  Future<AdminProduct> uploadImage(String productId, PickedImage image) {
    uploads.add((productId, image));
    return _product(
      'upload $productId',
      productId,
      (AdminProduct p) => adminProduct(
        id: p.id,
        nameUz: p.nameUz,
        nameRu: p.nameRu,
        imageUrl: 'https://api.test/storage/products/${uploads.length}.png',
      ),
    );
  }

  @override
  Future<AdminProduct> removeImage(String productId) {
    removedImages.add(productId);
    return _product(
      'remove image $productId',
      productId,
      (AdminProduct p) =>
          adminProduct(id: p.id, nameUz: p.nameUz, nameRu: p.nameRu),
    );
  }

  Future<AdminCategory> _saveCategory(String? id, CategoryDraft draft) async {
    savedCategories.add((id, draft));
    _failIfAsked();
    final AdminCategory saved = adminCategory(
      id: id ?? 'c-${_next++}',
      nameUz: draft.nameUz,
      nameRu: draft.nameRu,
      sortOrder: draft.sortOrder,
      isActive: draft.isActive ?? true,
    );
    categoryRows = <AdminCategory>[
      for (final AdminCategory c in categoryRows)
        if (c.id != saved.id) c,
      saved,
    ];
    return saved;
  }

  Future<AdminProduct> _saveProduct(String? id, ProductDraft draft) async {
    savedProducts.add((id, draft));
    _failIfAsked();
    final AdminProduct saved = adminProduct(
      id: id ?? 'p-${_next++}',
      categoryId: draft.categoryId,
      nameUz: draft.nameUz,
      nameRu: draft.nameRu,
      unitCode: draft.unitCode,
      priceMode: draft.priceMode,
      marketPriceUzs: draft.marketPriceUzs,
      sortOrder: draft.sortOrder,
      isActive: draft.isActive ?? true,
      updatedAt: DateTime.utc(2026, 9, 26, 6, _next),
    );
    productRows = <AdminProduct>[
      for (final AdminProduct p in productRows)
        if (p.id != saved.id) p,
      saved,
    ];
    return saved;
  }

  Future<AdminCategory> _category(
    String action,
    String id,
    AdminCategory Function(AdminCategory current) change,
  ) async {
    actions.add(action);
    _failIfAsked();
    final AdminCategory changed = change(
      categoryRows.firstWhere((AdminCategory c) => c.id == id),
    );
    categoryRows = <AdminCategory>[
      for (final AdminCategory c in categoryRows) c.id == id ? changed : c,
    ];
    return changed;
  }

  Future<AdminProduct> _product(
    String action,
    String id,
    AdminProduct Function(AdminProduct current) change,
  ) async {
    actions.add(action);
    _failIfAsked();
    final AdminProduct changed = change(
      productRows.firstWhere((AdminProduct p) => p.id == id),
    );
    productRows = <AdminProduct>[
      for (final AdminProduct p in productRows) p.id == id ? changed : p,
    ];
    return changed;
  }

  void _failIfAsked() {
    final ApiFailure? failure = changeFailure;
    if (failure != null) {
      changeFailure = null;
      throw failure;
    }
  }

  static Paged<T> _page<T>(List<T> all, int page, int perPage) {
    final int lastPage = all.isEmpty
        ? 1
        : (all.length + perPage - 1) ~/ perPage;
    return Paged<T>(
      items: all.skip((page - 1) * perPage).take(perPage).toList(),
      page: page,
      perPage: perPage,
      total: all.length,
      lastPage: lastPage,
    );
  }
}
