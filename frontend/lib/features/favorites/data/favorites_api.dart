import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/storage/token_store.dart';
import '../../catalog/data/catalog_api.dart';
import '../../catalog/domain/catalog.dart';
import '../domain/favorites_repository.dart';

/// The data source for the favourites of `docs/09-api-contracts.md`
/// section 58, always asking as the Customer account.
class FavoritesApi {
  FavoritesApi(this._dio);

  final Dio _dio;

  static const int pageSize = 20;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  Future<FavoritesPage> list({
    required ProductSort sort,
    required int page,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/customer/favorites',
      queryParameters: <String, Object>{
        'page': page,
        'per_page': pageSize,
        if (sort != ProductSort.shop) 'sort': sort.wire,
      },
      options: _customer,
    );
    final Paged<CatalogProduct> products = Paged.parse(
      response.data,
      parseFavorite,
    );
    if (products.page != page) {
      throw const FormatException('the page does not match the request');
    }
    final JsonFields envelope = JsonFields.of(response.data, 'page');
    final JsonFields meta = JsonFields.of(envelope.member('meta'), 'meta');
    final int unavailable = meta.integer('unavailable_count');
    if (unavailable < 0) {
      throw const FormatException('unavailable_count is out of range');
    }
    return FavoritesPage(products: products, unavailable: unavailable);
  }

  Future<void> add(String productId) async {
    await _dio.put<dynamic>(_path(productId), options: _customer);
  }

  Future<void> remove(String productId) async {
    await _dio.delete<dynamic>(_path(productId), options: _customer);
  }

  Future<void> removeNotSold() async {
    await _dio.delete<dynamic>(
      '/customer/favorites/unavailable',
      options: _customer,
    );
  }

  static String _path(String productId) =>
      '/customer/favorites/${Uri.encodeComponent(productId)}';

  /// A favourite is a product that also says whether it is sold now.
  static CatalogProduct parseFavorite(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'favourite');
    return CatalogApi.parseProduct(
      raw,
      isAvailable: json.boolean('is_available'),
    );
  }
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._api);

  final FavoritesApi _api;

  @override
  Future<FavoritesPage> list({required ProductSort sort, required int page}) =>
      guardApiCall(() => _api.list(sort: sort, page: page));

  @override
  Future<void> add(String productId) => guardApiCall(() => _api.add(productId));

  @override
  Future<void> remove(String productId) =>
      guardApiCall(() => _api.remove(productId));

  @override
  Future<void> removeNotSold() => guardApiCall(_api.removeNotSold);
}
