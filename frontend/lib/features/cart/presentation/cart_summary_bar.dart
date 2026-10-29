import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_paths.dart';

/// The green bar at the foot of a product list without the tab bar while the
/// cart holds a line (`DL-80` (3)): the last line's picture, how many lines,
/// the approximate total, and the way to the cart. Place it at the bottom of
/// a stack; it takes no room when the cart is empty.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key});

  /// The room the bar and its fade take at the foot of a list: the bar's
  /// own height at the current text scale, its paddings, and the bottom
  /// inset of the screen.
  static double reserved(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final double count = scaler.scale(12) * 1.5;
    final double total = scaler.scale(15) * 1.5;
    final double open = scaler.scale(14) * 1.5 * 2;
    final double content = math.max(46, math.max(count + total, open));
    final double bar = math.max(64, content + 16);
    return 24 + bar + 12 + MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Cart? cart = ref.watch(currentCartProvider).value;
    if (cart == null || cart.lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    final CartLine last = cart.lines.last;
    final double inset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00FFFFFF), Colors.white],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 12 + inset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: KitColors.primary.withValues(alpha: 0.35),
                offset: Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: Material(
            key: const ValueKey<String>('cart-summary'),
            color: KitColors.primary,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(CartPaths.cart),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: ProductImage(url: last.imageUrl, size: 40),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.cartSummaryCount(cart.itemCount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              l10n.catalogApproxPrice(
                                MoneyFormat.uzs(
                                  cart.estimatedSubtotalUzs,
                                  interfaceLanguage(context),
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${l10n.cartSummaryOpen} →',
                          maxLines: 2,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
