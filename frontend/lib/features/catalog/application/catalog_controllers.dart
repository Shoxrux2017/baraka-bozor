import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily, ProviderFamily;

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/platform/clock.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/loaded.dart';
import '../data/catalog_api.dart';
import '../data/catalog_repository_impl.dart';
import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';
import '../../favorites/application/favorites_controllers.dart';
import '../../favorites/domain/favorites_repository.dart';

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (Ref ref) =>
          CatalogRepositoryImpl(CatalogApi(ref.watch(apiClientProvider))),
    );

/// The catalog's sections and the moment they came (`DL-125`), so a screen
/// that could not refresh them says when what it shows is from. The catalog
/// needs a Customer session (`DL-17` (4)): with no Customer account nothing is
/// asked for.
final FutureProvider<Loaded<List<CatalogCategory>>> catalogCategoriesProvider =
    FutureProvider.autoDispose<Loaded<List<CatalogCategory>>>((Ref ref) async {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<Loaded<List<CatalogCategory>>>().future;
      }
      final List<CatalogCategory> rows = await ref
          .watch(catalogRepositoryProvider)
          .categories();
      return Loaded<List<CatalogCategory>>(rows, at: ref.read(clockProvider)());
    });

final FutureProviderFamily<CatalogProduct, String> catalogProductProvider =
    FutureProvider.autoDispose.family<CatalogProduct, String>((
      Ref ref,
      String id,
    ) {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<CatalogProduct>().future;
      }
      return ref.watch(catalogRepositoryProvider).product(id);
    });

/// A product list as far as it has been loaded: the items, whether more
/// pages exist, and what happened to the last attempt at the next one.
final class ProductListState {
  const ProductListState({
    required this.items,
    required this.total,
    required this.nextPage,
    required this.at,
    this.unavailable = 0,
    this.perPage = 20,
    this.loadingMore = false,
    this.moreFailure,
  });

  final List<CatalogProduct> items;
  final int total;

  /// How many favourites of the whole list are no longer sold; 0 for every
  /// other list (`DL-129`).
  final int unavailable;

  /// How many products a page holds, as the server answered.
  final int perPage;

  /// The page to load next, or `null` at the end of the list.
  final int? nextPage;

  /// When the first page came; `loadMore` and its failures keep it
  /// (`DL-127`).
  final DateTime at;
  final bool loadingMore;
  final ApiFailure? moreFailure;

  bool get hasMore => nextPage != null;
}

/// One product list per query — a category, a search, or both, or the
/// Customer's favourites (`DL-129`) — loaded a
/// page at a time as the Customer scrolls (infinite pagination).
///
/// Each query has a list of its own, so the results of a search the
/// Customer has since typed past belong to a list nobody shows, and a page
/// that arrives after its list was rebuilt or disposed is dropped by the
/// generation it was asked for (`docs/07-architecture.md` section 28).
class ProductListController extends AsyncNotifier<ProductListState> {
  ProductListController(this.query);

  final ProductListQuery query;

  int _generation = 0;

  /// Completes when the page now being loaded is in; null while none is.
  Completer<void>? _pending;

  @override
  Future<ProductListState> build() async {
    _generation++;
    if (ref.watch(customerAccountProvider) == null) {
      return Completer<ProductListState>().future;
    }
    final ({Paged<CatalogProduct> products, int unavailable}) first =
        await _ask(1);
    return ProductListState(
      items: first.products.items,
      total: first.products.total,
      nextPage: first.products.hasNext ? first.products.page + 1 : null,
      at: ref.read(clockProvider)(),
      unavailable: first.unavailable,
      perPage: first.products.perPage,
    );
  }

  /// One page from the favourites for a favourites query, else from the
  /// catalog (`DL-129`).
  Future<({Paged<CatalogProduct> products, int unavailable})> _ask(
    int page,
  ) async {
    if (query.favorites) {
      final FavoritesPage answer = await ref
          .read(favoritesRepositoryProvider)
          .list(sort: query.sort, page: page);
      return (products: answer.products, unavailable: answer.unavailable);
    }
    return (
      products: await ref
          .read(catalogRepositoryProvider)
          .products(query, page: page),
      unavailable: 0,
    );
  }

