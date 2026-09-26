import 'dart:convert';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/data/settings_api.dart';
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

  test('a save sends the whole form as a PATCH', () async {
    await repository.saveBusinessSettings(
      const BusinessSettingsDraft(
        markupPercent: '20',
        serviceFeeMode: ServiceFeeMode.percentage,
        serviceFeeFixedUzs: null,
        serviceFeePercent: '3.5',
        deliveryFeeUzs: 0,
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

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/admin/settings/business');
    expect(slotOf(request), SessionSlot.staff);
    final Map<String, dynamic> body =
        jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>;
    expect(body['markup_percent'], '20');
    expect(body['service_fee_mode'], 'percentage');
    expect(body['service_fee_percent'], '3.5');
    expect(body['service_fee_fixed_uzs'], isNull);
    expect(body['delivery_fee_uzs'], 0);
    expect(body.containsKey('minimum_order_uzs'), isTrue);
    expect(body.length, 13);
  });

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

  test('a validation refusal keeps its field errors', () async {
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
