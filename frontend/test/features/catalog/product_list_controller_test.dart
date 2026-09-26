import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

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
  late ProviderContainer container;
  const ProductListQuery all = ProductListQuery();

  setUp(() {
    catalog = FakeCatalogRepository(
      products: <CatalogProduct>[
        for (int i = 1; i <= 45; i++)
          catalogProduct(id: 'p-$i', nameUz: 'Mahsulot $i', nameRu: 'Товар $i'),
      ],
    );
    container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(catalog),
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
}
