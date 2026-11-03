import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/routing/flight_page.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/undo_bar.dart';
import '../../cart/application/cart_controllers.dart';
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

  /// The count of the last found list of this visit; a search never shares it
  /// with «Все товары» or an earlier visit.
  final ListTotalMemo _found = ListTotalMemo();

  /// The account the screen opened for, and its recent queries, captured
  /// while mounted so `dispose` never needs a `ref`.
  late final String? _account;
  late final RecentSearches? _recent;

  /// The messenger the undo bar of the cleared list shows in, and that bar
  /// while it stands.
  late ScaffoldMessengerState _messenger;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undo;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _pause?.cancel();
    // The undo bar belongs to this screen: it leaves with it, and the list
    // stays cleared (`DL-128`).
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? undo =
        _undo;
    if (undo != null) {
      final ScaffoldMessengerState messenger = _messenger;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (messenger.mounted) {
          undo.close();
        }
      });
    }
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

  /// Remembers the typed text and opens a category from the sections.
  void _openSection(CatalogCategory category) {
    final String typed = ProductListQuery.searchOf(_field.text);
    if (typed.isNotEmpty) {
      unawaited(_recent?.remember(typed));
    }
    context.push<void>(CatalogPaths.category(category.id));
  }

  /// Clears the recent queries and offers them back for 5 s (`DL-128`).
  Future<void> _clearRecent() async {
    final RecentSearches? recent = _recent;
    if (recent == null) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool barShows =
        ref.read(currentCartProvider).value?.lines.isNotEmpty == true &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    final EdgeInsetsGeometry? margin = barShows
        ? EdgeInsets.fromLTRB(16, 0, 16, CartSummaryBar.reserved(context))
        : null;
    final List<String> cleared = await recent.clear();
    if (!mounted || cleared.isEmpty) {
      return;
    }
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> bar =
        showUndoBar(
          _messenger,
          text: l10n.searchRecentCleared,
          actionLabel: l10n.undoAction,
          duration: const Duration(seconds: 5),
          margin: margin,
          onUndo: () {
            if (mounted) {
              unawaited(recent.restore(cleared));
            }
          },
        );
    _undo = bar;
    unawaited(
      bar.closed.then((SnackBarClosedReason _) {
        if (identical(_undo, bar)) {
          _undo = null;
        }
      }),
    );
  }

  /// The at most two categories whose name, in either language, holds the
  /// typed text, in category order.
  List<CatalogCategory> _sectionsFor(List<CatalogCategory> all) {
    final String needle = RecentSearches.fold(
      ProductListQuery.searchOf(_field.text),
    );
    if (needle.isEmpty) {
      return const <CatalogCategory>[];
    }
    return all
        .where(
          (CatalogCategory c) =>
              RecentSearches.fold(c.nameRu).contains(needle) ||
              RecentSearches.fold(c.nameUz).contains(needle),
        )
        .take(2)
        .toList(growable: false);
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
    final List<CatalogCategory> matching = _sectionsFor(
      ref.watch(catalogCategoriesProvider).value?.data ??
          const <CatalogCategory>[],
    );
    final Widget sections = matching.isEmpty
        ? const SizedBox.shrink()
        : _Sections(
            key: const ValueKey<String>('search-sections'),
            categories: matching,
            typed: ProductListQuery.searchOf(_field.text),
            onOpen: _openSection,
          );

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
                          ? _EmptyField(
                              account: _account,
                              onPick: _pick,
                              onClear: _clearRecent,
                              sections: sections,
                            )
                          : _Results(
                              query: ProductListQuery(
                                search: _query,
                                sort: sort,
                              ),
                              sections: sections,
                              found: _found,
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
                          : Semantics(
                              label: l10n.searchClearQuery,
                              button: true,
                              excludeSemantics: true,
                              onTap: _clear,
                              child: IconButton(
                                key: const ValueKey<String>('search-clear'),
                                icon: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: KitColors.muted,
                                ),
                                tooltip: l10n.searchClearQuery,
                                onPressed: _clear,
                              ),
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
      } else if (list.hasError) {
        // A new text that failed drops the old cards (the grid does the
        // same), and «Повторить» reloads over skeletons: no line, and nothing
        // left to come back under the next text.
        if (_cardsOf?.search != query.search) {
          _cardsOf = null;
        }
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

/// The empty field (drawing 15): the matching sections, the recent queries,
/// then "Рекомендуем".
class _EmptyField extends ConsumerWidget {
  const _EmptyField({
    required this.account,
    required this.onPick,
    required this.onClear,
    required this.sections,
  });

  final String? account;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;
  final Widget sections;

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
        sections,
        if (owner != null && recent.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.searchRecentTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('recent-clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: KitColors.primaryDark,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: onClear,
                  child: Semantics(
                    label: l10n.searchRecentClearSpoken,
                    excludeSemantics: true,
                    child: Text(l10n.searchRecentClear),
                  ),
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
                    removeKey: ValueKey<String>('recent-remove-$i'),
                    text: recent[i],
                    onTap: () => onPick(recent[i]),
                    onRemove: () => ref
                        .read(recentSearchesProvider(owner).notifier)
                        .forget(recent[i]),
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

/// A recent query: the text part searches it again, the × forgets it
/// (`DL-128`).
class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.text,
    required this.onTap,
    required this.onRemove,
    required this.removeKey,
    super.key,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final Key removeKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Material(
      color: KitColors.field,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Semantics(
              label: l10n.searchRecentSpoken(text),
              button: true,
              excludeSemantics: true,
              onTap: onTap,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.history,
                          size: 16,
                          color: KitColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: KitColors.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: l10n.searchRecentRemove(text),
            button: true,
            excludeSemantics: true,
            onTap: onRemove,
            child: SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: removeKey,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                icon: const Icon(Icons.close, size: 18, color: KitColors.muted),
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The categories the typed text matches, on top of the screen from the first
/// letter (`DL-128`); they fade in over 180 ms, at once with reduced motion.
class _Sections extends StatefulWidget {
  const _Sections({
    required this.categories,
    required this.typed,
    required this.onOpen,
    super.key,
  });

  final List<CatalogCategory> categories;
  final String typed;
  final ValueChanged<CatalogCategory> onOpen;

  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final CatalogCategory category in widget.categories)
            _SectionRow(
              key: ValueKey<String>('search-section-${category.id}'),
              category: category,
              typed: widget.typed,
              onTap: () => widget.onOpen(category),
            ),
          const Divider(height: 1, thickness: 1, color: KitColors.line),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.category,
    required this.typed,
    required this.onTap,
    super.key,
  });

  final CatalogCategory category;
  final String typed;
  final VoidCallback onTap;

  /// The name with the part that matched the typed text in bold.
  TextSpan _name(String name) {
    const TextStyle plain = TextStyle(
      fontSize: 15,
      height: 1.3,
      color: KitColors.ink2,
    );
    final String needle = RecentSearches.fold(typed);
    final String folded = RecentSearches.fold(name);
    final int at = folded.length == name.length && needle.isNotEmpty
        ? folded.indexOf(needle)
        : -1;
    if (at < 0) {
      return TextSpan(text: name, style: plain);
    }
    return TextSpan(
      style: plain,
      children: <InlineSpan>[
        if (at > 0) TextSpan(text: name.substring(0, at)),
        TextSpan(
          text: name.substring(at, at + needle.length),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
        if (at + needle.length < name.length)
          TextSpan(text: name.substring(at + needle.length)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = category.name(interfaceLanguage(context));
    return Semantics(
      label: l10n.searchSectionSpoken(name),
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KitColors.primaryWash,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ProductImage(url: category.imageUrl, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text.rich(_name(name)),
                      Text(
                        l10n.searchSectionCaption,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: KitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: KitColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A standing query (drawing 16): the count of what was found with the order
/// button, then the products in the current sort, or the nothing-found state.
class _Results extends ConsumerWidget {
  const _Results({
    required this.query,
    required this.sections,
    required this.found,
  });

  final ProductListQuery query;
  final Widget sections;
  final ListTotalMemo found;

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
        SliverToBoxAdapter(child: sections),
        if (counted)
          SliverToBoxAdapter(
            child: ProductListCountRow(
              key: const ValueKey<String>('search-found'),
              query: query,
              sort: query.sort,
              onSort: ref.read(productSortProvider.notifier).set,
              countText: l10n.searchFound,
              keepAcrossSearch: true,
              memo: found,
            ),
          ),
      ],
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + CartSummaryBar.reserved(context),
      ),
      emptyAlignment: Alignment.topCenter,
      emptyInset: false,
      empty: _NothingFound(query: query.search),
      spokenOnQuery: (ProductListQuery q, int total) => total == 0
          ? l10n.searchNothingSpoken(q.search)
          : l10n.searchFound(total),
    );
  }
}

/// Drawing 16a: nothing matches, with the way to every category, and the
/// recommended products under it (`DL-128`).
class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      key: const ValueKey<String>('search-nothing'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                key: const ValueKey<String>('search-nothing-icon'),
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: KitColors.primaryWash,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off,
                  size: 30,
                  color: KitColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.searchNothingTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.searchNothingText(query),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: KitColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey<String>('search-all-categories'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KitColors.primaryDark,
                  side: const BorderSide(color: KitColors.primary),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.push<void>(CatalogPaths.categories),
                child: Text(l10n.searchAllCategories),
              ),
            ],
          ),
        ),
        const RecommendedRow(),
      ],
    );
  }
}
