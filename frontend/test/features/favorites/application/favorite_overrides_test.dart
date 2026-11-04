import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
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
    container.listen(favoritesSortProvider, (_, _) {});
  });

  Map<String, bool> overrides() => container.read(favoriteOverridesProvider);

  FavoriteOverrides notifier() =>
      container.read(favoriteOverridesProvider.notifier);

  test(
    'a toggle flips the heart at once and keeps it when the server agrees',
    () async {
      final Completer<void> hold = Completer<void>();
      favorites.hold = hold;

      final Future<ApiFailure?> done = notifier().change('p-1', current: false);

      expect(overrides(), <String, bool>{'p-1': true});
      hold.complete();
      expect(await done, isNull);
      expect(overrides(), <String, bool>{'p-1': true});
      expect(favorites.changes, <String>['add:p-1']);
    },
  );

  test('un-favouriting calls remove', () async {
    final ApiFailure? done = await notifier().change('p-1', current: true);

    expect(done, isNull);
    expect(overrides()['p-1'], isFalse);
    expect(favorites.changes, <String>['remove:p-1']);
  });

  test('a failed change restores the previous heart and says so', () async {
    favorites.nextFailure = const ApiRefusal(
      ApiError(status: 409, code: 'favorites_full'),
    );
    final Completer<void> hold = Completer<void>();
    favorites.hold = hold;

    final Future<ApiFailure?> done = notifier().change('p-1', current: false);
    expect(overrides()['p-1'], isTrue);
    hold.complete();

    expect(
      await done,
      isA<ApiRefusal>().having(
        (ApiRefusal f) => f.error.code,
        'code',
        'favorites_full',
      ),
    );
    expect(overrides().containsKey('p-1'), isFalse);
  });

  test(
    'a failed change restores an earlier override, not the product flag',
    () async {
      await notifier().change('p-1', current: false);
      favorites.nextFailure = const UnexpectedFailure();

      expect(
        await notifier().change('p-1', current: true),
        isA<UnexpectedFailure>(),
      );
      expect(overrides()['p-1'], isTrue);
    },
  );

  test('another account starts with no overrides', () async {
    await notifier().change('p-1', current: false);
    expect(overrides(), isNotEmpty);

    container.read(_account.notifier).signIn('customer-b');

    expect(overrides(), isEmpty);
  });

  test('a change that fails after the account changed does not touch the new account', () async {
    final Completer<void> hold = Completer<void>();
    favorites
      ..hold = hold
      ..nextFailure = const UnexpectedFailure();
    final Future<ApiFailure?> done = notifier().change('p-1', current: false);

    container.read(_account.notifier).signIn('customer-b');
    final Future<ApiFailure?> other = notifier().change('p-1', current: false);
    hold.complete();

    expect(await done, isA<UnexpectedFailure>());
    expect(await other, isNull);
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

  test('a toggle leaves the favourites lists as they are', () async {
    favorites.rows = <CatalogProduct>[
      catalogProduct(id: 'p-1', isFavorite: true),
      catalogProduct(id: 'p-2', isFavorite: true, isAvailable: false),
    ];
    const ProductListQuery list = ProductListQuery.favorites();
    container.listen(productListProvider(list), (_, _) {});
    await container.read(productListProvider(list).future);
    final int loads = favorites.listLoads;

    await notifier().change('p-1', current: true);
    await Future<void>.delayed(Duration.zero);

    expect(favorites.listLoads, loads, reason: 'the screen refreshes them');
    expect(
      container
          .read(productListProvider(list))
          .requireValue
          .items
          .map((CatalogProduct p) => p.id),
      <String>['p-1', 'p-2'],
    );
  });

  test(
    'the favourites order starts as the shop order, is kept, and is its own',
    () {
      expect(container.read(favoritesSortProvider), ProductSort.shop);

      container.read(favoritesSortProvider.notifier).set(ProductSort.priceDesc);

      expect(container.read(favoritesSortProvider), ProductSort.priceDesc);
      expect(container.read(productSortProvider), ProductSort.shop);
    },
  );

  test('another account starts with the shop order', () {
    container.read(favoritesSortProvider.notifier).set(ProductSort.priceDesc);

    container.read(_account.notifier).signIn('customer-b');

    expect(container.read(favoritesSortProvider), ProductSort.shop);
  });
}
