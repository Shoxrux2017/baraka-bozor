import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/platform/clock.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_favorites_repository.dart';

class _Account extends Notifier<String?> {
  @override
  String? build() => 'c-1';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

/// Infinite pagination and its async safety (`docs/07-architecture.md`
/// section 28).
void main() {
  late FakeCatalogRepository catalog;
  late FakeFavoritesRepository favorites;
  late ProviderContainer container;
  // 12:46 in Tashkent (UTC+5).
  DateTime now = DateTime.utc(2026, 11, 3, 7, 46);
  const ProductListQuery all = ProductListQuery();

  setUp(() {
    now = DateTime.utc(2026, 11, 3, 7, 46);
    catalog = FakeCatalogRepository(
      products: <CatalogProduct>[
        for (int i = 1; i <= 45; i++)
          catalogProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
      ],
    );
    favorites = FakeFavoritesRepository(
      favorites: <CatalogProduct>[
        for (int i = 1; i <= 25; i++)
          catalogProduct(
            id: 'f-$i',
            isFavorite: true,
            isAvailable: i <= 22,
            customerUnitPriceUzs: 1000 * i,
          ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(catalog),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        clockProvider.overrideWithValue(() => now),
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(productListProvider(all), (_, _) {});
  });

  ProductListState stateOf() =>
      container.read(productListProvider(all)).requireValue;

  test('pages load one after another until the list ends', () async {
    await container.read(productListProvider(all).future);
    expect(stateOf().items, hasLength(20));
    expect(stateOf().hasMore, isTrue);

    await container.read(productListProvider(all).notifier).loadMore();
    await container.read(productListProvider(all).notifier).loadMore();

    expect(stateOf().items, hasLength(45));
    expect(stateOf().items.last.id, 'p-45');
    expect(stateOf().hasMore, isFalse);

    await container.read(productListProvider(all).notifier).loadMore();
    expect(catalog.requests, <String>['|null|1', '|null|2', '|null|3']);
  });

  test(
    'a second request for the next page while one runs is not sent',
    () async {
      await container.read(productListProvider(all).future);
      final Completer<void> gate = Completer<void>();
      catalog.gates[''] = gate;

      final Future<void> first = container
          .read(productListProvider(all).notifier)
          .loadMore();
      await container.read(productListProvider(all).notifier).loadMore();
      gate.complete();
      await first;

      expect(catalog.requests, <String>['|null|1', '|null|2']);
      expect(stateOf().items, hasLength(40));
    },
  );

  test(
    'a failed next page keeps what was loaded and can be tried again',
    () async {
      await container.read(productListProvider(all).future);
      catalog.nextFailure = const NetworkFailure();

      await container.read(productListProvider(all).notifier).loadMore();
      expect(stateOf().items, hasLength(20));
      expect(stateOf().moreFailure, isA<NetworkFailure>());
      expect(stateOf().hasMore, isTrue);

      await container.read(productListProvider(all).notifier).loadMore();
      expect(stateOf().items, hasLength(40));
      expect(stateOf().moreFailure, isNull);
    },
  );

  test(
    'a page that arrives after another account signed in is dropped',
    () async {
      await container.read(productListProvider(all).future);
      final Completer<void> gate = Completer<void>();
      catalog.gates[''] = gate;

      final Future<void> pending = container
          .read(productListProvider(all).notifier)
          .loadMore();
      container.read(_account.notifier).signIn('c-2');
      catalog.gates.remove('');
      await container.read(productListProvider(all).future);
      gate.complete();
      await pending;

      expect(
        stateOf().items,
        hasLength(20),
        reason: 'the new account sees its own first page',
      );
      expect(stateOf().loadingMore, isFalse);
    },
  );

  test(
    'a favourites query asks the favourites repository with its order',
    () async {
      const ProductListQuery cheapest = ProductListQuery.favorites(
        sort: ProductSort.priceAsc,
      );
      container.listen(productListProvider(cheapest), (_, _) {});
      final ProductListState first = await container.read(
        productListProvider(cheapest).future,
      );

      expect(favorites.requests, <String>['price_asc|1']);
      expect(catalog.requests, <String>[
        '|null|1',
      ], reason: 'the catalog is asked only by the list the setUp holds');
      expect(first.items, hasLength(20));
      expect(first.total, 25);
      expect(first.unavailable, 3);
      expect(first.perPage, 20);
      expect(first.hasMore, isTrue);

      await container.read(productListProvider(cheapest).notifier).loadMore();
      final ProductListState both = container
          .read(productListProvider(cheapest))
          .requireValue;
      expect(favorites.requests, <String>['price_asc|1', 'price_asc|2']);
      expect(both.items, hasLength(25));
      expect(both.items.last.isAvailable, isFalse);
      expect(both.unavailable, 3);
      expect(both.hasMore, isFalse);
      expect(
        const ProductListQuery.favorites(),
        isNot(const ProductListQuery()),
        reason: 'a favourites list is not the all-products list',
      );
    },
  );

  test(
    'a favourites page that comes for a previous account is dropped',
    () async {
      const ProductListQuery mine = ProductListQuery.favorites();
      container.listen(productListProvider(mine), (_, _) {});
      await container.read(productListProvider(mine).future);
      final Completer<void> gate = Completer<void>();
      favorites.listHold = gate;

      final Future<void> pending = container
          .read(productListProvider(mine).notifier)
          .loadMore();
      container.read(_account.notifier).signIn('c-2');
      favorites.listHold = null;
      await container.read(productListProvider(mine).future);
      gate.complete();
      await pending;

      final ProductListState state = container
          .read(productListProvider(mine))
          .requireValue;
      expect(
        state.items,
        hasLength(20),
        reason: 'the first page of the new account',
      );
      expect(state.loadingMore, isFalse);
    },
  );

  test('a list rebuilt for no account is not continued', () async {
    await container.read(productListProvider(all).future);
    final int asked = catalog.requests.length;

    container.read(_account.notifier).signIn(null);
    await container.read(productListProvider(all).notifier).loadMore();

    expect(catalog.requests, hasLength(asked));
  });

  test('a product a later page repeats is shown once', () async {
    await container.read(productListProvider(all).future);
    // A new product ahead of the others shifts every later page by one.
    catalog.productRows = <CatalogProduct>[
      catalogProduct(id: 'p-new', nameUz: 'Yangi', nameRu: 'Новый'),
      ...catalog.productRows,
    ];

    await container.read(productListProvider(all).notifier).loadMore();

    final List<String> ids = <String>[
      for (final CatalogProduct p in stateOf().items) p.id,
    ];
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, hasLength(39));
  });

  test('the list keeps the time its first page came', () async {
    await container.read(productListProvider(all).future);
    expect(stateOf().at, DateTime.utc(2026, 11, 3, 7, 46));

    now = DateTime.utc(2026, 11, 3, 7, 50);
    await container.read(productListProvider(all).notifier).loadMore();
    expect(stateOf().items, hasLength(40));
    expect(stateOf().at, DateTime.utc(2026, 11, 3, 7, 46));

    catalog.nextFailure = const NetworkFailure();
    await container.read(productListProvider(all).notifier).loadMore();
    expect(stateOf().moreFailure, isNotNull);
    expect(stateOf().at, DateTime.utc(2026, 11, 3, 7, 46));
  });

  test('loadThrough loads pages until the count', () async {
    await container.read(productListProvider(all).future);
    final ProductListController list = container.read(
      productListProvider(all).notifier,
    );

    await list.loadThrough(10);
    expect(stateOf().items, hasLength(20), reason: 'already there');

    await list.loadThrough(30);
    expect(stateOf().items, hasLength(40));
    expect(catalog.requests, <String>['|null|1', '|null|2']);

    await list.loadThrough(100);
    expect(stateOf().items, hasLength(45));
    expect(stateOf().hasMore, isFalse);
    expect(catalog.requests, hasLength(3), reason: 'nothing past the end');
  });

  test('loadThrough stops at a failure', () async {
    await container.read(productListProvider(all).future);
    final ProductListController list = container.read(
      productListProvider(all).notifier,
    );
    catalog.nextFailure = const NetworkFailure();

    await list.loadThrough(45);

    expect(stateOf().items, hasLength(20));
    expect(stateOf().moreFailure, isA<NetworkFailure>());
    expect(catalog.requests, <String>['|null|1', '|null|2']);

    await list.loadThrough(45);
    expect(catalog.requests, hasLength(2), reason: 'no retry of its own');
  });

  test('loadThrough waits for a page already on its way', () async {
    await container.read(productListProvider(all).future);
    final ProductListController list = container.read(
      productListProvider(all).notifier,
    );
    final Completer<void> gate = Completer<void>();
    catalog.gates[''] = gate;

    final Future<void> first = list.loadMore();
    final Future<void> through = list.loadThrough(45);
    catalog.gates.remove('');
    gate.complete();
    await first;
    await through;

    expect(stateOf().items, hasLength(45));
    expect(catalog.requests, <String>['|null|1', '|null|2', '|null|3']);
  });

  test(
    'loadThrough ends when the list is rebuilt for another account',
    () async {
      await container.read(productListProvider(all).future);
      final ProductListController list = container.read(
        productListProvider(all).notifier,
      );
      final Completer<void> gate = Completer<void>();
      catalog.gates[''] = gate;

      final Future<void> through = list.loadThrough(45);
      container.read(_account.notifier).signIn('c-2');
      catalog.gates.remove('');
      await container.read(productListProvider(all).future);
      gate.complete();
      await through;

      expect(stateOf().items, hasLength(20));
    },
  );
}
