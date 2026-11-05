import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/timed_banner.dart';
import '../domain/customer_orders.dart';

/// The strip the order page shows once an edit is saved: «Заказ изменён» over
/// the new total (`DL-132`). It moves as a [TimedBanner] from above does. It
/// does not announce: the editor did when it saved.
class OrderEditedBanner extends StatelessWidget {
  const OrderEditedBanner({required this.order, super.key});

  /// The order as the save answered it.
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? total = order.totalUzs;
    final String? totalWords =
        total == null || order.totalKind == TotalKind.none
        ? null
        : _words(context, l10n, total);

    final Widget card = DecoratedBox(
      key: const ValueKey<String>('edit-banner'),
      decoration: BoxDecoration(
        color: KitColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: KitColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.check_circle, size: 24, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.orderEditedTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (totalWords != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.orderEditedTotal(totalWords),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return TimedBanner(fromBelow: false, child: card);
  }

  /// The order's total, with «≈» while it is an estimate.
  String _words(BuildContext context, AppLocalizations l10n, int total) {
    final String amount = MoneyFormat.uzs(total, interfaceLanguage(context));
    return order.totalKind == TotalKind.estimate
        ? l10n.cartLineEstimate(amount)
        : amount;
  }
}
