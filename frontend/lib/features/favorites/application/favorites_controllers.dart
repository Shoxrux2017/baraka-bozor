import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/session/customer_account.dart';
import '../../catalog/domain/catalog.dart';
import '../data/favorites_api.dart';
import '../domain/favorites.dart';
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
  /// answer is `false`, so the caller can say so.
  Future<bool> toggle(String productId, {required bool current}) async =>
      await change(productId, current: current) == null;

  /// [toggle] answering why it failed: `null` when the server agreed.
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

    if (_sameAccount(account) && ref.exists(favoritesListProvider)) {
      ref.invalidate(favoritesListProvider);
    }
    return null;
  }

  bool _sameAccount(String? account) =>
      ref.mounted && ref.read(customerAccountProvider) == account;
}

final NotifierProvider<FavoriteOverrides, Map<String, bool>>
favoriteOverridesProvider =
    NotifierProvider<FavoriteOverrides, Map<String, bool>>(
      FavoriteOverrides.new,
    );

/// Whether [product] is a favourite: the heart the Customer just set, else
/// what the server said.
bool favoriteOf(Map<String, bool> overrides, CatalogProduct product) =>
    overrides[product.id] ?? product.isFavorite;

/// [favoriteOf] for a widget, rebuilding it when a heart changes.
bool isFavorite(WidgetRef ref, CatalogProduct product) =>
    favoriteOf(ref.watch(favoriteOverridesProvider), product);

/// The favourites as far as they have been loaded.
final class FavoritesListState {
  const FavoritesListState({
    required this.items,
    required this.total,
    required this.nextPage,
    this.loadingMore = false,
    this.moreFailure,
  });

  final List<FavoriteProduct> items;
  final int total;

  /// The page to load next, or `null` at the end of the list.
  final int? nextPage;
  final bool loadingMore;
  final ApiFailure? moreFailure;

  bool get hasMore => nextPage != null;
}

/// The Customer's favourites, a page at a time. A page that arrives after the
/// list was rebuilt — another account, a refresh — is dropped by the
/// generation it was asked for (`docs/07-architecture.md` section 28).
class FavoritesListController extends AsyncNotifier<FavoritesListState> {
  int _generation = 0;

  @override
  Future<FavoritesListState> build() async {
    _generation++;
    if (ref.watch(customerAccountProvider) == null) {
      return Completer<FavoritesListState>().future;
    }
    final Paged<FavoriteProduct> first = await ref
        .read(favoritesRepositoryProvider)
        .list(page: 1);
    return FavoritesListState(
      items: first.items,
      total: first.total,
      nextPage: first.hasNext ? first.page + 1 : null,
    );
  }

  /// Loads the next page, once at a time; nothing at the end of the list.
  Future<void> loadMore() async {
    final FavoritesListState? current = state.value;
    final int? page = current?.nextPage;
    if (current == null ||
        page == null ||
        current.loadingMore ||
        state.isLoading ||
        ref.read(customerAccountProvider) == null) {
      return;
    }

    final int generation = _generation;
    state = AsyncData<FavoritesListState>(
      FavoritesListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        loadingMore: true,
      ),
    );

    FavoritesListState next;
    try {
      final Paged<FavoriteProduct> loaded = await ref
          .read(favoritesRepositoryProvider)
          .list(page: page);
      final Set<String> shown = <String>{
        for (final FavoriteProduct f in current.items) f.product.id,
      };
      next = FavoritesListState(
        items: <FavoriteProduct>[
          ...current.items,
          for (final FavoriteProduct f in loaded.items)
            if (!shown.contains(f.product.id)) f,
        ],
        total: loaded.total,
        nextPage: loaded.hasNext ? loaded.page + 1 : null,
      );
    } on ApiFailure catch (failure) {
      next = FavoritesListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        moreFailure: failure,
      );
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while loading more favourites');
      next = FavoritesListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        moreFailure: const UnexpectedFailure(),
      );
    }

    if (ref.mounted && generation == _generation) {
      state = AsyncData<FavoritesListState>(next);
    }
  }
}

final AsyncNotifierProvider<FavoritesListController, FavoritesListState>
favoritesListProvider =
    AsyncNotifierProvider.autoDispose<
      FavoritesListController,
      FavoritesListState
    >(FavoritesListController.new);
