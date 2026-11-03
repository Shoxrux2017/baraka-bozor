import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/routing/flight_page.dart';
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

/// The wide first tile of «Категории»: «Все товары» over the count of every
/// product, with the pictures of the first three categories overlapping at its
/// left (`DL-128`). It presses to 0.96 and opens «Все товары» with its title
/// flying into the header; with reduced motion nothing flies. Callers key it
/// `all-products-tile`.
class AllProductsTile extends StatefulWidget {
  const AllProductsTile({required this.categories, super.key});

  final List<CatalogCategory> categories;

  @override
  State<AllProductsTile> createState() => _AllProductsTileState();
}

class _AllProductsTileState extends State<AllProductsTile> {
  /// True while the title flies to the header. One notifier for the State's
  /// whole life, never disposed: the flight page writes it from its own
  /// dispose, which may come after this tile's.
  final ValueNotifier<bool> _holding = ValueNotifier<bool>(false);
  final GlobalKey _titleKey = GlobalKey();

  int get _total => widget.categories.fold<int>(
    0,
    (int sum, CatalogCategory c) => sum + c.productCount,
  );

  void _open(String title) {
    final Size screen = MediaQuery.sizeOf(context);
    final List<FlightItem> items = <FlightItem>[];
    if (!MediaQuery.disableAnimationsOf(context)) {
      final RenderObject? box = _titleKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        items.add(
          FlightItem(
            id: 'title',
            from: box.localToGlobal(Offset.zero) & box.size,
            builder: (BuildContext context) => Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
        );
      }
    }
    context.push<void>(
      CatalogPaths.products,
      extra: FlightOpening(items: items, screen: screen, holding: _holding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String count = l10n.catalogProductCount(_total);
    final String title = l10n.allProductsTitle;
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 16) > 1.3;
    final List<CatalogCategory> shown = widget.categories.take(3).toList();
    return PressScale(
      label: l10n.categoryShownSpoken(title, count),
      onTap: () => _open(title),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: KitColors.primaryWash,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            if (!large && shown.isNotEmpty) ...<Widget>[
              SizedBox(
                width: 92,
                height: 40,
                child: Stack(
                  children: <Widget>[
                    for (int i = 0; i < shown.length; i++)
                      Positioned(
                        left: 26.0 * i,
                        child: _TilePicture(category: shown[i]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ValueListenableBuilder<bool>(
                    valueListenable: _holding,
                    builder: (BuildContext context, bool held, Widget? child) =>
                        Opacity(opacity: held ? 0 : 1, child: child),
                    child: Text(
                      title,
                      key: _titleKey,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: KitColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 24,
              color: KitColors.primaryDark,
            ),
          ],
        ),
      ),
    );
  }
}

/// A category's picture in a white 40 circle ringed in the tile's colour.
class _TilePicture extends StatelessWidget {
  const _TilePicture({required this.category});

  final CatalogCategory category;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = category.imageUrl;
    final String name = category.name(interfaceLanguage(context));
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: KitColors.primaryWash, width: 2),
      ),
      child: imageUrl == null
          ? ExcludeSemantics(
              child: Text(
                name.isEmpty ? '' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KitColors.primaryDark,
                ),
              ),
            )
          : ProductImage(url: imageUrl, size: 26),
    );
  }
}
