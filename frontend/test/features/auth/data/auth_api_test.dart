import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/data/auth_api.dart';
import 'package:baraka_bozor/features/auth/data/auth_repository_impl.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late ResponseBody Function(RequestOptions) reply;
  late AuthApi api;
  late AuthRepositoryImpl repository;

  Map<String, Object?> identity({String role = 'customer'}) =>
      <String, Object?>{
        'id': '3f1e9d2c-7c0a-4d6c-9a11-2a9b0f3c4d5e',
        'role': role,
        'phone': '+998901234567',
        'full_name': null,
        'status': 'active',
        'must_change_password': false,
        'preferred_language': 'uz',
      };

  setUp(() {
    reply = (RequestOptions _) =>
        jsonReply(200, <String, Object?>{'data': identity()});
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply(options));
    api = AuthApi(dioWith(adapter));
    repository = AuthRepositoryImpl(api);
  });

  SessionSlot? slotOf(RequestOptions options) =>
      RequestSlot.resolve(options, () => SessionSlot.staff);

  test('request code: POST /auth/customer/code/request with the phone, on behalf of no session', () async {
    reply = (RequestOptions _) => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{
        'channel': 'sms',
        'expires_in_seconds': 300,
        'resend_available_in_seconds': 60,
      },
    });

    final RequestedCode code = await api.requestCustomerCode('+998901234567');

    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'POST');
    expect(sent.path, '/auth/customer/code/request');
    expect(sent.data, <String, String>{'phone': '+998901234567'});
    expect(slotOf(sent), isNull);
    expect(code.channel, 'sms');
  });

  test('verify code: POST /auth/customer/code/verify with phone and code, no session', () async {
    reply = (RequestOptions _) => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{'token': '7|tok', 'user': identity()},
    });

    final IssuedSession session = await api.verifyCustomerCode(
      phone: '+998901234567',
      code: '482913',
    );

    final RequestOptions sent = adapter.requests.single;
    expect(sent.path, '/auth/customer/code/verify');
    expect(sent.data, <String, String>{
      'phone': '+998901234567',
      'code': '482913',
    });
    expect(slotOf(sent), isNull);
    expect(session.token, '7|tok');
  });

  test('staff login: POST /auth/staff/login, no session', () async {
    reply = (RequestOptions _) => jsonReply(200, <String, Object?>{
      'data': <String, Object?>{
        'token': '8|tok',
        'user': identity(role: 'operator'),
      },
    });

    final IssuedSession session = await api.staffLogin(
      phone: '+998901234567',
      password: 'secret',
    );

    final RequestOptions sent = adapter.requests.single;
    expect(sent.path, '/auth/staff/login');
    expect(sent.data, <String, String>{
      'phone': '+998901234567',
      'password': 'secret',
    });
    expect(slotOf(sent), isNull);
    expect(session.user.role, UserRole.operator);
  });

  test('me: GET /auth/me on behalf of the given slot', () async {
    await api.me(SessionSlot.customer);

    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'GET');
    expect(sent.path, '/auth/me');
    expect(slotOf(sent), SessionSlot.customer);
  });

  test('update language: PATCH /auth/me with the machine code', () async {
    await api.updateLanguage(SessionSlot.staff, AppLanguage.ru);

    final RequestOptions sent = adapter.requests.single;
    expect(sent.method, 'PATCH');
    expect(sent.path, '/auth/me');
    expect(sent.data, <String, String>{'preferred_language': 'ru'});
    expect(slotOf(sent), SessionSlot.staff);
  });

  test('change password: POST /auth/change-password with the confirmation as typed, never fabricated', () async {
    reply = (RequestOptions _) => emptyReply(204);

    await api.changePassword(
      SessionSlot.staff,
      currentPassword: 'old password 1',
      newPassword: 'new password 2',
      newPasswordConfirmation: 'new password 3',
    );

    final RequestOptions sent = adapter.requests.single;
    expect(sent.path, '/auth/change-password');
    expect(sent.data, <String, String>{
      'current_password': 'old password 1',
      'new_password': 'new password 2',
      'new_password_confirmation': 'new password 3',
    });
    expect(slotOf(sent), SessionSlot.staff);
  });

  test('logout: POST /auth/logout on behalf of the given slot', () async {
    reply = (RequestOptions _) => emptyReply(204);

    await api.logout(SessionSlot.customer);

    final RequestOptions sent = adapter.requests.single;
    expect(sent.path, '/auth/logout');
    expect(slotOf(sent), SessionSlot.customer);
  });

  group('the repository maps failures', () {
    test('an envelope becomes an ApiRefusal with its code', () async {
      reply = (RequestOptions _) => errorReply(401, 'invalid_credentials');

      await expectLater(
        repository.staffLogin(phone: '+998901234567', password: 'x'),
        throwsA(
          isA<ApiRefusal>().having(
            (ApiRefusal f) => f.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
    });

    test(
      'a success payload the DTO cannot parse is a malformed response',
      () async {
        reply = (RequestOptions _) => jsonReply(200, <String, Object?>{
          'data': <String, Object?>{'id': 'x'},
        });

        await expectLater(
          repository.me(SessionSlot.staff),
          throwsA(isA<MalformedResponseFailure>()),
        );
      },
    );

    test('a 200 whose JSON body cannot be decoded is a malformed response, not a lost connection', () async {
      reply = (RequestOptions _) => ResponseBody.fromString(
        '{"data": ',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

      await expectLater(
        repository.me(SessionSlot.staff),
        throwsA(isA<MalformedResponseFailure>()),
      );
    });

    test('a connection failure is a network failure', () async {
      adapter = FakeHttpClientAdapter((RequestOptions options) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        );
      });
      repository = AuthRepositoryImpl(AuthApi(dioWith(adapter)));

      await expectLater(
        repository.me(SessionSlot.staff),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
