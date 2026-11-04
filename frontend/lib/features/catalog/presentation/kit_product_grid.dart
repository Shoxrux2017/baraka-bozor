import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/flight_page.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fade_in_sliver.dart';
import '../../../core/widgets/list_scroll_indicator.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/stale_data_line.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'aisles.dart';
import 'grid_glide.dart';
import 'kit_product_card.dart';
import 'sort_menu.dart';

/// The height of one kit card: the picture, and the texts and the control
/// under it, which grow with the text scale. Each text is scaled by its own
/// font size, as a nonlinear scaler (Android 14 and later) enlarges small
/// sizes more than large ones.
double kitCardExtent(
  TextScaler scaler, {
  required KitCardSize size,
  required double imageHeight,
}) {
  final KitCardType type = KitCardType.of(size);
  final bool large = KitCardType.largeText(scaler, size);
  final double name =
      (large ? 3 : 2) *
      (scaler.scale(type.nameSize) * (type.nameHeight / type.nameSize))
          .ceilToDouble();
  // A laid-out line is as high as its rounded-up fractional height.
  final double price =
      (large ? 2 : 1) *
      (scaler.scale(type.priceSize) * KitCardType.priceLineHeight)
          .ceilToDouble();
  return 2 * KitCardType.padding +
      imageHeight +
      KitCardType.gapAfterPicture +
      name +
      KitCardType.gapAfterName +
      price +
      KitCardType.gapAfterPrice +
      KitCardType.bottomRowHeight;
}

/// How many cards stand side by side in a grid [width] wide inside its side
/// padding: as many as fit at the card's base width grown by the text scale,
/// two at least (`DL-127`).
int productColumns(double width, TextScaler scaler, KitCardSize size) {
  final double base = size == KitCardSize.compact ? 124 : 150;
  final double card =
      base * textScaleAt(scaler, KitCardType.of(size).nameSize) + 12;
  return math.max(2, ((width + 12) / card).floor());
}

/// A product list as a grid of kit cards in one scroll (`DL-127`): the stale
/// line, the [header] slivers, then the cards loaded a page at a time. Before
/// the first page it draws skeletons; a first page that fails shows the stale
/// line over still skeletons; a pull refreshes, and a refresh that fails keeps
/// the cards under a line that says when they are from. The columns follow the
/// width inside [padding] (`productColumns`). [empty] is shown when nothing
/// matches; [alsoRefresh] runs beside a pull and [alsoFailed] puts a failure
/// of something else on the screen into the same line. [end] closes the list
/// once it has no more; [spokenOnQuery] is announced when the first page of a
/// query comes, and every grid announces a new order, a later page and a
/// failed one (`DL-128`). With [aisles], and the shop's own order, the cards
/// stand under a heading for each aisle and report where the headings are.
class KitProductGrid extends ConsumerStatefulWidget {
  const KitProductGrid({
    required this.query,
    this.size = KitCardSize.regular,
    this.imageHeight = 150,
    this.empty,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.header = const <Widget>[],
    this.alsoRefresh,
    this.alsoFailed,
    this.controller,
    this.end,
    this.spokenOnQuery,
    this.emptyAlignment = Alignment.center,
    this.emptyInset = true,
    this.aisles,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.keepCardsOf,
    this.leaving = const <String>{},
    this.notSoldHeading,
    this.onHeartOff,
    this.landing = const <String, GlobalKey>{},
    this.beforeRefresh,
    super.key,
  });

  final ProductListQuery query;
  final KitCardSize size;
  final double imageHeight;
  final Widget? empty;
  final EdgeInsets padding;

  /// Slivers drawn above the cards, under the stale line.
  final List<Widget> header;

  /// Refreshed together with the list by a pull.
  final Future<Object?> Function()? alsoRefresh;

  /// A failure of what [alsoRefresh] loads, with when its data is from.
  final ({ApiFailure failure, DateTime at})? alsoFailed;
  final ScrollController? controller;

