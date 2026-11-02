import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/application/card_quantity.dart';
import '../domain/catalog.dart';

/// What the bar's action shows and does (`DL-122`).
enum ProductBarAction {
  /// "В корзину" over the sum.
  add,

  /// The add is on its way: the same green button with a spinner.
  adding,

  /// The add was taken: a check and "В корзине", for a moment.
  added,

  /// The product is in the cart: "Открыть корзину" over what is there.
  openCart,
}

/// The product screen's bottom bar (drawing 18): the quantity stepper, which
/// steps as the card does, and the action with the previewed sum under its
/// label. The screen owns the quantity and what the action does; the bar
/// only shows them. A null [onAction] disables the action, and [locked]
/// makes the stepper and the quantity wait.
class ProductBar extends StatelessWidget {
  const ProductBar({
    required this.product,
    required this.quantity,
    required this.sumUzs,
    required this.onQuantity,
    required this.action,
    required this.onAction,
    this.locked = false,
    this.onQuantityTap,
    super.key,
  });

  final CatalogProduct product;

  /// The quantity as the API takes it: `1`, `1.5`.
  final String quantity;

  /// The sum written under the label.
  final int sumUzs;
  final ValueChanged<String> onQuantity;
  final ProductBarAction action;
  final VoidCallback? onAction;

  /// Whether the stepper and the quantity wait for an answer.
  final bool locked;

  /// Opens the entry of an exact quantity; the quantity is not a button
  /// without it.
  final VoidCallback? onQuantityTap;

  static const double height = 54;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // While the add waits the quantity stays as sent.
    final String? lower = locked
        ? null
        : CardQuantity.previous(product.unitCode, quantity);
    final String? upper = locked
        ? null
        : CardQuantity.next(product.unitCode, quantity);
    final String sum = l10n.catalogApproxPrice(
      MoneyFormat.uzs(sumUzs, interfaceLanguage(context)),
    );

    final String shownQuantity =
        '${QuantityRules.display(quantity)} '
        '${CatalogLabels.unit(l10n, product.unitCode)}';

    final Widget actionButton = switch (action) {
      ProductBarAction.add || ProductBarAction.adding => FilledButton(
        key: const ValueKey<String>('add-to-cart'),
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
        // While adding the tap is taken and does nothing, so the button
        // keeps its colour and shows the wait.
        onPressed: onAction == null
            ? null
            : (action == ProductBarAction.adding ? () {} : onAction),
        child: action == ProductBarAction.adding
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: _labelOverSum(l10n.productAdding, sum)),
                ],
              )
            : _labelOverSum(l10n.productAddToCart, sum),
      ),
      ProductBarAction.added => _AddedMark(text: l10n.productAdded),
      ProductBarAction.openCart => OutlinedButton(
        key: const ValueKey<String>('open-cart'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: KitColors.primaryDark,
          side: const BorderSide(color: KitColors.primary, width: 1.5),
          minimumSize: const Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onAction,
        child: _labelOverSum(l10n.cartOpen, '$shownQuantity · $sum'),
      ),
    };

    Widget stepper() => _Stepper(
      quantity: shownQuantity,
      minusLabel: l10n.cartStepMinus,
      plusLabel: l10n.cartStepPlus,
      onQuantityTap: locked ? null : onQuantityTap,
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
                  Expanded(child: actionButton),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                stepper(),
                const SizedBox(height: 10),
                actionButton,
              ],
            );
          },
        ),
      ),
    );
  }

  /// A label over a sum, one line each.
  static Widget _labelOverSum(String label, String sum) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      Text(
        sum,
        key: const ValueKey<String>('product-sum'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ],
  );

  static const double _gap = 10;

  /// The least the action gets beside the stepper before it moves below.
  static const double _actionMinWidth = 120;
}

/// "В корзине" with a check that pops in from small and clear in 340 ms; with
/// reduced motion it stands at once (`DL-122`).
class _AddedMark extends StatelessWidget {
  const _AddedMark({required this.text});

  final String text;

  static const Cubic _pop = Cubic(0.2, 0.9, 0.3, 1.3);

  @override
  Widget build(BuildContext context) {
    const Widget check = Icon(
      Icons.check_circle,
      size: 22,
      color: Colors.white,
    );
    return DecoratedBox(
      key: const ValueKey<String>('product-added'),
      decoration: BoxDecoration(
        color: KitColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ProductBar.height),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (MediaQuery.disableAnimationsOf(context))
                check
              else
                TweenAnimationBuilder<double>(
                  key: const ValueKey<String>('product-added-check'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 340),
                  curve: _pop,
                  builder: (BuildContext context, double t, Widget? child) =>
                      Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.3 + 0.7 * t,
                          child: child,
                        ),
                      ),
                  child: check,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
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

  static const double _buttonSize = 44;
  static const double _quantityMinWidth = 64;

  static const TextStyle quantityStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KitColors.ink,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dotted,
    decorationColor: KitColors.muted,
  );

  /// The width the stepper needs: two 44 buttons and the quantity at
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
    return 2 * _buttonSize +
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
          ],
        ),
      ),
    );
  }
}
