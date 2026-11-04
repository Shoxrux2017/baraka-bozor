import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/customer_orders.dart';

const Cubic _slide = Cubic(0.2, 0.8, 0.2, 1);

/// The two tabs of the orders as one segmented control (`DL-131`): a green
/// thumb slides to the chosen one, each label says how many orders it holds,
/// and the past count bumps once for each time it rose ([pastBumps]). A
/// segment is as tall as the control, so a thumb's tap is a 44 px target.
class OrdersSegment extends StatelessWidget {
  const OrdersSegment({
    required this.tab,
    required this.currentCount,
    required this.pastCount,
    required this.pastBumps,
    required this.onTab,
    super.key,
  });

  final OrdersTab tab;
  final int currentCount;
  final int pastCount;

  /// How many times the past count rose; each rise is one bump.
  final int pastBumps;
  final ValueChanged<OrdersTab> onTab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool still = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      child: DecoratedBox(
        key: const ValueKey<String>('orders-segment'),
        decoration: BoxDecoration(
          color: KitColors.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double width = (box.maxWidth - 12) / 2;
              return Stack(
                children: <Widget>[
                  AnimatedPositioned(
                    key: const ValueKey<String>('orders-thumb'),
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 320),
                    curve: _slide,
                    left: tab == OrdersTab.past ? 8 + width : 4,
                    top: 4,
                    bottom: 4,
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: KitColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            child: _Segment(
                              itemKey: 'orders-tab-current',
                              label: l10n.ordersTabCurrent,
                              count: currentCount,
                              chosen: tab == OrdersTab.current,
                              onTap: () => onTab(OrdersTab.current),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _Segment(
                              itemKey: 'orders-tab-past',
                              label: l10n.ordersTabPast,
                              count: pastCount,
                              chosen: tab == OrdersTab.past,
                              bumps: pastBumps,
                              onTap: () => onTab(OrdersTab.past),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.itemKey,
    required this.label,
    required this.count,
    required this.chosen,
    required this.onTap,
    this.bumps,
  });

  final String itemKey;
  final String label;
  final int count;
  final bool chosen;
  final VoidCallback onTap;

  /// The bumps of the count, or null for a count that does not bump.
  final int? bumps;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool still = MediaQuery.disableAnimationsOf(context);
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3;
    final Widget number = Text(
      ' · $count',
      style: const TextStyle(fontWeight: FontWeight.w500),
    );

    return Semantics(
      role: SemanticsRole.tab,
      selected: chosen,
      excludeSemantics: true,
      onTap: onTap,
      label: count > 0 ? '$label, ${l10n.ordersCount(count)}' : label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            key: ValueKey<String>(itemKey),
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: large ? 6 : 0,
                ),
                child: AnimatedDefaultTextStyle(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: chosen ? Colors.white : KitColors.muted,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(label),
                      if (count > 0)
                        bumps == null
                            ? number
                            : _CountBump(bumps: bumps!, child: number),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grows its [child] to 1.3 at 40 % of 340 ms and back each time [bumps]
/// goes up; with reduced motion it does not move.
class _CountBump extends StatefulWidget {
  const _CountBump({required this.bumps, required this.child});

  final int bumps;
  final Widget child;

  @override
  State<_CountBump> createState() => _CountBumpState();
}

class _CountBumpState extends State<_CountBump>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  late final Animation<double> _scale = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.3,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
    ],
  ).animate(_controller);

  @override
  void didUpdateWidget(_CountBump oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bumps > oldWidget.bumps &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    key: const ValueKey<String>('orders-past-bump'),
    scale: _scale,
    child: widget.child,
  );
}
