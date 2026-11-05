import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/customer_orders.dart';

/// The strip the order page shows once an edit is saved: «Заказ изменён» over
/// the new total (`DL-132`). It comes down from above in 420 ms, stays until
/// 4 s have passed and goes up with a fade in 300 ms; with reduced motion it
/// only fades, 250 ms each way. It does not announce: the editor did when it
/// saved.
class OrderEditedBanner extends StatefulWidget {
  const OrderEditedBanner({required this.order, super.key});

  /// The order as the save answered it.
  final CustomerOrder order;

  @override
  State<OrderEditedBanner> createState() => _OrderEditedBannerState();
}

class _OrderEditedBannerState extends State<OrderEditedBanner>
    with SingleTickerProviderStateMixin {
  static const Cubic _settle = Cubic(0.2, 0.8, 0.2, 1);
  static const double _stay = 4000;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Reduced motion changes how the banner moves, not how long it stays.
    animationBehavior: AnimationBehavior.preserve,
  );
  late bool _reduced;
  late double _inMs;
  late double _outMs;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _inMs = _reduced ? 250 : 420;
    _outMs = _reduced ? 250 : 300;
    _controller.duration = Duration(milliseconds: (_stay + _outMs).round());
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? total = widget.order.totalUzs;
    final String? totalWords =
        total == null || widget.order.totalKind == TotalKind.none
        ? null
        : _words(l10n, total);

    final Widget card = DecoratedBox(
      key: const ValueKey<String>('edit-banner'),
      decoration: BoxDecoration(
        color: KitColors.primaryDark,
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
            const Icon(Icons.check_circle, size: 24, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.orderEditedTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (totalWords != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.orderEditedTotal(totalWords),
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
    );

    return AnimatedBuilder(
      animation: _controller,
      child: card,
      builder: (BuildContext context, Widget? child) {
        if (_controller.isCompleted) {
          return const SizedBox.shrink();
        }
        final double ms = _controller.value * (_stay + _outMs);
        double rise = 0;
        double opacity = 1;
        if (ms < _inMs) {
          final double t = ms / _inMs;
          if (_reduced) {
            opacity = Curves.easeOut.transform(t);
          } else {
            rise = -1.4 * (1 - _settle.transform(t));
          }
        } else if (ms > _stay) {
          final double eased = Curves.easeIn.transform(
            ((ms - _stay) / _outMs).clamp(0, 1),
          );
          opacity = 1 - eased;
          if (!_reduced) {
            rise = -1.4 * eased;
          }
        }
        return Opacity(
          opacity: opacity,
          child: FractionalTranslation(
            translation: Offset(0, rise),
            child: child,
          ),
        );
      },
    );
  }

  /// The order's total, with «≈» while it is an estimate.
  String _words(AppLocalizations l10n, int total) {
    final String amount = MoneyFormat.uzs(total, interfaceLanguage(context));
    return widget.order.totalKind == TotalKind.estimate
        ? l10n.cartLineEstimate(amount)
        : amount;
  }
}
