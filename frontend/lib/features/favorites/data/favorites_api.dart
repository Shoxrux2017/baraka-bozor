import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/storage/token_store.dart';
import '../../catalog/data/catalog_api.dart';
import '../domain/favorites.dart';
import '../domain/favorites_repository.dart';

/// The data source for the favourites of `docs/09-api-contracts.md`
/// section 14, always asking as the Customer account.
class FavoritesApi {
  FavoritesApi(this._dio);

  final Dio _dio;

  static const int pageSize = 20;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  Future<Paged<FavoriteProduct>> list({required int page}) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/customer/favorites',
      queryParameters: <String, Object>{'page': page, 'per_page': pageSize},
      options: _customer,
    );
    final Paged<FavoriteProduct> answer = Paged.parse(
      response.data,
      parseFavorite,
    );
    if (answer.page != page) {
      throw const FormatException('the page does not match the request');
    }
    return answer;
  }

  Future<void> add(String productId) async {
    await _dio.put<dynamic>(_path(productId), options: _customer);
  }

  Future<void> remove(String productId) async {
    await _dio.delete<dynamic>(_path(productId), options: _customer);
  }

  static String _path(String productId) =>
      '/customer/favorites/${Uri.encodeComponent(productId)}';

  static FavoriteProduct parseFavorite(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'favourite');
    return FavoriteProduct(
      product: CatalogApi.parseProduct(raw),
      isAvailable: json.boolean('is_available'),
    );
  }
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._api);

  final FavoritesApi _api;

  @override
  Future<Paged<FavoriteProduct>> list({required int page}) =>
      guardApiCall(() => _api.list(page: page));

  @override
  Future<void> add(String productId) => guardApiCall(() => _api.add(productId));

  @override
  Future<void> remove(String productId) =>
      guardApiCall(() => _api.remove(productId));
}
