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
import '../../favorites/application/favorites_controllers.dart';
import '../../favorites/domain/favorites_repository.dart';
import '../data/catalog_api.dart';
import '../data/catalog_repository_impl.dart';
import '../domain/catalog.dart';
import '../domain/catalog_repository.dart';

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
    this.edits = 0,
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

  /// How many in-place edits (withdraw, restore, settle, put) the list has
  /// had: a screen tells a change by an edit from a later page by it
  /// (`DL-129`).
  final int edits;

  /// The page to load next, or `null` at the end of the list.
  final int? nextPage;

  /// When the first page came; `loadMore` and its failures keep it
  /// (`DL-127`).
  final DateTime at;
  final bool loadingMore;
  final ApiFailure? moreFailure;

  bool get hasMore => nextPage != null;
}

/// Products taken out of a list in place, with what is needed to put them
/// back or to settle the removal (`DL-129`). Opaque to callers.
final class ListWithdrawal {
  const ListWithdrawal._({
    required this.generation,
    required this.removed,
    required this.endsList,
    required this.productCount,
    required this.notSoldCount,
    required this.total,
    required this.unavailable,
    required this.nextPage,
  });

  final int generation;

  /// Each product with its place: the index it had, the product that stood
  /// after it among those staying and the one before it.
  final List<
    ({int index, CatalogProduct product, String? before, String? after})
  >
  removed;

  /// True for the removal of every not-sold product, which ends the list.
  final bool endsList;

  /// How many products the server still counts for it, and how many of
  /// those are not sold.
  final int productCount;
  final int notSoldCount;
  final int total;
  final int unavailable;
  final int? nextPage;
}

