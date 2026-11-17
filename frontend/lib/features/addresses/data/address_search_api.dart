import 'package:dio/dio.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/json_fields.dart';
import '../../../core/storage/token_store.dart';
import '../domain/address_search.dart';
import '../domain/addresses.dart';

/// `POST /customer/address-search` on the Customer session.
class AddressSearchRepositoryImpl implements AddressSearchRepository {
  AddressSearchRepositoryImpl(this._dio);

  final Dio _dio;

  static final Options _customer = RequestSlot.of(SessionSlot.customer);
  static final RegExp _latitude = RegExp(r'^-?\d{1,2}\.\d{6}$');
  static final RegExp _radius = RegExp(r'^\d{1,4}(\.\d{1,2})?$');
  static final RegExp _longitude = RegExp(r'^-?\d{1,3}\.\d{6}$');

  @override
  Future<GeoPoint?> locate(String query) => guardApiCall(() async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/customer/address-search',
      data: <String, Object?>{'query': query},
      options: _customer,
    );
    return parse(ApiEnvelope.unwrap(response.data));
  });

  @override
  Future<PointAddress?> addressAt(GeoPoint point, {required String language}) =>
      guardApiCall(() async {
        final Response<dynamic> response = await _dio.post<dynamic>(
          '/customer/address-search/reverse',
          data: <String, Object?>{
            'latitude': point.latitude,
            'longitude': point.longitude,
            'language': language,
          },
          options: _customer,
        );
        return _parseAddress(ApiEnvelope.unwrap(response.data));
      });

  @override
  Future<ServiceArea?> serviceArea() => guardApiCall(() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/customer/service-area',
      options: _customer,
    );
    return _parseArea(ApiEnvelope.unwrap(response.data));
  });

  static PointAddress? _parseAddress(Object? raw) {
    if (raw == null) {
      return null;
    }
    final JsonFields json = JsonFields.of(raw, 'point address');
    final String line = json.string('line');
    if (line.length > 160) {
      throw const FormatException('address line off the contract');
    }
    return PointAddress(line: line, houseKnown: json.boolean('house_known'));
  }

  static ServiceArea? _parseArea(Object? raw) {
    if (raw == null) {
      return null;
    }
    final JsonFields json = JsonFields.of(raw, 'service area');
    final GeoPoint? centre = parse(<String, Object?>{
      'latitude': json.string('latitude'),
      'longitude': json.string('longitude'),
    });
    final String radius = json.string('radius_km');
    if (!_radius.hasMatch(radius) || double.parse(radius) <= 0) {
      throw const FormatException('radius off the contract');
    }
    return ServiceArea(centre: centre!, radiusKm: radius);
  }

  /// The point, held to its contract: two six-decimal strings on the globe;
  /// `null` when the server found nothing.
  static GeoPoint? parse(Object? raw) {
    if (raw == null) {
      return null;
    }
    final JsonFields json = JsonFields.of(raw, 'address point');
    final String latitude = json.string('latitude');
    final String longitude = json.string('longitude');
    if (!_latitude.hasMatch(latitude) ||
        !_longitude.hasMatch(longitude) ||
        double.parse(latitude).abs() > 90 ||
        double.parse(longitude).abs() > 180) {
      throw const FormatException('coordinates off the contract');
    }
    return GeoPoint(latitude: latitude, longitude: longitude);
  }
}
