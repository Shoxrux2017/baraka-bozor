import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_person.dart';
import '../domain/board.dart';
import 'order_actions.dart';

/// The cancellation requests, in one card that is amber while one waits for
/// a decision. Shown only when there is a request.
class RequestsCard extends StatelessWidget {
  const RequestsCard({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<BoardCancellationRequest> requests = order
        .cancellationRequests
        .reversed
        .toList();

    return PanelCard(
      title: l10n.orderSectionCancellationRequests,
      tone: order.pendingCancellationRequest == null ? null : KitTone.amber,
      children: <Widget>[
        for (int index = 0; index < requests.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CancellationRequestTile(
              order: order,
              request: requests[index],
            ),
          ),
      ],
    );
  }
}

/// The Customer's rating, amber while it is low and waits for a call.
class RatingCard extends StatelessWidget {
  const RatingCard({required this.order, required this.rating, super.key});

  final BoardOrder order;
  final OrderRating rating;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: AppLocalizations.of(context).ratingTitle,
      tone: ratingWaits(rating) ? KitTone.amber : null,
      children: <Widget>[RatingDetails(order: order, rating: rating)],
    );
  }
}

const TextStyle _label = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: KitColors.muted,
);

/// The Customer, the address and the delivery wish.
class ClientCard extends StatelessWidget {
  const ClientCard({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardAddress? address = order.address;
    final String? wish = order.customerErased
        ? null
        : order.deliveryTimeNote ?? l10n.orderNoDeliveryWish;
    const TextStyle line = TextStyle(fontSize: 13, color: KitColors.ink2);
    Widget rule() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 1, color: KitColors.line),
    );

    return PanelCard(
      title: l10n.orderSectionCustomer,
      children: <Widget>[
        const SizedBox(height: 12),
        if (order.customerErased)
          Row(
            children: <Widget>[
              const Icon(Icons.person_off, size: 20, color: KitColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.orderCustomerErased,
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: KitColors.muted,
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: <Widget>[
              PersonAvatar(order.customer.fullName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      order.customer.fullName ?? l10n.customerNoName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KitColors.ink,
                      ),
                    ),
                    if (order.customer.phone != null)
                      Text(
                        formatPhone(order.customer.phone!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: KitColors.ink2,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        if (address != null) ...<Widget>[
          rule(),
          Text(l10n.orderSectionAddress.toUpperCase(), style: _label),
          const SizedBox(height: 6),
          Text('${address.street}, ${address.house}', style: line),
          if (address.apartment != null)
            Text('${l10n.addressApartment}: ${address.apartment}', style: line),
          if (address.landmark != null)
            Text('${l10n.addressLandmark}: ${address.landmark}', style: line),
          if (address.deliveryNote != null)
            Text(
              '${l10n.addressDeliveryNote}: ${address.deliveryNote}',
              style: line,
            ),
          const SizedBox(height: 2),
          Text(
            l10n.orderCoordinates(address.latitude, address.longitude),
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
        ],
        if (wish != null) ...<Widget>[
          rule(),
          Text(l10n.orderSectionDeliveryWish.toUpperCase(), style: _label),
          const SizedBox(height: 6),
          Text(wish, style: line),
        ],
      ],
    );
  }
}

/// What the order comes to, with the kind of the total.
class TotalsCard extends StatelessWidget {
  const TotalsCard({required this.totals, super.key});

  final BoardTotals totals;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);

    if (totals.kind == TotalKind.none) {
      return PanelCard(
        title: l10n.orderSectionTotals,
        children: <Widget>[
          const SizedBox(height: 10),
          Text(
            l10n.totalNothingDue,
            key: const ValueKey<String>('totals'),
            style: const TextStyle(fontSize: 13, color: KitColors.ink2),
          ),
        ],
      );
    }

    Widget line(String label, int amount) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: KitColors.ink2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              MoneyFormat.uzs(amount, language),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KitColors.ink,
              ),
            ),
          ),
        ],
      ),
    );

    return PanelCard(
      title: l10n.orderSectionTotals,
      children: <Widget>[
        Column(
          key: const ValueKey<String>('totals'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 4),
            line(l10n.totalsMerchandise, totals.merchandiseSubtotalUzs!),
            line(l10n.totalsServiceFee, totals.serviceFeeUzs!),
            line(l10n.totalsDeliveryFee, totals.deliveryFeeUzs!),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1, color: KitColors.line),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.totalsTotal,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    MoneyFormat.uzs(totals.totalUzs ?? 0, language),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                totals.kind == TotalKind.estimate
                    ? l10n.totalKindEstimate
                    : l10n.totalKindFinal,
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The payment: the method in the header, its status as a tag, and what was
/// paid, when and to whom.
class PaymentCard extends StatelessWidget {
  const PaymentCard({required this.order, super.key});

  final BoardOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BoardPayment? payment = order.payment;
    final bool large = kitLargeText(context);
    final String method = OrderLabels.paymentMethod(
      l10n,
      payment?.method ?? order.paymentMethod,
    );
    final Widget? tag = payment == null
        ? null
        : KitTag(
            text: OrderLabels.paymentStatus(l10n, payment.status),
            tone: switch (payment.status) {
              PaymentStatus.paid => KitTone.green,
              PaymentStatus.pending => KitTone.amber,
              PaymentStatus.cancelled => KitTone.red,
              PaymentStatus.unpaid => KitTone.grey,
            },
          );

    // The method and the status stand in the header; at large text they
    // would not fit beside the title and go below it.
    return PanelCard(
      title: l10n.orderSectionPayment,
      count: large ? null : method,
      trailing: large || tag == null
          ? null
          : Padding(padding: const EdgeInsets.only(left: 8), child: tag),
      children: <Widget>[
        if (large)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  method,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KitColors.muted,
                  ),
                ),
                ?tag,
              ],
            ),
          ),
        const SizedBox(height: 6),
        PaymentDetails(order: order),
      ],
    );
  }
}
