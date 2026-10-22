import 'package:flutter/material.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../domain/board.dart';

/// Where the order is on its way, in five steps — created, shopping, ready
/// for delivery, on the way, completed — each with the instant the server
/// recorded for it. The step under way says since when; a cancelled order
/// ends in red after the last step it reached (`DL-100` (4)).
class OrderPath extends StatelessWidget {
  const OrderPath({required this.order, super.key});

  final BoardOrder order;

  /// The instant of step [step] (0 to 4), when the server recorded one.
  DateTime? _instant(int step) => switch (step) {
    0 => order.createdAt,
    1 => order.shoppingStartedAt,
    2 => order.readyForDeliveryAt,
    3 => order.onTheWayAt,
    _ => order.completedAt,
  };

  /// The step the order is at: its first not done. Five once completed.
  int get _current => switch (order.status) {
    OrderStatus.newOrder || OrderStatus.shoppingAssigned => 0,
    OrderStatus.shopping || OrderStatus.finalPaymentPending => 1,
    OrderStatus.readyForDelivery || OrderStatus.deliveryAssigned => 2,
    OrderStatus.onTheWay => 3,
    OrderStatus.completed => 5,
    // A cancelled order is shown by what it reached, not by a current step.
    OrderStatus.cancelled => -1,
  };

  /// How many steps a cancelled order reached: from the first, while each
  /// recorded its instant.
  int get _reached {
    int reached = 1;
    while (reached < 4 && _instant(reached) != null) {
      reached++;
    }
    return reached;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool cancelled = order.status == OrderStatus.cancelled;
    final int current = _current;
    final List<String> labels = <String>[
      l10n.orderPathCreated,
      l10n.orderPathShopping,
      OrderLabels.status(l10n, OrderStatus.readyForDelivery),
      OrderLabels.status(l10n, OrderStatus.onTheWay),
      OrderLabels.status(l10n, OrderStatus.completed),
    ];

    String clock(int step) {
      final DateTime? instant = _instant(step);
      return instant == null ? '—' : TashkentTime.time(instant);
    }

    String? underWay(int step) {
      final DateTime? instant = _instant(step);
      if (instant == null) {
        return null;
      }
      final String time = TashkentTime.time(instant);
      return switch (step) {
        1 when order.status == OrderStatus.finalPaymentPending =>
          OrderLabels.status(l10n, order.status),
        1 || 3 => l10n.orderPathRunning(time),
        _ => l10n.orderPathWaiting(time),
      };
    }

    final int shown = cancelled ? _reached + 1 : 5;

    return KitCard(
      key: const ValueKey<String>('order-path'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int step = 0; step < shown; step++)
            Expanded(
              child: cancelled && step == shown - 1
                  ? _Step(
                      key: ValueKey<String>('order-path-$step'),
                      state: _StepState.cancelled,
                      label: OrderLabels.status(l10n, OrderStatus.cancelled),
                      time: order.cancelledAt == null
                          ? '—'
                          : TashkentTime.time(order.cancelledAt!),
                      barAfter: null,
                    )
                  : _Step(
                      key: ValueKey<String>('order-path-$step'),
                      state: cancelled || step < current
                          ? _StepState.done
                          : step == current
                          ? _StepState.current
                          : _StepState.ahead,
                      label: labels[step],
                      time: step == current
                          ? underWay(step) ?? '—'
                          : clock(step),
                      timeEmphasised: step == current && underWay(step) != null,
                      barAfter: step == shown - 1
                          ? null
                          : (cancelled || step < current),
                    ),
            ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, ahead, cancelled }

class _Step extends StatelessWidget {
  const _Step({
    required this.state,
    required this.label,
    required this.time,
    required this.barAfter,
    this.timeEmphasised = false,
    super.key,
  });

  final _StepState state;
  final String label;
  final String time;

  /// `null` for the last step shown; else whether the bar to the next step
  /// is green, the step being done.
  final bool? barAfter;
  final bool timeEmphasised;

  @override
  Widget build(BuildContext context) {
    final bool ahead = state == _StepState.ahead;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Dot(state: state),
            if (barAfter != null)
              Expanded(
                child: Container(
                  height: 3,
                  color: barAfter! ? KitColors.primary : KitColors.line,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: ahead ? FontWeight.w500 : FontWeight.w600,
              color: switch (state) {
                _StepState.ahead => KitColors.muted,
                _StepState.cancelled => KitColors.dangerDark,
                _ => KitColors.ink,
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8, top: 1),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: timeEmphasised ? FontWeight.w600 : FontWeight.w400,
              color: timeEmphasised ? KitColors.primaryDark : KitColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Border? border, Widget? mark) = switch (state) {
      _StepState.done => (
        KitColors.primary,
        null,
        const Icon(Icons.check, size: 13, color: Colors.white),
      ),
      _StepState.current => (
        Colors.white,
        Border.all(color: KitColors.primary, width: 5),
        null,
      ),
      _StepState.ahead => (
        Colors.white,
        Border.all(color: KitColors.line, width: 3),
        null,
      ),
      _StepState.cancelled => (
        KitColors.danger,
        null,
        const Icon(Icons.close, size: 13, color: Colors.white),
      ),
    };

    return Container(
      width: 19,
      height: 19,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border,
      ),
      child: mark,
    );
  }
}
