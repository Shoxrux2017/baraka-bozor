import 'package:flutter/material.dart';

import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';

const ColorFilter _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// A product's picture in a square of the kit's card colour, radius 12;
/// [greyed] for a line that went.
class ShopperPicture extends StatelessWidget {
  const ShopperPicture({
    required this.url,
    required this.size,
    this.greyed = false,
    super.key,
  });

  final String? url;
  final double size;
  final bool greyed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KitColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: greyed
          ? Opacity(
              opacity: 0.4,
              child: ColorFiltered(
                colorFilter: _grey,
                child: ProductImage(url: url, size: size),
              ),
            )
          : ProductImage(url: url, size: size),
    );
  }
}