  /// Drawn after the last row once the list has no more; not while empty.
  final Widget? end;

  /// What is announced when the first page of a query comes, unless only its
  /// order changed from the query drawn before.
  final String Function(ProductListQuery query, int total)? spokenOnQuery;

  /// Where the [empty] slot stands in the room under the header.
  final Alignment emptyAlignment;

  /// Whether the [empty] slot keeps the 24 px margin around it; the slot that
  /// draws a full-width row of its own (`DL-128`) turns it off.
  final bool emptyInset;

  /// The aisles of the shop's order; the list is flat without them.
  final ProductAisles? aisles;

  /// Whether a drag over the list puts the keyboard away (`DL-128`).
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Whether the cards of the query drawn stay, dimmed, while the next one
  /// loads; by default only when the order alone differs (`DL-128`).
  final bool Function(ProductListQuery drawn, ProductListQuery next)?
  keepCardsOf;

  /// The cards that melt away and take no taps, until the list drops them
  /// (`DL-129`).
  final Set<String> leaving;

  /// Builds the full-width heading the not-sold cards stand under, from how
  /// many there are; drawn from the first not-sold card loaded on (`DL-129`).
  final Widget Function(int count)? notSoldHeading;

  /// Called for a tap on a red heart of a card, instead of the card changing
  /// the favourite (`DL-129`).
  final ValueChanged<CatalogProduct>? onHeartOff;

  /// The cards whose photo is hidden while a copy of it flies in, with the key
  /// each marks its photo with (`DL-129`).
  final Map<String, GlobalKey> landing;

  /// Awaited before a pull or «Повторить» asks the list again (`DL-129`).
  final Future<void> Function()? beforeRefresh;

  @override
  ConsumerState<KitProductGrid> createState() => _KitProductGridState();
}

class _KitProductGridState extends ConsumerState<KitProductGrid> {
  static const int _skeletons = 6;
  static const double _gap = 12;

  /// The page-failure row's least height, with its gap.
  static const double _failureRow = 56 + _gap;

  bool _sawSkeleton = false;

  /// Whether dimmed cards stood before the data now drawn: it fades in from
  /// their opacity (`DL-128`).
  bool _sawDimmed = false;
  bool _askScheduled = false;
  final ScrollController _own = ScrollController();

  /// Set at each build: how far from the end the next page is asked.
  double _askBelow = 0;

  /// The products that came with a later page, and those of them whose fade
  /// has started: a card fades in once, the first time it is built.
  final Set<String> _paged = <String>{};
  final Set<String> _faded = <String>{};

  /// The list last drawn with data, kept to dim while another order of the
  /// same products comes.
  ProductListQuery? _drawnQuery;
  List<CatalogProduct> _drawnItems = const <CatalogProduct>[];

  /// The edit count of the list last drawn: a change of products with another
  /// count is an edit in place, never a later page (`DL-129`).
  int _drawnEdits = 0;

  /// The layout last drawn with data, the basis of where a card was when the
  /// list changes under it (`DL-129`).
  ({
    int columns,
    double pitch,
    double rowExtent,
    int? tailStart,
    double headingHeight,
  })?
  _layout;

  /// How high the not-sold heading stood when last laid out, with the 10 px
  /// above it; until then the height of its button row.
  double _headingHeight = 54;
  final GlobalKey _headingKey = GlobalKey();
  bool _headingMeasureScheduled = false;

  /// Set at each build for the cards built from it: where a moved card was
  /// and the cards that arrive (`DL-129`).
  Map<String, Offset> _glides = const <String, Offset>{};
  Map<String, double> _arrivals = const <String, double>{};
  final GridMotionRegistry _motion = GridMotionRegistry();

  /// Whether the end of the list now drawn has faded in: it does so once per
  /// list, however often its row is built again (`DL-128`).
  bool _endShown = false;

  /// Whether the failure of the page now shown has been announced.
  bool _failureAnnounced = false;

