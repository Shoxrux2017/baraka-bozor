import 'package:flutter/material.dart';

/// A product's image, or a placeholder.
class ProductImage extends StatelessWidget {
  const ProductImage({required this.url, required this.size, super.key});

  final String? url;
  final double size;

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
        errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
            placeholder,
      ),
    );
  }
}
