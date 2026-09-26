import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/network/paged.dart';
import '../../../core/storage/token_store.dart';
import '../domain/addresses.dart';

/// `/customer/addresses` (`docs/09-api-contracts.md` section 13) on the
/// Customer session, with its strict parsing.
class AddressesRepositoryImpl implements AddressesRepository {
  AddressesRepositoryImpl(this._dio);

  final Dio _dio;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);

  @override
  Future<List<Address>> addresses() => guardApiCall(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/customer/addresses',
      queryParameters: <String, Object>{'per_page': 100},
      options: _customer,
    );
    return Paged.parse(response.data, parse).items;
  });

  @override
  Future<Address> create(AddressDraft draft) => guardApiCall(() async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/addresses',
      data: body(draft),
      options: _customer,
    );
    return parse(ApiEnvelope.unwrap(response.data));
  });

  /// Only what changed, as `DL-28` (9) does for the panel, and the two
  /// coordinates always together; an unchanged point is not sent, so the
  /// server checks the area only when the pin moved (`DL-23` (3)).
  @override
  Future<Address> update(Address address, AddressDraft draft) =>
      guardApiCall(() async {
        final Map<String, Object?> changes = changed(address, draft);
        if (changes.isEmpty) {
          return address;
        }
        final Response<dynamic> response = await _dio.patch<dynamic>(
          '/customer/addresses/${Uri.encodeComponent(address.id)}',
          data: changes,
          options: _customer,
        );
        return parse(ApiEnvelope.unwrap(response.data));
      });

  @override
  Future<void> remove(String id) => guardApiCall(
    () => _dio.delete<dynamic>(
      '/customer/addresses/${Uri.encodeComponent(id)}',
      options: _customer,
    ),
  );

  static Map<String, Object?> body(AddressDraft draft) => <String, Object?>{
    'label': draft.label,
    'latitude': draft.point.latitude,
    'longitude': draft.point.longitude,
    'street': draft.street,
    'house': draft.house,
    'apartment': draft.apartment,
    'landmark': draft.landmark,
    'delivery_note': draft.deliveryNote,
  };

  /// The fields of [draft] that differ from [address].
  static Map<String, Object?> changed(Address address, AddressDraft draft) {
    final Map<String, Object?> before = body(AddressDraft.fromAddress(address));
    return <String, Object?>{
      for (final MapEntry<String, Object?> field in body(draft).entries)
        if (before[field.key] != field.value) field.key: field.value,
      // The API takes the two coordinates together or not at all.
      if (draft.point != address.point) ...<String, Object?>{
        'latitude': draft.point.latitude,
        'longitude': draft.point.longitude,
      },
    };
  }

  static final RegExp _latitude = RegExp(r'^-?\d{1,2}\.\d{6}$');
  static final RegExp _longitude = RegExp(r'^-?\d{1,3}\.\d{6}$');

  /// An address, held to its contract: a UUID id and the coordinates as
  /// six-decimal strings on the globe (`docs/09` section 13).
  static Address parse(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'address');
    final String latitude = json.string('latitude');
    final String longitude = json.string('longitude');
    if (!_latitude.hasMatch(latitude) ||
        !_longitude.hasMatch(longitude) ||
        double.parse(latitude).abs() > 90 ||
        double.parse(longitude).abs() > 180) {
      throw const FormatException('coordinates off the contract');
    }
    return Address(
      id: json.uuid('id'),
      label: json.nullableString('label'),
      point: GeoPoint(latitude: latitude, longitude: longitude),
      street: json.string('street'),
      house: json.string('house'),
      apartment: json.nullableString('apartment'),
      landmark: json.nullableString('landmark'),
      deliveryNote: json.nullableString('delivery_note'),
    );
  }
}
