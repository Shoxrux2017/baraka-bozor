import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites_repository.dart';

import 'fake_catalog_repository.dart';

/// The Customer's favourites in memory, paginated like the API.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository({List<FavoriteProduct>? favorites})
    : rows = favorites ?? <FavoriteProduct>[];

  List<FavoriteProduct> rows;
  int pageSize = 20;

  /// Every change, as `add:<id>` or `remove:<id>`.
  final List<String> changes = <String>[];

  /// How many times the list was asked for.
  int listLoads = 0;

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

  /// While set, every load of the list answers this.
  ApiFailure? listFailure;

  @override
  Future<Paged<FavoriteProduct>> list({required int page}) async {
    listLoads++;
    final ApiFailure? failure = listFailure;
    if (failure != null) {
      throw failure;
    }
    final int lastPage = rows.isEmpty
        ? 1
        : (rows.length + pageSize - 1) ~/ pageSize;
    return Paged<FavoriteProduct>(
      items: rows.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      perPage: pageSize,
      total: rows.length,
      lastPage: lastPage,
    );
  }

  @override
  Future<void> add(String productId) async {
    await _change('add:$productId');
    if (!rows.any((FavoriteProduct f) => f.product.id == productId)) {
      rows = <FavoriteProduct>[
        ...rows,
        FavoriteProduct(
          product: catalogProduct(id: productId, isFavorite: true),
          isAvailable: true,
        ),
      ];
    }
  }

  @override
  Future<void> remove(String productId) async {
    await _change('remove:$productId');
    rows = rows
        .where((FavoriteProduct f) => f.product.id != productId)
        .toList();
  }
}
