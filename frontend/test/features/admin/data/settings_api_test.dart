import 'dart:convert';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/data/settings_api.dart';
import 'package:baraka_bozor/features/admin/data/settings_dto.dart';
import 'package:baraka_bozor/features/admin/data/settings_repository_impl.dart';
import 'package:baraka_bozor/features/admin/domain/business_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../../support/settings_json.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late SettingsRepositoryImpl repository;
  late ResponseBody Function(RequestOptions options) reply;

  setUp(() {
    reply = (RequestOptions options) =>
        jsonReply(200, <String, Object?>{'data': businessJson()});
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply(options));
    repository = SettingsRepositoryImpl(SettingsApi(dioWith(adapter)));
  });

  SessionSlot? slotOf(RequestOptions options) =>
      RequestSlot.resolve(options, () => SessionSlot.customer);

  test('the settings are read on the staff session', () async {
    final BusinessSettings settings = await repository.businessSettings();

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/admin/settings/business');
    expect(slotOf(request), SessionSlot.staff);
    expect(settings.markupPercent, '15.00');
  });

  test('a save sends as a PATCH only what the form changed', () async {
    final BusinessSettings base = SettingsDto.parseBusinessSettings(
      businessJson(),
    );

    await repository.saveBusinessSettings(
      const BusinessSettingsDraft(
        markupPercent: '20',
        serviceFeeMode: ServiceFeeMode.percentage,
        serviceFeeFixedUzs: null,
        serviceFeePercent: '3.5',
        deliveryFeeUzs: 15000,
        minimumOrderUzs: 100000,
        priceTolerancePercent: '10.00',
        opensAt: '09:00',
        closesAt: '21:00',
        serviceCentreLatitude: '41.311081',
        serviceCentreLongitude: '69.240562',
        serviceRadiusKm: '5.00',
        deliveryDelayThresholdMinutes: 30,
      ),
      base,
    );

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/admin/settings/business');
    expect(slotOf(request), SessionSlot.staff);
    expect(jsonDecode(jsonEncode(request.data)), <String, Object?>{
      'markup_percent': '20',
      'service_fee_mode': 'percentage',
      'service_fee_fixed_uzs': null,
      'service_fee_percent': '3.5',
    });
  });

  test('a validation refusal of a save keeps its field errors', () async {
    reply = (RequestOptions options) => options.method == 'PATCH'
        ? errorReply(
            422,
            'validation_failed',
            errors: <String, List<String>>{
              'closes_at': <String>['Must differ from opens_at.'],
            },
          )
        : jsonReply(200, <String, Object?>{'data': businessJson()});
    final BusinessSettings base = await repository.businessSettings();

    await expectLater(
      repository.saveBusinessSettings(
        const BusinessSettingsDraft(
          markupPercent: '15.00',
          serviceFeeMode: ServiceFeeMode.fixed,
          serviceFeeFixedUzs: 5000,
          serviceFeePercent: null,
          deliveryFeeUzs: 15000,
          minimumOrderUzs: 100000,
          priceTolerancePercent: '10.00',
          opensAt: '09:00',
          closesAt: '09:00',
          serviceCentreLatitude: '41.311081',
          serviceCentreLongitude: '69.240562',
          serviceRadiusKm: '5.00',
          deliveryDelayThresholdMinutes: 30,
        ),
        base,
      ),
      throwsA(
        isA<ApiRefusal>().having(
          (ApiRefusal r) => r.error.errors.keys,
          'fields',
          <String>['closes_at'],
        ),
      ),
    );
  });

  test(
    'an answer about another provider than the one switched is refused',
    () async {
      reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
        'data': providerJson('payme', enabled: true),
      });

      await expectLater(
        repository.setPaymentProviderEnabled(
          PaymentProvider.click,
          enabled: true,
        ),
        throwsA(isA<MalformedResponseFailure>()),
      );
    },
  );

  test('the providers are listed and one is switched', () async {
    reply = (RequestOptions options) => options.method == 'GET'
        ? jsonReply(200, <String, Object?>{
            'data': <Object?>[
              providerJson('payme'),
              providerJson('click'),
              providerJson('paynet'),
              providerJson('xazna'),
            ],
            'meta': <String, Object?>{
              'pagination': <String, int>{
                'page': 1,
                'per_page': 4,
                'total': 4,
                'last_page': 1,
              },
            },
          })
        : jsonReply(200, <String, Object?>{
            'data': providerJson('click', enabled: true),
          });

    expect(await repository.paymentProviders(), hasLength(4));
    final PaymentProviderSetting click = await repository
        .setPaymentProviderEnabled(PaymentProvider.click, enabled: true);

    final RequestOptions request = adapter.requests.last;
    expect(request.method, 'PATCH');
    expect(request.path, '/admin/settings/payment-providers/click');
    expect(request.data, <String, bool>{'is_enabled': true});
    expect(slotOf(request), SessionSlot.staff);
    expect(click.isEnabled, isTrue);
  });

  test('a refusal of the read keeps its field errors', () async {
    reply = (RequestOptions options) => errorReply(
      422,
      'validation_failed',
      errors: <String, List<String>>{
        'closes_at': <String>['Must differ from opens_at.'],
      },
    );

    await expectLater(
      repository.businessSettings(),
      throwsA(
        isA<ApiRefusal>()
            .having((ApiRefusal r) => r.code, 'code', 'validation_failed')
            .having((ApiRefusal r) => r.error.errors.keys, 'fields', <String>[
              'closes_at',
            ]),
      ),
    );
  });

  test(
    'a success payload that breaks the contract is a malformed response',
    () async {
      reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
        'data': <String, Object?>{...businessJson(), 'markup_percent': 15},
      });

      await expectLater(
        repository.businessSettings(),
        throwsA(isA<MalformedResponseFailure>()),
      );
    },
  );
}
