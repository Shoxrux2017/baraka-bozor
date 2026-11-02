import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'kit_product_card.dart';
import 'kit_product_grid.dart';
import 'section_title.dart';

/// "Рекомендуем": up to ten recommended products in a row. The section is
/// absent while there is none and, unless [placeholders] is set, while it
/// loads and when it fails: the home stands without it. With [placeholders]
/// (the home) the title stands over three skeleton cards until the products
/// come, and over still ones if the load failed; the products then fade in
/// (`DL-125`). The cart shows it as "Добавьте к заказу": under its own
/// [title], without the products in [excludedProductIds], without "Все" and
/// with its own [rowKey].
class RecommendedRow extends ConsumerStatefulWidget {
  const RecommendedRow({
    this.title,
    this.excludedProductIds = const <String>{},
    this.showAll = true,
    this.rowKey = 'recommended-row',
    this.placeholders = false,
    super.key,
  });

  final String? title;
  final Set<String> excludedProductIds;
  final bool showAll;
  final String rowKey;
  final bool placeholders;

  static const int shown = 10;
  static const int skeletonCards = 3;
  static const double imageHeight = 130;

  /// A card's width: 150, and wider with the text size, up to 260 (`DL-125`).
  static double cardWidth(TextScaler scaler) =>
      math.min(260, math.max(150, scaler.scale(150)));

  @override
  ConsumerState<RecommendedRow> createState() => _RecommendedRowState();
}

class _RecommendedRowState extends ConsumerState<RecommendedRow> {
  bool _sawSkeleton = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ProductListState> async = ref.watch(
      productListProvider(const ProductListQuery(featuredOnly: true)),
    );
    final bool skeletons = widget.placeholders && async.value == null;
    final List<CatalogProduct> items =
        (async.value?.items ?? const <CatalogProduct>[])
            .where(
              (CatalogProduct product) =>
                  !widget.excludedProductIds.contains(product.id),
            )
            .toList();
    if (!skeletons && items.isEmpty) {
      return const SizedBox.shrink();
    }
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double extent = kitCardExtent(
      scaler,
      size: KitCardSize.regular,
      imageHeight: RecommendedRow.imageHeight,
    );
    final double width = RecommendedRow.cardWidth(scaler);
    if (skeletons) {
      _sawSkeleton = true;
    }

    final Widget row = SizedBox(
      height: extent,
      child: skeletons
          ? _list(
              key: const ValueKey<String>('recommended-skeletons'),
              count: RecommendedRow.skeletonCards,
              card: (int index) =>
                  _SkeletonCard(width: width, pulsing: !async.hasError),
            )
          : _list(
              key: ValueKey<String>(widget.rowKey),
              count: math.min(items.length, RecommendedRow.shown),
              card: (int index) => SizedBox(
                width: width,
                child: KitProductCard(
                  key: ValueKey<String>(items[index].id),
                  product: items[index],
                  imageHeight: RecommendedRow.imageHeight,
                ),
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionTitle(
          title: widget.title ?? l10n.recommendedTitle,
          seeAllKey: 'open-recommended',
          seeAllLabel: l10n.recommendedAll,
          onSeeAll: widget.showAll && !skeletons
              ? () => context.push<void>(CatalogPaths.recommended)
              : null,
        ),
        if (!skeletons && _sawSkeleton)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (BuildContext context, double opacity, Widget? child) =>
                Opacity(
                  key: const ValueKey<String>('recommended-fade'),
                  opacity: opacity,
                  child: child,
                ),
            child: row,
          )
        else
          row,
      ],
    );
  }

  Widget _list({
    required Key key,
    required int count,
    required Widget Function(int index) card,
  }) {
    return ListView.separated(
      key: key,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: count,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(width: 12),
      itemBuilder: (BuildContext context, int index) => card(index),
    );
  }
}

/// A card's place while the products load: the picture, the name, the price
/// and the add button as bars.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.width, required this.pulsing});

  final double width;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBar(
            width: width,
            height: RecommendedRow.imageHeight,
            radius: 12,
            pulsing: pulsing,
          ),
          SizedBox(height: KitCardType.gapAfterPicture),
          SkeletonBar(width: width * 0.8, height: 12, pulsing: pulsing),
          SizedBox(height: KitCardType.gapAfterName),
          SkeletonBar(width: width * 0.55, height: 14, pulsing: pulsing),
          const Spacer(),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SkeletonBar(
              width: KitCardType.tapSide,
              height: KitCardType.tapSide,
              radius: 12,
              pulsing: pulsing,
            ),
          ),
        ],
      ),
    );
  }
}
