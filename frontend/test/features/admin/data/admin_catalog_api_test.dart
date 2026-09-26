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

const String categoryId = '0f0e3c6a-6b1f-4f7e-9a51-2d6c1c1e9a01';
const String productId = '5b2a1c3d-8e4f-4a6b-9c7d-1e2f3a4b5c6d';

/// A category as `docs/09-api-contracts.md` section 15 returns it.
Map<String, Object?> categoryJson({String? archivedAt}) => <String, Object?>{
  'id': categoryId,
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
  'id': productId,
  'category_id': categoryId,
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
        <String, Object?>{...productJson(), 'id': 'p-1'},
        <String, Object?>{...productJson(), 'category_id': 'c-1'},
        // `DL-17` (14): an archived entry is never active.
        <String, Object?>{
          ...productJson(),
          'archived_at': '2026-09-26T06:00:00Z',
        },
      ]) {
        expect(
          () => AdminCatalogDto.parseProduct(broken),
          throwsFormatException,
        );
      }
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        <String, Object?>{...categoryJson(), 'name_uz': ''},
        <String, Object?>{...categoryJson(), 'id': 'c-1'},
        <String, Object?>{
          ...categoryJson(archivedAt: '2026-09-26T06:00:00Z'),
          'is_active': true,
        },
      ]) {
        expect(
          () => AdminCatalogDto.parseCategory(broken),
          throwsFormatException,
        );
      }
    });

    test('a page is its items and its pagination', () {
      final Paged<AdminCategory> page = Paged.parse(
        pageOf(<Object?>[categoryJson()], page: 2, lastPage: 3),
        AdminCatalogDto.parseCategory,
      );
      expect(page.items.single.id, categoryId);
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
        categoryId: categoryId,
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
        'category_id': categoryId,
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

    test('an edit sends only what changed from what it was made from', () {
      final AdminProduct product = AdminCatalogDto.parseProduct(productJson());
      final ProductDraft unchanged = ProductDraft.fromProduct(product);

      expect(AdminCatalogDto.productBody(unchanged, base: product), isEmpty);
      expect(
        AdminCatalogDto.productBody(
          ProductDraft(
            categoryId: unchanged.categoryId,
            nameUz: unchanged.nameUz,
            nameRu: 'Помидоры',
            descriptionUz: unchanged.descriptionUz,
            descriptionRu: unchanged.descriptionRu,
            unitCode: unchanged.unitCode,
            priceMode: unchanged.priceMode,
            marketPriceUzs: 17000,
            sortOrder: unchanged.sortOrder,
            isActive: false,
          ),
          base: product,
        ),
        <String, Object?>{
          'name_ru': 'Помидоры',
          'market_price_uzs': 17000,
          'is_active': false,
        },
      );

      final AdminCategory archived = AdminCatalogDto.parseCategory(
        categoryJson(archivedAt: '2026-09-26T06:00:00Z'),
      );
      final CategoryDraft kept = CategoryDraft.fromCategory(archived);
      expect(kept.isActive, isNull);
      expect(
        AdminCatalogDto.categoryBody(
          CategoryDraft(
            nameUz: kept.nameUz,
            nameRu: kept.nameRu,
            descriptionUz: 'Yangi',
            descriptionRu: kept.descriptionRu,
            sortOrder: kept.sortOrder,
            isActive: null,
          ),
          base: archived,
        ),
        <String, Object?>{'description_uz': 'Yangi'},
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
          categoryId: categoryId,
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
        'category_id': categoryId,
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

      await repository.archiveCategory(categoryId);
      await repository.restoreCategory(categoryId);
      await repository.archiveProduct(productId);
      await repository.restoreProduct(productId);
      await repository.removeImage(productId);
      await repository.product(productId);

      expect(
        adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
        <String>[
          'POST /admin/categories/$categoryId/archive',
          'POST /admin/categories/$categoryId/restore',
          'POST /admin/products/$productId/archive',
          'POST /admin/products/$productId/restore',
          'DELETE /admin/products/$productId/image',
          'GET /admin/products/$productId',
        ],
      );
      for (final RequestOptions request in adapter.requests) {
        expect(slotOf(request), SessionSlot.staff);
      }
    });

    test('a new entry is sent whole, an edit only as its changes', () async {
      reply = (RequestOptions options) =>
          jsonReply(options.method == 'POST' ? 201 : 200, <String, Object?>{
            'data': options.path.startsWith('/admin/categories')
                ? categoryJson()
                : productJson(),
          });
      final AdminCategory category = AdminCatalogDto.parseCategory(
        categoryJson(),
      );
      final AdminProduct product = AdminCatalogDto.parseProduct(productJson());
      final CategoryDraft categoryDraft = CategoryDraft.fromCategory(category);
      final ProductDraft productDraft = ProductDraft.fromProduct(product);

      await repository.createCategory(categoryDraft);
      await repository.updateCategory(
        category,
        CategoryDraft(
          nameUz: categoryDraft.nameUz,
          nameRu: categoryDraft.nameRu,
          descriptionUz: categoryDraft.descriptionUz,
          descriptionRu: categoryDraft.descriptionRu,
          sortOrder: 5,
          isActive: categoryDraft.isActive,
        ),
      );
      await repository.createProduct(productDraft);
      await repository.updateProduct(
        product,
        ProductDraft(
          categoryId: productDraft.categoryId,
          nameUz: 'Pomidorlar',
          nameRu: productDraft.nameRu,
          descriptionUz: productDraft.descriptionUz,
          descriptionRu: productDraft.descriptionRu,
          unitCode: productDraft.unitCode,
          priceMode: productDraft.priceMode,
          marketPriceUzs: productDraft.marketPriceUzs,
          sortOrder: productDraft.sortOrder,
          isActive: productDraft.isActive,
        ),
      );

      expect(
        adapter.requests.map((RequestOptions o) => '${o.method} ${o.path}'),
        <String>[
          'POST /admin/categories',
          'PATCH /admin/categories/$categoryId',
          'POST /admin/products',
          'PATCH /admin/products/$productId',
        ],
      );
      expect(
        adapter.requests[0].data,
        AdminCatalogDto.categoryBody(categoryDraft),
      );
      expect(adapter.requests[1].data, <String, Object?>{'sort_order': 5});
      expect(
        adapter.requests[2].data,
        AdminCatalogDto.productBody(productDraft),
      );
      expect(adapter.requests[3].data, <String, Object?>{
        'name_uz': 'Pomidorlar',
      });
      for (final RequestOptions request in adapter.requests) {
        expect(slotOf(request), SessionSlot.staff);
      }
    });

    test('an edit that changes nothing sends nothing', () async {
      final AdminCategory category = AdminCatalogDto.parseCategory(
        categoryJson(),
      );
      final AdminProduct product = AdminCatalogDto.parseProduct(productJson());

      expect(
        await repository.updateCategory(
          category,
          CategoryDraft.fromCategory(category),
        ),
        same(category),
      );
      expect(
        await repository.updateProduct(
          product,
          ProductDraft.fromProduct(product),
        ),
        same(product),
      );
      expect(adapter.requests, isEmpty);
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

      await repository.uploadImage(productId, image);

      final RequestOptions request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/admin/products/$productId/image');
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
        repository.restoreProduct(productId),
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
