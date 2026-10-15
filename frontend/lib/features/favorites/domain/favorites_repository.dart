import '../../../core/network/paged.dart';
import 'favorites.dart';

/// The Customer's favourites (`docs/09-api-contracts.md` section 14), on the
/// Customer session. Every method throws an `ApiFailure`.
abstract interface class FavoritesRepository {
  Future<Paged<FavoriteProduct>> list({required int page});

  /// Adds the product; adding one already there is not an error.
  Future<void> add(String productId);

  /// Removes the product; removing one not there is not an error.
  Future<void> remove(String productId);
}
