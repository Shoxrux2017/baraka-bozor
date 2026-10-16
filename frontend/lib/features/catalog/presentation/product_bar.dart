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
    this.onQuantityTap,
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

  /// Opens the entry of an exact quantity; the quantity is not a button
  /// without it.
  final VoidCallback? onQuantityTap;

  static const double height = 54;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    // While the add or the save waits the quantity stays as sent.
    final String? lower = busy
        ? null
        : CardQuantity.previous(product.unitCode, quantity);
    final String? upper = busy
        ? null
        : CardQuantity.next(product.unitCode, quantity);
    final String sum = l10n.catalogApproxPrice(
      MoneyFormat.uzs(
        EstimatePreview.lineUzs(product.customerUnitPriceUzs, quantity),
        language,
      ),
    );

    final String shownQuantity =
        '${QuantityRules.display(quantity)} '
        '${CatalogLabels.unit(l10n, product.unitCode)}';

    final Widget action = FilledButton(
      key: actionKey,
      style: FilledButton.styleFrom(
        backgroundColor: KitColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: KitColors.primarySoft,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // While busy the tap is taken and does nothing, so the button keeps
      // its colour and shows the wait.
      onPressed: onAction == null ? null : (busy ? () {} : onAction),
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          Text(
            sum,
            key: const ValueKey<String>('product-sum'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    Widget stepper() => _Stepper(
      quantity: shownQuantity,
      minusLabel: l10n.cartStepMinus,
      plusLabel: l10n.cartStepPlus,
      onQuantityTap: busy ? null : onQuantityTap,
      onMinus: lower == null ? null : () => onQuantity(lower),
      onPlus: upper == null ? null : () => onQuantity(upper),
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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // The quantity is read at the Customer's text size and never
            // shrunk: beside the action when both fit, else above it.
            final double stepperWidth = _Stepper.widthOf(
              context,
              shownQuantity,
            );
            final bool beside =
                stepperWidth + _gap + _actionMinWidth <= constraints.maxWidth;
            if (beside) {
              return Row(
                children: <Widget>[
                  SizedBox(width: stepperWidth, child: stepper()),
                  const SizedBox(width: _gap),
                  Expanded(child: action),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[stepper(), const SizedBox(height: 10), action],
            );
          },
        ),
      ),
    );
  }

  static const double _gap = 10;

  /// The least the action gets beside the stepper before it moves below.
  static const double _actionMinWidth = 120;
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.minusLabel,
    required this.plusLabel,
    required this.onQuantityTap,
    required this.onMinus,
    required this.onPlus,
  });

  final String quantity;

  final String minusLabel;
  final String plusLabel;
  final VoidCallback? onQuantityTap;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  static const double _buttonSize = 38;
  static const double _quantityMinWidth = 64;
  static const double _edge = 4;

  static const TextStyle quantityStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KitColors.ink,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dotted,
    decorationColor: KitColors.muted,
  );

  /// The width the stepper needs: two buttons, the edges and the quantity at
  /// the real font and text scale, at least [_quantityMinWidth].
  static double widthOf(BuildContext context, String quantity) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: quantity,
        style: DefaultTextStyle.of(context).style.merge(quantityStyle),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double text = painter.width;
    painter.dispose();
    return 2 * _edge +
        2 * _buttonSize +
        (text > _quantityMinWidth ? text : _quantityMinWidth);
  }

  Widget _button(Key key, IconData icon, String label, VoidCallback? onTap) {
    return SizedBox.square(
      dimension: _buttonSize,
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
            const SizedBox(width: _edge),
            _button(
              const ValueKey<String>('product-minus'),
              Icons.remove,
              minusLabel,
              onMinus,
            ),
            // Not in a Center: it would take the whole height it is offered.
            Expanded(
              child: InkWell(
                onTap: onQuantityTap,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: _quantityMinWidth,
                  ),
                  child: Text(
                    quantity,
                    key: const ValueKey<String>('product-qty'),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: quantityStyle,
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
            const SizedBox(width: _edge),
          ],
        ),
      ),
    );
  }
}
