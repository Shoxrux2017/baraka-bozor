import 'addresses.dart';

/// Finds on the map an address the Customer typed in words
/// (`docs/09-api-contracts.md` section 13). It only gives a point to look
/// at; nothing the provider says is kept (`DL-84` (2)).
abstract interface class AddressSearchRepository {
  /// The point of [query], or `null` when nothing was found. Throws an
  /// `ApiFailure`: `provider_unavailable`, `rate_limited`, or the network.
  Future<GeoPoint?> locate(String query);
}
