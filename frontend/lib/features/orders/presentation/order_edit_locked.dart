import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/customer_orders.dart';
import 'order_edit_sheets.dart';
import 'order_sections.dart';

/// Leaves the editor for the order: back to it when the editor was opened
/// over it, with the order [saved] for its banner, to it when the editor was
/// opened by its address alone, with no banner (`DL-132`).
void backToOrder(GoRouter router, String orderId, [CustomerOrder? saved]) {
  if (router.canPop()) {
    router.pop(saved);
  } else {
    router.go(AppPaths.customerOrder(orderId));
  }
}

/// The lock view's title: the order was cancelled, or shopping started.
String lockedTitle(AppLocalizations l10n, CustomerOrder order) =>
    order.status == OrderStatus.cancelled
    ? l10n.orderEditLockedCancelled
    : l10n.orderEditLockedTitle;

/// What the editor says when the server refuses the edit because the order
/// can no longer change: what did not save, the way to the support phone
/// when the order has one, and the way back to the order (`DL-132`). [order]
/// is the order as it loaded again, [lost] the changes that were not saved.
class OrderEditLocked extends ConsumerWidget {
  const OrderEditLocked({required this.order, required this.lost, super.key});

  final CustomerOrder order;
  final List<String> lost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? phone = order.supportPhone;
    final String title = lockedTitle(l10n, order);

    return Column(
      key: const ValueKey<String>('edit-locked'),
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(child: _LockIcon()),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phone == null
                      ? l10n.orderEditLockedTextNoPhone
                      : l10n.orderEditLockedText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: KitColors.ink2,
                  ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.orderEditLost,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ChangeList(changes: lost),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: KitColors.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (phone != null) ...<Widget>[
                  OutlinedButton.icon(
                    key: const ValueKey<String>('edit-call-support'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KitColors.primaryDark,
                      side: const BorderSide(
                        color: KitColors.primary,
                        width: 1.5,
                      ),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.call, size: 20),
                    label: Text(
                      l10n.orderCallSupport,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => dialOrSay(context, ref, phone),
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton(
                  key: const ValueKey<String>('edit-back-to-order'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => backToOrder(GoRouter.of(context), order.id),
                  child: Text(
                    l10n.orderOpen,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LockIcon extends StatelessWidget {
  const _LockIcon();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: KitColors.warningWash,
        ),
        child: const Icon(
          Icons.shopping_basket,
          size: 36,
          color: KitColors.warningDark,
        ),
      ),
    );
  }
}
