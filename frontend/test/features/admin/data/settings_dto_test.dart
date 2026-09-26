import 'package:baraka_bozor/features/admin/data/settings_dto.dart';
import 'package:baraka_bozor/features/admin/domain/business_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/settings_json.dart';

void main() {
  group('business settings', () {
    test('parse every field as the API sends it', () {
      final BusinessSettings settings = SettingsDto.parseBusinessSettings(
        businessJson(),
      );

      expect(settings.markupPercent, '15.00');
      expect(settings.serviceFeeMode, ServiceFeeMode.fixed);
      expect(settings.serviceFeeFixedUzs, 5000);
      expect(settings.serviceFeePercent, isNull);
      expect(settings.deliveryFeeUzs, 15000);
      expect(settings.minimumOrderUzs, 100000);
      expect(settings.priceTolerancePercent, '10.00');
      expect(settings.opensAt, '09:00');
      expect(settings.closesAt, '21:00');
      expect(settings.serviceCentreLatitude, '41.311081');
      expect(settings.serviceCentreLongitude, '69.240562');
      expect(settings.serviceRadiusKm, '5.00');
      expect(settings.deliveryDelayThresholdMinutes, 30);
      expect(settings.updatedAt, DateTime.utc(2026, 9, 26, 5));
    });

    test('parse a fresh installation with every optional value unset', () {
      final BusinessSettings settings = SettingsDto.parseBusinessSettings(
        <String, dynamic>{
          ...businessJson(),
          'service_fee_mode': 'percentage',
          'service_fee_fixed_uzs': null,
          'service_fee_percent': null,
          'delivery_fee_uzs': null,
          'minimum_order_uzs': null,
          'opens_at': null,
          'closes_at': null,
          'service_centre_latitude': null,
          'service_centre_longitude': null,
          'service_radius_km': null,
        },
      );

      expect(settings.serviceFeeMode, ServiceFeeMode.percentage);
      expect(settings.deliveryFeeUzs, isNull);
      expect(settings.opensAt, isNull);
      expect(settings.serviceRadiusKm, isNull);
    });

    test('refuse a payload that breaks the contract', () {
      final List<Map<String, dynamic>> broken = <Map<String, dynamic>>[
        <String, dynamic>{...businessJson()}..remove('delivery_fee_uzs'),
        <String, dynamic>{...businessJson(), 'markup_percent': 15},
        <String, dynamic>{...businessJson(), 'markup_percent': null},
        <String, dynamic>{...businessJson(), 'service_fee_mode': 'free'},
        <String, dynamic>{...businessJson(), 'minimum_order_uzs': '100000'},
        <String, dynamic>{...businessJson(), 'opens_at': ''},
        <String, dynamic>{
          ...businessJson(),
          'updated_at': '2026-09-26T10:00:00+05:00',
        },
        <String, dynamic>{...businessJson(), 'updated_at': 'yesterday'},
      ];

      for (final Map<String, dynamic> json in broken) {
        expect(
          () => SettingsDto.parseBusinessSettings(json),
          throwsFormatException,
          reason: '$json',
        );
      }
      expect(
        () => SettingsDto.parseBusinessSettings(<dynamic>[]),
        throwsFormatException,
      );
    });

    test('the body carries only what changed from the settings loaded', () {
      final BusinessSettings base = SettingsDto.parseBusinessSettings(
        businessJson(),
      );

      expect(
        SettingsDto.businessSettingsBody(
          BusinessSettingsDraft.fromSettings(base),
          base,
        ),
        isEmpty,
      );

      BusinessSettingsDraft edit({
        String markup = '15.00',
        ServiceFeeMode mode = ServiceFeeMode.fixed,
        int? fixed = 5000,
        String? percent,
        String? opensAt = '09:00',
      }) => BusinessSettingsDraft(
        markupPercent: markup,
        serviceFeeMode: mode,
        serviceFeeFixedUzs: fixed,
        serviceFeePercent: percent,
        deliveryFeeUzs: 15000,
        minimumOrderUzs: 100000,
        priceTolerancePercent: '10.00',
        opensAt: opensAt,
        closesAt: '21:00',
        serviceCentreLatitude: '41.311081',
        serviceCentreLongitude: '69.240562',
        serviceRadiusKm: '5.00',
        deliveryDelayThresholdMinutes: 30,
      );

      expect(
        SettingsDto.businessSettingsBody(edit(markup: '12.5'), base),
        <String, Object?>{'markup_percent': '12.5'},
      );
      expect(
        SettingsDto.businessSettingsBody(edit(fixed: 7000), base),
        <String, Object?>{'service_fee_fixed_uzs': 7000},
      );
      expect(
        SettingsDto.businessSettingsBody(
          edit(mode: ServiceFeeMode.percentage, fixed: null, percent: '2.5'),
          base,
        ),
        <String, Object?>{
          'service_fee_mode': 'percentage',
          'service_fee_fixed_uzs': null,
          'service_fee_percent': '2.5',
        },
      );
      expect(
        SettingsDto.businessSettingsBody(edit(opensAt: null), base),
        <String, Object?>{'opens_at': null},
      );
    });

    test(
      'values out of their contract shape, or broken invariants, are refused',
      () {
        for (final Map<String, dynamic> json in <Map<String, dynamic>>[
          <String, dynamic>{...businessJson(), 'opens_at': '09:00:00'},
          <String, dynamic>{...businessJson(), 'markup_percent': '15.001'},
          <String, dynamic>{...businessJson(), 'service_radius_km': 'five'},
          <String, dynamic>{
            ...businessJson(),
            'service_centre_latitude': '41,3',
          },
          <String, dynamic>{...businessJson(), 'service_fee_percent': '2.00'},
          <String, dynamic>{...businessJson(), 'closes_at': null},
          <String, dynamic>{
            ...businessJson(),
            'service_centre_longitude': null,
          },
        ]) {
          expect(
            () => SettingsDto.parseBusinessSettings(json),
            throwsFormatException,
            reason: json.toString(),
          );
        }
      },
    );
  });

  group('payment providers', () {
    test('parse the four providers in order', () {
      final List<PaymentProviderSetting> parsed =
          SettingsDto.parsePaymentProviders(<dynamic>[
            providerJson('payme', enabled: true),
            providerJson('click'),
            providerJson('paynet'),
            providerJson('xazna'),
          ]);

      expect(
        parsed.map((PaymentProviderSetting s) => s.provider),
        PaymentProvider.values,
      );
      expect(parsed.first.isEnabled, isTrue);
      expect(parsed.last.isEnabled, isFalse);
    });

    test('refuse a list that is not the four providers once each', () {
      for (final List<dynamic> list in <List<dynamic>>[
        <dynamic>[
          providerJson('payme'),
          providerJson('click'),
          providerJson('paynet'),
        ],
        <dynamic>[
          providerJson('payme'),
          providerJson('payme'),
          providerJson('paynet'),
          providerJson('xazna'),
        ],
        <dynamic>[
          providerJson('payme'),
          providerJson('click'),
          providerJson('paynet'),
          providerJson('uzcard'),
        ],
        <dynamic>[
          providerJson('payme'),
          providerJson('click'),
          providerJson('paynet'),
          <String, dynamic>{...providerJson('xazna'), 'is_enabled': 'yes'},
        ],
      ]) {
        expect(
          () => SettingsDto.parsePaymentProviders(list),
          throwsFormatException,
        );
      }
      expect(
        () => SettingsDto.parsePaymentProviders(providerJson('payme')),
        throwsFormatException,
      );
    });
  });
}
