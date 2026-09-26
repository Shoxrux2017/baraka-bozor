/// A point on the map as the API carries it: two decimal strings of at most
/// six decimals (`docs/09-api-contracts.md` section 13).
final class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  /// The point a map gives as numbers, written with six decimals, which
  /// is about ten centimetres — as precise as the column keeps.
  factory GeoPoint.fromDegrees(double latitude, double longitude) => GeoPoint(
    latitude: latitude.toStringAsFixed(6),
    longitude: longitude.toStringAsFixed(6),
  );

  final String latitude;
  final String longitude;

  double get latitudeDegrees => double.parse(latitude);
  double get longitudeDegrees => double.parse(longitude);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// One of the Customer's delivery addresses.
final class Address {
  const Address({
    required this.id,
    required this.label,
    required this.point,
    required this.street,
    required this.house,
    required this.apartment,
    required this.landmark,
    required this.deliveryNote,
  });

  final String id;
  final String? label;
  final GeoPoint point;
  final String street;
  final String house;
  final String? apartment;
  final String? landmark;
  final String? deliveryNote;
}

/// An address as its form submits it.
final class AddressDraft {
  /// What [address] holds, as its form starts.
  factory AddressDraft.fromAddress(Address address) => AddressDraft(
    label: address.label,
    point: address.point,
    street: address.street,
    house: address.house,
    apartment: address.apartment,
    landmark: address.landmark,
    deliveryNote: address.deliveryNote,
  );

  const AddressDraft({
    required this.label,
    required this.point,
    required this.street,
    required this.house,
    required this.apartment,
    required this.landmark,
    required this.deliveryNote,
  });

  final String? label;
  final GeoPoint point;
  final String street;
  final String house;
  final String? apartment;
  final String? landmark;
  final String? deliveryNote;

  /// Whether [address] holds exactly this: an edit that changes nothing.
  bool sameAs(Address address) =>
      label == address.label &&
      point == address.point &&
      street == address.street &&
      house == address.house &&
      apartment == address.apartment &&
      landmark == address.landmark &&
      deliveryNote == address.deliveryNote;
}

/// The Customer's addresses (`docs/09` section 13), on the Customer
/// session. Every method throws an `ApiFailure`.
abstract interface class AddressesRepository {
  /// Every active address, page after page; a Customer keeps few, so
  /// usually one page of 100.
  Future<List<Address>> addresses();

  Future<Address> create(AddressDraft draft);

  /// Saves what [draft] changed from [address]; with nothing changed,
  /// nothing is sent and [address] is answered as it is.
  Future<Address> update(Address address, AddressDraft draft);

  /// Deactivates the address (`DL-17` (6)).
  Future<void> remove(String id);
}
