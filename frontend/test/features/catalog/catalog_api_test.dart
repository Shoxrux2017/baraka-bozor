import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/catalog/data/catalog_api.dart';
import 'package:baraka_bozor/features/catalog/data/catalog_repository_impl.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';

const String categoryId = '0f0e3c6a-6b1f-4f7e-9a51-2d6c1c1e9a01';
const String productId = '5b2a1c3d-8e4f-4a6b-9c7d-1e2f3a4b5c6d';

/// A product as `docs/09-api-contracts.md` section 14 shows it.
Map<String, Object?> productJson({String priceMode = 'estimate'}) =>
    <String, Object?>{
      'id': productId,
      'category_id': categoryId,
      'name_uz': 'Pomidor',
      'name_ru': 'Помидор',
      'description_uz': null,
      'description_ru': null,
      'unit_code': 'kg',
      'price_mode': priceMode,
      'customer_unit_price_uzs': 18400,
      'image_url': 'https://api.test/storage/products/p.webp',
      'is_active': true,
    };

Map<String, Object?> categoryJson() => <String, Object?>{
  'id': categoryId,
  'name_uz': 'Sabzavotlar',
  'name_ru': 'Овощи',
  'description_uz': null,
  'description_ru': null,
  'sort_order': 0,
};

Map<String, Object?> page(List<Object?> items, {int page = 1, int last = 1}) =>
    <String, Object?>{
      'data': items,
      'meta': <String, Object?>{
        'pagination': <String, int>{
          'page': page,
          'per_page': 20,
          'total': items.length,
          'last_page': last,
        },
      },
    };

void main() {
  test('an id off the contract is refused', () {
    for (final Map<String, Object?> broken in <Map<String, Object?>>[
      <String, Object?>{...productJson(), 'id': 'p-1'},
      <String, Object?>{...productJson(), 'category_id': 'c-1'},
    ]) {
      expect(() => CatalogApi.parseProduct(broken), throwsFormatException);
    }
    expect(
      () => CatalogApi.parseCategory(<String, Object?>{
        ...categoryJson(),
        'id': 'c-1',
      }),
      throwsFormatException,
    );
  });

  test('a search is trimmed and cut to what the server takes', () {
    expect(ProductListQuery.searchOf('  olma  '), 'olma');
    expect(
      ProductListQuery.searchOf('a' * 150),
      'a' * ProductListQuery.searchMaxLength,
    );
  });

  test('a product parses with the customer price and no market price', () {
    final CatalogProduct product = CatalogApi.parseProduct(productJson());

    expect(product.customerUnitPriceUzs, 18400);
    expect(product.unitCode, UnitCode.kg);
    expect(product.priceMode, PriceMode.estimate);
    expect(product.imageUrl, 'https://api.test/storage/products/p.webp');
    expect(
      () => CatalogApi.parseProduct(<String, Object?>{
        ...productJson(),
        'customer_unit_price_uzs': null,
      }),
      throwsFormatException,
    );
    expect(
      () => CatalogApi.parseProduct(<String, Object?>{
        ...productJson(),
        'price_mode': 'auction',
      }),
      throwsFormatException,
    );
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late CatalogRepositoryImpl repository;

    setUp(() {
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        if (options.path == '/catalog/categories') {
          return jsonReply(200, page(<Object?>[categoryJson()]));
        }
        if (options.path == '/catalog/products') {
          return jsonReply(
            200,
            page(<Object?>[productJson()], page: 2, last: 3),
          );
        }
        return jsonReply(200, <String, Object?>{'data': productJson()});
      });
      repository = CatalogRepositoryImpl(CatalogApi(dioWith(adapter)));
    });

    SessionSlot? slotOf(RequestOptions options) =>
        RequestSlot.resolve(options, () => SessionSlot.staff);

    test('every request goes on the Customer session', () async {
      await repository.categories();
      await repository.products(const ProductListQuery(), page: 1);
      await repository.product('p-1');

      for (final RequestOptions request in adapter.requests) {
        expect(slotOf(request), SessionSlot.customer, reason: request.path);
      }
    });

    test('categories come as one page of 100', () async {
      final List<CatalogCategory> categories = await repository.categories();

      expect(categories.single.nameRu, 'Овощи');
      expect(adapter.requests.single.queryParameters, <String, Object>{
        'per_page': 100,
      });
    });

    test(
      'products send the page, the category and the trimmed search',
      () async {
        final Paged<CatalogProduct> products = await repository.products(
          const ProductListQuery(categoryId: categoryId, search: '  pomi '),
          page: 2,
        );

        expect(adapter.requests.single.queryParameters, <String, Object>{
          'page': 2,
          'per_page': 20,
          'category_id': categoryId,
          'search': 'pomi',
        });
        expect(products.hasNext, isTrue);
      },
    );

    test('a product is read by its id', () async {
      await repository.product(productId);

      expect(adapter.requests.single.path, '/catalog/products/$productId');
    });
  });
}
