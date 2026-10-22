import 'package:flutter/material.dart';

/// The kit card: white, radius 16, the kit shadow. An [outline] draws a 1.5 px
/// inner border: green for a new order, amber for a waiting line.
class KitCard extends StatelessWidget {
  const KitCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.outline,
    this.color = Colors.white,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? outline;

  /// The card's ground: white, or a wash for a selected card.
  final Color color;

  /// Makes the whole card a button whose ripple shows on the white.
  final VoidCallback? onTap;

  /// What a screen reader says for a tappable card; its texts when null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);
    final Widget padded = Padding(padding: padding, child: child);

    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
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
        child: onTap == null
            ? padded
            : Material(
                color: color,
                borderRadius: radius,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onTap,
                  child: padded,
                ),
              ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: semanticLabel != null,
      child: card,
    );
  }
}
