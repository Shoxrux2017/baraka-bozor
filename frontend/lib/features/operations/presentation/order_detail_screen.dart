import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/board_controllers.dart';
import '../domain/board.dart';
import 'board_widgets.dart';
import 'order_history.dart';
import 'order_lines.dart';
import 'order_path.dart';
import 'order_side.dart';
import 'order_staff.dart';

/// One order as the Operator and the Admin see it (`docs/09` section 38,
/// `DL-100` (4)): a path of five steps, then the lines, the questions to the
/// Customer and the history at the left, and at the right who and where —
/// a waiting cancellation request and a low rating on top, the Customer
/// with the address and the wish, every Shopper and Courier assignment with
/// its self-order mark, the totals and the payment — with the actions the
/// rules allow on it (`DL-68`). Below [twoColumns] it is one column.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  /// From this width of the page — its content, without the padding — the
  /// order has two columns; the side column is [sideWidth] wide, [gap] apart.
  static const double twoColumns = 1100;
  static const double sideWidth = 372;
  static const double gap = 20;

  /// From this width the Shopper and Courier cards stand side by side in the
  /// one column.
  static const double staffBeside = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<BoardOrder> order = ref.watch(boardOrderProvider(orderId));
    final bool compact = MediaQuery.sizeOf(context).width < panelRailWidth;
    final EdgeInsets padding = compact
        ? const EdgeInsets.fromLTRB(24, 20, 24, 24)
        : const EdgeInsets.fromLTRB(28, 26, 28, 28);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double content = constraints.maxWidth - padding.horizontal;
        final bool labelled = content >= 560;
        final BoardOrder? loaded = order.value;

        return ListView(
          key: const ValueKey<String>('order-detail'),
          padding: padding,
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey<String>('order-back'),
                style: TextButton.styleFrom(
                  foregroundColor: KitColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.orderBackToBoard),
                onPressed: () => context.go(AppPaths.operations),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: loaded == null
                      ? const SizedBox(height: 32)
                      : _Header(order: loaded),
                ),
                const SizedBox(width: 12),
                if (labelled)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('order-refresh'),
                    style: kitOutlined(
                      height: 40,
                    ).copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(l10n.boardRefresh),
                    onPressed: () =>
                        ref.invalidate(boardOrderProvider(orderId)),
                  )
                else
                  Tooltip(
                    message: l10n.boardRefresh,
                    child: OutlinedButton(
                      key: const ValueKey<String>('order-refresh'),
                      style: kitOutlined(height: 40).copyWith(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const WidgetStatePropertyAll<Size>(
                          Size(40, 40),
                        ),
                        padding: const WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      onPressed: () =>
                          ref.invalidate(boardOrderProvider(orderId)),
                      child: const Icon(Icons.refresh, size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            order.when(
              skipLoadingOnRefresh: !order.hasError,
              data: (BoardOrder order) =>
                  _Order(order: order, twoColumns: content >= twoColumns),
              error: (Object error, StackTrace _) => LoadFailure(
                error: error,
                onRetry: () => ref.invalidate(boardOrderProvider(orderId)),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The order's number with its status, and when it was placed and how it is
/// paid; for a cancelled one, why.
class _Header extends StatelessWidget {
  const _Header({required this.order});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              l10n.orderTitle('${order.orderNumber}'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            OrderStatusChip(order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.orderPlacedAt(TashkentTime.format(order.createdAt))} · '
          '${OrderLabels.paymentMethod(l10n, order.paymentMethod)}',
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
        if (order.cancellationReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              OrderLabels.cancellationReason(l10n, order.cancellationReason!),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KitColors.dangerDark,
              ),
            ),
          ),
      ],
    );
  }
}

class _Order extends StatelessWidget {
  const _Order({required this.order, required this.twoColumns});

  final BoardOrder order;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final Widget items = OrderLines(order: order);
    final Widget questions = OrderQuestions(order: order);
    final Widget history = OrderHistory(order: order);
    final List<Widget> top = <Widget>[
      if (order.cancellationRequests.isNotEmpty) RequestsCard(order: order),
      if (order.rating != null) RatingCard(order: order, rating: order.rating!),
    ];
    final List<Widget> bottom = <Widget>[
      TotalsCard(totals: order.totals),
      PaymentCard(order: order),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OrderPath(order: order),
        const SizedBox(height: 16),
        if (twoColumns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _stack(<Widget>[items, questions, history])),
              const SizedBox(width: OrderDetailScreen.gap),
              SizedBox(
                width: OrderDetailScreen.sideWidth,
                child: _stack(<Widget>[
                  ...top,
                  ClientCard(order: order),
                  ShopperCard(order: order),
                  CourierCard(order: order),
                  ...bottom,
                ]),
              ),
            ],
          )
        else
          _stack(<Widget>[
            ...top,
            ClientCard(order: order),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  constraints.maxWidth >= OrderDetailScreen.staffBeside
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: ShopperCard(order: order)),
                        const SizedBox(width: 16),
                        Expanded(child: CourierCard(order: order)),
                      ],
                    )
                  : _stack(<Widget>[
                      ShopperCard(order: order),
                      CourierCard(order: order),
                    ]),
            ),
            items,
            questions,
            ...bottom,
            history,
          ]),
      ],
    );
  }

  /// [children] one above the other, 16 apart.
  static Widget _stack(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int index = 0; index < children.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(height: 16),
        children[index],
      ],
    ],
  );
}
