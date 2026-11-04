import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/favorites/data/favorites_api.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../catalog/catalog_api_test.dart' show page, productId, productJson;

/// The favourites' data source against `docs/09-api-contracts.md` section 58.
void main() {
  late FakeHttpClientAdapter adapter;
  late FavoritesRepositoryImpl repository;
  bool available = true;
  int? unavailableCount = 2;
  Map<String, Object?>? answeredEntry;

  setUp(() {
    available = true;
    unavailableCount = 2;
    answeredEntry = null;
    adapter = FakeHttpClientAdapter((RequestOptions options) {
      if (options.method == 'GET') {
        final Map<String, Object?> body = page(
          <Object?>[
            answeredEntry ??
                <String, Object?>{
                  ...productJson(isFavorite: true),
                  'is_available': available,
                },
          ],
          page: options.queryParameters['page']! as int,
          last: 2,
        );
        final Map<String, Object?> meta = body['meta']! as Map<String, Object?>;
        return jsonReply(200, <String, Object?>{
          ...body,
          'meta': <String, Object?>{
            ...meta,
            'unavailable_count': ?unavailableCount,
          },
        });
      }
      return emptyReply(204);
    });
    repository = FavoritesRepositoryImpl(FavoritesApi(dioWith(adapter)));
  });

  test(
    'the favourites ask for the order and read the not-sold count',
    () async {
      final FavoritesPage first = await repository.list(
        sort: ProductSort.priceAsc,
        page: 1,
      );

      expect(first.unavailable, 2);
      expect(first.products.items.single.id, productId);
      expect(first.products.items.single.isFavorite, isTrue);
      expect(first.products.hasNext, isTrue);
      final RequestOptions request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/customer/favorites');
      expect(request.queryParameters['page'], 1);
      expect(request.queryParameters['sort'], 'price_asc');
      expect(
        RequestSlot.resolve(request, () => SessionSlot.staff),
        SessionSlot.customer,
      );

      await repository.list(sort: ProductSort.shop, page: 2);
      expect(
        adapter.requests.last.queryParameters.containsKey('sort'),
        isFalse,
        reason: 'the default order is the server\'s default',
      );
    },
  );

  test('a favourite reads is_available into the product', () async {
    final FavoritesPage sold = await repository.list(
      sort: ProductSort.shop,
      page: 1,
    );
    available = false;
    final FavoritesPage gone = await repository.list(
      sort: ProductSort.shop,
      page: 2,
    );

    expect(sold.products.items.single.isAvailable, isTrue);
    expect(gone.products.items.single.isAvailable, isFalse);
  });

  test('an entry without is_available is a malformed response', () async {
    answeredEntry = productJson(isFavorite: true);

    await expectLater(
      repository.list(sort: ProductSort.shop, page: 1),
      throwsA(isA<MalformedResponseFailure>()),
    );
  });

  test('a page without unavailable_count is malformed', () async {
    unavailableCount = null;

    await expectLater(
      repository.list(sort: ProductSort.shop, page: 1),
      throwsA(isA<MalformedResponseFailure>()),
    );
  });

  test('add is a PUT and remove a DELETE, both without a body', () async {
    await repository.add(productId);
    await repository.remove(productId);

    expect(adapter.requests.map((RequestOptions r) => r.method), <String>[
      'PUT',
      'DELETE',
    ]);
    for (final RequestOptions request in adapter.requests) {
      expect(request.path, '/customer/favorites/$productId');
      expect(request.data, isNull);
      expect(
        RequestSlot.resolve(request, () => SessionSlot.staff),
        SessionSlot.customer,
      );
    }
  });

  test('removeNotSold deletes the not-sold favourites', () async {
    await repository.removeNotSold();

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/customer/favorites/unavailable');
    expect(request.data, isNull);
    expect(
      RequestSlot.resolve(request, () => SessionSlot.staff),
      SessionSlot.customer,
    );
  });
}
