import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../domain/checkout.dart';

/// The placed order (drawing 26): its number, how it is paid, and the way on.
/// [opensAt] is given only when the order was placed outside the working hours.
class CheckoutPlacedView extends StatelessWidget {
  const CheckoutPlacedView({
    required this.order,
    required this.opensAt,
    super.key,
  });

  final PlacedOrder order;
  final String? opensAt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? total = order.totalUzs;
    final String? opens = opensAt;
    // A replay answers the order as it is now: cancelled meanwhile, it is
    // said so.
    final bool cancelled = total == null;
    final String title = cancelled
        ? l10n.checkoutPlacedCancelled('${order.orderNumber}')
        : l10n.checkoutPlaced('${order.orderNumber}');
    final String body = cancelled
        ? l10n.totalNothingDue
        : order.totalKind == TotalKind.finalTotal
        ? l10n.checkoutPlacedCashFinal(
            MoneyFormat.uzs(total, interfaceLanguage(context)),
          )
        : l10n.checkoutPlacedCash;
    const TextStyle bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: KitColors.ink2,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          context.go(AppPaths.customer);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBEDEC),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    key: const ValueKey<String>('checkout-placed'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ExcludeSemantics(
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: const BoxDecoration(
                                color: KitColors.primaryWash,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: const BoxDecoration(
                                  color: KitColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: KitColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: bodyStyle,
                          ),
                          if (opens != null && !cancelled) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              l10n.checkoutPlacedOpensAt(opens),
                              textAlign: TextAlign.center,
                              style: bodyStyle,
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              key: const ValueKey<String>(
                                'checkout-open-order',
                              ),
                              onPressed: () {
                                final GoRouter router = GoRouter.of(context)
                                  ..go(AppPaths.customer);
                                router.push(AppPaths.customerOrder(order.id));
                              },
                              child: Text(l10n.checkoutOrderStatus),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              key: const ValueKey<String>('checkout-to-home'),
                              onPressed: () => context.go(AppPaths.customer),
                              child: Text(l10n.checkoutToHome),
                            ),
                          ),
                        ],
                      ),
                    ),
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