  /// The sliver of aisle rows, whose offset the headings' starts add to.
  final GlobalKey _aisleSliver = GlobalKey();

  /// The aisle rows last built, with their extents, for the report.
  List<AisleRow> _aisleRows = const <AisleRow>[];
  List<double> _aisleExtents = const <double>[];
  bool _reportScheduled = false;

  /// Announces [message] once the frame is built.
  void _announceAfterFrame(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        announce(context, message);
      }
    });
  }

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductListQuery query = widget.query;
    await _beforeRefresh();
    final Future<void> also = _alsoRefresh();
    String message;
    try {
      ref.invalidate(productListProvider(query));
      await ref.read(productListProvider(query).future);
      message = l10n.refreshDone;
    } on Object catch (error) {
      final String reason = error is NetworkFailure
          ? l10n.staleOffline
          : l10n.staleFailed;
      final ProductListState? kept = ref.read(productListProvider(query)).value;
      message = kept == null
          ? reason
          : l10n.staleSpoken(reason, TashkentTime.time(kept.at));
    }
    await also;
    if (mounted) {
      announce(context, message);
    }
  }

  Future<void> _beforeRefresh() async {
    try {
      await widget.beforeRefresh?.call();
    } on Object {
      // The pull asks again whatever it could not finish.
    }
  }

  Future<void> _alsoRefresh() async {
    try {
      await widget.alsoRefresh?.call();
    } on Object {
      // Its own failure reaches the line through `alsoFailed`.
    }
  }

  /// Asks for the next page when fewer than three rows (the last two and the
  /// placeholders) are left below the screen; never while one loads, after a
  /// failure until «Повторить», or without more.
  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis == Axis.vertical &&
        metrics.extentAfter < _askBelow &&
        !_askScheduled) {
      _askScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _askScheduled = false;
        final ScrollController controller = widget.controller ?? _own;
        if (!mounted ||
            !controller.hasClients ||
            controller.position.extentAfter >= _askBelow) {
          return;
        }
        final ProductListState? state = ref
            .read(productListProvider(widget.query))
            .value;
        if (state != null && state.hasMore && state.moreFailure == null) {
          ref.read(productListProvider(widget.query).notifier).loadMore();
        }
      });
      // The metrics come after the frame; with nothing animating no other
      // frame would run the ask.
      SchedulerBinding.instance.scheduleFrame();
    }
    return false;
  }

  /// Keeps the heading's laid-out height for the next change of the list.
  void _measureHeading() {
    if (_headingMeasureScheduled) {
      return;
    }
    _headingMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headingMeasureScheduled = false;
      final Object? box = _headingKey.currentContext?.findRenderObject();
      if (mounted && box is RenderBox && box.hasSize) {
        _headingHeight = box.size.height;
      }
    });
  }

  /// Where the not-sold cards start: the first one, as the server puts the
  /// sold ones first; none without a heading to stand under.
  int? _tailStart(List<CatalogProduct> items) {
    if (widget.notSoldHeading == null) {
      return null;
    }
    final int first = items.indexWhere((CatalogProduct p) => !p.isAvailable);
    return first < 0 ? null : first;
  }

  /// Whether [after] is [before] with products added at its end: a later page.
  bool _appended(List<CatalogProduct> before, List<CatalogProduct> after) {
    if (before.isEmpty || after.length <= before.length) {
      return false;
    }
    for (int i = 0; i < before.length; i++) {
      if (before[i].id != after[i].id) {
        return false;
      }
    }
    return true;
  }

  bool _sameProducts(List<CatalogProduct> a, List<CatalogProduct> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  /// Tells [ProductAisles] where each heading stands once the frame is laid
  /// out: the sliver's own offset plus the rows before the heading.
  void _reportAisles() {
    if (_reportScheduled) {
      return;
    }
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      final Object? sliver = _aisleSliver.currentContext?.findRenderObject();
      final ProductAisles? aisles = widget.aisles;
      if (!mounted || aisles == null || sliver is! RenderSliver) {
        return;
      }
      double at = sliver.constraints.precedingScrollExtent;
      final Map<String, double> starts = <String, double>{};
      for (int i = 0; i < _aisleRows.length; i++) {
        final CatalogCategory? heading = _aisleRows[i].category;
        if (heading != null) {
          starts[heading.id] = at;
        }
        at += _aisleExtents[i];
      }
      aisles.report(starts);
    });
  }

  /// The length the list will have once every page is loaded: what is laid
  /// out, plus the rows still to come (for aisles, [aisleToCome]), less the
  /// end row it stands on.
  double _fullExtent(
    ScrollMetrics metrics,
    ProductListState? state,
    int columns,
    double extent, {
    double? aisleToCome,
  }) {
    final double laid = metrics.maxScrollExtent + metrics.viewportDimension;
    if (state == null || state.items.isEmpty) {
      return laid;
    }
    int rows(int count) => (count + columns - 1) ~/ columns;
    // With the not-sold group the sold and the not-sold cards fill rows of
    // their own, and the heading stands between them once the first not-sold
    // card is loaded.
    final bool grouped = widget.notSoldHeading != null && state.unavailable > 0;
    final int? tail = _tailStart(state.items);
    final int toCome = grouped
        ? rows(state.total - state.unavailable) +
              rows(state.unavailable) -
              rows(tail ?? state.items.length) -
              rows(tail == null ? 0 : state.items.length - tail)
        : rows(state.total) - rows(state.items.length);
    final double heading = grouped && tail == null ? _headingHeight : 0;
    final double end = !state.hasMore
        ? 0
        : state.moreFailure == null
        ? extent + _gap
        : _failureRow;
    return laid +
        heading +
        (aisleToCome ?? math.max(0, toCome) * (extent + _gap)) -
        end;
  }

  bool _onlySortDiffers(ProductListQuery a, ProductListQuery b) =>
      a.categoryId == b.categoryId &&
      a.search == b.search &&
      a.featuredOnly == b.featuredOnly &&
      a.favorites == b.favorites &&
      a.sort != b.sort;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductListQuery query = widget.query;
    final EdgeInsets padding = widget.padding;
    final AsyncValue<ProductListState> list = ref.watch(
      productListProvider(query),
    );
    final ProductListState? state = list.isReloading ? null : list.value;
    final Object? error = list.hasError ? list.error : null;
    final ApiFailure? listFailure = list.hasError
        ? (error is ApiFailure ? error : const UnexpectedFailure())
        : null;
    final ApiFailure? failure = listFailure ?? widget.alsoFailed?.failure;
    final DateTime? shownAt = listFailure != null
        ? state?.at
        : widget.alsoFailed?.at;

    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double extent = kitCardExtent(
      scaler,
      size: widget.size,
      imageHeight: widget.imageHeight,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = productColumns(
          constraints.maxWidth - padding.horizontal,
          scaler,
          widget.size,
        );

        Widget rowOf(Widget Function(int column) cell) => SizedBox(
          height: extent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int c = 0; c < columns; c++) ...<Widget>[
                if (c > 0) const SizedBox(width: _gap),
                Expanded(child: cell(c)),
              ],
            ],
          ),
        );

        /// Rows of [count] cards of one lazy list, then [end], the last row.
        Widget cardRows(
          int count,
          Widget Function(int index) card, {
          Widget? end,
        }) {
          final int rows = (count + columns - 1) ~/ columns;
          return SliverList(
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int row,
            ) {
              if (row == rows) {
                return end;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: rowOf(
                  (int c) => row * columns + c < count
                      ? card(row * columns + c)
                      : const SizedBox.shrink(),
                ),
              );
            }, childCount: rows + (end == null ? 0 : 1)),
          );
        }

        Widget cardAt(List<CatalogProduct> items, int index) {
          final String id = items[index].id;
          final Widget card = FlightTarget(
            id: 'card-$id',
            child: KitProductCard(
              key: ValueKey<String>(id),
              product: items[index],
              size: widget.size,
              imageHeight: widget.imageHeight,
              available: items[index].isAvailable,
              onHeartOff: widget.onHeartOff,
              photoKey: widget.landing[id],
              photoHidden: widget.landing.containsKey(id),
            ),
          );
          return GridCardMotion(
            key: ValueKey<String>('card-motion-$id'),
            id: id,
            registry: _motion,
            glideFrom: _glides[id],
            arriveFrom: _arrivals[id],
            leaving: widget.leaving.contains(id),
            child: _paged.contains(id)
                ? _PageFade(
                    key: ValueKey<String>('card-fade-$id'),
                    animate: _faded.add(id),
                    child: card,
                  )
                : card,
          );
        }

        Widget cardsOf(List<CatalogProduct> items, {Widget? end}) => cardRows(
          items.length,
          (int index) => cardAt(items, index),
          end: end,
        );

        final ProductAisles? aisles = widget.aisles;
        final bool aisleMode =
            aisles != null &&
            query.sort == ProductSort.shop &&
            aisles.categories.isNotEmpty;
        final double innerWidth = constraints.maxWidth - padding.horizontal;
        final AppLanguage language = interfaceLanguage(context);
        double headingExtent(CatalogCategory c, {required bool first}) =>
            aisleHeadingExtent(
              c,
              innerWidth,
              scaler,
              Directionality.of(context),
              language: language,
              first: first,
            );

        /// The loaded products as one list of exact row extents: a heading
        /// before each aisle, the cards of an aisle [columns] to a row.
        Widget aisleCardsOf(List<CatalogProduct> items) {
          final List<AisleRow> rows = aisleRows(
            items,
            aisles!.categories,
            columns,
          );
          final List<double> extents = <double>[
            for (final AisleRow row in rows)
              row.category != null
                  ? headingExtent(row.category!, first: row.first)
                  : extent + _gap,
          ];
          _aisleRows = rows;
          _aisleExtents = extents;
          _reportAisles();
          return SliverVariedExtentList.builder(
            key: _aisleSliver,
            itemCount: rows.length,
            itemExtentBuilder: (int index, SliverLayoutDimensions d) =>
                extents[index],
            itemBuilder: (BuildContext context, int index) {
              final AisleRow row = rows[index];
              final CatalogCategory? heading = row.category;
              if (heading != null) {
                return AisleHeading(category: heading, first: row.first);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: rowOf(
                  (int c) => c < row.cards.length
                      ? cardAt(items, row.cards[c])
                      : const SizedBox.shrink(),
                ),
              );
            },
          );
        }

        /// The end of a list with more to come: placeholders while the next
        /// page is on its way or about to be asked, the failure row after a
        /// failed one.
        Widget pageEnd(ProductListState state) {
          final ApiFailure? failed = state.moreFailure;
          if (failed != null) {
            return _PageFailure(
              failure: failed,
              onRetry: ref.read(productListProvider(query).notifier).loadMore,
            );
          }
          return Padding(
            key: const ValueKey<String>('product-placeholders'),
            padding: const EdgeInsets.only(bottom: _gap),
            child: Semantics(
              container: true,
              label: l10n.catalogMoreLoading,
              excludeSemantics: true,
              child: rowOf(
                (int c) => _SkeletonCard(
                  size: widget.size,
                  imageHeight: widget.imageHeight,
                  pulsing: !list.hasError,
                ),
              ),
            ),
          );
        }

        final List<Widget> slivers = <Widget>[
          if (failure != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  padding.top,
                  padding.right,
                  10,
                ),
                child: StaleDataLine(
                  key: const ValueKey<String>('stale-line'),
                  failure: failure,
                  shownAt: shownAt,
                  onRetry: _refresh,
                  busy: list.isLoading,
                ),
              ),
            )
          else
            SliverToBoxAdapter(child: SizedBox(height: padding.top)),
          ...widget.header,
        ];
        final EdgeInsets body = EdgeInsets.fromLTRB(
          padding.left,
          0,
          padding.right,
          padding.bottom,
        );

        _askBelow = 3 * (extent + _gap);
        final double pitch =
            (constraints.maxWidth - padding.horizontal - (columns - 1) * _gap) /
                columns +
            _gap;
        final ProductListQuery? drawn = _drawnQuery;
        final List<CatalogProduct> drawnItems = _drawnItems;
        if (state != null) {
          if (drawn != query) {
            _paged.clear();
            _faded.clear();
            _endShown = false;
            final String Function(ProductListQuery, int)? spoken =
                widget.spokenOnQuery;
            final String count = l10n.catalogProductCount(state.total);
            if (drawn != null && _onlySortDiffers(drawn, query)) {
              _announceAfterFrame(
                l10n.categoryShownSpoken(
                  sortLabel(l10n, query.sort, newestFirst: query.favorites),
                  count,
                ),
              );
            } else if (spoken != null) {
              _announceAfterFrame(spoken(query, state.total));
            }
          } else if (state.edits == _drawnEdits &&
              _appended(drawnItems, state.items)) {
            _paged.addAll(
              state.items
                  .skip(drawnItems.length)
                  .map((CatalogProduct p) => p.id),
            );
            _announceAfterFrame(
              l10n.catalogMoreLoaded(
                l10n.catalogProductCount(
                  state.items.length - drawnItems.length,
                ),
              ),
            );
          } else if (!_sawSkeleton &&
              !_sawDimmed &&
              !_sameProducts(drawnItems, state.items)) {
            // The same list edited in place: the cards that stay but changed
            // place glide, the ones not drawn before arrive (`DL-129`).
            final ({
              int columns,
              double pitch,
              double rowExtent,
              int? tailStart,
              double headingHeight,
            })?
            was = _layout;
            final GridCellPlace placeAfter = gridCellPlace(
              columns: columns,
              cellWidth: pitch,
              rowExtent: extent + _gap,
              tailStart: _tailStart(state.items),
              tailTop: _headingHeight,
            );
            // A list by aisles has its own geometry: its cards only arrive.
            final Map<String, Offset> glides = was == null || aisleMode
                ? const <String, Offset>{}
                : glideOffsets(
                    before: <String>[for (final p in drawnItems) p.id],
                    after: <String>[for (final p in state.items) p.id],
                    placeBefore: gridCellPlace(
                      columns: was.columns,
                      cellWidth: was.pitch,
                      rowExtent: was.rowExtent,
                      tailStart: was.tailStart,
                      tailTop: was.headingHeight,
                    ),
                    placeAfter: placeAfter,
                  );
            final Set<String> drawnIds = <String>{
              for (final CatalogProduct p in drawnItems) p.id,
            };
            // A card still on its way goes on from where it is drawn, whether
            // it glides or arrives.
            _glides = <String, Offset>{
              for (final MapEntry<String, Offset> e in glides.entries)
                e.key: e.value + _motion.remaining(e.key),
            };
            _arrivals = <String, double>{
              for (final CatalogProduct p in state.items)
                if (!drawnIds.contains(p.id))
                  p.id: 0
                else if (glides.containsKey(p.id) && _motion.arrived(p.id) < 1)
                  p.id: _motion.arrived(p.id),
            };
            // Only the cards built in this frame move; one built later, as it
            // scrolls into view, stands where it is.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _glides = const <String, Offset>{};
              _arrivals = const <String, double>{};
            });
          }
          final ApiFailure? moreFailure = state.moreFailure;
          if (moreFailure == null) {
            _failureAnnounced = false;
          } else if (!_failureAnnounced) {
            _failureAnnounced = true;
            _announceAfterFrame(
              moreFailure is NetworkFailure
                  ? l10n.catalogMoreOffline
                  : l10n.catalogMoreFailed,
            );
          }
          _drawnQuery = query;
          _drawnItems = state.items;
          _drawnEdits = state.edits;
          _layout = (
            columns: columns,
            pitch: pitch,
            rowExtent: extent + _gap,
            tailStart: _tailStart(state.items),
            headingHeight: _headingHeight,
          );
          if (state.items.isEmpty) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: widget.emptyAlignment,
                  child: Padding(
                    padding: widget.emptyInset
                        ? EdgeInsets.fromLTRB(24, 24, 24, 24 + padding.bottom)
                        : EdgeInsets.only(bottom: padding.bottom),
                    child:
                        widget.empty ??
                        Text(
                          l10n.catalogNoProducts,
                          textAlign: TextAlign.center,
                        ),
                  ),
                ),
              ),
            );
          } else {
            final bool animate = _sawSkeleton || _sawDimmed;
            final double fadeFrom = _sawSkeleton ? 0 : 0.45;
            _sawSkeleton = false;
            _sawDimmed = false;
            final Widget? end = state.hasMore
                ? pageEnd(state)
                : widget.end == null
                ? null
                : _EndFade(
                    key: const ValueKey<String>('list-end-fade'),
                    shown: () => _endShown,
                    onShown: () => _endShown = true,
                    child: widget.end!,
                  );
            if (state.hasMore) {
              _endShown = false;
            }
            if (aisleMode) {
              // The end rows keep their own height, so they stand after the
              // rows of exact extents.
              slivers.addAll(<Widget>[
                FadeInSliver(
                  key: const ValueKey<String>('product-cards'),
                  animate: animate,
                  from: fadeFrom,
                  sliver: SliverPadding(
                    padding: body.copyWith(bottom: 0),
                    sliver: aisleCardsOf(state.items),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    0,
                    padding.right,
                    padding.bottom,
                  ),
                  sliver: SliverToBoxAdapter(child: end),
                ),
              ]);
            } else {
              final int? tail = _tailStart(state.items);
              if (tail != null) {
                _measureHeading();
              }
              slivers.add(
                FadeInSliver(
                  key: const ValueKey<String>('product-cards'),
                  animate: animate,
                  from: fadeFrom,
                  sliver: SliverPadding(
                    padding: body,
                    sliver: tail == null
                        ? cardsOf(state.items, end: end)
                        : SliverMainAxisGroup(
                            slivers: <Widget>[
                              cardRows(
                                tail,
                                (int index) => cardAt(state.items, index),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  key: _headingKey,
                                  child: widget.notSoldHeading!(
                                    state.unavailable,
                                  ),
                                ),
                              ),
                              cardRows(
                                state.items.length - tail,
                                (int index) =>
                                    cardAt(state.items, tail + index),
                                end: end,
                              ),
                            ],
                          ),
                  ),
                ),
              );
            }
          }
        } else if (drawn != null &&
            (widget.keepCardsOf ?? _onlySortDiffers)(drawn, query) &&
            drawnItems.isNotEmpty &&
            !(listFailure != null && drawn.search != query.search)) {
          // Another order, or another search of the same products: the old
          // cards stay, dimmed, until the new list replaces them. A new text
          // that fails drops them (`DL-128`).
          _sawDimmed = true;
          slivers.add(
            SliverIgnorePointer(
              key: const ValueKey<String>('dimmed-cards'),
              sliver: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1, end: 0.45),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                builder:
                    (BuildContext context, double opacity, Widget? child) =>
                        SliverOpacity(
                          opacity: opacity,
                          sliver: SliverPadding(
                            padding: body,
                            sliver: cardsOf(drawnItems),
                          ),
                        ),
              ),
            ),
          );
        } else {
          if (listFailure != null &&
              drawn != null &&
              drawn.search != query.search) {
            // A new text that failed dropped the old cards for good: they do
            // not come back dimmed under the next text.
            _drawnQuery = null;
            _drawnItems = const <CatalogProduct>[];
          }
          _sawSkeleton = true;
          final bool pulsing = failure == null || list.isLoading;
          slivers.add(
            SliverPadding(
              key: const ValueKey<String>('product-skeletons'),
              padding: body,
              sliver: cardRows(
                _skeletons,
                (int index) => _SkeletonCard(
                  size: widget.size,
                  imageHeight: widget.imageHeight,
                  pulsing: pulsing,
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: KitColors.primary,
          onRefresh: _refresh,
          child: KeyedSubtree(
            key: ValueKey<ProductListQuery>(query),
            child: ListScrollIndicator(
              bottomInset: padding.bottom,
              fullExtent: (ScrollMetrics metrics) => _fullExtent(
                metrics,
                state,
                columns,
                extent,
                aisleToCome: aisleMode && state != null
                    ? aisleExtentToCome(
                        categories: aisles.categories,
                        items: state.items,
                        columns: columns,
                        rowExtent: extent + _gap,
                        headingExtent: (CatalogCategory c) =>
                            headingExtent(c, first: false),
                      )
                    : null,
              ),
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (ScrollMetricsNotification n) =>
                    n.depth == 0 && _onMetrics(n.metrics),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification n) =>
                      n.depth == 0 && _onMetrics(n.metrics),
                  child: CustomScrollView(
                    key: const ValueKey<String>('product-grid'),
                    controller: widget.controller ?? _own,
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: widget.keyboardDismissBehavior,
                    slivers: slivers,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A card that stands where a product is not known yet: the picture's well,
/// two bars for the name, and the square of the add button at the bottom end.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.size,
    required this.imageHeight,
    required this.pulsing,
  });

  final KitCardSize size;
  final double imageHeight;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final double side = KitCardType.buttonSide(size);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F151D16),
            offset: Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(KitCardType.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SkeletonBar(
              width: double.infinity,
              height: imageHeight,
              radius: 12,
              pulsing: pulsing,
            ),
            const SizedBox(height: KitCardType.gapAfterPicture),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: 0.9,
                child: SkeletonBar(
                  width: double.infinity,
                  height: 12,
                  pulsing: pulsing,
                ),
              ),
            ),
            const SizedBox(height: KitCardType.gapAfterName),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: 0.55,
                child: SkeletonBar(
                  width: double.infinity,
                  height: 12,
                  pulsing: pulsing,
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SkeletonBar(
                width: side,
                height: side,
                radius: 10,
                pulsing: pulsing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end block of a list: fades in over 250 ms `easeOut` when the list
/// reaches its end; at once with reduced motion (`DL-128`).
class _EndFade extends StatefulWidget {
  const _EndFade({
    required this.child,
    required this.shown,
    required this.onShown,
    super.key,
  });

  final Widget child;

  /// Whether this list's end has faded in already, and the note that it has.
  final bool Function() shown;
  final VoidCallback onShown;

  @override
  State<_EndFade> createState() => _EndFadeState();
}

class _EndFadeState extends State<_EndFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (widget.shown() || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    widget.onShown();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}

/// A card that fades in over 250 ms the first time it is built with a later
/// page; with reduced motion, or when [animate] is not set, it is there at
/// once (`DL-127`).
class _PageFade extends StatefulWidget {
  const _PageFade({required this.animate, required this.child, super.key});

  final bool animate;
  final Widget child;

  @override
  State<_PageFade> createState() => _PageFadeState();
}

class _PageFadeState extends State<_PageFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
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
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}

/// The row that takes the place of the placeholders when the next page did
/// not load: what happened, and «Повторить» in place (`DL-127`). It fades in
/// over 200 ms, at once with reduced motion.
class _PageFailure extends StatelessWidget {
  const _PageFailure({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) =>
          Opacity(opacity: opacity, child: child),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          key: const ValueKey<String>('product-page-failure'),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KitColors.line),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.cloud_off, size: 18, color: KitColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  failure is NetworkFailure
                      ? l10n.catalogMoreOffline
                      : l10n.catalogMoreFailed,
                  style: const TextStyle(fontSize: 13, color: KitColors.ink2),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('load-more'),
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: KitColors.primaryDark,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
