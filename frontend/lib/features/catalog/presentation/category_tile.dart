import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';

/// How many category tiles fit a grid [width] (inside the side safe areas) at
/// the text size [scaler] gives: one rule for the home and «Все категории»
/// (`DL-125`); never fewer than two. A name is 12 px, so the factor is read
/// there (`DL-126`).
int categoryColumns(double width, TextScaler scaler) =>
    math.max(2, ((width - 20) / (88 * textScaleAt(scaler, 12) + 12)).round());

/// The height of a grid row of tiles [tile] wide in [columns] columns: the
/// picture, the gap and the name's lines at the text size [scaler] gives
/// (`DL-125`).
double categoryTileExtent(double tile, TextScaler scaler, int columns) =>
    tile + 6 + scaler.scale(12) * 1.25 * (columns == 2 ? 3 : 2) + 2;

/// What a tile hands the category screen it opens (`DL-125`): the tag of the
/// tile's own picture, so the picture flies from that tile into the rail and
/// back to it.
final class CategoryOpening {
  const CategoryOpening({required this.heroTag});

  final Object heroTag;
}

CategoryPictureWell _wellOf(BuildContext heroContext) =>
    (heroContext.widget as Hero).child as CategoryPictureWell;

/// The flight of a category's picture between its tile and the rail: the well
/// grows from the tile's corners (14) to the rail's (12), and its colour and
/// the picture's share of it follow. The route's animation runs 0 to 1 in and
/// 1 to 0 out, so one lerp serves both; 0 is the tile.
Widget categoryWellFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final bool pushing = direction == HeroFlightDirection.push;
  final CategoryPictureWell tile = _wellOf(pushing ? fromContext : toContext);
  final CategoryPictureWell rail = _wellOf(pushing ? toContext : fromContext);
  final CategoryPictureWell destination = _wellOf(toContext);
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? _) {
      final double t = animation.value;
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double side = box.biggest.shortestSide;
          return CategoryPictureWell(
            key: const ValueKey<String>('category-well-flight'),
            category: destination.category,
            size: side,
            radius: lerpDouble(14, 12, t)!,
            pictureSize:
                side *
                lerpDouble(
                  tile.pictureSize / tile.size,
                  rail.pictureSize / rail.size,
                  t,
                )!,
            color: Color.lerp(tile.fill, rail.fill, t),
            easeColor: false,
          );
        },
      );
    },
  );
}

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
    this.heroTag,
    super.key,
  });

  final CatalogCategory category;
  final int columns;
  final double? size;

  /// The tag the picture flies under when the tile opens its category; none
  /// (and no Hero) with reduced motion.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final String name = category.name(interfaceLanguage(context));
    final Object? tag = MediaQuery.disableAnimationsOf(context)
        ? null
        : heroTag;

    final Widget well = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final Widget picture = CategoryPictureWell(
            category: category,
            size: box.maxWidth,
            radius: 14,
            pictureSize: box.maxWidth * (columns == 2 ? 0.52 : 0.7),
            fadeIn: true,
          );
          return tag == null
              ? picture
              : Hero(
                  tag: tag,
                  flightShuttleBuilder: categoryWellFlight,
                  child: picture,
                );
        },
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
class CategoryButton extends StatefulWidget {
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
  State<CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<CategoryButton> {
  /// This tile's own tag: one category may stand on two screens at once.
  final Object _heroTag = Object();

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: widget.category.name(interfaceLanguage(context)),
      onTap: () => context.push<void>(
        CatalogPaths.category(widget.category.id),
        extra: CategoryOpening(heroTag: _heroTag),
      ),
      child: CategoryTile(
        category: widget.category,
        columns: widget.columns,
        size: widget.size,
        heroTag: _heroTag,
      ),
    );
  }
}

/// The square well of a category's picture, or — without one — the first
/// letter of its name in green, which a screen reader does not read. Without
/// a [color] the well is the card colour under a picture and the green wash
/// under a letter; a change of colour eases over 200 ms (`DL-127`).
class CategoryPictureWell extends StatelessWidget {
  const CategoryPictureWell({
    required this.category,
    required this.size,
    required this.radius,
    required this.pictureSize,
    this.color,
    this.fadeIn = false,
    this.easeColor = true,
    super.key,
  });

  final CatalogCategory category;
  final double size;
  final double radius;
  final double pictureSize;
  final Color? color;

  /// A picture not loaded at once fades in (`DL-125`).
  final bool fadeIn;

  /// Whether a change of [color] eases; a Hero's shuttle sets its colour every
  /// frame itself.
  final bool easeColor;

  /// The colour the well is filled with.
  Color get fill =>
      color ??
      (category.imageUrl == null ? KitColors.primaryWash : KitColors.card);

  @override
  Widget build(BuildContext context) {
    final String name = category.name(interfaceLanguage(context));
    final String? imageUrl = category.imageUrl;
    final Widget letterOrPicture = imageUrl == null
        ? ExcludeSemantics(
            child: Text(
              name.isEmpty ? '' : name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: KitColors.primaryDark,
              ),
            ),
          )
        : ProductImage(url: imageUrl, size: pictureSize, fadeIn: fadeIn);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: fill),
        duration: !easeColor || MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (BuildContext context, Color? colour, Widget? child) =>
            DecoratedBox(
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: child,
            ),
        child: Center(child: letterOrPicture),
      ),
    );
  }
}
