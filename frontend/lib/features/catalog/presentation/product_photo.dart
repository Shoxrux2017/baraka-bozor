import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/catalog.dart';

/// What a card hands the product screen it opens (`DL-122`): the product it
/// already holds, so the page shows at once, and the tag of the card's own
/// photo, so the photo flies from that card and back to it.
final class ProductOpening {
  const ProductOpening({required this.product, required this.heroTag});

  final CatalogProduct product;
  final Object heroTag;
}

/// The photo well of the product screen, and the shape the card's photo grows
/// into while it flies: a [KitColors.card] box of [radius] with the picture
/// centred at 0.68 of the shorter side.
class ProductPhotoWell extends StatelessWidget {
  const ProductPhotoWell({
    required this.imageUrl,
    required this.radius,
    super.key,
  });

  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.card,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Center(
          child: ProductImage(
            url: imageUrl,
            size: constraints.biggest.shortestSide * 0.68,
          ),
        ),
      ),
    );
  }
}

/// The flight of the photo between a card and the product screen: the well's
/// corners grow from 12 to 20 on the way in and shrink back on the way out.
/// The route's animation runs 0 to 1 in and 1 to 0 out, so one lerp serves
/// both.
Widget productPhotoFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final String? url = _imageUrlIn(fromContext) ?? _imageUrlIn(toContext);
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? _) => ProductPhotoWell(
      key: const ValueKey<String>('product-photo-flight'),
      imageUrl: url,
      radius: lerpDouble(12, 20, animation.value)!,
    ),
  );
}

/// The address of the first product picture under [context], if any.
String? _imageUrlIn(BuildContext context) {
  String? found;
  void visit(Element element) {
    final Widget widget = element.widget;
    if (widget is ProductImage) {
      found = widget.url;
      return;
    }
    element.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return found;
}
