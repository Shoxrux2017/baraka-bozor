import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/loaded.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/press_scale.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'all_categories_screen.dart';
import 'category_tile.dart';
import 'kit_product_card.dart';
import 'kit_product_grid.dart';

/// One category (drawing 12): a rail of every category on the left, as the
/// kit's subcategory rail, and the category's products on the right. Choosing
/// another category switches the section in place (`DL-127`): the header and
/// the rail stay, the marker glides, the products and the title fade in, and
/// the location keeps the opened category, so back returns to where the
/// Customer came from. Opened from a tile it takes that tile's [opening], so
/// the tile's picture flies into the rail's well (`DL-125`) while the opened
/// category is the selected one.
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

  @override
  void didUpdateWidget(CategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _selectedId = widget.categoryId;
    }
  }

  @override
  void dispose() {
    _products.dispose();
    super.dispose();
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

    // A switch is announced once, when the first page of the section still
    // selected is known; at once when it was loaded before.
    if (category != null && _announceFor == _selectedId) {
      final ProductListState? shown = ref
          .watch(productListProvider(ProductListQuery(categoryId: _selectedId)))
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
      body: UnderActiveMode(
        child: Builder(
          builder: (BuildContext context) {
            if (rows == null) {
              final Object? error = async.error;
              return async.hasError
                  ? CategoriesFailure(
                      failure: error is ApiFailure
                          ? error
                          : const UnexpectedFailure(),
                      onRetry: () => ref.invalidate(catalogCategoriesProvider),
                    )
                  : const Center(child: CircularProgressIndicator());
            }
            if (category == null) {
              return Center(child: Text(l10n.errorNotFound));
            }
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _CategoryRail(
                        categories: rows,
                        selectedId: _selectedId,
                        openedId: widget.categoryId,
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
                          child: _SectionFade(
                            section: _selectedId,
                            child: KitProductGrid(
                              query: ProductListQuery(categoryId: _selectedId),
                              size: KitCardSize.compact,
                              imageHeight: 84,
                              controller: _products,
                              padding: EdgeInsets.fromLTRB(
                                10,
                                12,
                                10,
                                12 + CartSummaryBar.reserved(context),
                              ),
                            ),
                          ),
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
    required this.heroTag,
    required this.onSelect,
  });

  final List<CatalogCategory> categories;
  final String selectedId;

  /// The category the screen was opened on, the only one whose well the tile's
  /// picture flies into.
  final String openedId;

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
    final double shownBottom = position.pixels + position.viewportDimension;
    final double? target = box.top < position.pixels
        ? box.top
        : bottom > shownBottom
        ? bottom - position.viewportDimension
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
