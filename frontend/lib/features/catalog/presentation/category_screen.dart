import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'all_categories_screen.dart';
import 'catalog_paths.dart';
import 'category_tile.dart';
import 'kit_product_card.dart';
import 'kit_product_grid.dart';

/// One category (drawing 12): a rail of every category on the left, as the
/// kit's subcategory rail, and the category's products on the right. Choosing
/// another category replaces the location, so back returns to where the
/// Customer came from.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({required this.categoryId, super.key});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final AsyncValue<List<CatalogCategory>> categories = ref.watch(
      catalogCategoriesProvider,
    );
    final CatalogCategory? category = categories.value
        ?.where((CatalogCategory c) => c.id == categoryId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: category?.name(language) ?? ''),
      // The mode stays visible while two sessions exist (DL-75), whatever
      // the body shows: loading, an error, not found or the products.
      body: UnderActiveMode(
        child: categories.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: !categories.hasError,
          data: (List<CatalogCategory> rows) {
            if (category == null) {
              return Center(child: Text(l10n.errorNotFound));
            }
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _CategoryRail(categories: rows, selectedId: categoryId),
                      Expanded(
                        child: ColoredBox(
                          color: KitColors.card,
                          child: KitProductGrid(
                            query: ProductListQuery(categoryId: categoryId),
                            size: KitCardSize.compact,
                            imageHeight: 84,
                            padding: EdgeInsets.fromLTRB(
                              10,
                              12,
                              10,
                              12 + CartSummaryBar.reserved(context),
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
          error: (Object error, StackTrace _) => CategoriesFailure(
            failure: error is ApiFailure ? error : const UnexpectedFailure(),
            onRetry: () => ref.invalidate(catalogCategoriesProvider),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatefulWidget {
  const _CategoryRail({required this.categories, required this.selectedId});

  final List<CatalogCategory> categories;
  final String selectedId;

  @override
  State<_CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<_CategoryRail> {
  final GlobalKey _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    // The selected category may lie below the fold: bring it into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _selected.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      child: SingleChildScrollView(
        key: const ValueKey<String>('category-rail'),
        padding: EdgeInsets.only(bottom: CartSummaryBar.reserved(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final CatalogCategory c in widget.categories)
              _RailItem(
                key: c.id == widget.selectedId ? _selected : null,
                category: c,
                selected: c.id == widget.selectedId,
                onTap: () => context.replace(CatalogPaths.category(c.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.category,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CatalogCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = category.name(interfaceLanguage(context));
    return InkWell(
      key: ValueKey<String>('rail-${category.id}'),
      onTap: selected ? null : onTap,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CategoryPictureWell(
                  category: category,
                  size: 70,
                  radius: 12,
                  pictureSize: 44,
                  color: selected ? KitColors.primaryWash : KitColors.card,
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
          if (selected)
            const PositionedDirectional(
              top: 0,
              bottom: 0,
              end: 0,
              width: 3,
              child: ColoredBox(color: KitColors.primary),
            ),
        ],
      ),
    );
  }
}
