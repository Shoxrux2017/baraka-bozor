import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
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
                  empty: Text(
                    l10n.recommendedEmpty,
                    textAlign: TextAlign.center,
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
