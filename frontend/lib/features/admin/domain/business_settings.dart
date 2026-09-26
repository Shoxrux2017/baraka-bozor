/// How the service fee is charged (`docs/08-database.md` section 11). The
/// machine value is what the API carries; labels come from the localized
/// strings.
enum ServiceFeeMode {
  fixed('fixed'),
  percentage('percentage');

  const ServiceFeeMode(this.code);

  final String code;

  static ServiceFeeMode? tryParse(String code) {
    for (final ServiceFeeMode mode in values) {
      if (mode.code == code) {
        return mode;
      }
    }
    return null;
  }
}

/// The business settings as `docs/09-api-contracts.md` section 44 carries
/// them. Percentages, coordinates and the radius stay the decimal strings the
/// API sends — the client never does arithmetic on them — and money is whole
/// UZS. A `null` is a value that is not set.
final class BusinessSettings {
  const BusinessSettings({
    required this.markupPercent,
    required this.serviceFeeMode,
    required this.serviceFeeFixedUzs,
    required this.serviceFeePercent,
    required this.deliveryFeeUzs,
    required this.minimumOrderUzs,
    required this.priceTolerancePercent,
    required this.opensAt,
    required this.closesAt,
    required this.serviceCentreLatitude,
    required this.serviceCentreLongitude,
    required this.serviceRadiusKm,
    required this.deliveryDelayThresholdMinutes,
    required this.updatedAt,
  });

  final String markupPercent;
  final ServiceFeeMode serviceFeeMode;
  final int? serviceFeeFixedUzs;
  final String? serviceFeePercent;
  final int? deliveryFeeUzs;
  final int? minimumOrderUzs;
  final String priceTolerancePercent;

  /// `HH:MM` in `Asia/Tashkent`.
  final String? opensAt;
  final String? closesAt;

  final String? serviceCentreLatitude;
  final String? serviceCentreLongitude;
  final String? serviceRadiusKm;
  final int deliveryDelayThresholdMinutes;
  final DateTime updatedAt;
}

/// The settings as the form submits them. Only what differs from the
/// settings the form was loaded with is sent (`DL-27` (3)), so two Admins
/// editing different settings at once do not undo each other.
final class BusinessSettingsDraft {
  const BusinessSettingsDraft({
    required this.markupPercent,
    required this.serviceFeeMode,
    required this.serviceFeeFixedUzs,
    required this.serviceFeePercent,
    required this.deliveryFeeUzs,
    required this.minimumOrderUzs,
    required this.priceTolerancePercent,
    required this.opensAt,
    required this.closesAt,
    required this.serviceCentreLatitude,
    required this.serviceCentreLongitude,
    required this.serviceRadiusKm,
    required this.deliveryDelayThresholdMinutes,
  });

  /// The draft of settings nobody has edited: what the form started from.
  factory BusinessSettingsDraft.fromSettings(BusinessSettings settings) =>
      BusinessSettingsDraft(
        markupPercent: settings.markupPercent,
        serviceFeeMode: settings.serviceFeeMode,
        serviceFeeFixedUzs: settings.serviceFeeFixedUzs,
        serviceFeePercent: settings.serviceFeePercent,
        deliveryFeeUzs: settings.deliveryFeeUzs,
        minimumOrderUzs: settings.minimumOrderUzs,
        priceTolerancePercent: settings.priceTolerancePercent,
        opensAt: settings.opensAt,
        closesAt: settings.closesAt,
        serviceCentreLatitude: settings.serviceCentreLatitude,
        serviceCentreLongitude: settings.serviceCentreLongitude,
        serviceRadiusKm: settings.serviceRadiusKm,
        deliveryDelayThresholdMinutes: settings.deliveryDelayThresholdMinutes,
      );

  final String markupPercent;
  final ServiceFeeMode serviceFeeMode;
  final int? serviceFeeFixedUzs;
  final String? serviceFeePercent;
  final int? deliveryFeeUzs;
  final int? minimumOrderUzs;
  final String priceTolerancePercent;
  final String? opensAt;
  final String? closesAt;
  final String? serviceCentreLatitude;
  final String? serviceCentreLongitude;
  final String? serviceRadiusKm;
  final int deliveryDelayThresholdMinutes;

  List<Object?> get _values => <Object?>[
    markupPercent,
    serviceFeeMode,
    serviceFeeFixedUzs,
    serviceFeePercent,
    deliveryFeeUzs,
    minimumOrderUzs,
    priceTolerancePercent,
    opensAt,
    closesAt,
    serviceCentreLatitude,
    serviceCentreLongitude,
    serviceRadiusKm,
    deliveryDelayThresholdMinutes,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! BusinessSettingsDraft) {
      return false;
    }
    final List<Object?> mine = _values;
    final List<Object?> theirs = other._values;
    for (int i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_values);
}

/// The four online payment providers, in the order the API lists them.
enum PaymentProvider {
  payme('payme', 'Payme'),
  click('click', 'Click'),
  paynet('paynet', 'Paynet'),
  xazna('xazna', 'xazna');

  const PaymentProvider(this.code, this.brand);

  final String code;

  /// The provider's own name, which is not translated.
  final String brand;

  static PaymentProvider? tryParse(String code) {
    for (final PaymentProvider provider in values) {
      if (provider.code == code) {
        return provider;
      }
    }
    return null;
  }
}

final class PaymentProviderSetting {
  const PaymentProviderSetting({
    required this.provider,
    required this.isEnabled,
    required this.updatedAt,
  });

  final PaymentProvider provider;
  final bool isEnabled;
  final DateTime updatedAt;
}
