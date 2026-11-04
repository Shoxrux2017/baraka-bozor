import 'package:flutter/material.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// The order page's four stages in its words: accepted, shopping, on the way,
/// delivered.
List<String> orderPageStageLabels(AppLocalizations l10n) => <String>[
  l10n.progressAccepted,
  l10n.progressShopping,
  l10n.progressDelivering,
  l10n.progressDelivered,
];

/// The list card's four stages in its shorter words (`DL-131`).
List<String> orderListStageLabels(AppLocalizations l10n) => <String>[
  l10n.progressAccepted,
  l10n.progressListShopping,
  l10n.progressListDelivering,
  l10n.progressDelivered,
];

/// Whether the stages stand up as a list rather than lie as a bar: the text
/// of a 12 px label is more than 1.3 times its size (`DL-126`, `DL-130`).
bool stageBarStacks(TextScaler scaler) => textScaleAt(scaler, 12) > 1.3;

/// Four 4 px segments on a visible track, the stages reached in the brand
/// colour that changes softly, a check before each stage already passed, the
/// current one bold, and the time a stage was reached when [times] knows it.
/// At large text the bar stands up as a list. It is the order page's `DL-130`
/// bar and the list card's `DL-131` one: the page gives it a
/// [semanticsLabel] and reads as one node; the card, which speaks for
/// itself, leaves it null and the bar says nothing.
class OrderStageBar extends StatelessWidget {
  const OrderStageBar({
    required this.stage,
    required this.labels,
    this.times,
    this.currentLabel,
    this.semanticsLabel,
    super.key,
  });

  /// `orderStage(status)`: 1 to 4.
  final int stage;

  /// The four stages' words.
  final List<String> labels;

  /// When each stage was reached, the order page's.
  final List<DateTime?>? times;

  /// The words of the current row when the stages stand as a list; the
  /// order page puts its heading there.
  final String? currentLabel;

  /// What a screen reader says for the whole bar; `null` leaves it silent.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final bool still = MediaQuery.disableAnimationsOf(context);
    final String? label = semanticsLabel;
    // A stage is past once the order has moved on from it; every one is,
    // once delivered.
    bool past(int i) => stage == 4 || i < stage - 1;
    final Widget bar = stageBarStacks(scaler)
        ? _stageList(scaler, past)
        : _stageSegments(still, past);

    if (label == null) {
      return ExcludeSemantics(child: bar);
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: bar,
    );
  }

  Widget _time(int i) => Text(
    TashkentTime.time(times![i]!),
    key: ValueKey<String>('order-stage-time-$i'),
    style: const TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: KitColors.muted,
    ),
  );

  bool _hasTime(int i) => i < stage && times != null && times![i] != null;

  Widget _stageSegments(bool still, bool Function(int) past) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Segment(
                  boxKey: ValueKey<String>('order-stage-$i'),
                  color: i < stage
                      ? KitColors.primary
                      : KitColors.primary.withValues(alpha: 0.22),
                  still: still,
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (past(i)) ...<Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.check,
                          size: 13,
                          color: KitColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                    Flexible(
                      child: Text(
                        labels[i],
                        key: ValueKey<String>('order-stage-label-$i'),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: i == stage - 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i < stage ? KitColors.ink : KitColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_hasTime(i)) _time(i),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _stageList(TextScaler scaler, bool Function(int) past) {
    return Column(
      key: const ValueKey<String>('order-stages-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                past(i)
                    ? Icons.check_circle
                    : i == stage - 1
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                key: ValueKey<String>('order-stage-icon-$i'),
                size: scaler.scale(18),
                color: i < stage ? KitColors.primary : KitColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  i == stage - 1 ? (currentLabel ?? labels[i]) : labels[i],
                  key: ValueKey<String>('order-stage-label-$i'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: i == stage - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i < stage ? KitColors.ink : KitColors.muted,
                  ),
                ),
              ),
              if (_hasTime(i)) ...<Widget>[const SizedBox(width: 8), _time(i)],
            ],
          ),
        ],
      ],
    );
  }
}

/// One 4 px segment; its colour moves over 500 ms `easeOut`, at once with
/// reduced motion (`DL-131`).
class _Segment extends StatelessWidget {
  const _Segment({
    required this.boxKey,
    required this.color,
    required this.still,
  });

  final Key boxKey;
  final Color color;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      width: double.infinity,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: still ? Duration.zero : const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (BuildContext context, Color? value, Widget? child) =>
            DecoratedBox(
              key: boxKey,
              decoration: BoxDecoration(
                color: value,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
      ),
    );
  }
}
