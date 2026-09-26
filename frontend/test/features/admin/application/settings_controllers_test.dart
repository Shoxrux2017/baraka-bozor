import 'dart:async';

import 'package:baraka_bozor/features/admin/application/admin_providers.dart';
import 'package:baraka_bozor/features/admin/application/business_settings_controller.dart';
import 'package:baraka_bozor/features/admin/application/payment_providers_controller.dart';
import 'package:baraka_bozor/features/admin/domain/business_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_settings_repository.dart';

/// The signed-in staff account, switchable by the test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'admin-1';

  void signIn(String? id) => state = id;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

/// `docs/07-architecture.md` section 28: an answer that belongs to an account
/// no longer signed in never lands on the state the new account sees.
void main() {
  late FakeSettingsRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeSettingsRepository();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        staffAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'a provider switch answered after another account signed in is dropped',
    () async {
      container.listen(paymentProvidersControllerProvider, (_, _) {});
      await container.read(paymentProvidersControllerProvider.future);
      final Completer<void> gate = Completer<void>();
      repository.switchGate = gate;

      final Future<void> pending = container
          .read(paymentProvidersControllerProvider.notifier)
          .setEnabled(PaymentProvider.click, enabled: true);
      expect(
        container.read(paymentProvidersControllerProvider).requireValue.busy,
        <PaymentProvider>{PaymentProvider.click},
      );

      container.read(_account.notifier).signIn('admin-2');
      final PaymentProvidersView reloaded = await container.read(
        paymentProvidersControllerProvider.future,
      );
      expect(reloaded.busy, isEmpty);

      gate.complete();
      await pending;

      final PaymentProvidersView after = container
          .read(paymentProvidersControllerProvider)
          .requireValue;
      expect(after.busy, isEmpty);
      expect(after.failure, isNull);
      expect(
        after.providers
            .singleWhere(
              (PaymentProviderSetting s) => s.provider == PaymentProvider.click,
            )
            .isEnabled,
        isFalse,
        reason: 'the reloaded list is what the new account was shown',
      );
    },
  );

  test('a save answered after another account signed in does not replace its settings', () async {
    container.listen(businessSettingsControllerProvider, (_, _) {});
    container.listen(saveBusinessSettingsControllerProvider, (_, _) {});
    await container.read(businessSettingsControllerProvider.future);
    final Completer<void> gate = Completer<void>();
    repository.saveGate = gate;
    repository.onSave = (BusinessSettingsDraft draft) => settings(
      markupPercent: '99.00',
      updatedAt: DateTime.utc(2026, 9, 26, 9),
    );

    final Future<bool> pending = container
        .read(saveBusinessSettingsControllerProvider.notifier)
        .save(
          const BusinessSettingsDraft(
            markupPercent: '99',
            serviceFeeMode: ServiceFeeMode.fixed,
            serviceFeeFixedUzs: null,
            serviceFeePercent: null,
            deliveryFeeUzs: null,
            minimumOrderUzs: null,
            priceTolerancePercent: '10.00',
            opensAt: null,
            closesAt: null,
            serviceCentreLatitude: null,
            serviceCentreLongitude: null,
            serviceRadiusKm: null,
            deliveryDelayThresholdMinutes: 30,
          ),
        );

    container.read(_account.notifier).signIn('admin-2');
    final BusinessSettings reloaded = await container.read(
      businessSettingsControllerProvider.future,
    );
    expect(reloaded.markupPercent, '15.00');

    gate.complete();
    await pending;

    expect(
      container
          .read(businessSettingsControllerProvider)
          .requireValue
          .markupPercent,
      '15.00',
    );
  });

  test('a save for the same account shows what the server stored', () async {
    container.listen(businessSettingsControllerProvider, (_, _) {});
    container.listen(saveBusinessSettingsControllerProvider, (_, _) {});
    await container.read(businessSettingsControllerProvider.future);
    repository.onSave = (BusinessSettingsDraft draft) => settings(
      markupPercent: '12.50',
      updatedAt: DateTime.utc(2026, 9, 26, 9),
    );

    final bool saved = await container
        .read(saveBusinessSettingsControllerProvider.notifier)
        .save(
          const BusinessSettingsDraft(
            markupPercent: '12.5',
            serviceFeeMode: ServiceFeeMode.fixed,
            serviceFeeFixedUzs: 5000,
            serviceFeePercent: null,
            deliveryFeeUzs: null,
            minimumOrderUzs: null,
            priceTolerancePercent: '10.00',
            opensAt: null,
            closesAt: null,
            serviceCentreLatitude: null,
            serviceCentreLongitude: null,
            serviceRadiusKm: null,
            deliveryDelayThresholdMinutes: 30,
          ),
        );

    expect(saved, isTrue);
    expect(
      container
          .read(businessSettingsControllerProvider)
          .requireValue
          .markupPercent,
      '12.50',
    );
  });
}
