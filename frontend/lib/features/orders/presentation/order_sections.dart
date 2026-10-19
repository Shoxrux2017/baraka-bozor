import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/address_format.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/presentation/cart_summary.dart';
import '../domain/customer_orders.dart';
import 'order_cards.dart';
import 'reorder_sheet.dart';

const List<BoxShadow> _cardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
];

const ColorFilter _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// The lines the Customer still orders: their own removals are gone from
/// what they see.
List<CustomerOrderLine> shownLines(CustomerOrder order) => <CustomerOrderLine>[
  for (final CustomerOrderLine line in order.lines)
    if (line.removedReason != ItemRemovedReason.customerRemoved) line,
];

/// A white card with the kit's shadow.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = 16, super.key});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

/// Opens the dialer on [phone]; where nothing opens it, says the number to
/// dial by hand.
Future<void> _dial(BuildContext context, WidgetRef ref, String phone) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool opened = await ref.read(phoneCallsProvider).call(phone);
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.callFailed(formatPhone(phone)))),
    );
  }
}

/// Where the order stands (drawings 29 to 29з): a circle with the state's
/// icon, its title and hint, the four stages with the times reached, and,
/// while the order may still change, that it may.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({required this.order, required this.now, super.key});

  final CustomerOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool cancelled = order.status == OrderStatus.cancelled;
    final (IconData icon, String title, String? hint) = _face(l10n);
    final String? reason = cancelled ? _reasonLine(l10n) : null;

    return DecoratedBox(
      key: const ValueKey<String>('order-status'),
      decoration: BoxDecoration(
        color: cancelled
            ? KitColors.danger.withValues(alpha: 0.08)
            : KitColors.primaryWash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cancelled ? KitColors.danger : KitColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(icon, size: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        key: const ValueKey<String>('order-status-title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      if (hint != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            hint,
                            key: const ValueKey<String>('order-status-hint'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: KitColors.ink2,
                            ),
                          ),
                        ),
                      if (reason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            reason,
                            key: const ValueKey<String>('order-status-reason'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: KitColors.ink2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (!cancelled) ...<Widget>[
              const SizedBox(height: 16),
              _StageBar(order: order),
            ],
            if (order.canEdit) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                l10n.orderCanStillChange,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: KitColors.ink2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The icon, title and hint of the state.
  (IconData, String, String?) _face(AppLocalizations l10n) {
    final DateTime? onTheWayAt = order.onTheWayAt;
    final DateTime? completedAt = order.completedAt;
    final DateTime? cancelledAt = order.cancelledAt;

    return switch (order.status) {
      OrderStatus.newOrder || OrderStatus.shoppingAssigned => (
        Icons.receipt_long,
        l10n.orderStateAccepted,
        l10n.orderStateAcceptedHint,
      ),
      OrderStatus.shopping => (
        Icons.shopping_basket,
        l10n.orderStateShopping,
        l10n.orderStateShoppingHint,
      ),
      OrderStatus.readyForDelivery || OrderStatus.deliveryAssigned => (
        Icons.inventory_2,
        l10n.orderStateCollected,
        l10n.orderStateCollectedHint,
      ),
      OrderStatus.finalPaymentPending => (
        Icons.payments,
        l10n.customerStatusFinalPaymentPending,
        null,
      ),
      OrderStatus.onTheWay => (
        Icons.two_wheeler,
        l10n.orderStateOnTheWay,
        onTheWayAt == null
            ? null
            : l10n.orderStateLeftAt(TashkentTime.time(onTheWayAt)),
      ),
      OrderStatus.completed => (
        Icons.check,
        l10n.orderStateDelivered,
        completedAt == null ? null : orderAt(l10n, completedAt, now),
      ),
      OrderStatus.cancelled => (
        Icons.close,
        l10n.orderStateCancelled,
        cancelledAt == null
            ? null
            : order.cancellationReason == CancellationReason.customerCancelled
            ? l10n.orderCancelledByYou(orderAtLower(l10n, cancelledAt, now))
            : l10n.orderCancelledWhen(orderAtLower(l10n, cancelledAt, now)),
      ),
    };
  }

  /// Why a cancelled order ended: the words of an approved request, or the
  /// business's reason; a cancel by the Customer says only when.
  String? _reasonLine(AppLocalizations l10n) {
    final CancellationReason? reason = order.cancellationReason;
    final CustomerCancellationRequest? request = order.cancellationRequest;
    if (reason == CancellationReason.cancellationRequestApproved &&
        request != null) {
      return l10n.orderCancelReasonQuoted(request.reason);
    }
    if (reason != null && reason != CancellationReason.customerCancelled) {
      return l10n.requestReason(OrderLabels.cancellationReason(l10n, reason));
    }
    return null;
  }
}

/// Accepted, shopping, on the way, delivered: the stages reached in the
/// brand colour, each with the time it was reached when the server knows it.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int stage = orderStage(order.status);
    final List<String> labels = <String>[
      l10n.progressAccepted,
      l10n.progressShopping,
      l10n.progressDelivering,
      l10n.progressDelivered,
    ];
    final List<DateTime?> times = <DateTime?>[
      order.createdAt,
      order.shoppingStartedAt,
      order.onTheWayAt,
      order.completedAt,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 4,
                  width: double.infinity,
                  child: DecoratedBox(
                    key: ValueKey<String>('order-stage-$i'),
                    decoration: BoxDecoration(
                      color: i < stage ? KitColors.primary : KitColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: i < stage ? KitColors.ink : KitColors.muted,
                    ),
                  ),
                ),
                if (i < stage && times[i] != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      TashkentTime.time(times[i]!),
                      key: ValueKey<String>('order-stage-time-$i'),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: KitColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One line of the order (drawings 29 and 29е): the picture, the name, what
/// was ordered or bought, a tag for its state, and the amount at the right.
class OrderLineRow extends StatelessWidget {
  const OrderLineRow({
    required this.line,
    required this.orderStatus,
    super.key,
  });

  final CustomerOrderLine line;
  final OrderStatus orderStatus;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final ItemRemovedReason? removedReason = line.removedReason;
    final bool removed = line.removed;
    final int? billedPrice = line.billableUnitPriceUzs;
    final bool estimate = line.priceMode == PriceMode.estimate;
    String sum(int amount) => MoneyFormat.uzs(amount, language);
    String ordered() {
      final String perUnit = l10n.catalogPricePerUnit(
        sum(line.customerUnitPriceUzs),
        unit,
      );
      return '${QuantityRules.display(line.quantity)} $unit · '
          '${estimate ? l10n.cartLineEstimate(perUnit) : perUnit}';
    }

    final String subtitle;
    final String amount;
    _Tag? tag;
    if (removed) {
      subtitle = '${QuantityRules.display(line.quantity)} $unit';
      amount = sum(0);
      tag = _removedTag(l10n, removedReason);
    } else if (billedPrice != null) {
      final String billed =
          '${QuantityRules.display(line.billableQuantity!)} $unit';
      amount = sum(line.lineTotalUzs);
      if (orderStatus == OrderStatus.shopping) {
        subtitle = '$billed × ${sum(billedPrice)}';
        tag = _Tag(
          text: l10n.lineTagBought,
          color: KitColors.primaryDark,
          icon: Icons.check,
        );
      } else {
        subtitle = l10n.orderLineBoughtKit(billed, sum(billedPrice));
      }
    } else {
      subtitle = ordered();
      amount = estimate
          ? l10n.cartLineEstimate(sum(line.lineTotalUzs))
          : sum(line.lineTotalUzs);
      if (line.question != null) {
        tag = _Tag(
          text: l10n.lineTagWaiting,
          color: KitColors.warning,
          icon: Icons.help,
        );
      }
    }

    const TextStyle small = TextStyle(fontSize: 12, color: KitColors.muted);
    final ProductNames? replacement = line.replacement;
    final String? note = line.customerNote;
    Widget picture = ProductImage(url: line.imageUrl, size: 40);
    if (removed) {
      picture = Opacity(
        opacity: 0.4,
        child: ColorFiltered(colorFilter: _grey, child: picture),
      );
    }

    return Padding(
      key: ValueKey<String>('order-line-${line.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: KitColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox.square(
              dimension: 48,
              child: Center(child: picture),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.name(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: removed ? KitColors.muted : KitColors.ink,
                    decoration: removed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(subtitle, style: small),
                ?tag,
                if (replacement != null)
                  Text(
                    l10n.itemReplacedWith(replacement.name(language)),
                    key: ValueKey<String>('order-line-replacement-${line.id}'),
                    style: small,
                  ),
                if (line.substitutionPolicy != SubstitutionPolicy.allowSimilar)
                  Text(
                    OrderLabels.substitution(l10n, line.substitutionPolicy),
                    style: small,
                  ),
                if (note != null) Text('«$note»', style: small),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: removed ? KitColors.muted : KitColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _Tag? _removedTag(AppLocalizations l10n, ItemRemovedReason? reason) {
    final String? text = switch (reason) {
      ItemRemovedReason.unavailable => l10n.lineTagUnavailable,
      ItemRemovedReason.customerRejected => l10n.lineTagRejected,
      ItemRemovedReason.approvalExpired => l10n.lineTagExpired,
      ItemRemovedReason.operatorRemoved => l10n.lineTagOperator,
      ItemRemovedReason.orderCancelled ||
      ItemRemovedReason.customerRemoved ||
      null => null,
    };
    return text == null ? null : _Tag(text: text, color: KitColors.danger);
  }
}

/// A line's state in a word, in the colour that says it.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The amounts, all the server's (`DL-37`): the goods, the delivery, the
/// service fee and the total, with the note that an estimate is one; or,
/// where nothing is due, that.
class OrderAmounts extends StatelessWidget {
  const OrderAmounts({required this.order, super.key});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final bool estimate = order.totalKind == TotalKind.estimate;
    String sum(int? amount) => MoneyFormat.uzs(amount ?? 0, language);
    String approx(int? amount) =>
        estimate ? l10n.cartLineEstimate(sum(amount)) : sum(amount);

    if (order.totalKind == TotalKind.none) {
      return SummaryAmountRow(
        valueKey: 'order-total',
        label: l10n.orderToPayLabel,
        value: l10n.orderNothingDue,
        emphasised: true,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SummaryAmountRow(
          valueKey: 'order-goods',
          label: l10n.cartGoods(
            order.lines.where((CustomerOrderLine line) => !line.removed).length,
          ),
          value: approx(order.merchandiseSubtotalUzs),
        ),
        SummaryAmountRow(
          valueKey: 'order-delivery',
          label: l10n.cartDelivery,
          value: sum(order.deliveryFeeUzs),
        ),
        SummaryAmountRow(
          valueKey: 'order-service-fee',
          label: l10n.cartServiceFee,
          value: approx(order.serviceFeeUzs),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, thickness: 1, color: KitColors.line),
        ),
        SummaryAmountRow(
          valueKey: 'order-total',
          label: l10n.cartTotal,
          value: approx(order.totalUzs),
          emphasised: true,
        ),
        if (estimate) ...<Widget>[
          const SizedBox(height: 8),
          const EstimateNote(),
        ],
      ],
    );
  }
}

/// One fact about the order with its icon: a title, what it says, and, where
/// there is something to do about it, a button at the right.
class OrderInfoRow extends StatelessWidget {
  const OrderInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.extra,
    this.actionLabel,
    this.actionKey,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// A second line under [subtitle].
  final String? extra;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    const TextStyle small = TextStyle(fontSize: 12, color: KitColors.muted);
    final String? extra = this.extra;
    final String? actionLabel = this.actionLabel;
    // Under large text the button takes the line under the words.
    final bool stacked = MediaQuery.textScalerOf(context).scale(14) > 18;
    final Widget? action = actionLabel == null
        ? null
        : TextButton(
            key: actionKey,
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.primaryWash,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 22, color: KitColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                  ),
                ),
                Text(subtitle, style: small),
                if (extra != null) Text(extra, style: small),
                if (stacked) ?action,
              ],
            ),
          ),
        ),
        if (!stacked && action != null) ...<Widget>[
          const SizedBox(width: 8),
          action,
        ],
      ],
    );
  }
}

