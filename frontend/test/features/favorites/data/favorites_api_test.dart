import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/favorites/data/favorites_api.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../catalog/catalog_api_test.dart' show page, productId, productJson;

/// The favourites' data source against `docs/09-api-contracts.md` section 14.
void main() {
  late FakeHttpClientAdapter adapter;
  late FavoritesRepositoryImpl repository;
  bool available = true;
  Map<String, Object?>? answeredEntry;

  setUp(() {
    available = true;
    answeredEntry = null;
    adapter = FakeHttpClientAdapter((RequestOptions options) {
      if (options.method == 'GET') {
        return jsonReply(
          200,
          page(
            <Object?>[
              answeredEntry ??
                  <String, Object?>{
                    ...productJson(isFavorite: true),
                    'is_available': available,
                  },
            ],
            page: options.queryParameters['page']! as int,
            last: 2,
          ),
        );
      }
      return emptyReply(204);
    });
    repository = FavoritesRepositoryImpl(FavoritesApi(dioWith(adapter)));
  });

  test('a page parses the products and whether each is available', () async {
    final Paged<FavoriteProduct> first = await repository.list(page: 1);
    available = false;
    final Paged<FavoriteProduct> second = await repository.list(page: 2);

    expect(first.items.single.product.id, productId);
    expect(first.items.single.product.isFavorite, isTrue);
    expect(first.items.single.isAvailable, isTrue);
    expect(first.hasNext, isTrue);
    expect(second.items.single.isAvailable, isFalse);
    final RequestOptions request = adapter.requests.first;
    expect(request.method, 'GET');
    expect(request.path, '/customer/favorites');
    expect(request.queryParameters['page'], 1);
    expect(
      RequestSlot.resolve(request, () => SessionSlot.staff),
      SessionSlot.customer,
    );
  });

  test('an entry without is_available is a malformed response', () async {
    answeredEntry = productJson(isFavorite: true);

    await expectLater(
      repository.list(page: 1),
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
}