  /// Loads the next page, once at a time; nothing at the end of the list.
  Future<void> loadMore() async {
    final ProductListState? current = state.value;
    final int? page = current?.nextPage;
    // While the list is rebuilt — for another account, or none — its old
    // pages are not continued; nor are those of a list whose refresh failed:
    // its stale line stays until a pull or «Обновить» succeeds (`DL-127`).
    if (current == null ||
        page == null ||
        current.loadingMore ||
        state.isLoading ||
        state.hasError ||
        ref.read(customerAccountProvider) == null) {
      return;
    }

    final int generation = _generation;
    final Completer<void> done = _pending = Completer<void>();
    state = AsyncData<ProductListState>(
      ProductListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        at: current.at,
        unavailable: current.unavailable,
        perPage: current.perPage,
        loadingMore: true,
      ),
    );

    ProductListState next;
    try {
      final ({Paged<CatalogProduct> products, int unavailable}) answer =
          await _ask(page);
      final Paged<CatalogProduct> loaded = answer.products;
      // Offset pages can repeat a product when the catalog changes between
      // them; a product already shown is not shown twice.
      final Set<String> shown = <String>{
        for (final CatalogProduct p in current.items) p.id,
      };
      next = ProductListState(
        items: <CatalogProduct>[
          ...current.items,
          for (final CatalogProduct p in loaded.items)
            if (!shown.contains(p.id)) p,
        ],
        total: loaded.total,
        nextPage: loaded.hasNext ? loaded.page + 1 : null,
        at: current.at,
        unavailable: answer.unavailable,
        perPage: loaded.perPage,
      );
    } on ApiFailure catch (failure) {
      next = ProductListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        at: current.at,
        unavailable: current.unavailable,
        perPage: current.perPage,
        moreFailure: failure,
      );
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while loading more products');
      next = ProductListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        at: current.at,
        unavailable: current.unavailable,
        perPage: current.perPage,
        moreFailure: const UnexpectedFailure(),
      );
    }

    if (ref.mounted && generation == _generation) {
      state = AsyncData<ProductListState>(next);
    }
    if (identical(_pending, done)) {
      _pending = null;
    }
    done.complete();
  }

  /// Loads the next pages one after another until [count] products are in.
  /// It stops when there is no more, when a page fails (its failure stays on
  /// the state), or when the list was rebuilt meanwhile (`DL-128`).
  Future<void> loadThrough(int count) async {
    final int generation = _generation;
    while (ref.mounted && generation == _generation) {
      final ProductListState? current = state.value;
      if (current == null ||
          state.isLoading ||
          state.hasError ||
          current.items.length >= count ||
          !current.hasMore ||
          current.moreFailure != null) {
        return;
      }
      final Completer<void>? running = _pending;
      if (running != null) {
        await running.future;
        continue;
      }
      await loadMore();
      if (identical(state.value, current)) {
        // Nothing moved: loading is refused, so waiting longer is pointless.
        return;
      }
    }
  }
}

final AsyncNotifierProviderFamily<
  ProductListController,
  ProductListState,
  ProductListQuery
>
productListProvider = AsyncNotifierProvider.autoDispose
    .family<ProductListController, ProductListState, ProductListQuery>(
      ProductListController.new,
    );

/// The last total a product list of one filter came with, whatever its order,
/// so a count row does not blank while another order of the same products
/// loads (`DL-127`). A plain holder, not observable state: it is written in a
/// build and read in a later one. Another account starts afresh.
final class ListTotalMemo {
  int? total;
}

final ProviderFamily<ListTotalMemo, ProductListQuery> listTotalMemoProvider =
    Provider.family<ListTotalMemo, ProductListQuery>((
      Ref ref,
      ProductListQuery filter,
    ) {
      ref.watch(customerAccountProvider);
      return ListTotalMemo();
    });

/// How the Customer's product lists are ordered, kept for the app's run.
class ProductSortController extends Notifier<ProductSort> {
  @override
  ProductSort build() => ProductSort.shop;

  void set(ProductSort sort) => state = sort;
}

final NotifierProvider<ProductSortController, ProductSort> productSortProvider =
    NotifierProvider<ProductSortController, ProductSort>(
      ProductSortController.new,
    );
