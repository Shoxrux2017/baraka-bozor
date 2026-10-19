import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/data/admin_customers_api.dart';
import 'package:baraka_bozor/features/admin/domain/admin_customers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  const String idA = '0198a000-0000-7000-8000-0000000000a1';
  const String idB = '0198a000-0000-7000-8000-0000000000a2';
  const String orderId = '0198a000-0000-7000-8000-0000000000b1';

  late FakeHttpClientAdapter adapter;
  late AdminCustomersApi api;
  late ResponseBody Function(RequestOptions options) reply;

  Map<String, Object?> customer({
    String id = idA,
    String? fullName = 'Aziza Karimova',
    String status = 'active',
    Map<String, Object?>? unfinished,
    String? lastLoginAt = '2026-10-18T09:00:00Z',
    String phone = '+998901234567',
  }) => <String, Object?>{
    'id': id,
    'phone': phone,
    'full_name': fullName,
    'status': status,
    'created_at': '2026-09-01T07:00:00Z',
    'last_login_at': lastLoginAt,
    'order_count': 3,
    'unfinished_order': unfinished,
  };

  setUp(() {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <Map<String, Object?>>[
        customer(
          unfinished: <String, Object?>{'id': orderId, 'order_number': 1042},
        ),
        customer(id: idB, fullName: null, status: 'blocked', lastLoginAt: null),
      ],
    });
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply(options));
    api = AdminCustomersApi(dioWith(adapter));
  });

  test('find sends the phone on the staff session and parses both', () async {
    final List<AdminCustomer> found = await api.find('+998901234567');

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/admin/customers');
    expect(request.queryParameters, <String, Object?>{
      'phone': '+998901234567',
    });
    expect(request.uri.toString(), contains('phone=%2B998901234567'));
    expect(
      RequestSlot.resolve(request, () => SessionSlot.customer),
      SessionSlot.staff,
    );

    expect(found, hasLength(2));
    expect(found[0].id, idA);
    expect(found[0].fullName, 'Aziza Karimova');
    expect(found[0].status, 'active');
    expect(found[0].createdAt, DateTime.utc(2026, 9, 1, 7));
    expect(found[0].lastLoginAt, DateTime.utc(2026, 10, 18, 9));
    expect(found[0].orderCount, 3);
    expect(found[0].unfinishedOrder, (id: orderId, number: 1042));
    expect(found[1].fullName, isNull);
    expect(found[1].isBlocked, isTrue);
    expect(found[1].lastLoginAt, isNull);
    expect(found[1].unfinishedOrder, isNull);
  });

  test('a malformed list is a failure', () async {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <Map<String, Object?>>[customer(status: 'deleted')],
    });
    await expectLater(
      api.find('+998901234567'),
      throwsA(isA<MalformedResponseFailure>()),
    );

    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <Map<String, Object?>>[customer(phone: '901234567')],
    });
    await expectLater(
      api.find('+998901234567'),
      throwsA(isA<MalformedResponseFailure>()),
    );
  });

  test('erase posts with no body on the staff session', () async {
    reply = (RequestOptions options) => ResponseBody.fromString('', 204);

    await api.erase(idA);

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/admin/customers/$idA/erase');
    expect(request.data, isNull);
    expect(
      RequestSlot.resolve(request, () => SessionSlot.customer),
      SessionSlot.staff,
    );
  });

  test('an unfinished order surfaces as a refusal with its number', () async {
    reply = (RequestOptions options) => errorReply(
      409,
      'account_has_unfinished_orders',
      details: <String, Object?>{'order_id': orderId, 'order_number': 1042},
    );

    final Object? failure = await api
        .erase(idA)
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(failure, isA<ApiRefusal>());
    expect((failure! as ApiFailure).code, 'account_has_unfinished_orders');
    expect((failure as ApiFailure).unfinishedOrder, (
      id: orderId,
      number: 1042,
    ));
  });

  test('another refusal names no unfinished order', () async {
    reply = (RequestOptions options) => errorReply(404, 'resource_not_found');

    final Object? failure = await api
        .erase(idA)
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect((failure! as ApiFailure).unfinishedOrder, isNull);
  });
}
