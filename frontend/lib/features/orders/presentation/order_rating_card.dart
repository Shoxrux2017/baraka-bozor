import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/order_dates.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_star.dart';
import '../application/rate_draft.dart';
import '../domain/customer_orders.dart';
import 'rate_rise.dart';
import 'rating_stars.dart';

const List<BoxShadow> _cardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 2)),
];

/// The white card both rating cards stand on; [decoration] draws a flash.
class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.boxKey,
    required this.child,
    this.decoration,
  });

  final Key boxKey;
  final Widget child;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: boxKey,
      decoration:
          decoration ??
          BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _cardShadow,
          ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// The amber strip under the order's stars while an unsent rating is kept:
/// «Оценка не отправлена» and «Продолжить». Above 1.3 at 13 px the button goes
/// under the words at full width.
class _DraftStrip extends StatelessWidget {
  const _DraftStrip({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final Widget words = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        l10n.rateDraftLine,
        style: const TextStyle(fontSize: 13, height: 1.4, color: KitColors.ink),
      ),
    );
    final Widget button = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onContinue,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: large ? null : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.rateDraftContinue,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KitColors.warningDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    const Icon icon = Icon(
      Icons.edit_note,
      size: 20,
      color: KitColors.warningDark,
    );
    // One stop for a reader: the words, then the button (`DL-134` (11)).
    return RateRise(
      child: Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        label: '${l10n.rateDraftLine}. ${l10n.rateDraftContinue}',
        onTap: onContinue,
        child: DecoratedBox(
          key: const ValueKey<String>('order-rate-draft'),
          decoration: BoxDecoration(
            color: KitColors.warningWash,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: icon,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: words),
                        ],
                      ),
                      button,
                    ],
                  )
                : Row(
                    children: <Widget>[
                      icon,
                      const SizedBox(width: 10),
                      Expanded(child: words),
                      button,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// "How was the order?" on a delivered order that can still be rated: five
/// stars that light to the tap and, after 300 ms (120 ms with reduced
/// motion), open the rating screen with those stars chosen (`DL-92` item 6,
/// `DL-134`). A kept draft shows under them with a way to continue it. Back
/// from the screen the stars are unlit.
class RateOrderCard extends ConsumerStatefulWidget {
  const RateOrderCard({required this.order, required this.onOpen, super.key});

  final CustomerOrder order;

  /// Opens the rating screen with the given stars chosen, or on the kept
  /// draft's when `null`.
  final ValueChanged<int?> onOpen;

  @override
  ConsumerState<RateOrderCard> createState() => _RateOrderCardState();
}

class _RateOrderCardState extends ConsumerState<RateOrderCard> {
  /// The star the Customer tapped while the screen is on its way.
  int? _lit;
  Timer? _timer;

  /// Whether the screen was asked for and has not yet come back.
  bool _away = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The route says it is current again once the screen has gone.
    if (_away && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _away = false;
      _lit = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tap(int stars, RatingInput how) {
    if (_lit != null) {
      return;
    }
    setState(() => _lit = stars);
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    // A Timer, since a controller would be shortened by the platform's
    // reduced-motion setting.
    _timer = Timer(Duration(milliseconds: reduced ? 120 : 300), () {
      _timer = null;
      if (!mounted) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        _away = true;
        widget.onOpen(stars);
      } else {
        setState(() => _lit = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool draft = ref.watch(
      rateDraftsProvider.select(
        (Map<String, RateDraft> drafts) => drafts.containsKey(widget.order.id),
      ),
    );

    return _RatingCard(
      boxKey: const ValueKey<String>('order-rate'),
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
          const SizedBox(height: 8),
          Center(
            child: RatingStars(
              value: _lit,
              enabled: _lit == null,
              onChanged: _tap,
              cell: 44,
              glyph: 34,
              spacing: 4,
              keyPrefix: 'order-rate',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rateBlockHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: KitColors.muted,
            ),
          ),
          if (draft) ...<Widget>[
            const SizedBox(height: 12),
            _DraftStrip(onContinue: () => widget.onOpen(null)),
          ],
        ],
      ),
    );
  }
}

/// The Customer's rating of the order: the stars, the reasons, the comment,
/// and what happens next. It flashes once each time [flash] takes a new value
/// above 0, from the line's green wash with a ring to white with its shadow
/// in 1.6 s (`DL-134`), with reduced motion too: colour, not movement.
class RatedOrderCard extends StatefulWidget {
  const RatedOrderCard({
    required this.rating,
    required this.now,
    required this.flash,
    super.key,
  });

  final CustomerRating rating;
  final DateTime now;
  final int flash;

  @override
  State<RatedOrderCard> createState() => _RatedOrderCardState();
}

class _RatedOrderCardState extends State<RatedOrderCard>
    with SingleTickerProviderStateMixin {
  static const BoxShadow _ring = BoxShadow(
    color: KitColors.primary,
    spreadRadius: 2,
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
    value: 1,
    // The flash is colour, so reduced motion leaves its length alone.
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void didUpdateWidget(RatedOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flash != oldWidget.flash && widget.flash > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BoxDecoration _decoration() {
    final double t = Curves.easeOut.transform(_controller.value);
    return BoxDecoration(
      color: Color.lerp(KitColors.lineFlash, Colors.white, t),
      borderRadius: BorderRadius.circular(16),
      boxShadow: t >= 1
          ? _cardShadow
          : BoxShadow.lerpList(<BoxShadow>[_ring], _cardShadow, t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CustomerRating rating = widget.rating;
    final String? comment = rating.comment;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => _RatingCard(
        boxKey: const ValueKey<String>('order-rated'),
        decoration: _decoration(),
        child: child!,
      ),
      // One stop for a reader, the whole phrase (`DL-134` (11)).
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: _spoken(l10n),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _RatedHead(
              title: l10n.ratedTitle,
              date: orderAtLower(l10n, rating.createdAt, widget.now),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: l10n.ratedStarsLabel(rating.stars),
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int star = 1; star <= 5; star++) ...<Widget>[
                    if (star > 1) const SizedBox(width: 2),
                    KitStar(filled: star <= rating.stars, size: 24),
                  ],
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
            _RatedNote(rating: rating, now: widget.now),
          ],
        ),
      ),
    );
  }

  /// The card as one phrase: the title and date, the stars, the reasons, the
  /// comment and what happens next; the parts that are absent are left out.
  String _spoken(AppLocalizations l10n) {
    final CustomerRating rating = widget.rating;
    final String? comment = rating.comment;
    return <String>[
      '${l10n.ratedTitle}, ${orderAtLower(l10n, rating.createdAt, widget.now)}',
      l10n.ratedStarsLabel(rating.stars),
      if (rating.reasons.isNotEmpty)
        rating.reasons
            .map(
              (RatingReason reason) => OrderLabels.ratingReason(l10n, reason),
            )
            .join(', '),
      if (comment != null && comment.isNotEmpty) '«$comment»',
      _ratedNote(l10n, rating, widget.now).$2,
    ].join('. ');
  }
}

/// «Ваша оценка» with the date at the end on the title's baseline; when they
/// do not fit on one line the date goes under the title.
class _RatedHead extends StatelessWidget {
  const _RatedHead({required this.title, required this.date});

  final String title;
  final String date;

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: KitColors.ink,
  );
  static const TextStyle _dateStyle = TextStyle(
    fontSize: 12,
    color: KitColors.muted,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool together =
            textWidth(context, title, _titleStyle) +
                8 +
                textWidth(context, date, _dateStyle) <=
            box.maxWidth;
        if (together) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(title, style: _titleStyle),
              Text(date, style: _dateStyle),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: _titleStyle),
            Text(date, style: _dateStyle),
          ],
        );
      },
    );
  }
}

/// What happens next, with its icon if it has one: thanks at 4 and 5; at 1 to
/// 3 that the Operator will call, or when they did.
(IconData?, String) _ratedNote(
  AppLocalizations l10n,
  CustomerRating rating,
  DateTime now,
) {
  final DateTime? reviewed = rating.reviewedAt;
  if (!isLowRating(rating.stars)) {
    return (null, l10n.ratedThanks);
  }
  return reviewed == null
      ? (Icons.support_agent, l10n.ratedOperatorWill)
      : (
          Icons.check_circle,
          l10n.ratedOperatorCalled(orderAtLower(l10n, reviewed, now)),
        );
}

class _RatedNote extends StatelessWidget {
  const _RatedNote({required this.rating, required this.now});

  final CustomerRating rating;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (IconData? icon, String words) = _ratedNote(
      AppLocalizations.of(context),
      rating,
      now,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: KitColors.primaryDark),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            words,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: KitColors.ink2,
            ),
          ),
        ),
      ],
    );
  }
}
