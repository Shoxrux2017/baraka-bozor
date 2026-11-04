import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/fly_over.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/widgets/undo_bar.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../catalog/application/catalog_controllers.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/catalog_paths.dart';
import '../../catalog/presentation/kit_product_card.dart';
import '../../catalog/presentation/kit_product_grid.dart';
import '../../catalog/presentation/recommended_row.dart';
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

  /// The cards put into the list by a heart in the empty state's row, with the
  /// key of their photo: it is hidden until a copy of it has flown in
  /// (`DL-129`).
  Map<String, GlobalKey> _landing = const <String, GlobalKey>{};

  /// The screen's route is the top one and its tickers are on, as
  /// `PeriodicRefresh` reads it.
  bool _shown = false;

  /// A favourites list has been drawn on this screen for this account.
  bool _drawn = false;

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

  /// A heart set in the empty state's row: the card is in the list at once and
  /// its photo flies there; a heart the server refuses takes it out again. With
  /// reduced motion the card only fades in (`DL-129`).
  void _heartedInRow(
    CatalogProduct product,
    Rect photo,
    Future<ApiFailure?> answer,
  ) {
    final ProductListQuery query = _query();
    final String id = product.id;
    ref.read(productListProvider(query).notifier).put(product);
    final GlobalKey key = GlobalKey();
    if (!MediaQuery.disableAnimationsOf(context)) {
      setState(() => _landing = <String, GlobalKey>{..._landing, id: key});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _landing[id] != key) {
          return;
        }
        unawaited(
          flyOver(
            context,
            from: photo,
            to: () => _globalRect(key),
            child: SizedBox.expand(
              key: const ValueKey<String>('fly-over'),
              child: KitProductCard.photoGhost(product),
            ),
          ).then((_) => _landed(id, key)),
        );
      });
    }
    unawaited(
      answer.then((ApiFailure? failure) {
        if (failure == null || !mounted) {
          return;
        }
        _landed(id, key);
        // The server never had it: nothing is held back for it.
        final ProductListController list = ref.read(
          productListProvider(query).notifier,
        );
        final ListWithdrawal? withdrawal = list.withdraw(<String>{id});
        if (withdrawal != null) {
          list.settle(withdrawal);
        }
      }),
    );
  }

  Rect? _globalRect(GlobalKey key) {
    final RenderObject? box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _landed(String id, GlobalKey key) {
    if (mounted && _landing[id] == key) {
      setState(() => _landing = <String, GlobalKey>{..._landing}..remove(id));
    }
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
    // The first list this screen draws is read out when its first page comes
    // while the screen is shown (one that comes while the tab is hidden waits
    // for the tab). Another order of a list already drawn is announced by the
    // grid, so it is not read out twice.
    ref.listen(customerAccountProvider, (_, _) => _drawn = false);
    ref.listen(productListProvider(query), (
      AsyncValue<ProductListState>? before,
      AsyncValue<ProductListState> after,
    ) {
      if (before?.value != null || after.value == null) {
        return;
      }
      final bool first = !_drawn;
      _drawn = true;
      if (first && _isShown) {
        _announceList(query);
      }
    });
    // The count row is not drawn while the list is empty.
    final bool empty =
        ref.watch(productListProvider(query)).value?.items.isEmpty ?? false;
    // Featured products loaded and none: the empty state has no row to show.
    final ProductListState? featured = ref
        .watch(productListProvider(const ProductListQuery(featuredOnly: true)))
        .value;
    final bool recommend = featured == null || featured.items.isNotEmpty;

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
            empty: _Empty(recommend: recommend, onHearted: _heartedInRow),
            emptyAlignment: recommend ? Alignment.topCenter : Alignment.center,
            emptyInset: !recommend,
            landing: _landing,
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

/// Nothing hearted yet: what a heart does and, under «Рекомендуем», hearts to
/// try; or, without products to recommend, the way to the shop (`DL-129`).
class _Empty extends StatelessWidget {
  const _Empty({required this.recommend, required this.onHearted});

  final bool recommend;
  final void Function(CatalogProduct, Rect, Future<ApiFailure?>) onHearted;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget circle = DecoratedBox(
      key: const ValueKey<String>('favorites-heart-circle'),
      decoration: const BoxDecoration(
        color: KitColors.primaryWash,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: recommend ? 112 : 160,
        child: Icon(
          Icons.favorite,
          size: recommend ? 60 : 96,
          color: KitColors.primary,
        ),
      ),
    );
    final Widget title = Text(
      l10n.favoritesEmptyTitle,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: KitColors.ink,
      ),
    );
    final Widget text = Text(
      l10n.favoritesEmptyText,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, height: 1.4, color: KitColors.muted),
    );

    if (recommend) {
      const EdgeInsets inset = EdgeInsets.symmetric(horizontal: 24);
      return Column(
        key: const ValueKey<String>('favorites-empty'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 32),
          Center(child: circle),
          const SizedBox(height: 20),
          Padding(padding: inset, child: title),
          const SizedBox(height: 8),
          Padding(padding: inset, child: text),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              header: true,
              child: Text(
                l10n.recommendedTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          RecommendedRow(
            placeholders: true,
            titled: false,
            onHearted: onHearted,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey<String>('favorites-categories'),
              style: TextButton.styleFrom(
                foregroundColor: KitColors.primaryDark,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => context.push<void>(CatalogPaths.categories),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: Text(l10n.searchAllCategories)),
                  const SizedBox(width: 4),
                  const ExcludeSemantics(
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      key: const ValueKey<String>('favorites-empty'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        circle,
        const SizedBox(height: 24),
        title,
        const SizedBox(height: 8),
        text,
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
