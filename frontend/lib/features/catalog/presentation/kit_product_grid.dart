import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fade_in_sliver.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/stale_data_line.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_widgets.dart';
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

  bool _sawSkeleton = false;

  /// The list last drawn with data, kept to dim while another order of the
  /// same products comes.
  ProductListQuery? _drawnQuery;
  List<CatalogProduct> _drawnItems = const <CatalogProduct>[];

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
    final ProductListState? state = list.value;
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

        /// Rows of [count] cards of one lazy list, so [end], the last row, is
        /// built, and asks for the next page, only when it comes into view.
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
                child: SizedBox(
                  height: extent,
                  child: Row(
                    children: <Widget>[
                      for (int c = 0; c < columns; c++) ...<Widget>[
                        if (c > 0) const SizedBox(width: _gap),
                        Expanded(
                          child: row * columns + c < count
                              ? card(row * columns + c)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }, childCount: rows + (end == null ? 0 : 1)),
          );
        }

        Widget cardsOf(List<CatalogProduct> items, {Widget? end}) => cardRows(
          items.length,
          (int index) => KitProductCard(
            key: ValueKey<String>(items[index].id),
            product: items[index],
            size: widget.size,
            imageHeight: widget.imageHeight,
          ),
          end: end,
        );

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

        final ProductListQuery? drawn = _drawnQuery;
        final List<CatalogProduct> drawnItems = _drawnItems;
        if (state != null) {
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
                    end: state.hasMore
                        ? ProductListEnd(query: query, state: state)
                        : null,
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
            child: CustomScrollView(
              key: const ValueKey<String>('product-grid'),
              controller: widget.controller,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
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