/// The payment, the address, the wish and, on a current order, the way to
/// reach support, each as an [OrderInfoRow] in one card.
class OrderInfoSection extends ConsumerWidget {
  const OrderInfoSection({required this.order, required this.now, super.key});

  final CustomerOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final OrderAddress address = order.address;
    final CustomerPayment? payment = order.payment;
    final DateTime? paidAt = payment?.paidAt;
    final int? total = order.totalUzs;
    final String? wish = order.deliveryTimeNote;
    final String? supportPhone = order.supportPhone;
    final bool current =
        order.status != OrderStatus.completed &&
        order.status != OrderStatus.cancelled;

    final OrderInfoRow? paymentRow;
    if (payment != null && paidAt != null) {
      paymentRow = OrderInfoRow(
        key: const ValueKey<String>('order-payment'),
        icon: Icons.payments,
        title: payment.method == PaymentMethod.online
            ? l10n.orderPaidOnline
            : l10n.orderPaidCash,
        subtitle: l10n.orderPaidWhen(
          MoneyFormat.uzs(payment.amountUzs, language),
          orderAtLower(l10n, paidAt, now),
        ),
      );
    } else if (order.totalKind == TotalKind.finalTotal && total != null) {
      paymentRow = OrderInfoRow(
        key: const ValueKey<String>('order-payment'),
        icon: Icons.payments,
        title: l10n.orderToPayAmount(MoneyFormat.uzs(total, language)),
        subtitle: l10n.orderCashOnDelivery,
      );
    } else if (order.status == OrderStatus.cancelled ||
        order.totalKind == TotalKind.none) {
      // Nothing is due, and the amounts say so; no promise of cash.
      paymentRow = null;
    } else {
      paymentRow = OrderInfoRow(
        key: const ValueKey<String>('order-payment'),
        icon: Icons.payments,
        title: l10n.paymentCashTitle,
        subtitle: l10n.paymentCashHint,
      );
    }

