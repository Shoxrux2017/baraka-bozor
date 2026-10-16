import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/estimate_preview.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/application/card_quantity.dart';
import '../domain/catalog.dart';

/// The product screen's bottom bar (drawing 18): the quantity stepper, which
/// steps as the card does, and the action with the previewed sum under its
/// label. The screen owns the quantity and what the action does; the bar
/// only shows them. A null [onAction] disables the action, and while [busy]
/// it waits and ignores taps.
class ProductBar extends StatelessWidget {
  const ProductBar({
    required this.product,
    required this.quantity,
    required this.onQuantity,
    required this.actionKey,
    required this.actionLabel,
    required this.onAction,
    required this.busy,
    super.key,
  });

  final CatalogProduct product;

  /// The quantity as the API takes it: `1`, `1.5`.
  final String quantity;
  final ValueChanged<String> onQuantity;
  final Key actionKey;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  static const double height = 54;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final String? lower = CardQuantity.previous(product.unitCode, quantity);
    final String upper = CardQuantity.next(product.unitCode, quantity)!;
    final String sum = l10n.catalogApproxPrice(
      MoneyFormat.uzs(
        EstimatePreview.lineUzs(product.customerUnitPriceUzs, quantity),
        language,
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            offset: Offset(0, -6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: _Stepper(
                quantity:
                    '${QuantityRules.display(quantity)} '
                    '${CatalogLabels.unit(l10n, product.unitCode)}',
                minusLabel: l10n.cartStepMinus,
                plusLabel: l10n.cartStepPlus,
                onMinus: lower == null ? null : () => onQuantity(lower),
                onPlus: () => onQuantity(upper),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: FilledButton(
                key: actionKey,
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: KitColors.primarySoft,
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size(0, height),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                // While busy the tap is taken and does nothing, so the
                // button keeps its colour and shows the wait.
                onPressed: onAction == null ? null : (busy ? () {} : onAction),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      busy
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                                semanticsLabel: l10n.cartSaving,
                              ),
                            )
                          : Text(
                              actionLabel,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      Text(
                        sum,
                        key: const ValueKey<String>('product-sum'),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.minusLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final String quantity;
  final String minusLabel;
  final String plusLabel;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  Widget _button(Key key, IconData icon, String label, VoidCallback? onTap) {
    return SizedBox.square(
      dimension: 38,
      child: IconButton(
        key: key,
        tooltip: label,
        padding: EdgeInsets.zero,
        iconSize: 22,
        color: KitColors.primaryDark,
        disabledColor: KitColors.muted,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ProductBar.height),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 4),
            _button(
              const ValueKey<String>('product-minus'),
              Icons.remove,
              minusLabel,
              onMinus,
            ),
            // Not in a Center: it would take the whole height it is offered.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  quantity,
                  key: const ValueKey<String>('product-qty'),
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: KitColors.muted,
                  ),
                ),
              ),
            ),
            _button(
              const ValueKey<String>('product-plus'),
              Icons.add,
              plusLabel,
              onPlus,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
