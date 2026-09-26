import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/storage/token_store.dart';
import '../domain/business_settings.dart';
import 'settings_dto.dart';

/// The data source for `docs/09-api-contracts.md` section 44. The panel is a
/// staff surface, so every request goes on the staff session whatever mode
/// is active. Transport failures leave as `DioException` and are mapped by
/// the repository.
class SettingsApi {
  SettingsApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);

  Future<BusinessSettings> businessSettings() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/admin/settings/business',
      options: _staff,
    );
    return SettingsDto.parseBusinessSettings(ApiEnvelope.unwrap(response.data));
  }

  Future<BusinessSettings> saveBusinessSettings(
    BusinessSettingsDraft draft,
    BusinessSettings base,
  ) async {
    final Response<dynamic> response = await _dio.patch<dynamic>(
      '/admin/settings/business',
      data: SettingsDto.businessSettingsBody(draft, base),
      options: _staff,
    );
    return SettingsDto.parseBusinessSettings(ApiEnvelope.unwrap(response.data));
  }

  Future<List<PaymentProviderSetting>> paymentProviders() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/admin/settings/payment-providers',
      options: _staff,
    );
    return SettingsDto.parsePaymentProviders(ApiEnvelope.unwrap(response.data));
  }

  Future<PaymentProviderSetting> setPaymentProviderEnabled(
    PaymentProvider provider, {
    required bool enabled,
  }) async {
    final Response<dynamic> response = await _dio.patch<dynamic>(
      '/admin/settings/payment-providers/${provider.code}',
      data: <String, bool>{'is_enabled': enabled},
      options: _staff,
    );
    final PaymentProviderSetting setting = SettingsDto.parsePaymentProvider(
      ApiEnvelope.unwrap(response.data),
    );
    if (setting.provider != provider) {
      throw FormatException(
        'asked to switch ${provider.code}, answered for ${setting.provider.code}',
      );
    }
    return setting;
  }
}
