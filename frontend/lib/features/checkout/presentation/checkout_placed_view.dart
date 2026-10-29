import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../domain/checkout.dart';

/// The placed order (drawing 26): its number, how it is paid, and the way on.
/// [opensAt] is given only when the order was placed outside the working hours.
/// It rises from the button and its circle opens, with a light haptic; with
/// reduced motion it stands still (`DL-121`).
class CheckoutPlacedView extends StatefulWidget {
  const CheckoutPlacedView({
    required this.order,
    required this.opensAt,
    super.key,
  });

  final PlacedOrder order;
  final String? opensAt;

  @override
  State<CheckoutPlacedView> createState() => _CheckoutPlacedViewState();
}

class _CheckoutPlacedViewState extends State<CheckoutPlacedView>
    with SingleTickerProviderStateMixin {
  static const Cubic _riseCurve = Cubic(0.2, 0.9, 0.25, 1);

  /// One run of 620 ms; the background, the card and the circle take their own
  /// stretch of it (`DL-121`).
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final Animation<Color?> _background =
      ColorTween(begin: Colors.white, end: const Color(0xFFEBEDEC)).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 300 / 620, curve: Curves.easeOut),
        ),
      );
  late final Animation<double> _cardProgress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 420 / 620, curve: _riseCurve),
  );
  late final Animation<double> _circleProgress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(120 / 620, 1, curve: _riseCurve),
  );
  late final Animation<double> _circleScale = Tween<double>(
    begin: 0.6,
    end: 1,
  ).animate(_circleProgress);
  late final Animation<double> _cardScale = Tween<double>(
    begin: 0.94,
    end: 1,
  ).animate(_cardProgress);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlacedOrder order = widget.order;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? total = order.totalUzs;
    final String? opens = widget.opensAt;
    // A replay answers the order as it is now: cancelled meanwhile, it is
    // said so.
    final bool cancelled = total == null;
    final String title = cancelled
        ? l10n.checkoutPlacedCancelled('${order.orderNumber}')
        : l10n.checkoutPlaced('${order.orderNumber}');
    final String body = cancelled
        ? l10n.totalNothingDue
        : order.totalKind == TotalKind.finalTotal
        ? l10n.checkoutPlacedCashFinal(
            MoneyFormat.uzs(total, interfaceLanguage(context)),
          )
        : l10n.checkoutPlacedCash;
    const TextStyle bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: KitColors.ink2,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          context.go(AppPaths.customer);
        }
      },
      child: AnimatedBuilder(
        animation: _background,
        builder: (BuildContext context, Widget? body) =>
            Scaffold(backgroundColor: _background.value, body: body),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    key: const ValueKey<String>('checkout-placed'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: AnimatedBuilder(
                      animation: _cardProgress,
                      builder: (BuildContext context, Widget? card) =>
                          Transform.translate(
                            offset: Offset(0, 48 * (1 - _cardProgress.value)),
                            child: ScaleTransition(
                              scale: _cardScale,
                              alignment: Alignment.bottomCenter,
                              child: FadeTransition(
                                opacity: _cardProgress,
                                child: card,
                              ),
                            ),
                          ),
                      child: Container(
                        key: const ValueKey<String>('checkout-placed-card'),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ExcludeSemantics(
                              child: FadeTransition(
                                opacity: _circleProgress,
                                child: ScaleTransition(
                                  scale: _circleScale,
                                  child: Container(
                                    key: const ValueKey<String>(
                                      'checkout-placed-circle',
                                    ),
                                    width: 130,
                                    height: 130,
                                    decoration: const BoxDecoration(
                                      color: KitColors.primaryWash,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: const BoxDecoration(
                                        color: KitColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: KitColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: bodyStyle,
                            ),
                            if (opens != null && !cancelled) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                l10n.checkoutPlacedOpensAt(opens),
                                textAlign: TextAlign.center,
                                style: bodyStyle,
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                key: const ValueKey<String>(
                                  'checkout-open-order',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: KitColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  final GoRouter router = GoRouter.of(context)
                                    ..go(AppPaths.customer);
                                  router.push(AppPaths.customerOrder(order.id));
                                },
                                child: Text(l10n.checkoutOrderStatus),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                key: const ValueKey<String>('checkout-to-home'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: KitColors.ink,
                                  side: const BorderSide(color: KitColors.line),
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => context.go(AppPaths.customer),
                                child: Text(l10n.checkoutToHome),
                              ),
                            ),
                          ],
                        ),
                      ),
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
