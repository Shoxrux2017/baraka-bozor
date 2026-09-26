import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog_repository.dart';

CatalogCategory catalogCategory({
  String id = 'c-1',
  String nameUz = 'Sabzavotlar',
  String nameRu = 'Овощи',
}) => CatalogCategory(
  id: id,
  nameUz: nameUz,
  nameRu: nameRu,
  descriptionUz: null,
  descriptionRu: null,
  sortOrder: 0,
);

CatalogProduct catalogProduct({
  String id = 'p-1',
  String categoryId = 'c-1',
  String nameUz = 'Pomidor',
  String nameRu = 'Помидор',
  String? descriptionUz,
  String? descriptionRu,
  UnitCode unitCode = UnitCode.kg,
  PriceMode priceMode = PriceMode.estimate,
  int customerUnitPriceUzs = 18400,
}) => CatalogProduct(
  id: id,
  categoryId: categoryId,
  nameUz: nameUz,
  nameRu: nameRu,
  descriptionUz: descriptionUz,
  descriptionRu: descriptionRu,
  unitCode: unitCode,
  priceMode: priceMode,
  customerUnitPriceUzs: customerUnitPriceUzs,
  imageUrl: null,
);

/// The Customer catalog in memory, paginated and searched like the API. A
/// test can hold a query's answer back with [gates] to see what arrives out
/// of order.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    List<CatalogCategory>? categories,
    List<CatalogProduct>? products,
  }) : categoryRows = categories ?? <CatalogCategory>[],
       productRows = products ?? <CatalogProduct>[];

  List<CatalogCategory> categoryRows;
  List<CatalogProduct> productRows;
  int pageSize = 20;

  /// Every product request, as `search|category|page`.
  final List<String> requests = <String>[];

  /// Answers held back until the test completes them, by search text.
  final Map<String, Completer<void>> gates = <String, Completer<void>>{};

  /// The next product request answers this instead.
  ApiFailure? nextFailure;

  /// How many times the sections were asked for.
  int categoryLoads = 0;

  /// The next sections request answers this instead.
  ApiFailure? categoriesFailure;

  @override
  Future<List<CatalogCategory>> categories() async {
    categoryLoads++;
    final ApiFailure? failure = categoriesFailure;
    if (failure != null) {
      categoriesFailure = null;
      throw failure;
    }
    return categoryRows;
  }

  @override
  Future<Paged<CatalogProduct>> products(
    ProductListQuery query, {
    required int page,
  }) async {
    requests.add('${query.search}|${query.categoryId}|$page');
    await gates[query.search]?.future;
    final ApiFailure? failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    final String search = query.search.toLowerCase();
    final List<CatalogProduct> matching = productRows
        .where(
          (CatalogProduct p) =>
              (query.categoryId == null || p.categoryId == query.categoryId) &&
              (search.isEmpty ||
                  p.nameUz.toLowerCase().contains(search) ||
                  p.nameRu.toLowerCase().contains(search)),
        )
        .toList();
    final int lastPage = matching.isEmpty
        ? 1
        : (matching.length + pageSize - 1) ~/ pageSize;
    return Paged<CatalogProduct>(
      items: matching.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      perPage: pageSize,
      total: matching.length,
      lastPage: lastPage,
    );
  }

  @override
  Future<CatalogProduct> product(String id) async => productRows.firstWhere(
    (CatalogProduct p) => p.id == id,
    orElse: () => throw const ApiRefusal(
      ApiError(status: 404, code: 'resource_not_found'),
    ),
  );
}
