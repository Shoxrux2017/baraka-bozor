import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';

/// How many category tiles fit a grid [width] (inside the side safe areas) at
/// the text size [scaler] gives: one rule for the home and «Все категории»
/// (`DL-125`); never fewer than two.
int categoryColumns(double width, TextScaler scaler) =>
    math.max(2, ((width - 20) / (scaler.scale(88) + 12)).round());

/// A category as the kit draws it (drawings 10b and 11): its picture on the
/// card colour, or — without one — the first letter of its name in green on
/// the green wash; the name under it in two lines, or in three when the grid
/// has only two [columns] (`DL-125`). [size] is the width of the tile; without
/// it the tile fills the width it is given.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    required this.category,
    required this.columns,
    this.size,
    super.key,
  });

  final CatalogCategory category;
  final int columns;
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
              pictureSize: box.maxWidth * (columns == 2 ? 0.52 : 0.7),
              fadeIn: true,
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
          maxLines: columns == 2 ? 3 : 2,
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

/// A category tile that opens its category; a screen reader hears the name
/// alone, not the letter of a tile without a picture (`DL-125`). Callers key
/// it `category-<id>`.
class CategoryButton extends StatelessWidget {
  const CategoryButton({
    required this.category,
    required this.columns,
    this.size,
    super.key,
  });

  final CatalogCategory category;
  final int columns;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: category.name(interfaceLanguage(context)),
      onTap: () => context.push<void>(CatalogPaths.category(category.id)),
      child: CategoryTile(category: category, columns: columns, size: size),
    );
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
    this.fadeIn = false,
    super.key,
  });

  final CatalogCategory category;
  final double size;
  final double radius;
  final double pictureSize;
  final Color? color;

  /// A picture not loaded at once fades in (`DL-125`).
  final bool fadeIn;

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
              : ProductImage(url: imageUrl, size: pictureSize, fadeIn: fadeIn),
        ),
      ),
    );
  }
}
