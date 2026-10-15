import '../../catalog/domain/catalog.dart';

/// One favourite as the Customer sees it: the product, and whether it can be
/// ordered now (`docs/09-api-contracts.md` section 14). A product that is no
/// longer available stays in the list.
final class FavoriteProduct {
  const FavoriteProduct({required this.product, required this.isAvailable});

  final CatalogProduct product;
  final bool isAvailable;
}
