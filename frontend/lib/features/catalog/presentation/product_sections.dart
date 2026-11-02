import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/soft_change.dart';

/// "В корзине: 2 кг" above the name; the quantity rises softly when it
/// changes (`DL-122`).
class ProductInCartChip extends StatelessWidget {
  const ProductInCartChip({required this.quantity, super.key});

  /// The line's quantity as it is written, unit included: `2 кг`.
  final String quantity;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.shopping_bag_outlined,
              size: 16,
              color: KitColors.primaryDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: SoftChange(
                value: quantity,
                child: Text(
                  l10n.productInCart(quantity),
                  key: const ValueKey<String>('product-in-cart'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KitColors.primaryDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the last change of a line in the cart stands (`DL-122`).
enum ProductSaveState { saving, saved }

/// The small mark beside a field that says its change is on its way or kept:
/// a spinner and «Сохраняем…», then a check and «Сохранено». It fades in over
/// 200 ms, and a screen reader hears it as a live region.
class ProductSaveMark extends StatelessWidget {
  const ProductSaveMark({required this.state, super.key});

  final ProductSaveState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool saving = state == ProductSaveState.saving;
    final Color colour = saving ? KitColors.muted : KitColors.primaryDark;
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: saving
              ? SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KitColors.primary,
                    backgroundColor: KitColors.primary.withValues(alpha: 0.2),
                  ),
                )
              : Icon(Icons.check, size: 16, color: colour),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            saving ? l10n.productSaving : l10n.productLineSaved,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      child: MediaQuery.disableAnimationsOf(context)
          ? row
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (BuildContext context, double opacity, Widget? child) =>
                  Opacity(opacity: opacity, child: child),
              child: row,
            ),
    );
  }
}
