import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// A rating star (DL-117): a filled one is amber with a darker edge, an empty
/// one is a grey outline. It draws only; each site keeps its own semantics.
class KitStar extends StatelessWidget {
  const KitStar({required this.filled, required this.size, super.key});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: filled
          ? Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(Icons.star, size: size, color: KitColors.star),
                Icon(Icons.star_border, size: size, color: KitColors.starEdge),
              ],
            )
          : Icon(Icons.star_border, size: size, color: KitColors.muted),
    );
  }
}
