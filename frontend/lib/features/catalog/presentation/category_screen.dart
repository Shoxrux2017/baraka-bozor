import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/loaded.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/press_scale.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/domain/cart.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'all_categories_screen.dart';
import 'category_tile.dart';
import 'kit_product_card.dart';
import 'kit_product_grid.dart';
import 'sort_menu.dart';

/// One category (drawing 12): a rail of every category on the left, as the
/// kit's subcategory rail, and the category's products on the right. Choosing
/// another category switches the section in place (`DL-127`): the header and
/// the rail stay, the marker glides, the products and the title fade in, and
/// the location keeps the opened category, so back returns to where the
/// Customer came from. Opened from a tile it takes that tile's [opening], so
/// the tile's picture flies into the rail's well (`DL-125`) while the opened
/// category is the selected one. A section shown before is kept for the life of
/// the screen: it comes at once and refreshes quietly. At large text the rail
/// gives way to a row of chips, and lying the body keeps clear of a camera at
/// the side (`DL-127`).
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({required this.categoryId, this.opening, super.key});

  final String categoryId;
  final CategoryOpening? opening;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  late String _selectedId = widget.categoryId;
  final ScrollController _products = ScrollController();

  /// The section a switch announces once its first page is known.
  String? _announceFor;

  /// One subscription per list shown, held for the life of the screen so a
  /// section shown before comes back at once (`DL-127`).
  final Map<
    ProductListQuery,
    ProviderSubscription<AsyncValue<ProductListState>>
  >
  _kept = {};

  @override
  void didUpdateWidget(CategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _selectedId = widget.categoryId;
    }
  }

  @override
  void dispose() {
    for (final ProviderSubscription<AsyncValue<ProductListState>> kept
        in _kept.values) {
      kept.close();
    }
    _products.dispose();
    super.dispose();
  }

  /// Refreshed together with the list by a pull.
  Future<Object?> _refreshCategories() async {
    ref.invalidate(catalogCategoriesProvider);
    return ref.read(catalogCategoriesProvider.future);
  }

  void _select(CatalogCategory category) {
    if (category.id == _selectedId) {
      if (_products.hasClients && _products.offset > 0) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _products.jumpTo(0);
        } else {
          _products.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
      return;
    }
    HapticFeedback.selectionClick();
    final ProductListQuery next = ProductListQuery(
      categoryId: category.id,
      sort: ref.read(productSortProvider),
    );
    if (_kept.containsKey(next)) {
      // Shown before: its cards stand while it refreshes.
      ref.invalidate(productListProvider(next));
    }
    setState(() {
      _selectedId = category.id;
      _announceFor = category.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final AsyncValue<Loaded<List<CatalogCategory>>> async = ref.watch(
      catalogCategoriesProvider,
    );
    // The categories kept from the last load stand even when a refresh
    // failed (`DL-125`); only without any is the failure shown.
    final List<CatalogCategory>? rows = async.value?.data;
    final CatalogCategory? category = rows
        ?.where((CatalogCategory c) => c.id == _selectedId)
        .firstOrNull;
    final ProductSort sort = ref.watch(productSortProvider);
    final bool cartShown = ref.watch(
      currentCartProvider.select(
        (AsyncValue<Cart> cart) => cart.value?.lines.isNotEmpty ?? false,
      ),
    );
    final ProductListQuery query = ProductListQuery(
      categoryId: _selectedId,
      sort: sort,
    );
    // A category that does not exist asks for no products.
    if (category != null) {
      _kept.putIfAbsent(
        query,
        () => ref.listenManual(productListProvider(query), (previous, next) {}),
      );
    }
    final Loaded<List<CatalogCategory>>? loaded = async.value;
    final Object? categoriesError = async.hasError ? async.error : null;

    // A switch is announced once, when the first page of the section still
    // selected is known; at once when it was loaded before.
    if (category != null && _announceFor == _selectedId) {
      final ProductListState? shown = ref
          .watch(productListProvider(query))
          .value;
      if (shown != null) {
        _announceFor = null;
        final String message = l10n.categoryShownSpoken(
          category.name(language),
          l10n.catalogProductCount(shown.total),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            announce(context, message);
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: category?.name(language) ?? '',
        search: true,
        fadeTitle: true,
      ),
      // The mode stays visible while two sessions exist (DL-75), whatever
      // the body shows: loading, an error, not found or the products.
      body: SafeArea(
        top: false,
        bottom: false,
        child: UnderActiveMode(
          child: Builder(
            builder: (BuildContext context) {
              if (rows == null) {
                final Object? error = async.error;
                return async.hasError
                    ? CategoriesFailure(
                        failure: error is ApiFailure
                            ? error
                            : const UnexpectedFailure(),
                        onRetry: () =>
                            ref.invalidate(catalogCategoriesProvider),
                      )
                    : const Center(child: CircularProgressIndicator());
              }
              if (category == null) {
                return Center(child: Text(l10n.errorNotFound));
              }
              final bool chips =
                  textScaleAt(MediaQuery.textScalerOf(context), 11) > 1.3;
              final Widget grid = _SectionFade(
                section: _selectedId,
                child: KitProductGrid(
                  query: query,
                  size: KitCardSize.compact,
                  imageHeight: 84,
                  controller: _products,
                  header: <Widget>[
                    SliverToBoxAdapter(
                      child: ProductListCountRow(
                        key: const ValueKey<String>('list-count-row'),
                        query: query,
                        sort: sort,
                        onSort: ref.read(productSortProvider.notifier).set,
                      ),
                    ),
                  ],
                  alsoRefresh: _refreshCategories,
                  alsoFailed: categoriesError != null && loaded != null
                      ? (
                          failure: categoriesError is ApiFailure
                              ? categoriesError
                              : const UnexpectedFailure(),
                          at: loaded.at,
                        )
                      : null,
                  padding: EdgeInsets.fromLTRB(
                    chips ? 16 : 10,
                    chips ? 4 : 12,
                    chips ? 16 : 10,
                    12 + CartSummaryBar.reserved(context),
                  ),
                ),
              );
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: chips
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _CategoryChips(
                                categories: rows,
                                selectedId: _selectedId,
                                onSelect: _select,
                              ),
                              Expanded(child: grid),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _CategoryRail(
                                categories: rows,
                                selectedId: _selectedId,
                                openedId: widget.categoryId,
                                cartShown: cartShown,
                                heroTag:
                                    widget.opening == null ||
                                        MediaQuery.disableAnimationsOf(context)
                                    ? null
                                    : widget.opening!.heroTag,
                                onSelect: _select,
                              ),
                              Expanded(
                                child: ColoredBox(
                                  color: KitColors.card,
                                  child: grid,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: CartSummaryBar(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The products of a section, which fade in over 220 ms from the top each time
/// the section changes; at once with reduced motion (`DL-127`).
class _SectionFade extends StatefulWidget {
  const _SectionFade({required this.section, required this.child});

  final String section;
  final Widget child;

  @override
  State<_SectionFade> createState() => _SectionFadeState();
}

class _SectionFadeState extends State<_SectionFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void didUpdateWidget(_SectionFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const ValueKey<String>('section-fade'),
      opacity: _opacity,
      child: widget.child,
    );
  }
}

class _CategoryRail extends StatefulWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.openedId,
    required this.cartShown,
    required this.heroTag,
    required this.onSelect,
  });

  final List<CatalogCategory> categories;
  final String selectedId;

  /// The category the screen was opened on, the only one whose well the tile's
  /// picture flies into.
  final String openedId;

  /// Whether the cart bar stands over the rail's foot.
  final bool cartShown;

  /// The tag of the tile's picture that flies into the opened category's well.
  final Object? heroTag;
  final ValueChanged<CatalogCategory> onSelect;

  @override
  State<_CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<_CategoryRail> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _stack = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  /// The selected item's top and height in the rail, measured after layout.
  ({double top, double height})? _marker;
  bool _measureScheduled = false;

  GlobalKey _keyOf(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    // The selected category may lie below the fold: bring it into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _keyOf(widget.selectedId).currentContext;
      if (mounted && target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.5);
      }
    });
  }

  @override
  void didUpdateWidget(_CategoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The selected item's top and height inside the rail's content.
  ({double top, double height})? _selectedBox() {
    final RenderObject? stack = _stack.currentContext?.findRenderObject();
    final RenderObject? item = _itemKeys[widget.selectedId]?.currentContext
        ?.findRenderObject();
    if (stack is! RenderBox ||
        item is! RenderBox ||
        !stack.attached ||
        !item.attached ||
        !item.hasSize) {
      return null;
    }
    return (
      top: item.localToGlobal(Offset.zero, ancestor: stack).dy,
      height: item.size.height,
    );
  }

  void _measure() {
    _measureScheduled = false;
    final ({double top, double height})? box = _selectedBox();
    if (mounted && box != null && box != _marker) {
      setState(() => _marker = box);
    }
  }

  /// Scrolls the rail only when the selected item is not wholly in view.
  void _reveal() {
    final ({double top, double height})? box = _selectedBox();
    if (!mounted || box == null || !_scroll.hasClients) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    final double bottom = box.top + box.height;
    // The cart bar, while the cart holds lines, covers the rail's foot: an
    // item under it is not in view.
    final double visible =
        position.viewportDimension -
        (widget.cartShown ? CartSummaryBar.reserved(context) : 0);
    final double shownBottom = position.pixels + visible;
    final double? target = box.top < position.pixels
        ? box.top
        : bottom > shownBottom
        ? bottom - visible
        : null;
    if (target == null) {
      return;
    }
    final double clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(clamped);
    } else {
      _scroll.animateTo(
        clamped,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_measureScheduled) {
      _measureScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
    final ({double top, double height})? marker = _marker;
    final int count = widget.categories.length;
    return SizedBox(
      width: 94,
      child: SingleChildScrollView(
        key: const ValueKey<String>('category-rail'),
        controller: _scroll,
        padding: EdgeInsets.only(bottom: CartSummaryBar.reserved(context)),
        child: Stack(
          key: _stack,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < count; i++)
                  _RailItem(
                    key: ValueKey<String>('rail-${widget.categories[i].id}'),
                    itemKey: _keyOf(widget.categories[i].id),
                    category: widget.categories[i],
                    index: i + 1,
                    count: count,
                    selected: widget.categories[i].id == widget.selectedId,
                    heroTag:
                        widget.categories[i].id == widget.selectedId &&
                            widget.selectedId == widget.openedId
                        ? widget.heroTag
                        : null,
                    onTap: () => widget.onSelect(widget.categories[i]),
                  ),
              ],
            ),
            if (marker != null)
              AnimatedPositionedDirectional(
                key: const ValueKey<String>('rail-marker'),
                top: marker.top,
                height: marker.height,
                end: 0,
                width: 3,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: const Cubic(0.2, 0.8, 0.2, 1),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: KitColors.primary,
                    borderRadius: BorderRadiusDirectional.horizontal(
                      start: Radius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The categories as a row of chips under the header, instead of the rail,
/// when the text is large (`DL-127`). The selected chip is centred on opening
/// and scrolled the least that shows it on a switch.
class _CategoryChips extends StatefulWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<CatalogCategory> categories;
  final String selectedId;
  final ValueChanged<CatalogCategory> onSelect;

  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  GlobalKey _keyOf(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  void _show({required bool centred}) {
    final BuildContext? target = _keyOf(widget.selectedId).currentContext;
    if (!mounted || target == null || !target.mounted) {
      return;
    }
    final bool still = centred || MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      alignmentPolicy: centred
          ? ScrollPositionAlignmentPolicy.explicit
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      duration: still ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(centred: true));
  }

  @override
  void didUpdateWidget(_CategoryChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _show(centred: false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final Duration fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final int count = widget.categories.length;
    return SingleChildScrollView(
      key: const ValueKey<String>('category-chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Builder(
              builder: (BuildContext context) {
                final CatalogCategory category = widget.categories[i];
                final bool selected = category.id == widget.selectedId;
                final String name = category.name(language);
                return PressScale(
                  key: ValueKey<String>('chip-${category.id}'),
                  label: l10n.categoryRailSpoken(name, i + 1, count),
                  selected: selected,
                  onTap: () => widget.onSelect(category),
                  child: AnimatedContainer(
                    key: _keyOf(category.id),
                    duration: fade,
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? KitColors.primaryWash : KitColors.chip,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? KitColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? KitColors.primaryDark
                            : KitColors.ink2,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.itemKey,
    required this.category,
    required this.index,
    required this.count,
    required this.selected,
    required this.heroTag,
    required this.onTap,
    super.key,
  });

  /// Lets the rail measure the item for the marker and the scroll.
  final GlobalKey itemKey;
  final CatalogCategory category;
  final int index;
  final int count;
  final bool selected;
  final Object? heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = category.name(interfaceLanguage(context));
    final Widget well = CategoryPictureWell(
      category: category,
      size: 70,
      radius: 12,
      pictureSize: 44,
      color: selected ? KitColors.primaryWash : KitColors.card,
    );
    return PressScale(
      key: itemKey,
      label: AppLocalizations.of(context)
          .categoryRailSpoken(name, index, count),
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            heroTag == null
                ? well
                : Hero(
                    tag: heroTag!,
                    flightShuttleBuilder: categoryWellFlight,
                    child: well,
                  ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 15 / 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? KitColors.ink : KitColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
