import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../catalog/presentation/kit_product_card.dart';
import '../../catalog/presentation/kit_product_grid.dart';
import '../application/favorites_controllers.dart';
import '../domain/favorites.dart';

/// "Избранное": the products the Customer hearted, as kit cards in two
/// columns. A favourite that stopped being sold stays, marked as not sold.
/// Un-hearting removes the card once the server has confirmed it.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static const double _imageHeight = 150;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<FavoritesListState> list = ref.watch(
      favoritesListProvider,
    );

    return CustomerTabScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(
          title: l10n.favoritesTitle,
          automaticallyImplyLeading: false,
        ),
        // The mode stays visible while two sessions exist (DL-75).
        body: UnderActiveMode(
          child: list.when(
            // A heart taken off reloads the list behind the cards, which stay
            // until the new list arrives.
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: !list.hasError,
            data: (FavoritesListState state) =>
                state.items.isEmpty ? const _Empty() : _Grid(state: state),
            error: (Object error, StackTrace _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FailureMessage(
                      error is ApiFailure ? error : const UnexpectedFailure(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const ValueKey<String>('retry-load'),
                      onPressed: () => ref.invalidate(favoritesListProvider),
                      child: Text(l10n.retryButton),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
        bottomNavigationBar: const CustomerTabBar(
          current: CustomerTab.favorites,
        ),
      ),
    );
  }
}

/// The favourites in two columns, a page at a time: the next page is asked
/// for when the end of the list comes into view.
class _Grid extends StatelessWidget {
  const _Grid({required this.state});

  final FavoritesListState state;

  static const int _columns = 2;

  @override
  Widget build(BuildContext context) {
    final int rows = (state.items.length + _columns - 1) ~/ _columns;
    final double extent = kitCardExtent(
      MediaQuery.textScalerOf(context),
      size: KitCardSize.regular,
      imageHeight: FavoritesScreen._imageHeight,
    );

    return ListView.builder(
      key: const ValueKey<String>('favorites-grid'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: rows + (state.hasMore ? 1 : 0),
      itemBuilder: (BuildContext context, int row) {
        if (row == rows) {
          return _End(state: state);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: extent,
            child: Row(
              children: <Widget>[
                for (int column = 0; column < _columns; column++) ...<Widget>[
                  if (column > 0) const SizedBox(width: 12),
                  Expanded(
                    child: row * _columns + column < state.items.length
                        ? _card(state.items[row * _columns + column])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(FavoriteProduct entry) => KitProductCard(
    key: ValueKey<String>(entry.product.id),
    product: entry.product,
    imageHeight: FavoritesScreen._imageHeight,
    available: entry.isAvailable,
  );
}

/// The last row of a list with more to load: it asks for the next page as it
/// is built, and after a failure offers the retry instead.
class _End extends ConsumerWidget {
  const _End({required this.state});

  final FavoritesListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FavoritesListController list = ref.read(
      favoritesListProvider.notifier,
    );
    final ApiFailure? failure = state.moreFailure;

    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            FailureMessage(failure),
            TextButton(
              key: const ValueKey<String>('load-more'),
              onPressed: list.loadMore,
              child: Text(AppLocalizations.of(context).catalogLoadMore),
            ),
          ],
        ),
      );
    }

    if (!state.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => list.loadMore());
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Nothing hearted yet: what a heart does, and the way to the shop.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            key: const ValueKey<String>('favorites-empty'),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
              ),
            ),
          ),
    );
  }
}
