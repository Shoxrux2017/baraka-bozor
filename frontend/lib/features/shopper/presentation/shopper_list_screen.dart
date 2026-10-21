import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/order_dates.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_empty_state.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../../shells/presentation/staff_area_menu.dart';
import '../application/shopper_orders_controllers.dart';
import '../domain/shopper_orders.dart';
import 'shopper_load.dart';
import 'shopper_status_card.dart';

/// The Shopper's area: their current orders, the longest-waiting first,
/// kept current while shown (`docs/09` section 28, `DL-69`, `DL-98`).
class ShopperOrdersScreen extends ConsumerWidget {
  const ShopperOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Paged<ShopperOrderRow>> page = ref.watch(
      shopperOrdersProvider,
    );
    final DateTime now = ref.watch(clockProvider)();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: l10n.myOrders,
        automaticallyImplyLeading: false,
        actions: const <Widget>[StaffAreaMenu()],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                active: loadSettled(page),
                onRefresh: () => ref.invalidate(shopperOrdersProvider),
                child: page.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: !page.hasError,
                  data: (Paged<ShopperOrderRow> page) =>
                      page.items.isEmpty && !page.hasPrevious
                      ? KitEmptyState(
                          key: const ValueKey<String>('shopper-orders-empty'),
                          icon: Icons.assignment_outlined,
                          title: l10n.shopperEmptyTitle,
                          text: l10n.shopperOrdersEmpty,
                        )
                      : ListView(
                          key: const ValueKey<String>('shopper-orders'),
                          padding: const EdgeInsets.all(20),
                          children: <Widget>[
                            // A page a refresh emptied, past the last one.
                            if (page.items.isEmpty)
                              Text(
                                l10n.shopperPageEmpty,
                                key: const ValueKey<String>(
                                  'shopper-page-empty',
                                ),
                              ),
                            for (final ShopperOrderRow row in page.items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _OrderCard(row: row, now: now),
                              ),
                            if (page.lastPage > 1 || page.hasPrevious)
                              PaginationBar(
                                page: page,
                                onPage: ref
                                    .read(shopperOrdersPageProvider.notifier)
                                    .goToPage,
                              ),
                          ],
                        ),
                  error: (Object error, StackTrace _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: LoadFailure(
                      error: error,
                      onRetry: () => ref.invalidate(shopperOrdersProvider),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One order of the list by the state of the assignment: new (to accept),
/// accepted (to start at the market), started (the lines left of all), or
/// any other status.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.row, required this.now});

  final ShopperOrderRow row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperAssignment assignment = row.assignment;
    final bool isNew = assignment.acceptedAt == null;
    final bool started =
        row.status == OrderStatus.shopping && assignment.startedAt != null;
    final bool accepted = !isNew && assignment.startedAt == null;

    final IconData icon;
    final Color tileColor;
    final Color iconColor;
    final String detail;
    final Widget chip;
    if (isNew) {
      icon = Icons.assignment_outlined;
      tileColor = KitColors.primaryWash;
      iconColor = KitColors.primaryDark;
      detail = l10n.shopperAssigned(
        orderAtLower(l10n, assignment.assignedAt, now),
      );
      chip = _NewChip(text: l10n.shopperChipNew);
    } else if (accepted) {
      icon = Icons.assignment_turned_in_outlined;
      tileColor = KitColors.field;
      iconColor = KitColors.muted;
      detail = l10n.shopperAccepted(
        orderAtLower(l10n, assignment.acceptedAt!, now),
      );
      chip = KitTag(text: l10n.shopperChipAccepted);
    } else if (started) {
      icon = Icons.shopping_basket_outlined;
      tileColor = KitColors.warningWash;
      iconColor = KitColors.warning;
      detail = l10n.shopperStarted(
        orderAtLower(l10n, assignment.startedAt!, now),
      );
      chip = KitTag(
        text: OrderLabels.status(l10n, row.status),
        tone: KitTone.amber,
      );
    } else {
      icon = Icons.assignment_outlined;
      tileColor = KitColors.field;
      iconColor = KitColors.muted;
      detail = '';
      chip = KitTag(text: OrderLabels.status(l10n, row.status));
    }

    return KitCard(
      key: ValueKey<String>('shopper-order-${row.id}'),
      onTap: () => context.push(AppPaths.shopperOrder(row.id)),
      outline: isNew ? KitColors.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          l10n.customerOrderTitle(row.orderNumber),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: KitColors.ink,
                          ),
                        ),
                        chip,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      started
                          ? l10n.shopperOpenOf(row.openItemCount, row.itemCount)
                          : l10n.orderItemCount(row.itemCount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KitColors.ink2,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (started && row.itemCount > 0) ...<Widget>[
            const SizedBox(height: 12),
            SegmentBar(
              segments: <Color>[
                for (int index = 0; index < row.itemCount; index++)
                  index < row.itemCount - row.openItemCount
                      ? KitColors.primary
                      : KitColors.line,
              ],
            ),
          ],
          if (row.deliveryTimeNote != null) ...<Widget>[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.schedule,
              text: l10n.shopperDeliveryWish(row.deliveryTimeNote!),
              color: KitColors.ink2,
            ),
          ],
          if (isNew) ...<Widget>[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.touch_app_outlined,
              text: l10n.shopperOpenToAccept,
              color: KitColors.primaryDark,
              bold: true,
            ),
          ] else if (accepted) ...<Widget>[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.storefront_outlined,
              text: l10n.shopperStartAtMarket,
              color: KitColors.ink2,
            ),
          ],
        ],
      ),
    );
  }
}

/// The solid green chip of a new order.
class _NewChip extends StatelessWidget {
  const _NewChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
