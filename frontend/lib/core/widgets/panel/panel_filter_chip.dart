import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// A 32-high filter chip: white with a `line` border, or — selected — a green
/// wash with a green border and dark text.
class PanelFilterChip extends StatelessWidget {
  const PanelFilterChip({
    super.key,
    required this.chipKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String chipKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? KitColors.primaryDark : KitColors.ink2;
    final BorderRadius radius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        key: ValueKey<String>(chipKey),
        color: selected ? KitColors.primaryWash : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? KitColors.primary : KitColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
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
