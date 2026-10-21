import 'package:flutter/material.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit/kit_status_card.dart';
import '../domain/courier_orders.dart';
import 'courier_stage.dart';

/// The card on top of a delivery (`DL-99`): what stage it is at, what to do
/// next, the four steps of the assignment with their times, and the
/// Customer's wish for the time. A cancellation request that waits turns it
/// amber and says not to set off.
class CourierStatusCard extends StatelessWidget {
  const CourierStatusCard({required this.order, super.key});

  final CourierOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CourierStage stage = courierStage(order);
    final CourierAssignment assignment = order.assignment;
    final DateTime? startedAt = assignment.deliveryStartedAt;
    final DateTime? delayAt = assignment.delayAt;
    final bool request =
        order.cancellationRequestPending &&
        (stage == CourierStage.assigned || stage == CourierStage.accepted);

    final IconData icon;
    final String title;
    String? hint;
    Key? hintKey;
    final KitTone tone;
    int? reached;
    switch (stage) {
      case CourierStage.assigned:
        tone = request ? KitTone.amber : KitTone.green;
        icon = request ? Icons.hourglass_top : Icons.local_shipping_outlined;
        title = request ? l10n.courierStatusRequest : l10n.courierStatusNew;
        hint = request ? l10n.courierRequestPending : l10n.courierStatusNewHint;
        reached = 1;
      case CourierStage.accepted:
        tone = request ? KitTone.amber : KitTone.green;
        icon = request
            ? Icons.hourglass_top
            : Icons.assignment_turned_in_outlined;
        title = request
            ? l10n.courierStatusRequest
            : l10n.courierStatusAccepted;
        hint = request
            ? l10n.courierRequestPending
            : l10n.courierStatusAcceptedHint('${order.orderNumber}');
        reached = 2;
      case CourierStage.onTheWay:
        tone = KitTone.green;
        icon = Icons.local_shipping_outlined;
        title = OrderLabels.status(l10n, order.status);
        if (startedAt != null && delayAt != null) {
          hint = l10n.courierOnTheWayHint(
            TashkentTime.time(startedAt),
            TashkentTime.time(delayAt),
          );
          hintKey = const ValueKey<String>('courier-due-by');
        } else if (startedAt != null) {
          hint = l10n.courierStartedAt(TashkentTime.time(startedAt));
        }
        reached = 3;
      case CourierStage.other:
        tone = KitTone.grey;
        icon = Icons.assignment_outlined;
        title = OrderLabels.status(l10n, order.status);
    }
    if (request) {
      hintKey = const ValueKey<String>('courier-request-pending');
    }
    final String? wish = order.deliveryTimeNote;

    return KitStatusCard(
      key: const ValueKey<String>('courier-order-status'),
      icon: icon,
      title: title,
      hint: hint,
      hintKey: hintKey,
      tone: tone,
      progress: reached == null
          ? null
          : KitSteps(
              reached: reached,
              steps: <KitStep>[
                (label: l10n.courierStepAssigned, at: assignment.assignedAt),
                (label: l10n.courierStepAccepted, at: assignment.acceptedAt),
                (label: l10n.courierStepOnTheWay, at: startedAt),
                (label: l10n.courierStepDelivered, at: null),
              ],
            ),
      below: stage == CourierStage.other
          ? const <Widget>[]
          : <Widget>[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.schedule, size: 17, color: KitColors.ink2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wish == null
                          ? l10n.courierNoWish
                          : l10n.courierDeliveryWish(wish),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: KitColors.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
    );
  }
}
