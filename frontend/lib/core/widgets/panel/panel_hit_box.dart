import 'package:flutter/material.dart';

/// Grows the tap area of a small, hand-drawn [child] to at least 44 × 44
/// without changing how it is drawn (DL-117). The box is the control's
/// semantic area, so a screen reader and the Apple tap-target guideline both
/// see 44 × 44; a tap anywhere in it runs [onTap].
class PanelHitBox extends StatelessWidget {
  const PanelHitBox({required this.onTap, required this.child, super.key});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}