const Object _keep = Object();

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

  /// True while [quietRefresh] reloads the pages.
  bool _refreshing = false;

  /// Bumped by every edit; a page asked for before it is dropped when it
  /// lands.
  int _epoch = 0;

  /// Withdrawals not yet restored or settled: the server still counts them.
  final List<ListWithdrawal> _held = <ListWithdrawal>[];

  @override
  Future<ProductListState> build() async {
    _generation++;
    _refreshing = false;
    _held.clear();
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
        _refreshing ||
        current.loadingMore ||
        state.isLoading ||
        state.hasError ||
        ref.read(customerAccountProvider) == null) {
      return;
    }

    final int generation = _generation;
    final int epoch = _epoch;
    final Completer<void> done = _pending = Completer<void>();
    state = AsyncData<ProductListState>(
      ProductListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        at: current.at,
        unavailable: current.unavailable,
        perPage: current.perPage,
        edits: current.edits,
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
      final Set<String> heldIds = <String>{
        for (final ListWithdrawal w in _held)
          for (final r in w.removed) r.product.id,
      };
      next = ProductListState(
        items: <CatalogProduct>[
          ...current.items,
          for (final CatalogProduct p in loaded.items)
            if (!shown.contains(p.id) && !heldIds.contains(p.id)) p,
        ],
        total: loaded.total - _heldProducts,
        nextPage: loaded.hasNext ? loaded.page + 1 : null,
        at: current.at,
        unavailable: answer.unavailable - _heldNotSold,
        perPage: loaded.perPage,
        edits: current.edits,
      );
    } on ApiFailure catch (failure) {
      next = ProductListState(
        items: current.items,
        total: current.total,
        nextPage: current.nextPage,
        at: current.at,
        unavailable: current.unavailable,
        perPage: current.perPage,
        edits: current.edits,
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
        edits: current.edits,
        moreFailure: const UnexpectedFailure(),
      );
    }

    if (ref.mounted && generation == _generation && epoch == _epoch) {
      state = AsyncData<ProductListState>(next);
    }
    if (identical(_pending, done)) {
      _pending = null;
    }
    if (!done.isCompleted) {
      done.complete();
    }
  }

  int get _heldProducts =>
      _held.fold(0, (int sum, ListWithdrawal w) => sum + w.productCount);

  int get _heldNotSold =>
      _held.fold(0, (int sum, ListWithdrawal w) => sum + w.notSoldCount);

  /// Every edit drops what is on its way: a page of [loadMore] or a running
  /// [quietRefresh] answers a list that is no longer this one (`DL-129`).
  void _dropInFlight() {
    _epoch++;
    _refreshing = false;
    final Completer<void>? running = _pending;
    _pending = null;
    if (running != null && !running.isCompleted) {
      running.complete();
    }
  }

  ProductListState _copy(
    ProductListState s, {
    List<CatalogProduct>? items,
    int? total,
    int? unavailable,
    Object? nextPage = _keep,
  }) {
    return ProductListState(
      items: items ?? s.items,
      total: total ?? s.total,
      nextPage: identical(nextPage, _keep) ? s.nextPage : nextPage as int?,
      at: s.at,
      unavailable: unavailable ?? s.unavailable,
      perPage: s.perPage,
      edits: s.edits + 1,
      moreFailure: s.moreFailure,
    );
  }

  String? _firstStaying(List<CatalogProduct> items, Set<int> gone, int from) {
    for (int i = from; i < items.length; i++) {
      if (!gone.contains(i)) {
        return items[i].id;
      }
    }
    return null;
  }

  ListWithdrawal? _take(
    ProductListState current,
    bool Function(CatalogProduct) takes, {
    required bool endsList,
  }) {
    final List<int> taken = <int>[
      for (int i = 0; i < current.items.length; i++)
        if (takes(current.items[i])) i,
    ];
    if (taken.isEmpty) {
      return null;
    }
    final Set<int> gone = taken.toSet();
    final List<
      ({int index, CatalogProduct product, String? before, String? after})
    >
    removed =
        <({int index, CatalogProduct product, String? before, String? after})>[
          for (final int i in taken)
            (
              index: i,
              product: current.items[i],
              before: _firstStaying(current.items, gone, i + 1),
              after: i > 0 ? current.items[i - 1].id : null,
            ),
        ];
    final int notSold = removed.where((r) => !r.product.isAvailable).length;
    _dropInFlight();
    state = AsyncData<ProductListState>(
      _copy(
        current,
        items: <CatalogProduct>[
          for (int i = 0; i < current.items.length; i++)
            if (!gone.contains(i)) current.items[i],
        ],
        total: endsList
            ? current.total - current.unavailable
            : current.total - removed.length,
        unavailable: endsList ? 0 : current.unavailable - notSold,
        nextPage: endsList ? null : _keep,
      ),
    );
    final ListWithdrawal withdrawal = ListWithdrawal._(
      generation: _generation,
      removed: removed,
      endsList: endsList,
      productCount: endsList ? current.unavailable : removed.length,
      notSoldCount: endsList ? current.unavailable : notSold,
      total: current.total,
      unavailable: current.unavailable,
      nextPage: current.nextPage,
    );
    _held.add(withdrawal);
    return withdrawal;
  }

  /// Takes the loaded products with these ids out of the list at once;
  /// `null` when none of them is loaded (`DL-129`).
  ListWithdrawal? withdraw(Set<String> ids) {
    final ProductListState? current = state.value;
    // A list being rebuilt answers a newer ask: the edit would be lost in it.
    if (current == null || state.isLoading) {
      return null;
    }
    return _take(
      current,
      (CatalogProduct p) => ids.contains(p.id),
      endsList: false,
    );
  }

  /// Takes every not-sold product out. The server puts them last, so with
  /// them gone nothing is left to load (`DL-129`).
  ListWithdrawal? withdrawNotSold() {
    final ProductListState? current = state.value;
    if (current == null || state.isLoading || current.unavailable == 0) {
      return null;
    }
    return _take(current, (CatalogProduct p) => !p.isAvailable, endsList: true);
  }

  /// Puts a withdrawal back at its places, with the counts and the next page
  /// as they were; nothing on a list rebuilt since (`DL-129`).
  void restore(ListWithdrawal w) {
    final ProductListState? current = state.value;
    if (current == null || w.generation != _generation || !_held.remove(w)) {
      return;
    }
    _dropInFlight();
    final List<CatalogProduct> items = <CatalogProduct>[...current.items];
    final List<CatalogProduct> back = <CatalogProduct>[];
    int indexOf(String? id) =>
        id == null ? -1 : items.indexWhere((CatalogProduct p) => p.id == id);
    for (final r in w.removed) {
      // A product the list holds again (hearted anew meanwhile) stays as is.
      if (indexOf(r.product.id) >= 0) {
        continue;
      }
      // Before the product that followed it, else after the one before it,
      // else where it was: removals undone in any order keep their places.
      final int beforeAt = indexOf(r.before);
      final int afterAt = indexOf(r.after);
      final int at = beforeAt >= 0
          ? beforeAt
          : afterAt >= 0
          ? afterAt + 1
          : r.index.clamp(0, items.length);
      items.insert(at, r.product);
      back.add(r.product);
    }
    final int nextPage = items.length ~/ current.perPage + 1;
    state = AsyncData<ProductListState>(
      _copy(
        current,
        items: items,
        total: current.total + (w.endsList ? w.productCount : back.length),
        unavailable:
            current.unavailable +
            (w.endsList
                ? w.notSoldCount
                : back.where((CatalogProduct p) => !p.isAvailable).length),
        nextPage: w.endsList && w.nextPage != null ? nextPage : _keep,
      ),
    );
  }

  /// The server removed the withdrawn products. While more remain, the next
  /// page starts where the server's offsets now are; the dedupe of
  /// [loadMore] drops what repeats (`DL-129`).
  void settle(ListWithdrawal w) {
    final ProductListState? current = state.value;
    if (current == null || w.generation != _generation) {
      return;
    }
    _held.remove(w);
    _dropInFlight();
    if (!current.hasMore) {
      state = AsyncData<ProductListState>(_copy(current));
      return;
    }
    state = AsyncData<ProductListState>(
      _copy(current, nextPage: current.items.length ~/ current.perPage + 1),
    );
  }

  /// Puts a product at the top of the list and counts it (`DL-129`).
  void put(CatalogProduct product) {
    final ProductListState? current = state.value;
    if (current == null ||
        state.isLoading ||
        current.items.any((CatalogProduct p) => p.id == product.id)) {
      return;
    }
    _dropInFlight();
    state = AsyncData<ProductListState>(
      _copy(
        current,
        items: <CatalogProduct>[product, ...current.items],
        total: current.total + 1,
      ),
    );
  }

  /// Reloads pages 1 to as many as are loaded, one after another, then
  /// replaces the list at once: never a loading state. A failure leaves the
  /// list under an error, so the screen keeps its cards under the stale line.
  /// A page that [loadMore] brings meanwhile is dropped (`DL-129`).
  Future<void> quietRefresh() async {
    while (_pending != null) {
      await _pending!.future;
    }
    final ProductListState? current = state.value;
    if (!ref.mounted ||
        current == null ||
        _held.isNotEmpty ||
        state.isLoading ||
        ref.read(customerAccountProvider) == null) {
      return;
    }
    // While it runs, no further page is started: it would land before the
    // replaced list and repeat it.
    final int generation = _generation;
    final int epoch = _epoch;
    _refreshing = true;
    final int pages = (current.items.length / current.perPage).ceil().clamp(
      1,
      1 << 20,
    );
    try {
      final List<CatalogProduct> items = <CatalogProduct>[];
      final Set<String> shown = <String>{};
      late ({Paged<CatalogProduct> products, int unavailable}) last;
      for (int page = 1; page <= pages; page++) {
        last = await _ask(page);
        if (!ref.mounted || generation != _generation || epoch != _epoch) {
          return;
        }
        for (final CatalogProduct p in last.products.items) {
          if (shown.add(p.id)) {
            items.add(p);
          }
        }
        if (!last.products.hasNext) {
          break;
        }
      }
      state = AsyncData<ProductListState>(
        ProductListState(
          items: items,
          total: last.products.total,
          nextPage: last.products.hasNext ? last.products.page + 1 : null,
          at: ref.read(clockProvider)(),
          unavailable: last.unavailable,
          perPage: last.products.perPage,
          edits: current.edits,
        ),
      );
    } on ApiFailure catch (failure, stackTrace) {
      _failQuietly(generation, epoch, failure, stackTrace);
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while refreshing products');
      _failQuietly(generation, epoch, const UnexpectedFailure(), stackTrace);
    } finally {
      if (generation == _generation && epoch == _epoch) {
        _refreshing = false;
      }
    }
  }

  void _failQuietly(
    int generation,
    int epoch,
    ApiFailure failure,
    StackTrace stack,
  ) {
    if (ref.mounted && generation == _generation && epoch == _epoch) {
      state = AsyncError<ProductListState>(failure, stack);
    }
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
