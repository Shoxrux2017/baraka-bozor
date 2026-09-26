import 'dart:typed_data';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/data/admin_catalog_api.dart';
import 'package:baraka_bozor/features/admin/data/admin_catalog_dto.dart';
import 'package:baraka_bozor/features/admin/data/admin_catalog_repository_impl.dart';
import 'package:baraka_bozor/features/admin/domain/admin_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

/// A category as `docs/09-api-contracts.md` section 15 returns it.
Map<String, Object?> categoryJson({String? archivedAt}) => <String, Object?>{
  'id': 'c-1',
  'name_uz': 'Sabzavotlar',
  'name_ru': 'Овощи',
  'description_uz': null,
  'description_ru': 'Свежие',
  'sort_order': 2,
  'is_active': archivedAt == null,
  'archived_at': archivedAt,
  'created_at': '2026-09-26T05:00:00Z',
  'updated_at': '2026-09-26T05:00:00Z',
};

/// A product as sections 15 and 16 return it.
Map<String, Object?> productJson({String? imageUrl}) => <String, Object?>{
  'id': 'p-1',
  'category_id': 'c-1',
  'name_uz': 'Pomidor',
  'name_ru': 'Помидор',
  'description_uz': null,
  'description_ru': null,
  'unit_code': 'kg',
  'price_mode': 'estimate',
  'market_price_uzs': 16000,
  'customer_unit_price_uzs': 18400,
  'image_url': imageUrl,
  'sort_order': 0,
  'is_active': true,
  'archived_at': null,
  'created_at': '2026-09-26T05:00:00Z',
  'updated_at': '2026-09-26T05:00:00Z',
};

Map<String, Object?> pageOf(
  List<Object?> items, {
  int page = 1,
  int lastPage = 1,
}) => <String, Object?>{
  'data': items,
  'meta': <String, Object?>{
    'pagination': <String, int>{
      'page': page,
      'per_page': 20,
      'total': items.length,
      'last_page': lastPage,
    },
  },
};

