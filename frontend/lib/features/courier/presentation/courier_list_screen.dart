import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/paged.dart';
import '../../../core/platform/clock.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_empty_state.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit/kit_status_card.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../../shells/presentation/staff_area_menu.dart';
import '../application/courier_orders_controllers.dart';
import '../domain/courier_orders.dart';
import 'courier_stage.dart';

/// Whether a screen's load has settled on data, so its periodic refresh
/// may run (`DL-54` (15)).
bool _settled(AsyncValue<Object?> value) =>
    value.hasValue && !value.hasError && !value.isLoading;

/// The Courier's area: their current deliveries, the longest-waiting first,
/// kept current while shown (`docs/09` section 36, `DL-72`, `DL-99`). Its
/// app bar holds one menu, as the Shopper's does (`DL-69` (5)).
class CourierOrdersScreen extends ConsumerWidget {
  const CourierOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Paged<CourierOrder>> page = ref.watch(
      courierOrdersProvider,
    );
    final DateTime now = ref.watch(clockProvider)();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: l10n.myDeliveries,
        automaticallyImplyLeading: false,
        actions: const <Widget>[StaffAreaMenu()],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                active: _settled(page),
                onRefresh: () => ref.invalidate(courierOrdersProvider),
                child: page.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: !page.hasError,
                  data: (Paged<CourierOrder> page) =>
                      page.items.isEmpty && !page.hasPrevious
                      ? KitEmptyState(
                          key: const ValueKey<String>('courier-orders-empty'),
                          icon: Icons.local_shipping_outlined,
                          title: l10n.courierEmptyTitle,
                          text: l10n.courierOrdersEmpty,
                        )
                      : ListView(
                          key: const ValueKey<String>('courier-orders'),
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                          children: <Widget>[
                            // A page a refresh emptied, past the last one.
                            if (page.items.isEmpty)
                              Text(
                                l10n.courierPageEmpty,
                                key: const ValueKey<String>(
                                  'courier-page-empty',
                                ),
                              ),
                            for (final CourierOrder order in page.items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _DeliveryCard(order: order, now: now),
                              ),
                            if (page.lastPage > 1 || page.hasPrevious)
                              PaginationBar(
                                page: page,
                                onPage: ref
                                    .read(courierOrdersPageProvider.notifier)
                                    .goToPage,
                              ),
                          ],
                        ),
                  error: (Object error, StackTrace _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: LoadFailure(
                      error: error,
                      onRetry: () => ref.invalidate(courierOrdersProvider),
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

/// One delivery of the list by its stage: new (to accept), accepted (to pick
/// up), on the way (with the time to deliver by), or any other status.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order, required this.now});

  final CourierOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CourierStage stage = courierStage(order);
    final CourierAssignment assignment = order.assignment;
    final DeliveryAddress? address = order.address;
    final DateTime? startedAt = assignment.deliveryStartedAt;
    final DateTime? delayAt = assignment.delayAt;
    final int? amount = order.amountToCollectUzs;

    final bool active =
        stage == CourierStage.assigned || stage == CourierStage.onTheWay;
    final String detail;
    final Widget chip;
    switch (stage) {
      case CourierStage.assigned:
        detail = l10n.courierAssigned(
          orderAtLower(l10n, assignment.assignedAt, now),
        );
        chip = _NewChip(text: l10n.courierChipNew);
      case CourierStage.accepted:
        detail = l10n.courierAccepted(
          orderAtLower(l10n, assignment.acceptedAt!, now),
        );
        chip = KitTag(text: l10n.courierChipAccepted);
      case CourierStage.onTheWay:
        final String since = startedAt == null
            ? ''
            : orderAtLower(l10n, startedAt, now);
        detail = startedAt == null
            ? ''
            : delayAt == null
            ? l10n.courierOnTheWaySince(since)
            : l10n.courierOnTheWayLine(since, TashkentTime.time(delayAt));
        chip = KitTag(
          text: OrderLabels.status(l10n, order.status),
          tone: KitTone.green,
        );
      case CourierStage.other:
        detail = '';
        chip = KitTag(text: OrderLabels.status(l10n, order.status));
    }

    return KitCard(
      key: ValueKey<String>('courier-order-${order.id}'),
      onTap: () => context.push(AppPaths.courierOrder(order.id)),
      outline: stage == CourierStage.assigned ? KitColors.primary : null,
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
                  color: active ? KitColors.primaryWash : KitColors.field,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  active
                      ? Icons.local_shipping_outlined
                      : Icons.assignment_turned_in_outlined,
                  size: 28,
                  color: active ? KitColors.primaryDark : KitColors.ink2,
                ),
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
                          l10n.customerOrderTitle(order.orderNumber),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: KitColors.ink,
                          ),
                        ),
                        chip,
                      ],
                    ),
                    if (address != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        addressLine(l10n, address),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.muted,
                        ),
                      ),
                    ],
                    if (detail.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (stage == CourierStage.onTheWay) ...<Widget>[
            const SizedBox(height: 12),
            SegmentBar(
              segments: <Color>[
                for (int index = 0; index < 4; index++)
                  index < 3 ? KitColors.primary : KitColors.line,
              ],
            ),
          ],
          if (order.cancellationRequestPending) ...<Widget>[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.pending_outlined,
              text: l10n.courierRequestShort,
              color: KitColors.warningDark,
              bold: true,
            ),
          ],
          if (order.deliveryTimeNote != null) ...<Widget>[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.schedule,
              text: l10n.courierDeliveryWish(order.deliveryTimeNote!),
              color: KitColors.ink2,
            ),
          ],
          const SizedBox(height: 12),
          if (amount == null)
            _InfoRow(
              icon: Icons.credit_card,
              text: l10n.courierPaidOnline,
              color: KitColors.ink2,
            )
          else
            _InfoRow(
              icon: Icons.payments_outlined,
              text: l10n.courierCollect(MoneyFormat.uzs(amount, language)),
              color: KitColors.ink2,
              bold: true,
            ),
          if (stage == CourierStage.assigned) ...<Widget>[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.touch_app_outlined,
              text: l10n.courierOpenToAccept,
              color: KitColors.primaryDark,
              bold: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// The solid green chip of a new delivery.
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
