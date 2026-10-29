import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/soft_change.dart';
import '../application/cart_controllers.dart';
import '../application/cart_quantity_queue.dart';
import '../domain/cart.dart';
import 'footer_total.dart';

const TextStyle _amountStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
);

/// The bar under the cart (drawing 19): "≈ total | Оформить", inactive with
/// its reason while a line is not sold or the minimum is not reached. With
/// the settings unfilled the total is absent and the button still opens the
/// checkout, which refuses as before. «Оформить» first sends what waits in the
/// quantity queue and opens the checkout only when that held; the total is
/// dimmed meanwhile. When "total | Оформить" does not fit the button at the
/// device's text size, the total stands over a button with «Оформить» alone
/// (`DL-119`).
class CartFooter extends ConsumerStatefulWidget {
  const CartFooter({required this.cart, super.key});

  final Cart cart;

  @override
  ConsumerState<CartFooter> createState() => _CartFooterState();
}

class _CartFooterState extends ConsumerState<CartFooter> {
  bool _settling = false;

  Future<void> _go() async {
    setState(() => _settling = true);
    final bool held = await ref
        .read(cartQuantityQueueProvider.notifier)
        .settle();
    if (!mounted) {
      return;
    }
    setState(() => _settling = false);
    // The answer may have closed the checkout (the minimum, a line gone); the
    // widget has not been rebuilt with it yet, so the provider is read.
    final bool open = ref.read(currentCartProvider).value?.canCheckout ?? false;
    if (!held || !open) {
      return;
    }
    // The "added" notices stay behind, queued ones too.
    ScaffoldMessenger.of(context).clearSnackBars();
    context.push(AppPaths.customerCheckout);
  }

  @override
  Widget build(BuildContext context) {
    final Cart cart = widget.cart;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool waiting = ref.watch(cartQuantityQueueProvider).isNotEmpty;
    final int? total = cart.availableCount > 0 ? cart.estimatedTotalUzs : null;
    final String? totalText = total == null
        ? null
        : l10n.cartLineEstimate(
            MoneyFormat.uzs(total, interfaceLanguage(context)),
          );
    final int? minimum = cart.minimumOrderUzs;
    final String? why = cart.hasUnavailable
        ? l10n.cartWhyUnavailable
        : cart.belowMinimum && minimum != null
        ? l10n.cartWhyMinimum(
            MoneyFormat.uzs(minimum, interfaceLanguage(context)),
          )
        : null;
    final bool active = cart.canCheckout && !_settling;

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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // The button's own padding is 18 on each side; its content is the
            // total, a 12 + 1 + 12 divider, «Оформить», 6 and the arrow.
            final double needed =
                (totalText == null
                    ? 0
                    : textWidth(context, totalText, _amountStyle) + 25) +
                textWidth(context, l10n.checkoutGo, _amountStyle) +
                6 +
                18 +
                36;
            final bool stacked =
                totalText != null && needed > constraints.maxWidth;
            return Column(
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: KitColors.muted,
                      ),
                    ),
                  ),
                if (stacked) ...<Widget>[
                  FooterTotal(
                    key: const ValueKey<String>('cart-footer-total'),
                    label: l10n.cartTotal,
                    value: totalText,
                    waiting: waiting,
                    width: constraints.maxWidth,
                  ),
                  const SizedBox(height: 8),
                ],
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
                  onPressed: active ? _go : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (totalText != null && !stacked) ...<Widget>[
                        SoftChange(
                          value: totalText,
                          waiting: waiting,
                          child: Text(totalText, style: _amountStyle),
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
                      Flexible(
                        child: Text(
                          l10n.checkoutGo,
                          textAlign: TextAlign.center,
                          style: _amountStyle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
