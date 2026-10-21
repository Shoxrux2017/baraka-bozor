import 'package:flutter/material.dart';

import '../../formatting/tashkent_time.dart';
import '../../theme/kit_colors.dart';
import 'kit_note.dart';

/// A bar of [segments], one box each: 4 high, round, with a gap of 4 up to
/// twelve segments and 2 above.
class SegmentBar extends StatelessWidget {
  const SegmentBar({required this.segments, super.key});

  final List<Color> segments;

  @override
  Widget build(BuildContext context) {
    final double gap = segments.length <= 12 ? 4 : 2;

    return Row(
      children: <Widget>[
        for (int index = 0; index < segments.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: gap),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: segments[index],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One step of an assignment: its label and the instant it was reached, when
/// the server knows it.
typedef KitStep = ({String label, DateTime? at});

/// The steps of an assignment: a [SegmentBar] with one segment per step, the
/// first [reached] green, each step named, with its time when known.
class KitSteps extends StatelessWidget {
  const KitSteps({required this.steps, required this.reached, super.key});

  final List<KitStep> steps;
  final int reached;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentBar(
          segments: <Color>[
            for (int index = 0; index < steps.length; index++)
              index < reached ? KitColors.primary : KitColors.primarySoft,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < steps.length; index++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        steps[index].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: index < reached
                              ? KitColors.primaryDark
                              : KitColors.muted,
                        ),
                      ),
                      if (steps[index].at != null)
                        Text(
                          TashkentTime.time(steps[index].at!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: KitColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

({Color wash, Color circle, Color icon}) _palette(KitTone tone) {
  return switch (tone) {
    KitTone.green => (
      wash: KitColors.primaryWash,
      circle: KitColors.primarySoft,
      icon: KitColors.primaryDark,
    ),
    KitTone.amber => (
      wash: KitColors.warningWash,
      circle: Colors.white,
      icon: KitColors.warning,
    ),
    // Red is not used on a status card and reads as grey.
    KitTone.grey || KitTone.red => (
      wash: KitColors.field,
      circle: Colors.white,
      icon: KitColors.muted,
    ),
  };
}

/// The card on top of a staff order: an icon, what stage the order is at,
/// what to do next, then [progress] and whatever goes [below] it.
class KitStatusCard extends StatelessWidget {
  const KitStatusCard({
    required this.icon,
    required this.title,
    this.hint,
    this.hintKey,
    this.tone = KitTone.green,
    this.progress,
    this.below = const <Widget>[],
    super.key,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Key? hintKey;
  final KitTone tone;
  final Widget? progress;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final ({Color wash, Color circle, Color icon}) palette = _palette(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.wash,
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.circle,
                  ),
                  child: Icon(icon, size: 26, color: palette.icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      if (hint != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          hint!,
                          key: hintKey,
                          style: const TextStyle(
                            fontSize: 13,
                            color: KitColors.ink2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: 14),
              progress!,
            ],
            ...below,
          ],
        ),
      ),
    );
  }
}
