import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/timed_banner.dart';
import 'cancel_sheet.dart';

/// The strip the order page shows once the cancel sheet answered for sure
/// (`DL-133`): «Заказ № … отменён» over how to order again, or «Просьба
/// отправлена» over who decides. It rises from the bottom as a [TimedBanner]
/// from below does, and announces nothing: the page does.
class OrderCancelledBanner extends StatelessWidget {
  const OrderCancelledBanner({
    required this.outcome,
    required this.orderNumber,
    super.key,
  });

  /// What the sheet answered: [CancelSheetExit.cancelled] or
  /// [CancelSheetExit.requested].
  final CancelSheetExit outcome;
  final int orderNumber;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool cancelled = outcome == CancelSheetExit.cancelled;
    final String title = cancelled
        ? l10n.cancelBannerTitle(orderNumber)
        : l10n.cancelSheetRequested;
    final String hint = cancelled
        ? l10n.cancelBannerHint
        : l10n.requestBannerHint;

    return TimedBanner(
      fromBelow: true,
      child: DecoratedBox(
        key: const ValueKey<String>('cancel-banner'),
        decoration: BoxDecoration(
          color: KitColors.ink2,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: KitColors.shadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                cancelled ? Icons.check_circle : Icons.schedule,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a part of the order page arrives once the order shows the cancel's
/// outcome (`DL-133`): the status card grows from 0.97 with a fade, the
/// request card comes 8 px down with a fade after 80 ms, the bar rises 12 px
/// with a fade.
enum OutcomeMove { card, request, bar }

/// Plays [move] on its child once each time [play] takes a new value above 0;
/// before and after it shows the child as it is. With reduced motion only a
/// fade plays (the card's from 0.4).
class OutcomeEntrance extends StatefulWidget {
  const OutcomeEntrance({
    required this.play,
    required this.move,
    required this.child,
    super.key,
  });

  final int play;
  final OutcomeMove move;
  final Widget child;

  @override
  State<OutcomeEntrance> createState() => _OutcomeEntranceState();
}

class _OutcomeEntranceState extends State<OutcomeEntrance>
    with SingleTickerProviderStateMixin {
  static const Cubic _settle = Cubic(0.2, 0.8, 0.2, 1);

  /// The request card waits 80 ms, then the 260 ms of the others.
  static const int _delayMs = 80;
  static const int _moveMs = 260;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
    // Reduced motion changes how the part arrives, not how long it takes.
    animationBehavior: AnimationBehavior.preserve,
  );

  int get _delay => widget.move == OutcomeMove.request ? _delayMs : 0;

  @override
  void initState() {
    super.initState();
    _controller.duration = Duration(milliseconds: _delay + _moveMs);
  }

  @override
  void didUpdateWidget(OutcomeEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play != oldWidget.play && widget.play > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        // One shape before, during and after, so the child never rebuilds
        // its state when the entrance ends.
        final double ms = _controller.value * (_delay + _moveMs);
        final double eased = _settle.transform(
          ((ms - _delay) / _moveMs).clamp(0, 1),
        );
        final bool card = widget.move == OutcomeMove.card;
        final double opacity = card && reduced ? 0.4 + 0.6 * eased : eased;
        final Matrix4 matrix = reduced
            ? Matrix4.identity()
            : switch (widget.move) {
                OutcomeMove.card => Matrix4.diagonal3Values(
                  0.97 + 0.03 * eased,
                  0.97 + 0.03 * eased,
                  1,
                ),
                OutcomeMove.request => Matrix4.translationValues(
                  0,
                  -8 * (1 - eased),
                  0,
                ),
                OutcomeMove.bar => Matrix4.translationValues(
                  0,
                  12 * (1 - eased),
                  0,
                ),
              };
        return Opacity(
          opacity: opacity,
          child: Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }
}
