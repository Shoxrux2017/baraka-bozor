import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';
import 'panel_hit_box.dart';

/// One choice of a [PanelSegmented]: its [value], [label], the [key] of its
/// button and an optional [dot] colour shown before the label.
typedef PanelSegment<T> = ({T value, String label, Key key, Color? dot});

/// A switch of a few choices in a `field` box: the selected one stands white
/// with a soft shadow. A null [onSelected] disables every segment.
///
/// A value in [hollowDots] shows its dot as a ring instead of a filled disc,
/// so the state a dot tells is not told by colour alone; a value's [hints]
/// entry is read after its label by a screen reader.
class PanelSegmented<T> extends StatelessWidget {
  const PanelSegmented({
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.hollowDots = const <Never>{},
    this.hints = const <Never, String>{},
    super.key,
  });

  final List<PanelSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onSelected;
  final Set<T> hollowDots;
  final Map<T, String> hints;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<T>? onSelected = this.onSelected;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KitColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Wrap(
          spacing: 2,
          children: <Widget>[
            for (final PanelSegment<T> segment in segments)
              _Segment(
                key: segment.key,
                label: segment.label,
                dot: segment.dot,
                hollow: hollowDots.contains(segment.value),
                hint: hints[segment.value],
                selected: segment.value == selected,
                onTap: onSelected == null
                    ? null
                    : () => onSelected(segment.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.dot,
    required this.hollow,
    required this.hint,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color? dot;
  final bool hollow;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(9);
    final Color? dot = this.dot;

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      excludeSemantics: true,
      label: hint == null ? label : '$label, $hint',
      onTap: onTap,
      // The drawn segment stays 34 high, with its highlight on that pill; its
      // tap area is 44 (DL-117).
      child: PanelHitBox(
        onTap: onTap,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Ink(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? Colors.white : null,
                borderRadius: radius,
                boxShadow: selected
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: KitColors.shadow,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (dot != null) ...<Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: hollow ? null : dot,
                        shape: BoxShape.circle,
                        border: hollow
                            ? Border.all(color: dot, width: 1.5)
                            : null,
                      ),
                      child: const SizedBox(width: 8, height: 8),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? KitColors.ink : KitColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
