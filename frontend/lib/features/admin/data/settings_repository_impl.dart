import '../../../core/network/api_call.dart';
import '../domain/business_settings.dart';
import '../domain/settings_repository.dart';
import 'settings_api.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._api);

  final SettingsApi _api;

  @override
  Future<BusinessSettings> businessSettings() =>
      guardApiCall(_api.businessSettings);

  @override
  Future<BusinessSettings> saveBusinessSettings(BusinessSettingsDraft draft) =>
      guardApiCall(() => _api.saveBusinessSettings(draft));

  @override
  Future<List<PaymentProviderSetting>> paymentProviders() =>
      guardApiCall(_api.paymentProviders);

  @override
  Future<PaymentProviderSetting> setPaymentProviderEnabled(
    PaymentProvider provider, {
    required bool enabled,
  }) => guardApiCall(
    () => _api.setPaymentProviderEnabled(provider, enabled: enabled),
  );
}
