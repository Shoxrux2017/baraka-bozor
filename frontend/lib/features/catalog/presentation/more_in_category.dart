import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'kit_product_card.dart';
import 'kit_product_grid.dart';
import 'section_title.dart';

/// "Ещё в категории": up to four other products of the product's category,
/// in the shop's order. The block is absent while it loads, when it fails
/// and when the category has nothing else: the product stands without it.
class MoreInCategory extends ConsumerWidget {
  const MoreInCategory({required this.product, super.key});

  final CatalogProduct product;

  static const int shown = 4;
  static const double cardWidth = 150;
  static const double imageHeight = 130;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final List<CatalogProduct> others =
        (ref
                    .watch(
                      productListProvider(
                        ProductListQuery(categoryId: product.categoryId),
                      ),
                    )
                    .value
                    ?.items ??
                const <CatalogProduct>[])
            .where((CatalogProduct other) => other.id != product.id)
            .take(shown)
            .toList();
    if (others.isEmpty) {
      return const SizedBox.shrink();
    }
    final CatalogCategory? category = ref
        .watch(catalogCategoriesProvider)
        .value
        ?.where((CatalogCategory c) => c.id == product.categoryId)
        .firstOrNull;
    final double extent = kitCardExtent(
      MediaQuery.textScalerOf(context),
      size: KitCardSize.regular,
      imageHeight: imageHeight,
    );

    return Column(
      key: const ValueKey<String>('more-in-category'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionTitle(
          title: category == null
              ? l10n.productMoreGeneric
              : l10n.productMoreIn(category.name(language)),
          seeAllKey: 'more-all',
          onSeeAll: () =>
              context.push<void>(CatalogPaths.category(product.categoryId)),
        ),
        SizedBox(
          height: extent,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // At most four cards: all of them are built.
            child: Row(
              children: <Widget>[
                for (int i = 0; i < others.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: cardWidth,
                    child: KitProductCard(
                      key: ValueKey<String>(others[i].id),
                      product: others[i],
                      imageHeight: imageHeight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
