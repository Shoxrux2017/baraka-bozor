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
    final List<Address> all = <Address>[];
    for (int page = 1; ; page++) {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/customer/addresses',
        queryParameters: <String, Object>{'page': page, 'per_page': 100},
        options: _customer,
      );
      final Paged<Address> answer = Paged.parse(response.data, parse);
      if (answer.page != page) {
        throw const FormatException('the page does not match the request');
      }
      all.addAll(answer.items);
      if (!answer.hasNext) {
        return all;
      }
    }
  });

  @override
  Future<Address> create(AddressDraft draft) => guardApiCall(() async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/addresses',
      data: body(draft),
      options: _customer,
    );
    return _matching(parse(ApiEnvelope.unwrap(response.data)), draft);
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
        final Address saved = _matching(
          parse(ApiEnvelope.unwrap(response.data)),
          draft,
        );
        if (saved.id != address.id) {
          throw const FormatException('the address does not match the request');
        }
        return saved;
      });

  /// [saved] when it holds what [draft] sent; an answer about something
  /// else is malformed (`DL-27` (6)).
  static Address _matching(Address saved, AddressDraft draft) {
    if (!draft.sameAs(saved)) {
      throw const FormatException('the address does not match the request');
    }
    return saved;
  }

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
      deliveryNote: _read(json),
    );
  }

  /// The last member the address carries, read with the two times the
  /// contract also names.
  static String? _read(JsonFields json) {
    json
      ..instant('created_at')
      ..instant('updated_at');
    return json.nullableString('delivery_note');
  }
}
