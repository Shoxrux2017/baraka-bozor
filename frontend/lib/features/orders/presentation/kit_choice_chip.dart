import 'package:flutter/material.dart';

import '../../../core/theme/kit_colors.dart';

/// One choice as a chip: a button with its state, and a place or hint for a
/// reader. The cancel sheet's reasons (white [ground]) and the rating's
/// (`KitColors.field`) are drawn with it (`DL-133`, `DL-134`).
class KitChoiceChip extends StatelessWidget {
  const KitChoiceChip({
    required this.label,
    required this.chosen,
    required this.onTap,
    this.enabled = true,
    this.hint,
    this.ground = Colors.white,
    super.key,
  });

  final String label;
  final bool chosen;
  final VoidCallback onTap;
  final bool enabled;

  /// What a reader hears after the label, such as the chip's place.
  final String? hint;

  /// The chip's colour while it is not chosen.
  final Color ground;

  @override
  Widget build(BuildContext context) {
    const Duration fade = Duration(milliseconds: 200);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: chosen,
      label: label,
      hint: hint,
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: fade,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: chosen ? KitColors.primaryWash : ground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: chosen ? KitColors.primary : KitColors.outline,
            width: chosen ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (chosen) ...<Widget>[
                      const Icon(
                        Icons.check,
                        size: 18,
                        color: KitColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: fade,
                        curve: Curves.easeOut,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: chosen
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: chosen ? KitColors.primaryDark : KitColors.ink,
                        ),
                        child: Text(label),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
