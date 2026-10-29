import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// The stepper of a cart line (drawing 19): a minus, the quantity — which
/// opens the exact-amount sheet — and a plus, in a green outline. While
/// [busy] its change runs all three are inactive; while the line cannot be
/// stepped, the minus and the plus are. With [atMinimum] the minus is a bin
/// (the order's editor, where the last step takes the line out).
class CartLineStepper extends StatelessWidget {
  const CartLineStepper({
    required this.id,
    required this.quantityText,
    required this.busy,
    required this.canStep,
    required this.onMinus,
    required this.onPlus,
    required this.onQuantity,
    this.atMinimum = false,
    super.key,
  });

  final String id;
  final String quantityText;
  final bool busy;
  final bool canStep;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onQuantity;
  final bool atMinimum;

  static const double width = 132;
  static const double height = 44;

  Widget _button(Key key, IconData icon, String label, VoidCallback onTap) {
    return SizedBox.square(
      dimension: height,
      child: IconButton(
        key: key,
        tooltip: label,
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: KitColors.primary,
        disabledColor: KitColors.primarySoft,
        icon: Icon(icon),
        onPressed: busy || !canStep ? null : onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Container(
      width: width,
      height: height,
      // The outline is drawn over the buttons, so they keep all 44.
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: KitColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          _button(
            ValueKey<String>('line-minus-$id'),
            atMinimum ? Icons.delete_outline : Icons.remove,
            atMinimum ? l10n.orderEditRemoveLine : l10n.cartStepMinus,
            onMinus,
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.cartQuantity,
              child: InkWell(
                key: ValueKey<String>('line-qty-$id'),
                onTap: busy ? null : onQuantity,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      quantityText,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _button(
            ValueKey<String>('line-plus-$id'),
            Icons.add,
            l10n.cartStepPlus,
            onPlus,
          ),
        ],
      ),
    );
  }
}
