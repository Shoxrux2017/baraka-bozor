import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/profile/data/account_deletion_api.dart';
import 'package:baraka_bozor/features/profile/domain/account_deletion.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';
import '../../../support/in_memory_stores.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late AccountDeletionApi api;
  late ResponseBody Function(RequestOptions options) reply;

  setUp(() {
    reply = (RequestOptions options) => emptyReply(204);
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply(options));
    api = AccountDeletionApi(dioWith(adapter));
  });

  Future<ApiFailure> failureOfDelete(String code) async {
    try {
      await api.delete(code);
    } on ApiFailure catch (failure) {
      return failure;
    }
    throw StateError('the delete did not fail');
  }

  test('the code is requested on the Customer session', () async {
    reply = (RequestOptions options) => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{
        'channel': 'sms',
        'expires_in_seconds': 300,
        'resend_available_in_seconds': 60,
      },
    });

    final RequestedCode code = await api.requestCode();

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/customer/account/deletion-code');
    expect(request.data, isNull);
    expect(
      RequestSlot.resolve(request, () => SessionSlot.staff),
      SessionSlot.customer,
    );
    expect(code.channel, 'sms');
    expect(code.expiresInSeconds, 300);
    expect(code.resendAvailableInSeconds, 60);
  });

  test('deleting sends the code and completes on 204', () async {
    await api.delete('123456');

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/customer/account/delete');
    expect(request.data, <String, String>{'code': '123456'});
    expect(
      RequestSlot.resolve(request, () => SessionSlot.staff),
      SessionSlot.customer,
    );
  });

  test('delete keeps the session on a 401 and throws it', () async {
    final List<SessionSlot> refused = <SessionSlot>[];
    final Dio dio = dioWith(adapter);
    dio.interceptors.add(
      AuthInterceptor(
        InMemoryTokenStore(<SessionSlot, String>{SessionSlot.customer: 't'}),
        () => SessionSlot.customer,
        (SessionSlot slot) async => refused.add(slot),
      ),
    );
    reply = (RequestOptions options) =>
        errorReply(401, 'authentication_required');

    try {
      await AccountDeletionApi(dio).delete('123456');
      fail('the delete did not fail');
    } on ApiRefusal catch (failure) {
      expect(failure.status, 401);
      expect(failure.code, 'authentication_required');
    }

    expect(refused, isEmpty);
  });

  test('stillExists is true on 200 and false on 401', () async {
    reply = (RequestOptions options) =>
        jsonReply(200, <String, Object?>{'data': <String, Object?>{}});

    expect(await api.stillExists(), isTrue);
    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/customer/profile');
    expect(
      RequestSlot.resolve(request, () => SessionSlot.staff),
      SessionSlot.customer,
    );

    reply = (RequestOptions options) =>
        errorReply(401, 'authentication_required');

    expect(await api.stillExists(), isFalse);
  });

  test('stillExists throws a network failure', () async {
    reply = (RequestOptions options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );

    await expectLater(api.stillExists(), throwsA(isA<ApiFailure>()));
  });

  test('stillExists throws any other refusal', () async {
    reply = (RequestOptions options) => errorReply(403, 'account_blocked');

    await expectLater(api.stillExists(), throwsA(isA<ApiRefusal>()));
  });

  test('an unfinished order is read from the 409', () async {
    reply = (RequestOptions options) => errorReply(
      409,
      'account_has_unfinished_orders',
      details: <String, Object?>{'order_id': 'o1', 'order_number': 1021},
    );

    final UnfinishedOrder? order = unfinishedOrderOf(
      await failureOfDelete('123456'),
    );

    expect(order?.id, 'o1');
    expect(order?.number, 1021);
    expect(order?.status, isNull);
    expect(order?.itemCount, 0);
  });

  test('the unfinished order reads its status and item count', () async {
    reply = (RequestOptions options) => errorReply(
      409,
      'account_has_unfinished_orders',
      details: <String, Object?>{
        'order_id': 'o1',
        'order_number': 1021,
        'status': 'shopping',
        'item_count': 7,
      },
    );

    final UnfinishedOrder? order = unfinishedOrderOf(
      await failureOfDelete('123456'),
    );

    expect(order?.status, OrderStatus.shopping);
    expect(order?.itemCount, 7);
  });

  test('an unknown status leaves only the number', () async {
    reply = (RequestOptions options) => errorReply(
      409,
      'account_has_unfinished_orders',
      details: <String, Object?>{
        'order_id': 'o1',
        'order_number': 1021,
        'status': 'teleporting',
        'item_count': 'many',
      },
    );

    final UnfinishedOrder? order = unfinishedOrderOf(
      await failureOfDelete('123456'),
    );

    expect(order?.number, 1021);
    expect(order?.status, isNull);
    expect(order?.itemCount, 0);
  });

  test('another refusal is no unfinished order', () async {
    reply = (RequestOptions options) => errorReply(422, 'code_invalid');

    expect(unfinishedOrderOf(await failureOfDelete('000000')), isNull);
  });

  test('a 409 without usable details is no unfinished order', () async {
    reply = (RequestOptions options) =>
        errorReply(409, 'account_has_unfinished_orders');

    expect(unfinishedOrderOf(await failureOfDelete('123456')), isNull);
  });
}
