import 'dart:math';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/network/idempotency_key.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/checkout/data/checkout_api.dart';
import 'package:baraka_bozor/features/checkout/domain/checkout.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_checkout_repository.dart';
import '../../../support/fake_http_client_adapter.dart';

/// The checkout's data source against `docs/09-api-contracts.md` sections
/// 18 and 19.
void main() {
  test('an idempotency key is a random UUID of version 4', () {
    final RegExp v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final Set<String> keys = <String>{
      for (int i = 0; i < 200; i++) newIdempotencyKey(),
    };
    expect(keys, hasLength(200));
    expect(keys.every(v4.hasMatch), isTrue);
    expect(newIdempotencyKey(Random(1)), newIdempotencyKey(Random(1)));
  });

  group('parsing', () {
    test('a preview with its lines, amounts, kind, hours and token', () {
      final CheckoutPreview preview = CheckoutApi.parsePreview(
        previewJson(note: 'Kechqurun', outside: true),
      );
      expect(preview.lines.single.quantity, '1.500');
      expect(preview.totalUzs, 47600);
      expect(preview.totalKind, TotalKind.estimate);
      expect(preview.deliveryTimeNote, 'Kechqurun');
      expect(preview.outsideWorkingHours, isTrue);
      expect(preview.opensAt, '08:00');
      expect(preview.token, 'token-1');
      expect(preview.tokenExpiresAt, DateTime.utc(2026, 9, 28, 7, 5));

      final CheckoutPreview always = CheckoutApi.parsePreview(
        previewJson(opensAt: null, totalKind: 'final'),
      );
      expect(always.opensAt, isNull);
      expect(always.totalKind, TotalKind.finalTotal);
    });

    test('a preview off the contract is refused', () {
      for (final Map<String, Object?> broken in <Map<String, Object?>>[
        previewJson(totalKind: 'none'),
        previewJson(outside: true, opensAt: null),
        previewJson(opensAt: '8:00'),
        <String, Object?>{...previewJson(), 'lines': <Object?>[]},
        <String, Object?>{...previewJson(), 'total_uzs': -1},
        <String, Object?>{...previewJson(), 'checkout_token': ''},
        <String, Object?>{
          ...previewJson(),
          'checkout_token_expires_at': '2026-09-28T12:05:00+05:00',
        },
      ]) {
        expect(
          () => CheckoutApi.parsePreview(broken),
          throwsFormatException,
          reason: '$broken',
        );
      }
    });

    test('a placed order with its number and total', () {
      final PlacedOrder order = CheckoutApi.parsePlaced(placedJson());
      expect(order.id, placedOrderId);
      expect(order.orderNumber, 1001);
      expect(order.totalUzs, 47600);
    });
  });

  group('requests', () {
    late FakeHttpClientAdapter adapter;
    late CheckoutRepositoryImpl repository;
    Map<String, Object?>? preview;

    setUp(() {
      preview = null;
      adapter = FakeHttpClientAdapter(
        (RequestOptions options) => options.path == '/customer/orders'
            ? jsonReply(201, <String, Object?>{'data': placedJson()})
            : jsonReply(200, <String, Object?>{
                'data': preview ?? previewJson(note: 'Kechqurun'),
              }),
      );
      repository = CheckoutRepositoryImpl(CheckoutApi(dioWith(adapter)));
    });

    const CheckoutRequest request = CheckoutRequest(
      addressId: '0192f0a0-0000-7000-8000-00000000ad01',
      paymentMethod: PaymentMethod.cash,
      deliveryTimeNote: 'Kechqurun',
    );

    test(
      'a preview and a placement on the Customer session, with the key',
      () async {
        await repository.preview(request);
        await repository.place('token-1', 'key-1');

        final RequestOptions previewing = adapter.requests.first;
        final RequestOptions placing = adapter.requests.last;
        expect(previewing.path, '/customer/checkout/preview');
        expect(previewing.data, <String, Object?>{
          'address_id': '0192f0a0-0000-7000-8000-00000000ad01',
          'payment_method': 'cash',
          'delivery_time_note': 'Kechqurun',
        });
        expect(placing.method, 'POST');
        expect(placing.path, '/customer/orders');
        expect(placing.data, <String, String>{'checkout_token': 'token-1'});
        expect(placing.headers['Idempotency-Key'], 'key-1');
        for (final RequestOptions sent in adapter.requests) {
          expect(
            RequestSlot.resolve(sent, () => SessionSlot.staff),
            SessionSlot.customer,
          );
        }
      },
    );

    test('a preview of another checkout is malformed', () async {
      preview = previewJson(note: 'Ertalab');
      await expectLater(
        repository.preview(request),
        throwsA(isA<MalformedResponseFailure>()),
      );

      preview = previewJson(paymentMethod: 'online', note: 'Kechqurun');
      await expectLater(
        repository.preview(request),
        throwsA(isA<MalformedResponseFailure>()),
      );
    });
  });
}
