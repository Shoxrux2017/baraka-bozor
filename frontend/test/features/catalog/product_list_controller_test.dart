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

  group('in-place operations on a favourites list (DL-129)', () {
    const ProductListQuery mine = ProductListQuery.favorites();

    ProductListController listOf() =>
        container.read(productListProvider(mine).notifier);
    ProductListState favState() =>
        container.read(productListProvider(mine)).requireValue;

    setUp(() {
      container.listen(productListProvider(mine), (_, _) {});
    });

    test('withdraw takes loaded products out with their places and lowers the counts', () async {
      await container.read(productListProvider(mine).future);

      final ListWithdrawal? w = listOf().withdraw(<String>{'f-2', 'f-23'});

      expect(w, isNotNull);
      expect(favState().items, hasLength(19), reason: 'f-23 was not loaded');
      expect(
        favState().items.map((CatalogProduct p) => p.id),
        isNot(contains('f-2')),
      );
      expect(favState().total, 24);
      expect(favState().unavailable, 3);
      expect(listOf().withdraw(<String>{'f-23', 'nope'}), isNull);
    });

    test('restore puts them back at their places with the counts and the next page', () async {
      await container.read(productListProvider(mine).future);
      final List<String> before = <String>[
        for (final CatalogProduct p in favState().items) p.id,
      ];

      final ListWithdrawal w = listOf().withdraw(<String>{'f-2', 'f-5'})!;
      listOf().restore(w);

      expect(<String>[
        for (final CatalogProduct p in favState().items) p.id,
      ], before);
      expect(favState().total, 25);
      expect(favState().nextPage, 2);
    });

    test('restore after the list was rebuilt changes nothing', () async {
      await container.read(productListProvider(mine).future);
      final ListWithdrawal w = listOf().withdraw(<String>{'f-2'})!;

      container.read(_account.notifier).signIn('c-2');
      await container.read(productListProvider(mine).future);
      listOf().restore(w);

      expect(favState().items, hasLength(20));
      expect(favState().total, 25);
    });

    test('withdrawNotSold takes every not-sold product, loaded or not, and ends the list', () async {
      favorites.rows = <CatalogProduct>[
        for (int i = 1; i <= 45; i++)
          catalogProduct(id: 'f-$i', isFavorite: true, isAvailable: i <= 20),
      ];
      await container.read(productListProvider(mine).future);
      await listOf().loadMore();
      expect(favState().items, hasLength(40));

      final ListWithdrawal? w = listOf().withdrawNotSold();

      expect(w, isNotNull);
      expect(favState().items, hasLength(20));
      expect(favState().total, 20);
      expect(favState().unavailable, 0);
      expect(favState().hasMore, isFalse);

      listOf().restore(w!);
      expect(favState().items, hasLength(40));
      expect(favState().total, 45);
      expect(favState().unavailable, 25);
      expect(favState().nextPage, 3);
    });

    test('after a settled removal the next page neither skips nor repeats a product', () async {
      favorites.rows = <CatalogProduct>[
        for (int i = 1; i <= 30; i++)
          catalogProduct(id: 'f-$i', isFavorite: true),
      ];
      await container.read(productListProvider(mine).future);

      final ListWithdrawal w = listOf().withdraw(<String>{'f-3'})!;
      await favorites.remove('f-3');
      listOf().settle(w);
      await listOf().loadMore();
      await listOf().loadMore();

      final List<String> ids = <String>[
        for (final CatalogProduct p in favState().items) p.id,
      ];
      expect(ids, hasLength(29));
      expect(ids.toSet(), hasLength(29));
      expect(ids.toSet(), <String>{
        for (final CatalogProduct p in favorites.rows) p.id,
      });
      expect(favState().hasMore, isFalse);
    });

    test('put adds a product at the top and counts it', () async {
      await container.read(productListProvider(mine).future);

      listOf().put(catalogProduct(id: 'f-new', isFavorite: true));

      expect(favState().items.first.id, 'f-new');
      expect(favState().items, hasLength(21));
      expect(favState().total, 26);
    });

    test(
      'quietRefresh reloads as many pages as were loaded with no loading state',
      () async {
        await container.read(productListProvider(mine).future);
        await listOf().loadMore();
        favorites.rows = favorites.rows.sublist(1);
        favorites.requests.clear();
        final List<AsyncValue<ProductListState>> seen =
            <AsyncValue<ProductListState>>[];
        container.listen(
          productListProvider(mine),
          (_, AsyncValue<ProductListState> next) => seen.add(next),
        );

        await listOf().quietRefresh();

        expect(favorites.requests, <String>['default|1', 'default|2']);
        expect(favState().items, hasLength(24));
        expect(favState().total, 24);
        expect(
          seen.any((AsyncValue<ProductListState> v) => v.isLoading),
          isFalse,
        );
        expect(
          seen.any((AsyncValue<ProductListState> v) => v.hasError),
          isFalse,
        );
      },
    );

    test(
      'a quietRefresh that fails keeps the list under its failure',
      () async {
        await container.read(productListProvider(mine).future);
        favorites.listFailure = const NetworkFailure();

        await listOf().quietRefresh();

        final AsyncValue<ProductListState> now0 = container.read(
          productListProvider(mine),
        );
        expect(now0.hasError, isTrue);
        expect(now0.isLoading, isFalse);
        expect(now0.error, isA<NetworkFailure>());
        expect(now0.value!.items, hasLength(20));
      },
    );

    test('a page loaded during a quietRefresh is dropped', () async {
      await container.read(productListProvider(mine).future);
      final Completer<void> gate = Completer<void>();
      favorites.listHold = gate;

      final Future<void> refresh = listOf().quietRefresh();
      final Future<void> more = listOf().loadMore();
      favorites.listHold = null;
      gate.complete();
      await refresh;
      await more;

      expect(favState().items, hasLength(20));
      expect(favState().loadingMore, isFalse);
      expect(favState().nextPage, 2);
    });

    test('a page on its way when a product is withdrawn is dropped and asked again', () async {
      await container.read(productListProvider(mine).future);
      final Completer<void> gate = Completer<void>();
      favorites.listHold = gate;

      final Future<void> more = listOf().loadMore();
      expect(favState().loadingMore, isTrue);
      listOf().withdraw(<String>{'f-2'});
      expect(favState().loadingMore, isFalse);
      favorites.listHold = null;
      gate.complete();
      await more;

      expect(favState().items, hasLength(19));
      await listOf().loadMore();
      expect(favorites.requests, <String>[
        'default|1',
        'default|2',
        'default|2',
      ]);
      expect(favState().items, hasLength(24));
    });

    test(
      'a page that lands while a withdrawal is held keeps it out of the count',
      () async {
        await container.read(productListProvider(mine).future);
        listOf().withdraw(<String>{'f-20'});
        // A new favourite ahead shifts f-20 onto the next page.
        favorites.rows = <CatalogProduct>[
          catalogProduct(id: 'f-0', isFavorite: true),
          ...favorites.rows,
        ];

        await listOf().loadMore();

        expect(
          favState().items.map((CatalogProduct p) => p.id),
          isNot(contains('f-20')),
        );
        expect(favState().total, 25);
        expect(favState().unavailable, 3);
      },
    );

    test(
      'restore after a later page counts back from the current total',
      () async {
        await container.read(productListProvider(mine).future);
        final ListWithdrawal w = listOf().withdraw(<String>{'f-2'})!;
        favorites.rows = <CatalogProduct>[
          catalogProduct(id: 'f-0', isFavorite: true),
          ...favorites.rows,
        ];
        await listOf().loadMore();
        expect(favState().total, 25);

        listOf().restore(w);

        expect(favState().total, 26);
        expect(
          favState().items.map((CatalogProduct p) => p.id),
          contains('f-2'),
        );
      },
    );

    test('a withdrawal during a quietRefresh drops the refresh', () async {
      await container.read(productListProvider(mine).future);
      final Completer<void> gate = Completer<void>();
      favorites.listHold = gate;

      final Future<void> refresh = listOf().quietRefresh();
      listOf().withdraw(<String>{'f-2'});
      favorites.listHold = null;
      gate.complete();
      await refresh;

      expect(favState().items, hasLength(19));
      expect(favState().total, 24);
    });

    test('quietRefresh does nothing while a withdrawal is held', () async {
      await container.read(productListProvider(mine).future);
      final ListWithdrawal w = listOf().withdraw(<String>{'f-2'})!;
      favorites.requests.clear();

      await listOf().quietRefresh();
      expect(favorites.requests, isEmpty);

      listOf().settle(w);
      await listOf().quietRefresh();
      expect(favorites.requests, <String>['default|1']);
    });

    test('two held withdrawals both stay out of a later page', () async {
      favorites.pageSize = 5;
      favorites.rows = <CatalogProduct>[
        for (int i = 1; i <= 12; i++)
          catalogProduct(id: 'f-$i', isFavorite: true, isAvailable: i <= 9),
      ];
      container.invalidate(productListProvider(mine));
      await container.read(productListProvider(mine).future);
      await listOf().loadMore();
      listOf().withdraw(<String>{'f-10'});
      listOf().withdraw(<String>{'f-1'});
      expect(favState().total, 10);

      await listOf().loadMore();

      expect(favState().items, hasLength(10));
      expect(favState().total, 10);
      expect(favState().unavailable, 2);
      final List<String> ids = <String>[
        for (final CatalogProduct p in favState().items) p.id,
      ];
      expect(ids, isNot(contains('f-10')));
      expect(ids, isNot(contains('f-1')));
    });
  });
}
