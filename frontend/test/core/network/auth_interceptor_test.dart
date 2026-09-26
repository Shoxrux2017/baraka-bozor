import 'package:baraka_bozor/core/network/auth_interceptor.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client_adapter.dart';
import '../../support/in_memory_stores.dart';

void main() {
  late InMemoryTokenStore tokens;
  late SessionSlot? active;
  late List<SessionSlot> refused;
  late FakeHttpClientAdapter adapter;
  late Dio dio;

  ResponseBody Function(RequestOptions) okReply = (RequestOptions _) =>
      jsonReply(200, <String, Object?>{'data': <String, Object?>{}});

  setUp(() {
    tokens = InMemoryTokenStore(<SessionSlot, String>{
      SessionSlot.staff: 'staff-token',
      SessionSlot.customer: 'customer-token',
    });
    active = SessionSlot.staff;
    refused = <SessionSlot>[];
    adapter = FakeHttpClientAdapter(
      (RequestOptions options) => okReply(options),
    );
    dio = dioWith(adapter);
    dio.interceptors.add(
      AuthInterceptor(
        tokens,
        () => active,
        (SessionSlot slot) async => refused.add(slot),
      ),
    );
  });

  test('a request carries the active mode\'s token by default', () async {
    await dio.get<dynamic>('/auth/me');

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer staff-token',
    );

    active = SessionSlot.customer;
    await dio.get<dynamic>('/auth/me');

    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer customer-token',
    );
  });

  test('a request for an explicit slot carries that slot\'s token whatever the active mode', () async {
    await dio.get<dynamic>(
      '/auth/me',
      options: RequestSlot.of(SessionSlot.customer),
    );

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer customer-token',
    );
  });

  test(
    'a request for no session carries no token even while signed in',
    () async {
      await dio.post<dynamic>(
        '/auth/customer/code/request',
        options: RequestSlot.of(null),
      );

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  test('no token in the slot means no header, not a broken one', () async {
    tokens.tokens.clear();

    await dio.get<dynamic>('/auth/me');

    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test(
    'a refused token drops only the slot the request was made for',
    () async {
      okReply = (RequestOptions _) =>
          errorReply(401, 'authentication_required');

      await expectLater(
        dio.get<dynamic>(
          '/auth/me',
          options: RequestSlot.of(SessionSlot.customer),
        ),
        throwsA(isA<DioException>()),
      );

      expect(refused, <SessionSlot>[SessionSlot.customer]);
    },
  );

  test('a blocked account drops the active slot', () async {
    okReply = (RequestOptions _) => errorReply(401, 'account_blocked');

    await expectLater(
      dio.get<dynamic>('/auth/me'),
      throwsA(isA<DioException>()),
    );

    expect(refused, <SessionSlot>[SessionSlot.staff]);
  });

  test(
    'a 401 for wrong credentials on a session-less request drops nothing',
    () async {
      okReply = (RequestOptions _) => errorReply(401, 'invalid_credentials');

      await expectLater(
        dio.post<dynamic>('/auth/staff/login', options: RequestSlot.of(null)),
        throwsA(isA<DioException>()),
      );

      expect(refused, isEmpty);
    },
  );

  test('a 403 or a 5xx drops nothing', () async {
    okReply = (RequestOptions _) => errorReply(403, 'password_change_required');
    await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));

    okReply = (RequestOptions _) => errorReply(503, 'service_unavailable');
    await expectLater(dio.get<dynamic>('/x'), throwsA(isA<DioException>()));

    expect(refused, isEmpty);
  });

  test('the slot is fixed when the request is sent: a mode switch while it is in flight does not move the refusal', () async {
    okReply = (RequestOptions _) {
      active = SessionSlot.customer;
      return errorReply(401, 'authentication_required');
    };

    await expectLater(
      dio.get<dynamic>('/orders'),
      throwsA(isA<DioException>()),
    );

    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer staff-token',
    );
    expect(refused, <SessionSlot>[SessionSlot.staff]);
  });

  test(
    'a 401 for a token that a new login has since replaced drops nothing',
    () async {
      okReply = (RequestOptions _) {
        tokens.tokens[SessionSlot.staff] = 'fresh-token';
        return errorReply(401, 'authentication_required');
      };

      await expectLater(
        dio.get<dynamic>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(refused, isEmpty);
      expect(tokens.tokens[SessionSlot.staff], 'fresh-token');
    },
  );

  test('a 401 for a request that carried no token drops nothing', () async {
    tokens.tokens.clear();
    okReply = (RequestOptions _) => errorReply(401, 'authentication_required');

    await expectLater(
      dio.get<dynamic>('/auth/me'),
      throwsA(isA<DioException>()),
    );

    expect(refused, isEmpty);
  });

  test(
    'a 401 without an envelope drops nothing, because it cannot be trusted',
    () async {
      okReply = (RequestOptions _) =>
          ResponseBody.fromString('Unauthorized', 401);

      await expectLater(
        dio.get<dynamic>('/auth/me'),
        throwsA(isA<DioException>()),
      );

      expect(refused, isEmpty);
    },
  );
}
