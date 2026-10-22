import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// A row action of a panel table: a 36 square outlined button of radius 10
/// with a `muted` [icon] and a [tooltip]. A null [onTap] disables it.
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
    );
  }
}
