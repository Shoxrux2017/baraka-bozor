import '../../../core/network/json_fields.dart';
import '../domain/business_settings.dart';

/// Strict parsing and request bodies for `docs/09-api-contracts.md`
/// section 44.
abstract final class SettingsDto {
  static BusinessSettings parseBusinessSettings(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'business settings');

    return BusinessSettings(
      markupPercent: json.string('markup_percent'),
      serviceFeeMode: json.choice('service_fee_mode', ServiceFeeMode.tryParse),
      serviceFeeFixedUzs: json.nullableInteger('service_fee_fixed_uzs'),
      serviceFeePercent: json.nullableString('service_fee_percent'),
      deliveryFeeUzs: json.nullableInteger('delivery_fee_uzs'),
      minimumOrderUzs: json.nullableInteger('minimum_order_uzs'),
      priceTolerancePercent: json.string('price_tolerance_percent'),
      opensAt: json.nullableString('opens_at'),
      closesAt: json.nullableString('closes_at'),
      serviceCentreLatitude: json.nullableString('service_centre_latitude'),
      serviceCentreLongitude: json.nullableString('service_centre_longitude'),
      serviceRadiusKm: json.nullableString('service_radius_km'),
      deliveryDelayThresholdMinutes: json.integer(
        'delivery_delay_threshold_minutes',
      ),
      updatedAt: json.instant('updated_at'),
    );
  }

  /// Every field of the form, so the saved row is exactly what the form
  /// showed. The value of the service-fee mode not chosen goes as `null`.
  static Map<String, Object?> businessSettingsBody(
    BusinessSettingsDraft draft,
  ) {
    final bool fixed = draft.serviceFeeMode == ServiceFeeMode.fixed;

    return <String, Object?>{
      'markup_percent': draft.markupPercent,
      'service_fee_mode': draft.serviceFeeMode.code,
      'service_fee_fixed_uzs': fixed ? draft.serviceFeeFixedUzs : null,
      'service_fee_percent': fixed ? null : draft.serviceFeePercent,
      'delivery_fee_uzs': draft.deliveryFeeUzs,
      'minimum_order_uzs': draft.minimumOrderUzs,
      'price_tolerance_percent': draft.priceTolerancePercent,
      'opens_at': draft.opensAt,
      'closes_at': draft.closesAt,
      'service_centre_latitude': draft.serviceCentreLatitude,
      'service_centre_longitude': draft.serviceCentreLongitude,
      'service_radius_km': draft.serviceRadiusKm,
      'delivery_delay_threshold_minutes': draft.deliveryDelayThresholdMinutes,
    };
  }

  static PaymentProviderSetting parsePaymentProvider(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'payment provider');

    return PaymentProviderSetting(
      provider: json.choice('provider', PaymentProvider.tryParse),
      isEnabled: json.boolean('is_enabled'),
      updatedAt: json.instant('updated_at'),
    );
  }

  /// The collection of section 44: exactly the four providers, each once.
  static List<PaymentProviderSetting> parsePaymentProviders(Object? raw) {
    if (raw is! List<dynamic>) {
      throw FormatException(
        'payment providers is not a list: ${raw.runtimeType}',
      );
    }

    final List<PaymentProviderSetting> providers = raw
        .map(parsePaymentProvider)
        .toList(growable: false);
    final Set<PaymentProvider> seen = providers
        .map((PaymentProviderSetting setting) => setting.provider)
        .toSet();

    if (providers.length != PaymentProvider.values.length ||
        seen.length != providers.length) {
      throw const FormatException(
        'payment providers are not the four providers, each once',
      );
    }

    return providers;
  }
}
