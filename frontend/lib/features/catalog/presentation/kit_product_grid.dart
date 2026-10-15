import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_widgets.dart';
import 'kit_product_card.dart';

/// The height of one kit card: the picture, and the texts and the control
/// under it, which grow with the text scale. Each text is scaled by its own
/// font size, as a nonlinear scaler (Android 14 and later) enlarges small
/// sizes more than large ones.
double kitCardExtent(
  TextScaler scaler, {
  required KitCardSize size,
  required double imageHeight,
}) {
  final KitCardType type = KitCardType.of(size);
  final double name =
      2 *
      (scaler.scale(type.nameSize) * (type.nameHeight / type.nameSize))
          .ceilToDouble();
  // A laid-out line is as high as its rounded-up fractional height.
  final double price =
      (scaler.scale(type.priceSize) * KitCardType.priceLineHeight)
          .ceilToDouble();
  return 2 * KitCardType.padding +
      imageHeight +
      KitCardType.gapAfterPicture +
      name +
      KitCardType.gapAfterName +
      price +
      KitCardType.gapAfterPrice +
      KitCardType.bottomRowHeight;
}

/// A product list as a grid of kit cards, loaded a page at a time: the next
/// page when the end comes into view, a failed page with the retry of the
/// plain list. [empty] is shown when nothing matches; [padding] leaves room
/// for what floats over the list.
class KitProductGrid extends ConsumerWidget {
  const KitProductGrid({
    required this.query,
    this.columns = 2,
    this.size = KitCardSize.regular,
    this.imageHeight = 150,
    this.empty,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    super.key,
  });

  final ProductListQuery query;
  final int columns;
  final KitCardSize size;
  final double imageHeight;
  final Widget? empty;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ProductListState> list = ref.watch(
      productListProvider(query),
    );
    final EdgeInsets centred = EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + padding.bottom,
    );

    return list.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: !list.hasError,
      data: (ProductListState state) {
        if (state.items.isEmpty) {
          return Center(
            child: Padding(
              padding: centred,
              child:
                  empty ??
                  Text(l10n.catalogNoProducts, textAlign: TextAlign.center),
            ),
          );
        }
        final int rows = (state.items.length + columns - 1) ~/ columns;
        final double extent = kitCardExtent(
          MediaQuery.textScalerOf(context),
          size: size,
          imageHeight: imageHeight,
        );
        // Rows of one lazy list, so the end of the list is built, and asks
        // for the next page, only when it comes into view.
        return ListView.builder(
          key: const ValueKey<String>('product-grid'),
          padding: padding,
          itemCount: rows + (state.hasMore ? 1 : 0),
          itemBuilder: (BuildContext context, int row) {
            if (row == rows) {
              return ProductListEnd(query: query, state: state);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: extent,
                child: Row(
                  children: <Widget>[
                    for (
                      int column = 0;
                      column < columns;
                      column++
                    ) ...<Widget>[
                      if (column > 0) const SizedBox(width: 12),
                      Expanded(
                        child: row * columns + column < state.items.length
                            ? KitProductCard(
                                key: ValueKey<String>(
                                  state.items[row * columns + column].id,
                                ),
                                product: state.items[row * columns + column],
                                size: size,
                                imageHeight: imageHeight,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: centred,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FailureMessage(
                error is ApiFailure ? error : const UnexpectedFailure(),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey<String>('retry-load'),
                onPressed: () => ref.invalidate(productListProvider(query)),
                child: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
