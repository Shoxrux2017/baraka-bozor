import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../catalog/application/catalog_controllers.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/kit_product_grid.dart';
import '../../catalog/presentation/sort_menu.dart';
import '../application/favorites_controllers.dart';

/// "Избранное": the products the Customer hearted, an ordinary product list
/// on the kit grid with a count-and-order row (`DL-129`). A favourite that
/// stopped being sold stays, marked as not sold, after the sold ones.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductSort sort = ref.watch(favoritesSortProvider);
    final ProductListQuery query = ProductListQuery.favorites(sort: sort);
    // The count row is not drawn while the list is empty.
    final bool empty =
        ref.watch(productListProvider(query)).value?.items.isEmpty ?? false;

    return CustomerTabScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(
          title: l10n.favoritesTitle,
          automaticallyImplyLeading: false,
          search: true,
          actions: const <Widget>[CartButton()],
        ),
        // The mode stays visible while two sessions exist (DL-75).
        body: UnderActiveMode(
          child: KitProductGrid(
            key: const ValueKey<String>('favorites-grid'),
            query: query,
            // A tap on the current tab takes the list back to the top.
            controller: PrimaryScrollController.maybeOf(context),
            empty: const _Empty(),
            header: empty
                ? const <Widget>[]
                : <Widget>[
                    SliverToBoxAdapter(
                      child: ProductListCountRow(
                        key: const ValueKey<String>('list-count-row'),
                        query: query,
                        sort: sort,
                        onSort: ref.read(favoritesSortProvider.notifier).set,
                      ),
                    ),
                  ],
          ),
        ),
        bottomNavigationBar: const CustomerTabBar(
          current: CustomerTab.favorites,
        ),
      ),
    );
  }
}

/// Nothing hearted yet: what a heart does, and the way to the shop.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey<String>('favorites-empty'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.primaryWash,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 96,
              color: KitColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.favoritesEmptyTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.favoritesEmptyText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: KitColors.muted,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey<String>('favorites-shop'),
            style: FilledButton.styleFrom(
              backgroundColor: KitColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => context.go(AppPaths.customer),
            child: Text(l10n.favoritesEmptyAction),
          ),
        ),
      ],
    );
  }
}
