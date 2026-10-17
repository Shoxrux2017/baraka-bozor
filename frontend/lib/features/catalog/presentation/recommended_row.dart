import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'kit_product_card.dart';
import 'kit_product_grid.dart';
import 'section_title.dart';

/// "Рекомендуем": up to ten recommended products in a row. The section is
/// absent while there is none, while it loads and when it fails: the home
/// stands without it. The cart shows it as "Добавьте к заказу": under its own
/// [title], without the products in [excludedProductIds], without "Все" and
/// with its own [rowKey].
class RecommendedRow extends ConsumerWidget {
  const RecommendedRow({
    this.title,
    this.excludedProductIds = const <String>{},
    this.showAll = true,
    this.rowKey = 'recommended-row',
    super.key,
  });

  final String? title;
  final Set<String> excludedProductIds;
  final bool showAll;
  final String rowKey;

  static const int shown = 10;
  static const double cardWidth = 150;
  static const double imageHeight = 130;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<CatalogProduct> items =
        (ref
                    .watch(
                      productListProvider(
                        const ProductListQuery(featuredOnly: true),
                      ),
                    )
                    .value
                    ?.items ??
                const <CatalogProduct>[])
            .where(
              (CatalogProduct product) =>
                  !excludedProductIds.contains(product.id),
            )
            .toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final double extent = kitCardExtent(
      MediaQuery.textScalerOf(context),
      size: KitCardSize.regular,
      imageHeight: imageHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionTitle(
          title: title ?? l10n.recommendedTitle,
          seeAllKey: 'open-recommended',
          onSeeAll: showAll
              ? () => context.push<void>(CatalogPaths.recommended)
              : null,
        ),
        SizedBox(
          height: extent,
          child: ListView.separated(
            key: ValueKey<String>(rowKey),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length < shown ? items.length : shown,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) => SizedBox(
              width: cardWidth,
              child: KitProductCard(
                key: ValueKey<String>(items[index].id),
                product: items[index],
                imageHeight: imageHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
