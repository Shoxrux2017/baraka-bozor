import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:baraka_bozor/features/favorites/domain/favorites.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_catalog_repository.dart';
import '../../../support/fake_favorites_repository.dart';

/// The signed-in Customer, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'customer-a';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

void main() {
  late FakeFavoritesRepository favorites;
  late ProviderContainer container;

  setUp(() {
    favorites = FakeFavoritesRepository();
    container = ProviderContainer(
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    addTearDown(container.dispose);
    container.listen(favoriteOverridesProvider, (_, _) {});
  });

  Map<String, bool> overrides() => container.read(favoriteOverridesProvider);

  FavoriteOverrides notifier() =>
      container.read(favoriteOverridesProvider.notifier);

  test(
    'a toggle flips the heart at once and keeps it when the server agrees',
    () async {
      final Completer<void> hold = Completer<void>();
      favorites.hold = hold;

      final Future<bool> done = notifier().toggle('p-1', current: false);

      expect(overrides(), <String, bool>{'p-1': true});
      hold.complete();
      expect(await done, isTrue);
      expect(overrides(), <String, bool>{'p-1': true});
      expect(favorites.changes, <String>['add:p-1']);
    },
  );

  test('un-favouriting calls remove', () async {
    final bool done = await notifier().toggle('p-1', current: true);

    expect(done, isTrue);
    expect(overrides()['p-1'], isFalse);
    expect(favorites.changes, <String>['remove:p-1']);
  });

  test('a failed change restores the previous heart and says so', () async {
    favorites.nextFailure = const ApiRefusal(
      ApiError(status: 409, code: 'favorites_full'),
    );
    final Completer<void> hold = Completer<void>();
    favorites.hold = hold;

    final Future<bool> done = notifier().toggle('p-1', current: false);
    expect(overrides()['p-1'], isTrue);
    hold.complete();

    expect(await done, isFalse);
    expect(overrides().containsKey('p-1'), isFalse);
  });

  test(
    'a failed change restores an earlier override, not the product flag',
    () async {
      await notifier().toggle('p-1', current: false);
      favorites.nextFailure = const UnexpectedFailure();

      expect(await notifier().toggle('p-1', current: true), isFalse);
      expect(overrides()['p-1'], isTrue);
    },
  );

  test('another account starts with no overrides', () async {
    await notifier().toggle('p-1', current: false);
    expect(overrides(), isNotEmpty);

    container.read(_account.notifier).signIn('customer-b');

    expect(overrides(), isEmpty);
  });

  test('a change that fails after the account changed does not touch the new account', () async {
    final Completer<void> hold = Completer<void>();
    favorites
      ..hold = hold
      ..nextFailure = const UnexpectedFailure();
    final Future<bool> done = notifier().toggle('p-1', current: false);

    container.read(_account.notifier).signIn('customer-b');
    final Future<bool> other = notifier().toggle('p-1', current: false);
    hold.complete();

    expect(await done, isFalse);
    expect(await other, isTrue);
    expect(
      overrides()['p-1'],
      isTrue,
      reason: 'the second account hearted p-1 itself',
    );
  });

  test('the override wins over the product, otherwise the product decides', () {
    final CatalogProduct liked = catalogProduct(isFavorite: true);
    final CatalogProduct plain = catalogProduct(id: 'p-2');

    expect(favoriteOf(overrides(), liked), isTrue);
    expect(favoriteOf(overrides(), plain), isFalse);
    expect(favoriteOf(<String, bool>{'p-1': false}, liked), isFalse);
    expect(favoriteOf(<String, bool>{'p-2': true}, plain), isTrue);
  });

  test('the list loads pages and is refreshed after a toggle', () async {
    favorites
      ..pageSize = 1
      ..rows = <FavoriteProduct>[
        FavoriteProduct(
          product: catalogProduct(id: 'p-1', isFavorite: true),
          isAvailable: true,
        ),
        FavoriteProduct(
          product: catalogProduct(id: 'p-2', isFavorite: true),
          isAvailable: false,
        ),
      ];
    container.listen(favoritesListProvider, (_, _) {});

    final FavoritesListState first = await container.read(
      favoritesListProvider.future,
    );
    expect(first.items.single.product.id, 'p-1');
    expect(first.hasMore, isTrue);

    await container.read(favoritesListProvider.notifier).loadMore();
    final FavoritesListState both = container
        .read(favoritesListProvider)
        .requireValue;
    expect(both.items.map((FavoriteProduct f) => f.product.id), <String>[
      'p-1',
      'p-2',
    ]);
    expect(both.hasMore, isFalse);

    final int loads = favorites.listLoads;
    await notifier().toggle('p-1', current: true);
    await container.read(favoritesListProvider.future);

    expect(favorites.listLoads, greaterThan(loads));
    expect(
      container
          .read(favoritesListProvider)
          .requireValue
          .items
          .map((FavoriteProduct f) => f.product.id),
      <String>['p-2'],
    );
  });

  test('the sort starts as the shop order and is kept', () {
    expect(container.read(productSortProvider), ProductSort.shop);

    container.read(productSortProvider.notifier).set(ProductSort.priceDesc);

    expect(container.read(productSortProvider), ProductSort.priceDesc);
  });
}
