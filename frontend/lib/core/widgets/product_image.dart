import 'package:flutter/material.dart';

/// A product's image, or a placeholder. With [fadeIn] a picture that is not
/// ready at once fades in over 250 ms (at once with reduced motion), `DL-125`.
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.url,
    required this.size,
    this.fadeIn = false,
    super.key,
  });

  final String? url;
  final double size;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = SizedBox.square(
      dimension: size,
      child: Icon(Icons.shopping_basket_outlined, size: size / 2),
    );
    final String? url = this.url;
    if (url == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        frameBuilder: fadeIn
            ? (
                BuildContext context,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) {
                if (wasSynchronouslyLoaded) {
                  return child;
                }
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: child,
                );
              }
            : null,
        errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
            placeholder,
      ),
    );
  }
}
