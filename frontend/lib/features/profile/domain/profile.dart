/// The Customer's profile as `docs/09-api-contracts.md` section 12 shows it.
final class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.phone,
    required this.fullName,
  });

  final String id;
  final String phone;
  final String? fullName;
}

/// `GET|PATCH /customer/profile` on the Customer session. The language is
/// reported by the language switch through `PATCH /auth/me`, so the profile
/// changes only the name here. Every method throws an `ApiFailure`.
abstract interface class ProfileRepository {
  Future<CustomerProfile> profile();

  /// Renames the Customer; an unchanged name is not sent, and [profile]
  /// is answered as it is.
  Future<CustomerProfile> rename(CustomerProfile profile, String fullName);
}
