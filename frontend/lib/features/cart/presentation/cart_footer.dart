import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/cart.dart';

/// The bar under the cart (drawing 19): "≈ total | Оформить", inactive with
/// its reason while a line is not sold or the minimum is not reached. With
/// the settings unfilled the total is absent and the button still opens the
/// checkout, which refuses as before.
class CartFooter extends StatelessWidget {
  const CartFooter({required this.cart, super.key});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? total = cart.estimatedTotalUzs;
    final int? minimum = cart.minimumOrderUzs;
    final String? why = cart.hasUnavailable
        ? l10n.cartWhyUnavailable
        : cart.belowMinimum && minimum != null
        ? l10n.cartWhyMinimum(
            MoneyFormat.uzs(minimum, interfaceLanguage(context)),
          )
        : null;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (why != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  why,
                  key: const ValueKey<String>('cart-why'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
              ),
            FilledButton(
              key: const ValueKey<String>('go-to-checkout'),
              style: FilledButton.styleFrom(
                backgroundColor: KitColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: KitColors.line,
                disabledForegroundColor: KitColors.muted,
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: cart.canCheckout
                  ? () {
                      // The "added" notices stay behind, queued ones too.
                      ScaffoldMessenger.of(context).clearSnackBars();
                      context.push(AppPaths.customerCheckout);
                    }
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (total != null) ...<Widget>[
                      Text(
                        l10n.cartLineEstimate(
                          MoneyFormat.uzs(total, interfaceLanguage(context)),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 1,
                        height: 22,
                        child: ColoredBox(
                          color: cart.canCheckout
                              ? Colors.white54
                              : KitColors.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      l10n.checkoutGo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
