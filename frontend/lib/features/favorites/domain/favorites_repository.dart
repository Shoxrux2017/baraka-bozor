import '../../../core/network/paged.dart';
import '../../catalog/domain/catalog.dart';

/// One page of the favourites: the products, sold ones first, and how many
/// favourites in the whole list are no longer sold (`DL-129`).
final class FavoritesPage {
  const FavoritesPage({required this.products, required this.unavailable});

  final Paged<CatalogProduct> products;
  final int unavailable;
}

/// The Customer's favourites (`docs/09-api-contracts.md` section 58), on the
/// Customer session. Every method throws an `ApiFailure`.
abstract interface class FavoritesRepository {
  /// One page of the list in [sort]; the server puts the not-sold favourites
  /// after the sold ones whatever the order.
  Future<FavoritesPage> list({required ProductSort sort, required int page});

  /// Adds the product; adding one already there is not an error.
  Future<void> add(String productId);

  /// Removes the product; removing one not there is not an error.
  Future<void> remove(String productId);

  /// Removes every favourite that is no longer sold, in one call.
  Future<void> removeNotSold();
}
