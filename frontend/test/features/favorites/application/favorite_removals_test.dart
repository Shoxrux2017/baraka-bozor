import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/catalog/application/catalog_controllers.dart';
import 'package:baraka_bozor/features/catalog/domain/catalog.dart';
import 'package:baraka_bozor/features/favorites/application/favorite_removals.dart';
import 'package:baraka_bozor/features/favorites/application/favorites_controllers.dart';
import 'package:flutter/foundation.dart';
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
  final ProductListQuery query = ProductListQuery.favorites(
    sort: ProductSort.shop,
  );

  CatalogProduct favorite(String id, {bool available = true}) =>
      catalogProduct(id: id, isFavorite: true, isAvailable: available);

  setUp(() {
    favorites = FakeFavoritesRepository(
      favorites: <CatalogProduct>[
        favorite('p-1'),
        favorite('p-2'),
        favorite('p-3', available: false),
      ],
    );
    container = ProviderContainer(
      overrides: [
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    addTearDown(container.dispose);
    container.listen(favoriteOverridesProvider, (_, _) {});
    container.listen(favoriteRemovalsProvider, (_, _) {});
    container.listen(productListProvider(query), (_, _) {});
  });

  FavoriteRemovals removals() =>
      container.read(favoriteRemovalsProvider.notifier);

  ProductListController list() =>
      container.read(productListProvider(query).notifier);

  List<String> ids() => container
      .read(productListProvider(query))
      .requireValue
      .items
      .map((CatalogProduct p) => p.id)
      .toList();

  /// Takes [id] off the list and the heart, as the screen does, and holds it.
  Future<FavoriteRemoval> takeOff(String id, {VoidCallback? closeBar}) async {
    await container.read(productListProvider(query).future);
    container
        .read(favoriteOverridesProvider.notifier)
        .mark(id, favorite: false);
    final FavoriteRemoval removal = FavoriteRemoval(
      query: query,
      withdrawal: list().withdraw(<String>{id})!,
      productIds: <String>[id],
      everyNotSold: false,
    );
    removals().hold(removal, closeBar: closeBar ?? () {});
    return removal;
  }

  test('a removal is sent once, however often it is asked', () async {
    final FavoriteRemoval removal = await takeOff('p-1');

    final Future<ApiFailure?> first = removals().commit(removal);
    final Future<ApiFailure?> second = removals().commit(removal);
    await removals().flush();

    expect(await first, isNull);
    expect(await second, isNull);
    expect(favorites.changes, <String>['remove:p-1']);
    expect(removals().holding, isFalse);
    expect(ids(), <String>['p-2', 'p-3']);
    expect(container.read(favoriteOverridesProvider)['p-1'], isFalse);
  });

  test('«Вернуть» brings the card back and sends nothing, ever', () async {
    final FavoriteRemoval removal = await takeOff('p-1');

    removals().undo(removal);
    expect(await removals().commit(removal), isNull);

    expect(favorites.changes, isEmpty);
    expect(ids(), <String>['p-1', 'p-2', 'p-3']);
    expect(container.read(favoriteOverridesProvider), isEmpty);
  });

  test('a failed removal brings the card back and forgets its heart', () async {
    final FavoriteRemoval removal = await takeOff('p-1');
    favorites.nextFailure = const NetworkFailure();

    expect(await removals().commit(removal), isA<NetworkFailure>());

    expect(ids(), <String>['p-1', 'p-2', 'p-3']);
    expect(container.read(favoriteOverridesProvider), isEmpty);
  });

  test('a second removal sends the first at once', () async {
    final FavoriteRemoval first = await takeOff('p-1');
    final FavoriteRemoval second = await takeOff('p-2');
    await removals().commit(first);

    expect(favorites.changes, <String>['remove:p-1']);
    expect(removals().state, same(second));

    removals().undo(second);
    expect(ids(), <String>['p-2', 'p-3']);
    expect(favorites.changes, <String>['remove:p-1']);
  });

  test('flush closes the bar and waits for the sending', () async {
    int closed = 0;
    await takeOff('p-1', closeBar: () => closed++);
    final Completer<void> hold = Completer<void>();
    favorites.hold = hold;

    bool done = false;
    final Future<void> flushed = removals().flush().then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, 1);
    expect(done, isFalse);
    hold.complete();
    await flushed;

    expect(favorites.changes, <String>['remove:p-1']);
    await removals().flush();
    expect(favorites.changes, <String>['remove:p-1']);
  });

  test(
    'another account: what was held is dropped and nothing is sent',
    () async {
      int closed = 0;
      final FavoriteRemoval removal = await takeOff(
        'p-1',
        closeBar: () => closed++,
      );

      container.read(_account.notifier).signIn('customer-b');
      await Future<void>.delayed(Duration.zero);

      expect(closed, 1);
      expect(removals().holding, isFalse);
      expect(await removals().commit(removal), isNull);
      expect(favorites.changes, isEmpty);
    },
  );

  test('a removal that was in the air when the account changed does not '
      'touch the new account', () async {
    final FavoriteRemoval removal = await takeOff('p-1');
    final Completer<void> hold = Completer<void>();
    favorites
      ..hold = hold
      ..nextFailure = const NetworkFailure();
    final Future<ApiFailure?> sent = removals().commit(removal);

    container.read(_account.notifier).signIn('customer-b');
    hold.complete();

    expect(await sent, isNull);
  });
}
