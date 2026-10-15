import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../cart/presentation/cart_summary_bar.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'kit_product_grid.dart';
import 'sort_sheet.dart';

/// "Все товары": every product the Customer may see, in the order the
/// Customer chose; the chip under the header shows it and reopens the sheet.
/// The header's search arrives with the search screen (kit stage 3).
class AllProductsScreen extends ConsumerWidget {
  const AllProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductSort sort = ref.watch(productSortProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: l10n.allProductsTitle),
      // The mode stays visible while two sessions exist (DL-75).
      body: UnderActiveMode(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Column(
                children: <Widget>[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: ActionChip(
                        key: const ValueKey<String>('sort-chip'),
                        avatar: const Icon(
                          Icons.swap_vert,
                          size: 18,
                          color: KitColors.ink,
                        ),
                        label: Text(sortLabel(l10n, sort)),
                        backgroundColor: KitColors.field,
                        side: const BorderSide(color: KitColors.line),
                        onPressed: () async {
                          final ProductSort? chosen = await showSortSheet(
                            context,
                            sort,
                          );
                          if (chosen != null) {
                            ref.read(productSortProvider.notifier).set(chosen);
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: KitProductGrid(
                      query: ProductListQuery(sort: sort),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        16 + CartSummaryBar.reserved(context),
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
        ),
      ),
    );
  }
}
