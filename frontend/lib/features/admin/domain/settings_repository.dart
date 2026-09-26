import 'business_settings.dart';

/// The settings operations the panel needs (`docs/09-api-contracts.md`
/// section 44), on the staff session. Every method throws an `ApiFailure`.
abstract interface class SettingsRepository {
  Future<BusinessSettings> businessSettings();

  /// Saves what [draft] changed from [base], the settings the form was
  /// loaded with.
  Future<BusinessSettings> saveBusinessSettings(
    BusinessSettingsDraft draft,
    BusinessSettings base,
  );

  Future<List<PaymentProviderSetting>> paymentProviders();

  Future<PaymentProviderSetting> setPaymentProviderEnabled(
    PaymentProvider provider, {
    required bool enabled,
  });
}
