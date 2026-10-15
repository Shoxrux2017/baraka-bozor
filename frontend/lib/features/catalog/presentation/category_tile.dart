import 'package:flutter/material.dart';

import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/catalog.dart';

/// A category as the kit draws it (drawings 10b and 11): its picture on the
/// card colour, or — without one — the first letter of its name in green on
/// the green wash; the name under it, in two lines at most. [size] is the
/// width of the tile; without it the tile fills the width it is given.
class CategoryTile extends StatelessWidget {
  const CategoryTile({required this.category, this.size, super.key});

  final CatalogCategory category;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final String name = category.name(interfaceLanguage(context));

    final Widget well = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) =>
            CategoryPictureWell(
              category: category,
              size: box.maxWidth,
              radius: 14,
              pictureSize: box.maxWidth * 0.7,
            ),
      ),
    );

    final Widget tile = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        well,
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.25,
            color: KitColors.ink,
          ),
        ),
      ],
    );
    return size == null ? tile : SizedBox(width: size, child: tile);
  }
}

/// The square well of a category's picture, or — without one — the first
/// letter of its name in green. Without a [color] the well is the card colour
/// under a picture and the green wash under a letter.
class CategoryPictureWell extends StatelessWidget {
  const CategoryPictureWell({
    required this.category,
    required this.size,
    required this.radius,
    required this.pictureSize,
    this.color,
    super.key,
  });

  final CatalogCategory category;
  final double size;
  final double radius;
  final double pictureSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final String name = category.name(interfaceLanguage(context));
    final String? imageUrl = category.imageUrl;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              color ??
              (imageUrl == null ? KitColors.primaryWash : KitColors.card),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: imageUrl == null
              ? Text(
                  name.isEmpty ? '' : name.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w700,
                    color: KitColors.primaryDark,
                  ),
                )
              : ProductImage(url: imageUrl, size: pictureSize),
        ),
      ),
    );
  }
}
