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
