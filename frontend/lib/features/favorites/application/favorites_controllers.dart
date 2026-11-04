import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../../catalog/domain/catalog.dart';
import '../data/favorites_api.dart';
import '../domain/favorites_repository.dart';

final Provider<FavoritesRepository> favoritesRepositoryProvider =
    Provider<FavoritesRepository>(
      (Ref ref) =>
          FavoritesRepositoryImpl(FavoritesApi(ref.watch(apiClientProvider))),
    );

/// The hearts the Customer has just changed, by product id: what the screens
/// show before the lists they came from are loaded again. Kept for the
/// signed-in Customer account only — another account starts empty, and a
/// change still on its way for the previous one never touches it.
class FavoriteOverrides extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    ref.watch(customerAccountProvider);
    return const <String, bool>{};
  }

  /// Flips the heart of [productId] — [current] is what it shows now — at
  /// once, then asks the server. On a failure the heart goes back and the
  /// answer is why it failed, so the caller can say so; `null` when the
  /// server agreed.
  Future<ApiFailure?> change(String productId, {required bool current}) async {
    final String? account = ref.read(customerAccountProvider);
    final bool wanted = !current;
    final bool? previous = state[productId];
    state = <String, bool>{...state, productId: wanted};

    final FavoritesRepository favorites = ref.read(favoritesRepositoryProvider);
    try {
      await (wanted ? favorites.add(productId) : favorites.remove(productId));
    } catch (error, stackTrace) {
      if (error is! ApiFailure) {
        reportUnexpectedError(error, stackTrace, 'while changing a favourite');
      }
      if (_sameAccount(account) && state[productId] == wanted) {
        final Map<String, bool> restored = <String, bool>{...state};
        if (previous == null) {
          restored.remove(productId);
        } else {
          restored[productId] = previous;
        }
        state = restored;
      }
      return error is ApiFailure ? error : const UnexpectedFailure();
    }
    return null;
  }

  /// Shows [productId] as [favorite] without asking the server: the heart of
  /// a card that is leaving the favourites list (`DL-129`).
  void mark(String productId, {required bool favorite}) {
    state = <String, bool>{...state, productId: favorite};
  }

  /// Lets go of what was marked for [productIds]: their hearts show what the
  /// server said again.
  void forget(Iterable<String> productIds) {
    if (!ref.mounted) {
      return;
    }
    final Map<String, bool> kept = <String, bool>{...state}
      ..removeWhere((String id, bool _) => productIds.contains(id));
    if (kept.length != state.length) {
      state = kept;
    }
  }

  bool _sameAccount(String? account) =>
      ref.mounted && ref.read(customerAccountProvider) == account;
}

final NotifierProvider<FavoriteOverrides, Map<String, bool>>
favoriteOverridesProvider =
    NotifierProvider<FavoriteOverrides, Map<String, bool>>(
      FavoriteOverrides.new,
    );

/// How many hearts the Customer has set in this run, per account: the
/// «Избранное» tab bumps on each new count (`DL-129`). A heart taken off is
/// not counted.
class FavoriteAdded extends Notifier<int> {
  @override
  int build() {
    ref.watch(customerAccountProvider);
    return 0;
  }

  void bump() => state = state + 1;
}

final NotifierProvider<FavoriteAdded, int> favoriteAddedProvider =
    NotifierProvider<FavoriteAdded, int>(FavoriteAdded.new);

/// Whether [product] is a favourite: the heart the Customer just set, else
/// what the server said.
bool favoriteOf(Map<String, bool> overrides, CatalogProduct product) =>
    overrides[product.id] ?? product.isFavorite;

/// [favoriteOf] for a widget, rebuilding it when a heart changes.
bool isFavorite(WidgetRef ref, CatalogProduct product) =>
    favoriteOf(ref.watch(favoriteOverridesProvider), product);

/// How the Customer's favourites are ordered, kept for the app's run
/// (`DL-129`). It has its own memory: the favourites' order does not move the
/// order of the shop's lists. Another account starts afresh.
class FavoritesSortController extends Notifier<ProductSort> {
  @override
  ProductSort build() {
    ref.watch(customerAccountProvider);
    return ProductSort.shop;
  }

  void set(ProductSort sort) => state = sort;
}

final NotifierProvider<FavoritesSortController, ProductSort>
favoritesSortProvider = NotifierProvider<FavoritesSortController, ProductSort>(
  FavoritesSortController.new,
);