    final List<Widget> rows = <Widget>[
      ?paymentRow,
      OrderInfoRow(
        key: const ValueKey<String>('order-address'),
        icon: Icons.home,
        title: l10n.orderAddressTitle,
        subtitle: addressFullLine(
          l10n,
          street: address.street,
          house: address.house,
          apartment: address.apartment,
        ),
        extra: address.landmark,
      ),
      if (wish != null)
        OrderInfoRow(
          key: const ValueKey<String>('order-wish'),
          icon: Icons.schedule,
          title: l10n.checkoutWishLabel,
          subtitle: wish,
        ),
      if (supportPhone != null && current)
        OrderInfoRow(
          key: const ValueKey<String>('order-support'),
          icon: Icons.support_agent,
          title: l10n.supportTitle,
          subtitle: l10n.supportHint,
          actionLabel: l10n.callAction,
          actionKey: const ValueKey<String>('order-call-support'),
          onAction: () => _dial(context, ref, supportPhone),
        ),
    ];

    return _Card(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: KitColors.line),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// The Courier bringing the order, by first name or, without one, by phone,
/// with a button to call them.
class CourierCard extends ConsumerWidget {
  const CourierCard({required this.courier, super.key});

  final OrderCourier courier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? name = courier.firstName;

    return _Card(
      key: const ValueKey<String>('order-courier'),
      padding: 14,
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(
              color: KitColors.primaryWash,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: name == null || name.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 24,
                        color: KitColors.primary,
                      )
                    : Text(
                        String.fromCharCode(name.runes.first).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: KitColors.primary,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name == null || name.isEmpty
                      ? formatPhone(courier.phone)
                      : name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
                Text(
                  l10n.courierYours,
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey<String>('order-call-courier'),
            tooltip: l10n.callCourier,
            style: IconButton.styleFrom(
              backgroundColor: KitColors.primary,
              foregroundColor: Colors.white,
              fixedSize: const Size.square(44),
            ),
            icon: const Icon(Icons.call),
            onPressed: () => _dial(context, ref, courier.phone),
          ),
        ],
      ),
    );
  }
}

