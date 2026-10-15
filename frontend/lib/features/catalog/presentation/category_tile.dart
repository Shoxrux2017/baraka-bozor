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
    final String? imageUrl = category.imageUrl;

    final Widget well = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) => DecoratedBox(
          decoration: BoxDecoration(
            color: imageUrl == null ? KitColors.primaryWash : KitColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: imageUrl == null
                ? Text(
                    name.isEmpty ? '' : name.characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: box.maxWidth * 0.4,
                      fontWeight: FontWeight.w700,
                      color: KitColors.primaryDark,
                    ),
                  )
                : ProductImage(url: imageUrl, size: box.maxWidth * 0.7),
          ),
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
