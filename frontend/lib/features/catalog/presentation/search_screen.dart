import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/flight_page.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../application/recent_searches.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'kit_product_grid.dart';
import 'recommended_row.dart';
import 'sort_menu.dart';

/// The search on its own screen (`DL-83`, drawings 15 to 17): the field, the
/// Customer's recent queries and the recommended
/// products while the field is empty, and the products it finds with their
/// count, or the nothing-found state, once a query stands.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  /// How long typing must pause before a search is sent, so a word typed
  /// quickly asks once rather than once per letter.
  static const Duration searchPause = Duration(milliseconds: 300);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _pause;
  String _query = '';

  /// The account the screen opened for, and its recent queries, captured
  /// while mounted so `dispose` never needs a `ref`.
  late final String? _account;
  late final RecentSearches? _recent;

  @override
  void initState() {
    super.initState();
    _account = ref.read(customerAccountProvider);
    final String? account = _account;
    _recent = account == null
        ? null
        : ref.read(recentSearchesProvider(account).notifier);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pause?.cancel();
    final String typed = ProductListQuery.searchOf(_field.text);
    if (typed.isNotEmpty) {
      unawaited(_recent?.remember(typed));
    }
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTyped(String text) {
    _pause?.cancel();
    setState(() {});
    _pause = Timer(SearchScreen.searchPause, () {
      if (mounted) {
        setState(() => _query = ProductListQuery.searchOf(text));
      }
    });
  }

  void _submit(String text) {
    _pause?.cancel();
    final String query = ProductListQuery.searchOf(text);
    setState(() => _query = query);
    if (query.isNotEmpty) {
      unawaited(_recent?.remember(query));
    }
  }

  void _pick(String recent) {
    _field.value = TextEditingValue(
      text: recent,
      selection: TextSelection.collapsed(offset: recent.length),
    );
    _submit(recent);
  }

  void _clear() {
    _pause?.cancel();
    _field.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductSort sort = ref.watch(productSortProvider);
    final bool keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // The mode stays visible while two sessions exist (DL-75).
        child: UnderActiveMode(
          child: Column(
            children: <Widget>[
              _topRow(l10n),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: _query.isEmpty
                          ? _EmptyField(account: _account, onPick: _pick)
                          : _Results(
                              query: ProductListQuery(
                                search: _query,
                                sort: sort,
                              ),
                            ),
                    ),
                    // The bar and the keyboard take turns (`DL-128`).
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: CartSummaryBar(hidden: keyboardUp),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow(AppLocalizations l10n) {
    final OutlineInputBorder plain = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    final OutlineInputBorder ring = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: KitColors.primary, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            key: const ValueKey<String>('search-back'),
            icon: const Icon(
              Icons.chevron_left,
              size: 28,
              color: KitColors.ink,
            ),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _back,
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                FlightTarget(
                  id: 'search-field',
                  child: TextField(
                    key: const ValueKey<String>('search-field'),
                    controller: _field,
                    focusNode: _focus,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(
                        ProductListQuery.searchMaxLength,
                      ),
                    ],
                    style: const TextStyle(color: KitColors.ink, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: l10n.catalogSearchHint,
                      hintStyle: const TextStyle(
                        color: KitColors.muted,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: KitColors.field,
                      constraints: const BoxConstraints(minHeight: 50),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 22,
                        color: KitColors.muted,
                      ),
                      suffixIcon: _field.text.isEmpty
                          ? null
                          : IconButton(
                              key: const ValueKey<String>('search-clear'),
                              icon: const Icon(
                                Icons.close,
                                size: 20,
                                color: KitColors.muted,
                              ),
                              tooltip: l10n.catalogSearchClear,
                              onPressed: _clear,
                            ),
                      border: plain,
                      enabledBorder: plain,
                      focusedBorder: _focus.hasFocus ? ring : plain,
                    ),
                    onChanged: _onTyped,
                    onSubmitted: _submit,
                  ),
                ),
                Positioned.fill(
                  child: _SearchProgress(
                    query: _query.isEmpty
                        ? null
                        : ProductListQuery(
                            search: _query,
                            sort: ref.watch(productSortProvider),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether a search keeps the cards of the one before it, dimmed, while it
/// loads: when the category and the recommended filter are the same
/// (`DL-128`).
bool searchKeepsCards(ProductListQuery drawn, ProductListQuery next) =>
    drawn.categoryId == next.categoryId &&
    drawn.featuredOnly == next.featuredOnly;

/// The 2 px line along the field's bottom edge while [query] loads with the
/// cards of another query dimmed under it (`DL-128`): a bar 40 % wide runs
/// across it, 1 s `easeInOut`, over and over; with reduced motion it stands
/// still, full width, at half opacity.
class _SearchProgress extends ConsumerStatefulWidget {
  const _SearchProgress({required this.query});

  final ProductListQuery? query;

  @override
  ConsumerState<_SearchProgress> createState() => _SearchProgressState();
}

class _SearchProgressState extends ConsumerState<_SearchProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  /// The last query that stood with cards, which the line is waiting to
  /// replace.
  ProductListQuery? _cardsOf;

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProductListQuery? query = widget.query;
    bool waiting = false;
    if (query == null) {
      _cardsOf = null;
    } else {
      final AsyncValue<ProductListState> list = ref.watch(
        productListProvider(query),
      );
      final ProductListState? known = list.isReloading ? null : list.value;
      if (known != null) {
        _cardsOf = known.items.isEmpty ? null : query;
      } else if (list.isLoading) {
        final ProductListQuery? drawn = _cardsOf;
        waiting =
            drawn != null && drawn != query && searchKeepsCards(drawn, query);
      }
    }
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (!waiting || reduced) {
      _run.stop();
    } else if (!_run.isAnimating) {
      _run.repeat();
    }
    if (!waiting) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(14),
            ),
            child: SizedBox(
              key: const ValueKey<String>('search-progress'),
              height: 2,
              width: double.infinity,
              child: ColoredBox(
                color: KitColors.primaryWash,
                child: Opacity(
                  opacity: reduced ? 0.5 : 1,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      if (reduced) {
                        return const ColoredBox(
                          key: ValueKey<String>('search-progress-bar'),
                          color: KitColors.primary,
                        );
                      }
                      return AnimatedBuilder(
                        animation: _run,
                        builder: (BuildContext context, Widget? child) {
                          final double t = Curves.easeInOut.transform(
                            _run.value,
                          );
                          return Stack(
                            children: <Widget>[
                              Positioned(
                                left: box.maxWidth * (-0.4 + 1.4 * t),
                                width: box.maxWidth * 0.4,
                                top: 0,
                                bottom: 0,
                                child: const ColoredBox(
                                  key: ValueKey<String>('search-progress-bar'),
                                  color: KitColors.primary,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The empty field (drawing 15): the recent queries, then "Рекомендуем".
class _EmptyField extends ConsumerWidget {
  const _EmptyField({required this.account, required this.onPick});

  final String? account;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? owner = account;
    final List<String> recent = owner == null
        ? const <String>[]
        : ref.watch(recentSearchesProvider(owner)).value ?? const <String>[];

    return ListView(
      padding: EdgeInsets.only(bottom: 16 + CartSummaryBar.reserved(context)),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        if (owner != null && recent.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.searchRecentTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('recent-clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: KitColors.primaryDark,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () =>
                      ref.read(recentSearchesProvider(owner).notifier).clear(),
                  child: Text(l10n.searchRecentClear),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (int i = 0; i < recent.length; i++)
                  _RecentChip(
                    key: ValueKey<String>('recent-$i'),
                    text: recent[i],
                    onTap: () => onPick(recent[i]),
                  ),
              ],
            ),
          ),
        ],
        const RecommendedRow(),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.text, required this.onTap, super.key});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KitColors.field,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.history, size: 16, color: KitColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: KitColors.ink2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A standing query (drawing 16): the count of what was found with the order
/// button, then the products in the current sort, or the nothing-found state.
class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final ProductListQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ProductListState> list = ref.watch(
      productListProvider(query),
    );
    // Nothing is counted for a search that found nothing or failed.
    final bool counted = list.value != null
        ? list.value!.total > 0
        : !list.hasError;

    return KitProductGrid(
      query: query,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      keepCardsOf: searchKeepsCards,
      header: <Widget>[
        if (counted)
          SliverToBoxAdapter(
            child: ProductListCountRow(
              key: const ValueKey<String>('search-found'),
              query: query,
              sort: query.sort,
              onSort: ref.read(productSortProvider.notifier).set,
              countText: l10n.searchFound,
              keepAcrossSearch: true,
            ),
          ),
      ],
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + CartSummaryBar.reserved(context),
      ),
      empty: _NothingFound(query: query.search),
    );
  }
}

/// Drawing 16a: nothing matches, with the way to every category.
class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const ValueKey<String>('search-nothing'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: KitColors.primaryWash,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off,
              size: 44,
              color: KitColors.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.searchNothingTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.searchNothingText(query),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: KitColors.muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const ValueKey<String>('search-all-categories'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              side: const BorderSide(color: KitColors.primary),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.push<void>(CatalogPaths.categories),
            child: Text(l10n.searchAllCategories),
          ),
        ],
      ),
    );
  }
}