/// The Customer's request for an Operator to cancel the order: their words
/// and where it stands (`DL-65` (5)).
class CancellationRequestCard extends StatelessWidget {
  const CancellationRequestCard({required this.request, super.key});

  final CustomerCancellationRequest request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool pending = request.status == CancellationRequestStatus.pending;
    final (Color ink, Color wash) = switch (request.status) {
      CancellationRequestStatus.pending => (
        KitColors.warning,
        KitColors.warningWash,
      ),
      CancellationRequestStatus.approved => (
        KitColors.primaryDark,
        KitColors.primaryWash,
      ),
      CancellationRequestStatus.rejected => (
        KitColors.danger,
        KitColors.danger.withValues(alpha: 0.08),
      ),
      CancellationRequestStatus.closed => (KitColors.muted, KitColors.field),
    };
    final String status = switch (request.status) {
      CancellationRequestStatus.pending => l10n.requestStatusPending,
      CancellationRequestStatus.approved => l10n.requestStateApproved,
      CancellationRequestStatus.rejected => l10n.requestStateRejected,
      CancellationRequestStatus.closed => l10n.requestStateClosed,
    };

    return _Card(
      key: const ValueKey<String>('order-cancellation-request'),
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                l10n.requestYouAsked,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KitColors.ink,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: wash,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    status,
                    key: ValueKey<String>(
                      pending
                          ? 'order-cancellation-requested'
                          : 'order-cancellation-request-${request.status.code}',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '«${request.reason}»',
            style: const TextStyle(fontSize: 14, color: KitColors.ink2),
          ),
          if (pending) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              l10n.requestPendingHint,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: KitColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The bar under the order: what the Customer may do now. Cancel and edit
/// while the server allows them, the request to an Operator once shopping
/// began, "Повторить заказ" for an order that ended; and what a cancel that
/// failed says. It shows only when it has one of those.
class OrderFooter extends StatelessWidget {
  const OrderFooter({
    required this.order,
    required this.cancelling,
    required this.onEdit,
    required this.onCancel,
    required this.onRequestCancel,
    super.key,
  });

  final CustomerOrder order;
  final MutationState cancelling;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onRequestCancel;

  /// Shopping began since the order was shown: the cancel now asks an
  /// Operator, and a request needs its reason (`DL-65` (1)).
  static bool needsReason(ApiFailure? failure) =>
      failure is ApiRefusal &&
      failure.status == 422 &&
      failure.error.errors.containsKey('reason');

  /// A request filed meanwhile, from another device: the order loaded again
  /// shows it, and its words are the Operator's.
  static bool alreadyRequested(ApiFailure? failure) =>
      failure is ApiRefusal && failure.code == 'cancellation_already_pending';

  static bool _ended(CustomerOrder order) =>
      order.status == OrderStatus.completed ||
      order.status == OrderStatus.cancelled;

  /// Whether there is anything for the bar to hold.
  static bool shows(CustomerOrder order, MutationState cancelling) {
    final ApiFailure? failure = cancelling.failure;
    return order.canEdit ||
        order.canCancelDirectly ||
        order.canRequestCancellation ||
        _ended(order) ||
        needsReason(failure) ||
        (failure != null && !alreadyRequested(failure));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = cancelling.isBusy;
    final bool stacked = MediaQuery.textScalerOf(context).scale(14) > 18;
    final ApiFailure? failure = cancelling.failure;

    Widget label(String text) => busy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: l10n.orderCancelling,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: _buttonText(text)),
            ],
          )
        : _buttonText(text);

