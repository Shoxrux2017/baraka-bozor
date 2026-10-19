import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/customer_orders.dart';
import 'reorder_sheet.dart';

/// How far an order has come, for the card's progress bar: 1 accepted, 2
/// being shopped or made ready, 3 on the way, 4 delivered; 0 for an order
/// that did not happen.
int orderStage(OrderStatus status) => switch (status) {
  OrderStatus.newOrder || OrderStatus.shoppingAssigned => 1,
  OrderStatus.shopping ||
  OrderStatus.finalPaymentPending ||
  OrderStatus.readyForDelivery ||
  OrderStatus.deliveryAssigned => 2,
  OrderStatus.onTheWay => 3,
  OrderStatus.completed => 4,
  OrderStatus.cancelled => 0,
};

/// The order's status in the Customer's words on a wash of its colour.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color ink, Color wash) = switch (status) {
      OrderStatus.shopping || OrderStatus.finalPaymentPending => (
        KitColors.warning,
        KitColors.warningWash,
      ),
      OrderStatus.cancelled => (
        KitColors.danger,
        KitColors.danger.withValues(alpha: 0.08),
      ),
      OrderStatus.completed => (KitColors.muted, KitColors.field),
      _ => (KitColors.primaryDark, KitColors.primaryWash),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          OrderLabels.customerStatus(AppLocalizations.of(context), status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      ),
    );
  }
}

/// Four segments, the first [stage] of them in the brand colour.
class OrderProgressBar extends StatelessWidget {
  const OrderProgressBar({required this.stage, super.key});

  final int stage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 4,
              child: DecoratedBox(
                key: ValueKey<String>('progress-segment-$i'),
                decoration: BoxDecoration(
                  color: i < stage ? KitColors.primary : KitColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// An order still in hand (drawing 27): where it stands, the question
/// waiting for the Customer, and the Courier's phone once it is on the way.
class CurrentOrderCard extends ConsumerWidget {
  const CurrentOrderCard({required this.order, super.key});

  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? phone = order.courierPhone;
    void open() => context.push(AppPaths.customerOrder(order.id));

    return _CardShell(
      cardKey: ValueKey<String>('order-${order.id}'),
      onTap: open,
      children: <Widget>[
        _Top(order: order),
        const SizedBox(height: 12),
        OrderProgressBar(
          key: ValueKey<String>('order-progress-${order.id}'),
          stage: orderStage(order.status),
        ),
        if (order.pendingApprovalCount > 0) ...<Widget>[
          const SizedBox(height: 12),
          _QuestionStrip(order: order, onOpen: open),
        ],
        const SizedBox(height: 12),
        _Bottom(order: order),
        if (phone != null) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: ValueKey<String>('order-call-courier-${order.id}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: KitColors.ink,
              side: const BorderSide(color: KitColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.call, size: 18, color: KitColors.primary),
            label: Text(
              l10n.callCourier,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _call(context, ref, phone),
          ),
        ],
      ],
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String phone) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool opened = await ref.read(phoneCallsProvider).call(phone);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.callFailed(formatPhone(phone)))),
      );
    }
  }
}

/// An order that ended (drawings 27a and 28): its rating, or the way to give
/// one while the server allows it, and the way to order it again.
class PastOrderCard extends StatelessWidget {
  const PastOrderCard({required this.order, super.key});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final int? rated = order.ratingStars;
    final Widget? left = order.canRate
        ? _RateBoxes(order: order)
        : rated != null
        ? _RatedStars(order: order, stars: rated)
        : null;

    return _CardShell(
      cardKey: ValueKey<String>('order-${order.id}'),
      onTap: () => context.push(AppPaths.customerOrder(order.id)),
      children: <Widget>[
        _Top(order: order),
        const SizedBox(height: 12),
        _Bottom(order: order),
        const SizedBox(height: 12),
        _RateRow(left: left, order: order),
      ],
    );
  }
}

/// The rating on the left and "Повторить" at the right end; under large text
/// the two take a line each.
class _RateRow extends StatelessWidget {
  const _RateRow({required this.left, required this.order});

  final Widget? left;
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final Widget repeat = RepeatOrderButton(
      orderId: order.id,
      orderNumber: order.orderNumber,
      wide: false,
    );
    final Widget? left = this.left;
    final bool stacked = MediaQuery.textScalerOf(context).scale(14) > 18;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (left != null) ...<Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(fit: BoxFit.scaleDown, child: left),
            ),
            const SizedBox(height: 8),
          ],
          Align(alignment: AlignmentDirectional.centerEnd, child: repeat),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: left == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(fit: BoxFit.scaleDown, child: left),
                ),
        ),
        const SizedBox(width: 8),
        repeat,
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.cardKey,
    required this.onTap,
    required this.children,
  });

  final Key cardKey;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);

    return DecoratedBox(
      key: cardKey,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture, the number, the address and the count, the status at the
/// right.
class _Top extends StatelessWidget {
  const _Top({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const TextStyle small = TextStyle(fontSize: 12, color: KitColors.muted);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox.square(
            dimension: 56,
            child: Center(child: ProductImage(url: order.imageUrl, size: 48)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.customerOrderTitle(order.orderNumber),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${order.street}, ${order.house}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: small,
              ),
              Text(
                l10n.orderItemCount(order.itemCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: small,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: OrderStatusChip(status: order.status),
        ),
      ],
    );
  }
}

/// When the order was placed and what the server says it costs.
class _Bottom extends ConsumerWidget {
  const _Bottom({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DateTime now = ref.watch(clockProvider)();
    final int? total = order.totalUzs;
    final String amount = total == null
        ? l10n.totalNothingDue
        : order.totalKind == TotalKind.estimate
        ? l10n.cartLineEstimate(MoneyFormat.uzs(total, language))
        : MoneyFormat.uzs(total, language);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(
          child: Text(
            orderWhen(l10n, order.createdAt, now),
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            amount,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionStrip extends StatelessWidget {
  const _QuestionStrip({required this.order, required this.onOpen});

  final OrderSummary order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Material(
      key: ValueKey<String>('order-waiting-${order.id}'),
      color: KitColors.warningWash,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              const Icon(Icons.help, size: 20, color: KitColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.orderCardQuestion(order.pendingApprovalCount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: FilledButton(
                  key: ValueKey<String>('order-answer-${order.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KitColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onOpen,
                  child: Text(
                    l10n.questionAnswer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

/// Five boxes "N★": the Customer's way to rate a finished order. Until the
/// rating page exists they open the order.
class _RateBoxes extends StatelessWidget {
  const _RateBoxes({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int stars = 1; stars <= 5; stars++) ...<Widget>[
          if (stars > 1) const SizedBox(width: 4),
          Semantics(
            button: true,
            label: l10n.rateStarsLabel(stars),
            excludeSemantics: true,
            child: Material(
              key: ValueKey<String>('order-rate-${order.id}-$stars'),
              color: KitColors.field,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push(AppPaths.customerOrder(order.id)),
                child: SizedBox(
                  width: 34,
                  height: 30,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$stars★',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RatedStars extends StatelessWidget {
  const _RatedStars({required this.order, required this.stars});

  final OrderSummary order;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).rateStarsLabel(stars),
      excludeSemantics: true,
      child: Row(
        key: ValueKey<String>('order-stars-${order.id}'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 1; i <= 5; i++)
            Icon(
              Icons.star,
              size: 20,
              color: i <= stars ? KitColors.warning : KitColors.line,
            ),
        ],
      ),
    );
  }
}
