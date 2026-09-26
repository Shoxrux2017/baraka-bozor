import 'package:dio/dio.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/storage/token_store.dart';
import '../domain/catalog.dart';

/// The data source for `docs/09-api-contracts.md` section 14. The catalog
/// answers a Customer session only, so a Shopper or Courier browsing in
/// Customer mode is always asking as their Customer account.
class CatalogApi {
  CatalogApi(this._dio);

  final Dio _dio;

  static const int pageSize = 20;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  Future<List<CatalogCategory>> categories() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/catalog/categories',
      queryParameters: <String, Object>{'per_page': 100},
      options: _customer,
    );
    return Paged.parse(response.data, parseCategory).items;
  }

  Future<Paged<CatalogProduct>> products(
    ProductListQuery query, {
    required int page,
  }) async {
    final String search = query.search.trim();
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/catalog/products',
      queryParameters: <String, Object>{
        'page': page,
        'per_page': pageSize,
        if (query.categoryId != null) 'category_id': query.categoryId!,
        if (search.isNotEmpty) 'search': search,
      },
      options: _customer,
    );
    final Paged<CatalogProduct> answer = Paged.parse(
      response.data,
      parseProduct,
    );
    // An answer for another page, or with another section's products, is
    // malformed (`DL-27` (6)): the list would repeat or never end.
    if (answer.page != page ||
        (query.categoryId != null &&
            answer.items.any(
              (CatalogProduct p) => p.categoryId != query.categoryId,
            ))) {
      throw const FormatException('the page does not match the request');
    }
    return answer;
  }

  Future<CatalogProduct> product(String id) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/catalog/products/${Uri.encodeComponent(id)}',
      options: _customer,
    );
    final CatalogProduct product = parseProduct(
      ApiEnvelope.unwrap(response.data),
    );
    if (product.id != id) {
      throw const FormatException('the product does not match the request');
    }
    return product;
  }

  static CatalogCategory parseCategory(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'category');
    return CatalogCategory(
      id: json.uuid('id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      descriptionUz: json.nullableString('description_uz'),
      descriptionRu: json.nullableString('description_ru'),
      sortOrder: json.integer('sort_order'),
    );
  }

  /// A product, held to its contract: UUID ids, and a customer price above
  /// zero, as the market price it is computed from must be (`DL-20` (6)).
  static CatalogProduct parseProduct(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'product');
    final int price = json.integer('customer_unit_price_uzs');
    if (price <= 0) {
      throw const FormatException('a customer price is above zero');
    }
    return CatalogProduct(
      id: json.uuid('id'),
      categoryId: json.uuid('category_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      descriptionUz: json.nullableString('description_uz'),
      descriptionRu: json.nullableString('description_ru'),
      unitCode: json.choice('unit_code', UnitCode.tryParse),
      priceMode: json.choice('price_mode', PriceMode.tryParse),
      customerUnitPriceUzs: price,
      imageUrl: json.nullableString('image_url'),
    );
  }
}
