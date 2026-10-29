import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_star.dart';
import '../domain/customer_orders.dart';

const List<BoxShadow> _cardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
];

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// "How was the order?" on a delivered order that can still be rated: five
/// stars, each opening the rating screen with those stars chosen
/// (`DL-92` item 6).
class RateOrderCard extends StatelessWidget {
  const RateOrderCard({required this.order, super.key});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return _RatingCard(
      key: const ValueKey<String>('order-rate'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.rateBlockTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int stars = 1; stars <= 5; stars++)
                Semantics(
                  button: true,
                  label: l10n.rateStarsLabel(stars),
                  excludeSemantics: true,
                  child: Material(
                    key: ValueKey<String>('order-rate-$stars'),
                    color: KitColors.field,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.push<void>(
                        AppPaths.customerOrderRate(order.id, stars: stars),
                      ),
                      child: const SizedBox.square(
                        dimension: 40,
                        child: Center(child: KitStar(filled: false, size: 26)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.rateBlockHint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: KitColors.muted),
          ),
        ],
      ),
    );
  }
}

/// The Customer's rating of the order: the stars, the reasons, the comment,
/// and what happens next.
class RatedOrderCard extends StatelessWidget {
  const RatedOrderCard({required this.rating, super.key});

  final CustomerRating rating;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? comment = rating.comment;

    return _RatingCard(
      key: const ValueKey<String>('order-rated'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.ratedTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.ratedStarsLabel(rating.stars),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int star = 1; star <= 5; star++)
                  KitStar(filled: star <= rating.stars, size: 24),
              ],
            ),
          ),
          if (rating.reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final RatingReason reason in rating.reasons)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.field,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        OrderLabels.ratingReason(l10n, reason),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (comment != null && comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '«$comment»',
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: KitColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            rating.stars <= 3 ? l10n.ratedThanksLow : l10n.ratedThanks,
            style: const TextStyle(fontSize: 13, color: KitColors.muted),
          ),
        ],
      ),
    );
  }
}
