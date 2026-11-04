import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites_repository.dart';

import 'fake_catalog_repository.dart';

/// The Customer's favourites in memory, paginated like the API.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository({List<CatalogProduct>? favorites})
    : rows = favorites ?? <CatalogProduct>[];

  /// The favourites in the order they were added; a product with
  /// `isAvailable` false is one that is no longer sold.
  List<CatalogProduct> rows;
  int pageSize = 20;

  /// Every change, as `add:<id>` or `remove:<id>`.
  final List<String> changes = <String>[];

  /// How many times the list was asked for.
  int listLoads = 0;

  /// Every list request, as `sort|page` with the sort's wire value.
  final List<String> requests = <String>[];

  /// How many times the not-sold favourites were removed in one call.
  int removeNotSoldCalls = 0;

  /// The next change answers this instead.
  ApiFailure? nextFailure;

  /// The next change waits for this.
  Completer<void>? hold;

  Future<void> _change(String entry) async {
    changes.add(entry);
    final ApiFailure? failure = nextFailure;
    nextFailure = null;
    await hold?.future;
    if (failure != null) {
      throw failure;
    }
  }

  /// While set, every load of the list waits for it.
  Completer<void>? listHold;

  /// While set, every load of the list answers this.
  ApiFailure? listFailure;

  @override
  Future<FavoritesPage> list({
    required ProductSort sort,
    required int page,
  }) async {
    listLoads++;
    requests.add('${sort.wire}|$page');
    await listHold?.future;
    final ApiFailure? failure = listFailure;
    if (failure != null) {
      throw failure;
    }
    // The server's order: sold ones first, then the rest, each in the order
    // asked for (newest first when the default is asked).
    int byPrice(CatalogProduct a, CatalogProduct b) =>
        a.customerUnitPriceUzs.compareTo(b.customerUnitPriceUzs);
    List<CatalogProduct> ordered(bool sold) {
      final List<CatalogProduct> part = rows
          .where((CatalogProduct p) => p.isAvailable == sold)
          .toList();
      switch (sort) {
        case ProductSort.shop:
          return part;
        case ProductSort.priceAsc:
          return part..sort(byPrice);
        case ProductSort.priceDesc:
          return part
            ..sort((CatalogProduct a, CatalogProduct b) => byPrice(b, a));
      }
    }

    final List<CatalogProduct> all = <CatalogProduct>[
      ...ordered(true),
      ...ordered(false),
    ];
    final int lastPage = all.isEmpty
        ? 1
        : (all.length + pageSize - 1) ~/ pageSize;
    return FavoritesPage(
      products: Paged<CatalogProduct>(
        items: all.skip((page - 1) * pageSize).take(pageSize).toList(),
        page: page,
        perPage: pageSize,
        total: all.length,
        lastPage: lastPage,
      ),
      unavailable: rows.where((CatalogProduct p) => !p.isAvailable).length,
    );
  }

  @override
  Future<void> add(String productId) async {
    await _change('add:$productId');
    if (!rows.any((CatalogProduct p) => p.id == productId)) {
      rows = <CatalogProduct>[
        ...rows,
        catalogProduct(id: productId, isFavorite: true),
      ];
    }
  }

  @override
  Future<void> remove(String productId) async {
    await _change('remove:$productId');
    rows = rows.where((CatalogProduct p) => p.id != productId).toList();
  }

  @override
  Future<void> removeNotSold() async {
    removeNotSoldCalls++;
    await _change('remove-not-sold');
    rows = rows.where((CatalogProduct p) => p.isAvailable).toList();
  }
}
