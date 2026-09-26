import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/admin/domain/business_settings.dart';
import 'package:baraka_bozor/features/admin/domain/settings_repository.dart';

/// Settings as a fresh installation plus a configured service area — the
/// shape the backend returns, with every optional value set.
BusinessSettings settings({
  String markupPercent = '15.00',
  ServiceFeeMode serviceFeeMode = ServiceFeeMode.fixed,
  int? serviceFeeFixedUzs = 5000,
  String? serviceFeePercent,
  int? deliveryFeeUzs = 15000,
  int? minimumOrderUzs = 100000,
  String priceTolerancePercent = '10.00',
  String? opensAt = '09:00',
  String? closesAt = '21:00',
  String? serviceCentreLatitude = '41.311081',
  String? serviceCentreLongitude = '69.240562',
  String? serviceRadiusKm = '5.00',
  int deliveryDelayThresholdMinutes = 30,
  DateTime? updatedAt,
}) {
  return BusinessSettings(
    markupPercent: markupPercent,
    serviceFeeMode: serviceFeeMode,
    serviceFeeFixedUzs: serviceFeeFixedUzs,
    serviceFeePercent: serviceFeePercent,
    deliveryFeeUzs: deliveryFeeUzs,
    minimumOrderUzs: minimumOrderUzs,
    priceTolerancePercent: priceTolerancePercent,
    opensAt: opensAt,
    closesAt: closesAt,
    serviceCentreLatitude: serviceCentreLatitude,
    serviceCentreLongitude: serviceCentreLongitude,
    serviceRadiusKm: serviceRadiusKm,
    deliveryDelayThresholdMinutes: deliveryDelayThresholdMinutes,
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 26, 5),
  );
}

List<PaymentProviderSetting> providers({
  Set<PaymentProvider> enabled = const <PaymentProvider>{},
}) => <PaymentProviderSetting>[
  for (final PaymentProvider provider in PaymentProvider.values)
    PaymentProviderSetting(
      provider: provider,
      isEnabled: enabled.contains(provider),
      updatedAt: DateTime.utc(2026, 9, 26, 5),
    ),
];

/// A settings repository that answers from memory. A save answers with what
/// [onSave] makes of the draft — by default the draft stored as it was sent —
/// or with the next queued failure.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    BusinessSettings? current,
    List<PaymentProviderSetting>? providerSettings,
  }) : current = current ?? settings(),
       providerSettings = providerSettings ?? providers();

  BusinessSettings current;
  List<PaymentProviderSetting> providerSettings;

  final List<BusinessSettingsDraft> saved = <BusinessSettingsDraft>[];

  /// The settings each save was made against.
  final List<BusinessSettings> bases = <BusinessSettings>[];
  final List<(PaymentProvider, bool)> switched = <(PaymentProvider, bool)>[];

  ApiFailure? loadFailure;
  ApiFailure? saveFailure;
  ApiFailure? switchFailure;

  /// When set, a switch waits for it before answering.
  Completer<void>? switchGate;

  /// When set, a save waits for it before answering.
  Completer<void>? saveGate;

  int loads = 0;

  BusinessSettings Function(BusinessSettingsDraft draft)? onSave;

  @override
  Future<BusinessSettings> businessSettings() async {
    loads++;
    final ApiFailure? failure = loadFailure;
    if (failure != null) {
      throw failure;
    }
    return current;
  }

  @override
  Future<BusinessSettings> saveBusinessSettings(
    BusinessSettingsDraft draft,
    BusinessSettings base,
  ) async {
    saved.add(draft);
    bases.add(base);
    await saveGate?.future;
    final ApiFailure? failure = saveFailure;
    if (failure != null) {
      saveFailure = null;
      throw failure;
    }
    current = onSave?.call(draft) ?? _stored(draft);
    return current;
  }

  @override
  Future<List<PaymentProviderSetting>> paymentProviders() async =>
      providerSettings;

  @override
  Future<PaymentProviderSetting> setPaymentProviderEnabled(
    PaymentProvider provider, {
    required bool enabled,
  }) async {
    switched.add((provider, enabled));
    await switchGate?.future;
    final ApiFailure? failure = switchFailure;
    if (failure != null) {
      switchFailure = null;
      throw failure;
    }
    final PaymentProviderSetting setting = PaymentProviderSetting(
      provider: provider,
      isEnabled: enabled,
      updatedAt: DateTime.utc(2026, 9, 26, 6),
    );
    providerSettings = <PaymentProviderSetting>[
      for (final PaymentProviderSetting other in providerSettings)
        other.provider == provider ? setting : other,
    ];
    return setting;
  }

  static BusinessSettings _stored(BusinessSettingsDraft draft) => settings(
    markupPercent: draft.markupPercent,
    serviceFeeMode: draft.serviceFeeMode,
    serviceFeeFixedUzs: draft.serviceFeeFixedUzs,
    serviceFeePercent: draft.serviceFeePercent,
    deliveryFeeUzs: draft.deliveryFeeUzs,
    minimumOrderUzs: draft.minimumOrderUzs,
    priceTolerancePercent: draft.priceTolerancePercent,
    opensAt: draft.opensAt,
    closesAt: draft.closesAt,
    serviceCentreLatitude: draft.serviceCentreLatitude,
    serviceCentreLongitude: draft.serviceCentreLongitude,
    serviceRadiusKm: draft.serviceRadiusKm,
    deliveryDelayThresholdMinutes: draft.deliveryDelayThresholdMinutes,
    updatedAt: DateTime.utc(2026, 9, 26, 6),
  );
}