    final ButtonStyle outlinedDanger = OutlinedButton.styleFrom(
      foregroundColor: KitColors.danger,
      side: const BorderSide(color: KitColors.danger),
      minimumSize: const Size.fromHeight(54),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    final Widget? cancel = order.canCancelDirectly
        ? OutlinedButton(
            key: const ValueKey<String>('order-cancel'),
            style: outlinedDanger,
            onPressed: busy ? null : onCancel,
            child: label(l10n.orderCancelShort),
          )
        : null;
    final Widget? edit = order.canEdit
        ? FilledButton.icon(
            key: const ValueKey<String>('order-edit'),
            style: FilledButton.styleFrom(
              backgroundColor: KitColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.edit, size: 18),
            label: _buttonText(l10n.orderEdit),
            onPressed: busy ? null : onEdit,
          )
        : null;
    final Widget? request = order.canRequestCancellation
        ? OutlinedButton(
            key: const ValueKey<String>('order-request-cancel'),
            style: outlinedDanger,
            onPressed: busy ? null : onRequestCancel,
            child: label(l10n.orderRequestCancel),
          )
        : null;

    final List<Widget> buttons = <Widget>[
      if (cancel != null && edit != null)
        if (stacked) ...<Widget>[edit, const SizedBox(height: 10), cancel] else
          Row(
            children: <Widget>[
              Expanded(child: cancel),
              const SizedBox(width: 12),
              Expanded(child: edit),
            ],
          )
      else ...<Widget>[?cancel, ?edit],
      ?request,
      if (_ended(order))
        RepeatOrderButton(
          orderId: order.id,
          orderNumber: order.orderNumber,
          wide: true,
        ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (needsReason(failure))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.orderCancellationNeedsReason,
                      key: const ValueKey<String>('order-cancel-needs-reason'),
                      style: const TextStyle(color: KitColors.danger),
                    ),
                  )
                else
                  FailureMessage(alreadyRequested(failure) ? null : failure),
                for (int i = 0; i < buttons.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 10),
                  buttons[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buttonText(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}