void main() {
  group('parsing', () {
    test('a category and its state', () {
      final AdminCategory active = AdminCatalogDto.parseCategory(
        categoryJson(),
      );
      expect(active.nameRu, 'Овощи');
      expect(active.descriptionUz, isNull);
      expect(active.state, CatalogEntryState.active);

      final AdminCategory archived = AdminCatalogDto.parseCategory(
        categoryJson(archivedAt: '2026-09-26T06:00:00Z'),
      );
      expect(archived.state, CatalogEntryState.archived);
      expect(
        AdminCatalogDto.parseCategory(<String, Object?>{
          ...categoryJson(),
          'is_active': false,
        }).state,
        CatalogEntryState.hidden,
      );
    });

    test('a product with its prices, unit and image', () {
      final AdminProduct parsed = AdminCatalogDto.parseProduct(
        productJson(imageUrl: 'https://api.test/storage/products/a.webp'),
      );

      expect(parsed.unitCode, UnitCode.kg);
      expect(parsed.priceMode, PriceMode.estimate);
      expect(parsed.marketPriceUzs, 16000);
      expect(parsed.customerUnitPriceUzs, 18400);
      expect(parsed.imageUrl, 'https://api.test/storage/products/a.webp');
    });

    test('a payload that breaks the contract is refused', () {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        <String, Object?>{...productJson(), 'unit_code': 'tonne'},
        <String, Object?>{...productJson(), 'price_mode': 'free'},
        <String, Object?>{...productJson(), 'market_price_uzs': '16000'},
        <String, Object?>{...productJson()}..remove('image_url'),
        <String, Object?>{...productJson(), 'archived_at': 'yesterday'},
      ]) {
        expect(
          () => AdminCatalogDto.parseProduct(broken),
          throwsFormatException,
        );
      }
      expect(
        () => AdminCatalogDto.parseCategory(<String, Object?>{
          ...categoryJson(),
          'name_uz': '',
        }),
        throwsFormatException,
      );
    });

    test('a page is its items and its pagination', () {
      final Paged<AdminCategory> page = Paged.parse(
        pageOf(<Object?>[categoryJson()], page: 2, lastPage: 3),
        AdminCatalogDto.parseCategory,
      );
      expect(page.items.single.id, 'c-1');
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isTrue);

      expect(
        () => Paged.parse(<String, Object?>{
          'data': <Object?>[],
        }, AdminCatalogDto.parseCategory),
        throwsFormatException,
      );
      expect(
        () => Paged.parse(
          pageOf(<Object?>[
            <String, Object?>{'id': 'x'},
          ]),
          AdminCatalogDto.parseCategory,
        ),
        throwsFormatException,
      );
    });

    test('a body sends is_active only when the form offers it', () {
      const ProductDraft draft = ProductDraft(
        categoryId: 'c-1',
        nameUz: 'Pomidor',
        nameRu: 'Помидор',
        descriptionUz: null,
        descriptionRu: 'Свежие',
        unitCode: UnitCode.piece,
        priceMode: PriceMode.fixed,
        marketPriceUzs: 5000,
        sortOrder: -3,
        isActive: null,
      );

      expect(AdminCatalogDto.productBody(draft), <String, Object?>{
        'category_id': 'c-1',
        'name_uz': 'Pomidor',
        'name_ru': 'Помидор',
        'description_uz': null,
        'description_ru': 'Свежие',
        'unit_code': 'piece',
        'price_mode': 'fixed',
        'market_price_uzs': 5000,
        'sort_order': -3,
      });
      expect(
        AdminCatalogDto.categoryBody(
          const CategoryDraft(
            nameUz: 'A',
            nameRu: 'Б',
            descriptionUz: null,
            descriptionRu: null,
            sortOrder: 0,
            isActive: false,
          ),
        )['is_active'],
        isFalse,
      );
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late AdminCatalogRepositoryImpl repository;
    late ResponseBody Function(RequestOptions options) reply;

    setUp(() {
      reply = (RequestOptions options) =>
          jsonReply(200, <String, Object?>{'data': productJson()});
      adapter = FakeHttpClientAdapter((RequestOptions o) => reply(o));
      repository = AdminCatalogRepositoryImpl(
        AdminCatalogApi(dioWith(adapter)),
      );
    });

    SessionSlot? slotOf(RequestOptions options) =>
        RequestSlot.resolve(options, () => SessionSlot.customer);

    test('the product list sends only the filters that are set', () async {
      reply = (RequestOptions options) =>
          jsonReply(200, pageOf(<Object?>[productJson()]));

      await repository.products(const ProductQuery());
      await repository.products(
        const ProductQuery(
          page: 3,
          includeArchived: true,
          categoryId: 'c-1',
          search: '  pomi ',
        ),
      );

      expect(adapter.requests.first.path, '/admin/products');
      expect(adapter.requests.first.queryParameters, <String, Object>{
        'page': 1,
      });
      expect(adapter.requests.last.queryParameters, <String, Object>{
        'page': 3,
        'include_archived': 'true',
        'category_id': 'c-1',
        'search': 'pomi',
      });
      expect(slotOf(adapter.requests.last), SessionSlot.staff);
    });

    test('the category list asks for the page size it needs', () async {
      reply = (RequestOptions options) =>
          jsonReply(200, pageOf(<Object?>[categoryJson()]));

      await repository.categories(
        const CategoryQuery(includeArchived: true),
        perPage: 100,
      );

      expect(adapter.requests.single.path, '/admin/categories');
      expect(adapter.requests.single.queryParameters, <String, Object>{
        'page': 1,
        'per_page': 100,
        'include_archived': 'true',
      });
    });

    test('each action goes to its own path', () async {
      reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
        'data': options.path.startsWith('/admin/categories')
            ? categoryJson()
            : productJson(),
      });

      await repository.archiveCategory('c-1');
      await repository.restoreCategory('c-1');
      await repository.archiveProduct('p-1');
      await repository.restoreProduct('p-1');
      await repository.removeImage('p-1');
      await repository.product('p-1');

      expect(
        adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
        <String>[
          'POST /admin/categories/c-1/archive',
          'POST /admin/categories/c-1/restore',
          'POST /admin/products/p-1/archive',
          'POST /admin/products/p-1/restore',
          'DELETE /admin/products/p-1/image',
          'GET /admin/products/p-1',
        ],
      );
      for (final RequestOptions request in adapter.requests) {
        expect(slotOf(request), SessionSlot.staff);
      }
    });

    test('an image goes as the one multipart field the API takes', () async {
      final PickedImage image = PickedImage(
        bytes: Uint8List.fromList(<int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          1,
          2,
        ]),
        name: 'pomidor.png',
      );

      await repository.uploadImage('p-1', image);

      final RequestOptions request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/admin/products/p-1/image');
      expect(slotOf(request), SessionSlot.staff);
      final FormData form = request.data as FormData;
      expect(form.fields, isEmpty);
      expect(form.files.single.key, 'image');
      expect(form.files.single.value.filename, 'pomidor.png');
      expect(form.files.single.value.length, 10);
      expect(request.contentType, startsWith('multipart/form-data'));
    });

    test('a refusal keeps its code', () async {
      reply = (RequestOptions options) => errorReply(409, 'business_conflict');

      await expectLater(
        repository.restoreProduct('p-1'),
        throwsA(
          isA<ApiRefusal>().having(
            (ApiRefusal r) => r.code,
            'code',
            'business_conflict',
          ),
        ),
      );
    });
  });
}
