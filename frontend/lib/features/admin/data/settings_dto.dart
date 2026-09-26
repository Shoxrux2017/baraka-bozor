import '../../../core/network/json_fields.dart';
import '../domain/business_settings.dart';

/// Strict parsing and request bodies for `docs/09-api-contracts.md`
/// section 44.
abstract final class SettingsDto {
  static final RegExp _percent = RegExp(r'^\d{1,3}(\.\d{1,2})?$');
  static final RegExp _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final RegExp _latitude = RegExp(r'^-?\d{1,2}(\.\d{1,6})?$');
  static final RegExp _longitude = RegExp(r'^-?\d{1,3}(\.\d{1,6})?$');
  static final RegExp _radius = RegExp(r'^\d{1,4}(\.\d{1,2})?$');

  /// The settings, their values in the shapes the contract gives them and
  /// its invariants holding: the value of the fee mode not chosen is `null`,
  /// and working hours and the centre come in pairs. A payload that breaks
  /// one is a failure, never a form the Admin would have to repair.
  static BusinessSettings parseBusinessSettings(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'business settings');

    final BusinessSettings settings = BusinessSettings(
      markupPercent: _shaped(
        json.string('markup_percent'),
        _percent,
        'markup_percent',
      ),
      serviceFeeMode: json.choice('service_fee_mode', ServiceFeeMode.tryParse),
      serviceFeeFixedUzs: json.nullableInteger('service_fee_fixed_uzs'),
      serviceFeePercent: _shapedOrNull(
        json.nullableString('service_fee_percent'),
        _percent,
        'service_fee_percent',
      ),
      deliveryFeeUzs: json.nullableInteger('delivery_fee_uzs'),
      minimumOrderUzs: json.nullableInteger('minimum_order_uzs'),
      priceTolerancePercent: _shaped(
        json.string('price_tolerance_percent'),
        _percent,
        'price_tolerance_percent',
      ),
      opensAt: _shapedOrNull(
        json.nullableString('opens_at'),
        _time,
        'opens_at',
      ),
      closesAt: _shapedOrNull(
        json.nullableString('closes_at'),
        _time,
        'closes_at',
      ),
      serviceCentreLatitude: _shapedOrNull(
        json.nullableString('service_centre_latitude'),
        _latitude,
        'service_centre_latitude',
      ),
      serviceCentreLongitude: _shapedOrNull(
        json.nullableString('service_centre_longitude'),
        _longitude,
        'service_centre_longitude',
      ),
      serviceRadiusKm: _shapedOrNull(
        json.nullableString('service_radius_km'),
        _radius,
        'service_radius_km',
      ),
      deliveryDelayThresholdMinutes: json.integer(
        'delivery_delay_threshold_minutes',
      ),
      updatedAt: json.instant('updated_at'),
    );

    final bool fixed = settings.serviceFeeMode == ServiceFeeMode.fixed;
    if ((fixed && settings.serviceFeePercent != null) ||
        (!fixed && settings.serviceFeeFixedUzs != null)) {
      throw const FormatException(
        'a service-fee value is set for the mode not chosen',
      );
    }
    if ((settings.opensAt == null) != (settings.closesAt == null) ||
        (settings.serviceCentreLatitude == null) !=
            (settings.serviceCentreLongitude == null)) {
      throw const FormatException('half of a pair is set');
    }

    return settings;
  }

  /// The fields of [draft] that differ from [base], the settings the form
  /// was loaded with: an Admin saves what they changed, and a setting another
  /// Admin changed in the meantime stays as that Admin left it. A change of
  /// fee mode carries both fee values, the one not chosen as `null`.
  static Map<String, Object?> businessSettingsBody(
    BusinessSettingsDraft draft,
    BusinessSettings base,
  ) {
    final Map<String, Object?> after = _fields(draft);
    final Map<String, Object?> before = _fields(
      BusinessSettingsDraft.fromSettings(base),
    );

    return <String, Object?>{
      for (final MapEntry<String, Object?> field in after.entries)
        if (field.value != before[field.key]) field.key: field.value,
    };
  }

  static Map<String, Object?> _fields(BusinessSettingsDraft draft) {
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

  static String _shaped(String value, RegExp shape, String key) {
    if (!shape.hasMatch(value)) {
      throw FormatException('$key is not in its contract shape: $value');
    }
    return value;
  }

  static String? _shapedOrNull(String? value, RegExp shape, String key) =>
      value == null ? null : _shaped(value, shape, key);
}
