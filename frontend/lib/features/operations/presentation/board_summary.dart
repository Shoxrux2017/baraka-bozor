import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_pills.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';

/// Below this board width the four tiles stand two by two and the status
/// pills scroll in one row instead of wrapping.
const double boardCompactWidth = 900;

const TextStyle _numberStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);

/// The day's four numbers: the open orders, today's completed and cancelled
/// — each of the last two a way to filter the board by that status — and
/// today's sales.
class BoardSummaryTiles extends ConsumerWidget {
  const BoardSummaryTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BoardSummary> summary = ref.watch(boardSummaryProvider);
    final BoardQueryController queries = ref.read(boardQueryProvider.notifier);
    final OrderStatus? filtered = ref.watch(
      boardQueryProvider.select((BoardQuery query) => query.status),
    );

    void toggle(OrderStatus status) =>
        queries.filterByStatus(filtered == status ? null : status);

    return summary.when(
      skipLoadingOnRefresh: !summary.hasError,
      data: (BoardSummary summary) {
        final int open = summary.openByStatus.values.fold(
          0,
          (int sum, int count) => sum + count,
        );
        final List<Widget> tiles = <Widget>[
          _Tile(
            key: const ValueKey<String>('summary-open'),
            icon: Icons.pending_actions,
            label: l10n.summaryOpen,
            value: Text('$open', style: _numberStyle),
          ),
          _Tile(
            key: const ValueKey<String>('summary-completed'),
            icon: Icons.task_alt,
            label: l10n.summaryCompletedToday,
            value: Text('${summary.completedToday}', style: _numberStyle),
            selected: filtered == OrderStatus.completed,
            onTap: () => toggle(OrderStatus.completed),
          ),
          _Tile(
            key: const ValueKey<String>('summary-cancelled'),
            icon: Icons.cancel,
            grey: true,
            label: l10n.summaryCancelledToday,
            value: Text('${summary.cancelledToday}', style: _numberStyle),
            selected: filtered == OrderStatus.cancelled,
            onTap: () => toggle(OrderStatus.cancelled),
          ),
          _Tile(
            key: const ValueKey<String>('summary-sales'),
            icon: Icons.payments,
            label: l10n.summarySalesToday,
            value: _Sales(summary.salesTodayUzs),
          ),
        ];

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            Widget row(List<Widget> tiles) => IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < tiles.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
            );

            return Column(
              key: const ValueKey<String>('board-summary'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: constraints.maxWidth >= boardCompactWidth
                  ? <Widget>[row(tiles)]
                  : <Widget>[
                      row(tiles.sublist(0, 2)),
                      const SizedBox(height: 16),
                      row(tiles.sublist(2)),
                    ],
            );
          },
        );
      },
      error: (Object error, StackTrace _) => LoadFailure(
        error: error,
        onRetry: () => ref.invalidate(boardSummaryProvider),
      ),
      loading: () => const LinearProgressIndicator(),
    );
  }
}

class _Sales extends StatelessWidget {
  const _Sales(this.amount);

  final int amount;

  @override
  Widget build(BuildContext context) {
    final String whole = MoneyFormat.uzs(amount, interfaceLanguage(context));
    final String number = MoneyFormat.grouped(amount);

    return Text.rich(
      TextSpan(
        text: number,
        style: _numberStyle,
        children: <InlineSpan>[
          TextSpan(
            text: whole.substring(number.length),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: KitColors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    this.grey = false,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Widget value;
  final bool grey;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KitCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      color: selected ? KitColors.primaryWash : Colors.white,
      outline: selected ? KitColors.primary : null,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: grey ? KitColors.field : KitColors.primaryWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: 24,
                color: grey ? KitColors.muted : KitColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: KitColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                value,
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: Color(0xFFC7CCC8)),
        ],
      ),
    );
  }
}

/// "Все заказы" and the open statuses with their counts, one tap each: a
/// wrapping row on a wide board, one row that scrolls — faded at its right
/// edge — on a narrow one.
class BoardStatusPills extends ConsumerWidget {
  const BoardStatusPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardSummary? summary = ref.watch(boardSummaryProvider).value;
    final BoardQueryController queries = ref.read(boardQueryProvider.notifier);
    final OrderStatus? filtered = ref.watch(
      boardQueryProvider.select((BoardQuery query) => query.status),
    );

    // The pills stand and filter while the summary loads or fails; only the
    // counts wait for it.
    final List<Widget> pills = <Widget>[
      PanelPill(
        key: const ValueKey<String>('summary-all'),
        label: l10n.boardAllOrders,
        selected: filtered == null,
        onTap: () => queries.filterByStatus(null),
      ),
      for (final OrderStatus status in OrderStatus.open)
        PanelPill(
          key: ValueKey<String>('summary-${status.code}'),
          label: OrderLabels.status(l10n, status),
          count: summary?.openByStatus[status],
          selected: filtered == status,
          onTap: () =>
              queries.filterByStatus(filtered == status ? null : status),
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return PanelPillRow(
          pills: pills,
          wrap: constraints.maxWidth >= boardCompactWidth,
        );
      },
    );
  }
}
