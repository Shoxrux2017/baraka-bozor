import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'kit_product_grid.dart';
import 'sort_menu.dart';

/// "Рекомендуем": the products the shop recommends, as kit cards, under a
/// count row with the order menu (`DL-127`). The header's search arrives with
/// the search screen (kit stage 3).
class RecommendedScreen extends ConsumerWidget {
  const RecommendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductSort sort = ref.watch(productSortProvider);
    final ProductListQuery query = ProductListQuery(
      featuredOnly: true,
      sort: sort,
    );

    final int? total = ref.watch(productListProvider(query)).value?.total;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: l10n.recommendedTitle,
        search: true,
        titleFlight: true,
      ),
      // The mode stays visible while two sessions exist (DL-75).
      // Side insets (a camera at the side, lying) are kept clear (DL-127).
      body: SafeArea(
        top: false,
        bottom: false,
        child: UnderActiveMode(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: KitProductGrid(
                  query: query,
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + CartSummaryBar.reserved(context),
                  ),
                  emptyAlignment: Alignment.topCenter,
                  empty: const _EmptySelection(),
                  end: total == null || total == 0
                      ? null
                      : _SelectionEnd(total: total),
                  spokenOnQuery: (ProductListQuery q, int count) =>
                      l10n.categoryShownSpoken(
                        l10n.recommendedTitle,
                        l10n.catalogProductCount(count),
                      ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CartSummaryBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The block that closes the list: "Это вся подборка: 24 товара" and the way
/// on to every product (`DL-128`).
class _SelectionEnd extends StatelessWidget {
  const _SelectionEnd({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('list-end'),
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KitColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            l10n.recommendedEnd(l10n.catalogProductCount(total)),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: KitColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const ValueKey<String>('list-end-all'),
            onPressed: () => context.push<void>(CatalogPaths.products),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              backgroundColor: KitColors.primaryWash,
              foregroundColor: KitColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    l10n.allProductsTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KitColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: KitColors.primaryDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What stands in the list when nothing is recommended: a picture, what
/// happened, and the way to the categories (`DL-128`).
class _EmptySelection extends StatelessWidget {
  const _EmptySelection();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      key: const ValueKey<String>('recommended-empty'),
      // The grid's empty slot adds 24 a side: 24 + 16 = the drawing's 40.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: KitColors.primaryWash,
              shape: BoxShape.circle,
            ),
            child: const ExcludeSemantics(
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 56,
                color: KitColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.recommendedEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.recommendedEmptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 20 / 13,
              color: KitColors.muted,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const ValueKey<String>('recommended-empty-categories'),
            onPressed: () => context.push<void>(CatalogPaths.categories),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              backgroundColor: KitColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.searchAllCategories,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
