import 'business_settings.dart';

/// The settings operations the panel needs (`docs/09-api-contracts.md`
/// section 44), on the staff session. Every method throws an `ApiFailure`.
abstract interface class SettingsRepository {
  Future<BusinessSettings> businessSettings();

  Future<BusinessSettings> saveBusinessSettings(BusinessSettingsDraft draft);

  Future<List<PaymentProviderSetting>> paymentProviders();

  Future<PaymentProviderSetting> setPaymentProviderEnabled(
    PaymentProvider provider, {
    required bool enabled,
  });
}
