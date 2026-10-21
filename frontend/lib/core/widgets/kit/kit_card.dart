import 'package:flutter/material.dart';

/// The kit card: white, radius 16, the kit shadow. An [outline] draws a 1.5 px
/// inner border: green for a new order, amber for a waiting line.
class KitCard extends StatelessWidget {
  const KitCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.outline,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: outline == null
              ? null
              : Border.all(color: outline!, width: 1.5),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
