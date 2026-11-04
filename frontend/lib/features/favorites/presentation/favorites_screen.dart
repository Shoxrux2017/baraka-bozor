import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/widgets/undo_bar.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../catalog/application/catalog_controllers.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/kit_product_grid.dart';
import '../../catalog/presentation/sort_menu.dart';
import '../application/favorite_removals.dart';
import '../application/favorites_controllers.dart';
import 'not_sold_heading.dart';

/// "Избранное": the products the Customer hearted, an ordinary product list
/// on the kit grid with a count-and-order row (`DL-129`). A favourite that
/// stopped being sold stays, marked as not sold, after the sold ones. A heart
/// taken off melts its card and shows «Вернуть» for 5 s; the server is told
/// when that bar closes.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  static const Duration _barDuration = Duration(seconds: 5);

  /// The cards that melt away, and the timers that take them out of the list
  /// when the melt is over.
  Set<String> _leaving = const <String>{};
  final Map<Timer, List<String>> _timers = <Timer, List<String>>{};
  late final FavoriteOverrides _overrides = ref.read(
    favoriteOverridesProvider.notifier,
  );
  late final FavoriteRemovals _removals = ref.read(
    favoriteRemovalsProvider.notifier,
  );

  /// The screen's route is the top one and its tickers are on, as
  /// `PeriodicRefresh` reads it.
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool shown = _isShown;
    if (shown && !_shown) {
      // Not during the build that showed the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isShown) {
          unawaited(_enter());
        }
      });
    }
    _shown = shown;
  }

  bool get _isShown =>
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      TickerMode.valuesOf(context).enabled;

  /// The screen is shown with a list loaded: it is brought up to date without
  /// a skeleton or a spinner, unless a removal waits for its bar, and the
  /// list is read out once. A list still loading is read out when its first
  /// page comes (`DL-129`).
  Future<void> _enter() async {
    final ProductListQuery query = _query();
    if (ref.read(productListProvider(query)).value == null) {
      return;
    }
    if (!_removals.holding) {
      await ref.read(productListProvider(query).notifier).quietRefresh();
    }
    if (mounted) {
      _announceList(query);
    }
  }

  void _announceList(ProductListQuery query) {
    final ProductListState? list = ref.read(productListProvider(query)).value;
    if (list == null) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String count = l10n.catalogProductCount(list.total);
    announce(
      context,
      list.unavailable > 0
          ? l10n.favoritesEntryNotSoldSpoken(count, list.unavailable)
          : l10n.favoritesEntrySpoken(count),
    );
  }

  @override
  void dispose() {
    // A card that never got to leave has its heart back as the server has it.
    // A provider is not changed while the tree is torn down, so it follows.
    for (final MapEntry<Timer, List<String>> pending in _timers.entries) {
      pending.key.cancel();
      final FavoriteOverrides overrides = _overrides;
      final List<String> ids = pending.value;
      scheduleMicrotask(() => overrides.forget(ids));
    }
    _timers.clear();
    super.dispose();
  }

  ProductListQuery _query() =>
      ProductListQuery.favorites(sort: ref.read(favoritesSortProvider));

  void _heartOff(CatalogProduct product) {
    if (_leaving.contains(product.id)) {
      return;
    }
    final String name = product.name(interfaceLanguage(context));
    _begin(<String>[product.id], everyNotSold: false, name: (_) => name);
  }

  void _removeAll() {
    final List<String> ids = <String>[
      for (final CatalogProduct p
          in ref.read(productListProvider(_query())).value?.items ??
              const <CatalogProduct>[])
        if (!p.isAvailable && !_leaving.contains(p.id)) p.id,
    ];
    if (ids.isEmpty) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    _begin(
      ids,
      everyNotSold: true,
      name: (ProductListState state) =>
          l10n.catalogProductCount(state.unavailable),
    );
  }

  /// The cards of [ids] show an empty heart and melt; once they have, they
  /// leave the list and the bar stands for the removal.
  void _begin(
    List<String> ids, {
    required bool everyNotSold,
    required String Function(ProductListState state) name,
  }) {
    final ProductListQuery query = _query();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    for (final String id in ids) {
      _overrides.mark(id, favorite: false);
    }
    setState(() => _leaving = <String>{..._leaving, ...ids});
    final Duration melt = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 160 : 200,
    );
    late final Timer timer;
    timer = Timer(melt, () {
      _timers.remove(timer);
      unawaited(
        _leave(
          ids,
          query: query,
          everyNotSold: everyNotSold,
          name: name,
          l10n: l10n,
          messenger: messenger,
        ),
      );
    });
    _timers[timer] = ids;
  }

  Future<void> _leave(
    List<String> ids, {
    required ProductListQuery query,
    required bool everyNotSold,
    required String Function(ProductListState state) name,
    required AppLocalizations l10n,
    required ScaffoldMessengerState messenger,
  }) async {
    final ProductListState? before = ref.exists(productListProvider(query))
        ? ref.read(productListProvider(query)).value
        : null;
    ListWithdrawal? withdrawal;
    if (before != null) {
      final ProductListController list = ref.read(
        productListProvider(query).notifier,
      );
      withdrawal = everyNotSold
          ? list.withdrawNotSold()
          : list.withdraw(ids.toSet());
    }
    if (mounted) {
      setState(() => _leaving = _leaving.difference(ids.toSet()));
    }
    if (withdrawal == null || before == null) {
      await _sendAtOnce(
        ids,
        everyNotSold: everyNotSold,
        l10n: l10n,
        messenger: messenger,
      );
      return;
    }

    final String shown = name(before);
    final String text = l10n.favoriteRemoved(shown);
    final String restored = l10n.favoriteRestoredSpoken(shown);
    final FavoriteRemoval removal = FavoriteRemoval(
      query: query,
      withdrawal: withdrawal,
      productIds: ids,
      everyNotSold: everyNotSold,
    );
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? bar;
    _removals.hold(removal, closeBar: () => bar?.close());
    bar = showUndoBar(
      messenger,
      text: text,
      actionLabel: l10n.undoAction,
      duration: _barDuration,
      onUndo: () {
        _removals.undo(removal);
        if (mounted) {
          announce(context, restored);
        }
      },
    );
    announce(context, text);
    // «Вернуть» leaves the removal undone, so its commit sends nothing; any
    // other end of the bar sends it.
    await bar.closed;
    final ApiFailure? failure = await _removals.commit(removal);
    if (failure != null) {
      _showFailure(failure, l10n: l10n, messenger: messenger);
    }
  }

  /// Nothing of the removal is on the list to take back, so the server is
  /// asked at once, as for any heart (`DL-129`).
  Future<void> _sendAtOnce(
    List<String> ids, {
    required bool everyNotSold,
    required AppLocalizations l10n,
    required ScaffoldMessengerState messenger,
  }) async {
    _overrides.forget(ids);
    if (everyNotSold) {
      return;
    }
    for (final String id in ids) {
      final ApiFailure? failure = await _overrides.change(id, current: true);
      if (failure != null) {
        _showFailure(failure, l10n: l10n, messenger: messenger);
      }
    }
  }

  void _showFailure(
    ApiFailure failure, {
    required AppLocalizations l10n,
    required ScaffoldMessengerState messenger,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure is NetworkFailure
              ? l10n.favoriteRemoveOffline
              : l10n.favoriteRemoveFailed,
        ),
      ),
    );
  }

  /// A new order asks the server for the list again, so a removal waiting for
  /// its bar is sent first.
  Future<void> _setSort(ProductSort sort) async {
    await _removals.flush();
    if (mounted) {
      ref.read(favoritesSortProvider.notifier).set(sort);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductSort sort = ref.watch(favoritesSortProvider);
    final ProductListQuery query = ProductListQuery.favorites(sort: sort);
    // A removal waiting for its bar is dropped when the account changes; the
    // provider is listened to while the screen stands so that it is, at once.
    ref.listen(favoriteRemovalsProvider, (_, _) {});
    // The first page of a list comes while the screen is shown: it is read
    // out (a list that comes while the tab is hidden waits for the tab).
    ref.listen(productListProvider(query), (
      AsyncValue<ProductListState>? before,
      AsyncValue<ProductListState> after,
    ) {
      if (before?.value == null && after.value != null && _isShown) {
        _announceList(query);
      }
    });
    // The count row is not drawn while the list is empty.
    final bool empty =
        ref.watch(productListProvider(query)).value?.items.isEmpty ?? false;

    return CustomerTabScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(
          title: l10n.favoritesTitle,
          automaticallyImplyLeading: false,
          search: true,
          actions: const <Widget>[CartButton()],
        ),
        // The mode stays visible while two sessions exist (DL-75).
        body: UnderActiveMode(
          child: KitProductGrid(
            key: const ValueKey<String>('favorites-grid'),
            query: query,
            // A tap on the current tab takes the list back to the top.
            controller: PrimaryScrollController.maybeOf(context),
            empty: const _Empty(),
            leaving: _leaving,
            onHeartOff: _heartOff,
            beforeRefresh: _removals.flush,
            notSoldHeading: (int count) =>
                NotSoldHeading(count: count, onRemoveAll: _removeAll),
            header: empty
                ? const <Widget>[]
                : <Widget>[
                    SliverToBoxAdapter(
                      child: ProductListCountRow(
                        key: const ValueKey<String>('list-count-row'),
                        query: query,
                        sort: sort,
                        onSort: (ProductSort next) => unawaited(_setSort(next)),
                      ),
                    ),
                  ],
          ),
        ),
        bottomNavigationBar: const CustomerTabBar(
          current: CustomerTab.favorites,
        ),
      ),
    );
  }
}

/// Nothing hearted yet: what a heart does, and the way to the shop.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey<String>('favorites-empty'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.primaryWash,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 96,
              color: KitColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.favoritesEmptyTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.favoritesEmptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: KitColors.muted,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey<String>('favorites-shop'),
            style: FilledButton.styleFrom(
              backgroundColor: KitColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => context.go(AppPaths.customer),
            child: Text(l10n.favoritesEmptyAction),
          ),
        ),
      ],
    );
  }
}
