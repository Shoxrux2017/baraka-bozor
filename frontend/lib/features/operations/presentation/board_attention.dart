import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/order_dates.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/platform/clock.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_widgets.dart';
import 'operations_paths.dart';

/// What an Operator should look at, the longest-waiting first. It shows its
/// first [besideFolded] items beside the orders and [aboveFolded] above
/// them, and folds the rest behind a button, so a long list never pushes the
/// orders out of sight (`DL-67` (4), `DL-100` (2)).
class BoardAttention extends ConsumerStatefulWidget {
  const BoardAttention({required this.beside, super.key});

  static const int besideFolded = 5;
  static const int aboveFolded = 2;

  /// Whether the list stands at the right of the orders rather than above.
  final bool beside;

  @override
  ConsumerState<BoardAttention> createState() => _BoardAttentionState();
}

class _BoardAttentionState extends ConsumerState<BoardAttention> {
  bool _unfolded = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<AttentionItem>> items = ref.watch(attentionProvider);
    final int folded = widget.beside
        ? BoardAttention.besideFolded
        : BoardAttention.aboveFolded;
    final DateTime now = ref.watch(clockProvider)();

    return PanelCard(
      key: const ValueKey<String>('board-attention'),
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                l10n.attentionTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            ),
            if (items.value?.isNotEmpty ?? false) ...<Widget>[
              const SizedBox(width: 10),
              DecoratedBox(
                key: const ValueKey<String>('summary-attention'),
                decoration: BoxDecoration(
                  color: KitColors.danger,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        '${items.value!.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          l10n.attentionLongestFirst,
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
        const SizedBox(height: 12),
        items.when(
          skipLoadingOnRefresh: !items.hasError,
          data: (List<AttentionItem> items) {
            if (items.isEmpty) {
              return Text(l10n.attentionEmpty);
            }
            final List<AttentionItem> shown = _unfolded
                ? items
                : items.take(folded).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < shown.length; i++) ...<Widget>[
                  if (i > 0) ...<Widget>[
                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 14),
                  ],
                  _Item(item: shown[i], now: now),
                ],
                if (items.length > folded) ...<Widget>[
                  const SizedBox(height: 14),
                  TextButton(
                    key: const ValueKey<String>('attention-fold'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: KitColors.field,
                      foregroundColor: KitColors.ink2,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => setState(() => _unfolded = !_unfolded),
                    child: Text(
                      _unfolded
                          ? l10n.attentionShowFewer
                          : l10n.attentionShowAll(items.length),
                    ),
                  ),
                ],
              ],
            );
          },
          error: (Object error, StackTrace _) => LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(attentionProvider),
          ),
          loading: () => const LinearProgressIndicator(),
        ),
      ],
    );
  }
}

/// How an item looks: the colour of what it asks and its icon.
enum _Urgency { red, amber, grey }

_Urgency _urgencyOf(AttentionType type) => switch (type) {
  AttentionType.approvalExpired ||
  AttentionType.deliveryFailed ||
  AttentionType.staffBlocked => _Urgency.red,
  AttentionType.lowRating || AttentionType.selfOrder => _Urgency.grey,
  _ => _Urgency.amber,
};

IconData _iconOf(AttentionType type) => switch (type) {
  AttentionType.approvalExpired => Icons.timer_off,
  AttentionType.deliveryFailed => Icons.local_shipping,
  AttentionType.staffBlocked => Icons.person_off,
  AttentionType.approvalPending => Icons.call,
  AttentionType.courierDelayed => Icons.schedule,
  AttentionType.cancellationRequest => Icons.block,
  AttentionType.paymentOverdue => Icons.payments,
  AttentionType.refundOutstanding => Icons.currency_exchange,
  AttentionType.other => Icons.notifications,
  AttentionType.lowRating => Icons.star,
  AttentionType.selfOrder => Icons.person,
};

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.now});

  final AttentionItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final _Urgency urgency = _urgencyOf(item.type);
    final (Color wash, Color strong, Color waiting) = switch (urgency) {
      _Urgency.red => (
        KitColors.dangerWash,
        KitColors.danger,
        KitColors.danger,
      ),
      _Urgency.amber => (
        KitColors.warningWash,
        KitColors.warning,
        KitColors.warningDark,
      ),
      _Urgency.grey => (KitColors.field, KitColors.ink2, KitColors.warningDark),
    };
    final int minutes = now.difference(item.since).inMinutes;
    final int waited = minutes < 0 ? 0 : minutes;

    return InkWell(
      key: ValueKey<String>('attention-${item.code}-${item.orderId}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(OperationsPaths.order(item.orderId)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            key: ValueKey<String>(
              'attention-icon-${item.code}-${item.orderId}',
            ),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: wash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconOf(item.type), size: 20, color: strong),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: <Widget>[
                      Text(
                        l10n.boardOrderNumber('${item.orderNumber}'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      Text(
                        waited >= 60
                            ? l10n.attentionWaitingHours(
                                waited ~/ 60,
                                waited % 60,
                              )
                            : l10n.attentionWaitingMinutes(waited),
                        key: ValueKey<String>(
                          'attention-waiting-${item.code}-${item.orderId}',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: waiting,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _describe(l10n, item),
                  style: const TextStyle(fontSize: 13, color: KitColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    if (item.shopper != null)
                      l10n.historyAssignedTo(nameOf(l10n, item.shopper!)),
                    if (item.courier != null)
                      l10n.historyCourierAssignedTo(
                        nameOf(l10n, item.courier!),
                      ),
                    l10n.attentionSince(panelWhen(item.since, now)),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: KitColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _describe(AppLocalizations l10n, AttentionItem item) =>
      switch (item.type) {
        AttentionType.selfOrder => l10n.selfOrderExplained,
        AttentionType.approvalPending => l10n.attentionApprovalPending,
        AttentionType.approvalExpired => l10n.attentionApprovalExpired,
        AttentionType.paymentOverdue => l10n.attentionPaymentOverdue,
        AttentionType.refundOutstanding => l10n.attentionRefundOutstanding,
        AttentionType.courierDelayed => l10n.attentionCourierDelayed,
        AttentionType.deliveryFailed => l10n.attentionDeliveryFailed,
        AttentionType.cancellationRequest => l10n.attentionCancellationRequest,
        AttentionType.staffBlocked => l10n.attentionStaffBlocked,
        AttentionType.lowRating => l10n.attentionLowRating,
        AttentionType.other => l10n.attentionOther,
      };
}
