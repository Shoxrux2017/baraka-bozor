import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fade_in_sliver.dart';
import '../../../core/widgets/list_scroll_indicator.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/stale_data_line.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'kit_product_card.dart';

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
/// of something else on the screen into the same line.
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

  @override
  ConsumerState<KitProductGrid> createState() => _KitProductGridState();
}

class _KitProductGridState extends ConsumerState<KitProductGrid> {
  static const int _skeletons = 6;
  static const double _gap = 12;

  /// The page-failure row's least height, with its gap.
  static const double _failureRow = 56 + _gap;

  bool _sawSkeleton = false;
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

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductListQuery query = widget.query;
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

  /// The length the list will have once every page is loaded: what is laid
  /// out, plus the rows still to come, less the end row it stands on.
  double _fullExtent(
    ScrollMetrics metrics,
    ProductListState? state,
    int columns,
    double extent,
  ) {
    final double laid = metrics.maxScrollExtent + metrics.viewportDimension;
    if (state == null || state.items.isEmpty) {
      return laid;
    }
    final int toCome =
        (state.total + columns - 1) ~/ columns -
        (state.items.length + columns - 1) ~/ columns;
    final double end = !state.hasMore
        ? 0
        : state.moreFailure == null
        ? extent + _gap
        : _failureRow;
    return laid + math.max(0, toCome) * (extent + _gap) - end;
  }

  bool _onlySortDiffers(ProductListQuery a, ProductListQuery b) =>
      a.categoryId == b.categoryId &&
      a.search == b.search &&
      a.featuredOnly == b.featuredOnly &&
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

        Widget cardsOf(List<CatalogProduct> items, {Widget? end}) =>
            cardRows(items.length, (int index) {
              final String id = items[index].id;
              final Widget card = KitProductCard(
                key: ValueKey<String>(id),
                product: items[index],
                size: widget.size,
                imageHeight: widget.imageHeight,
              );
              return _paged.contains(id)
                  ? _PageFade(
                      key: ValueKey<String>('card-fade-$id'),
                      animate: _faded.add(id),
                      child: card,
                    )
                  : card;
            }, end: end);

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
            child: rowOf(
              (int c) => _SkeletonCard(
                size: widget.size,
                imageHeight: widget.imageHeight,
                pulsing: !list.hasError,
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
        final ProductListQuery? drawn = _drawnQuery;
        final List<CatalogProduct> drawnItems = _drawnItems;
        if (state != null) {
          if (drawn != query) {
            _paged.clear();
            _faded.clear();
          } else if (state.items.length > drawnItems.length &&
              drawnItems.isNotEmpty) {
            _paged.addAll(
              state.items
                  .skip(drawnItems.length)
                  .map((CatalogProduct p) => p.id),
            );
          }
          _drawnQuery = query;
          _drawnItems = state.items;
          if (state.items.isEmpty) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + padding.bottom,
                    ),
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
            final bool animate = _sawSkeleton;
            _sawSkeleton = false;
            slivers.add(
              FadeInSliver(
                key: const ValueKey<String>('product-cards'),
                animate: animate,
                sliver: SliverPadding(
                  padding: body,
                  sliver: cardsOf(
                    state.items,
                    end: state.hasMore ? pageEnd(state) : null,
                  ),
                ),
              ),
            );
          }
        } else if (drawn != null &&
            _onlySortDiffers(drawn, query) &&
            drawnItems.isNotEmpty) {
          // Another order of the same products: the old cards stay, dimmed,
          // until the new list replaces them.
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
              fullExtent: (ScrollMetrics metrics) =>
                  _fullExtent(metrics, state, columns, extent),
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
