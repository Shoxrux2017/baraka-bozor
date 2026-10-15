import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../domain/catalog.dart';
import 'kit_product_grid.dart';

/// "Рекомендуем": the products the shop recommends, as kit cards. The
/// header's search arrives with the search screen (kit stage 3).
class RecommendedScreen extends StatelessWidget {
  const RecommendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          l10n.recommendedTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: KitProductGrid(
              query: const ProductListQuery(featuredOnly: true),
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + CartSummaryBar.height,
              ),
              empty: Text(l10n.recommendedEmpty, textAlign: TextAlign.center),
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
    );
  }
}
