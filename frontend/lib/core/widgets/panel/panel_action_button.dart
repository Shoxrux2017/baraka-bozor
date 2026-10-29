import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';
import 'panel_hit_box.dart';

/// A row action of a panel table: a 36 square outlined button of radius 10
/// with a `muted` [icon] and a [tooltip]. A null [onTap] disables it. Drawn 36,
/// it taps from 44 square (DL-117).
class PanelActionButton extends StatelessWidget {
  const PanelActionButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(10);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        excludeSemantics: true,
        onTap: onTap,
        child: PanelHitBox(
          onTap: onTap,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: const BorderSide(color: KitColors.line),
            ),
            child: InkWell(
              key: buttonKey,
              borderRadius: radius,
              onTap: onTap,
              child: SizedBox.square(
                dimension: 36,
                child: Icon(icon, size: 19, color: KitColors.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
