import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_client_adapter.dart';
import '../support/in_memory_stores.dart';

/// The root providers wired as in production — the real client, interceptor,
/// data source, repository and session controller — with only the transport
/// and the stores replaced. The unit tests prove each part; this proves the
/// closures in `providers.dart` connect them the right way round.
void main() {
  late InMemoryTokenStore tokens;
  late FakeHttpClientAdapter adapter;
  late ResponseBody Function(RequestOptions) reply;

  Map<String, Object?> identity(String id, String role) => <String, Object?>{
    'id': id,
    'role': role,
    'phone': '+998901234567',
    'full_name': null,
    'status': 'active',
    'must_change_password': false,
    'preferred_language': 'uz',
  };

  /// Answers `/auth/me` for the two known tokens and refuses anything else.
  ResponseBody byToken(RequestOptions options) {
    return switch (options.headers['Authorization']) {
      'Bearer s' => jsonReply(200, <String, Object?>{
        'data': identity('s', 'shopper'),
      }),
      'Bearer c' => jsonReply(200, <String, Object?>{
        'data': identity('c', 'customer'),
      }),
      _ => errorReply(401, 'authentication_required'),
    };
  }

  ProviderContainer container() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
        deviceLocaleProvider.overrideWithValue(const Locale('uz')),
      ],
    );
    addTearDown(container.dispose);
    // The one client, with the network swapped for the fake transport.
    container.read(apiClientProvider).httpClientAdapter = adapter;
    return container;
  }

  setUp(() {
    tokens = InMemoryTokenStore(<SessionSlot, String>{
      SessionSlot.staff: 's',
      SessionSlot.customer: 'c',
    });
    reply = byToken;
    adapter = FakeHttpClientAdapter((RequestOptions options) => reply(options));
  });

  test('bootstrap confirms each slot with its own token', () async {
    final ProviderContainer c = container();

    final SignedIn state =
        await c.read(sessionControllerProvider.future) as SignedIn;

    expect(state.activeMode, SessionMode.staff);
    expect(state.staffUser?.id, 's');
    expect(state.customerUser?.id, 'c');
    expect(
      adapter.requests.map((RequestOptions r) => r.headers['Authorization']),
      <String>['Bearer s', 'Bearer c'],
    );
  });

  test('a default-slot request refused after a mode switch in flight drops the session it was sent for, and the next request carries the other token', () async {
    final ProviderContainer c = container();
    final Dio client = c.read(apiClientProvider);
    await c.read(sessionControllerProvider.future);

    // The person switches to Customer mode while the staff request is out;
    // then the server refuses the staff token.
    reply = (RequestOptions options) {
      c
          .read(sessionControllerProvider.notifier)
          .switchMode(SessionMode.customer);
      return errorReply(401, 'authentication_required');
    };

    await expectLater(
      client.get<dynamic>('/orders'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests.last.headers['Authorization'], 'Bearer s');
    final SignedIn after = c.read(sessionControllerProvider).value as SignedIn;
    expect(after.staffUser, isNull, reason: 'the staff session is dropped');
    expect(after.customerUser?.id, 'c', reason: 'the customer one stays');
    expect(after.activeMode, SessionMode.customer);
    expect(tokens.tokens, <SessionSlot, String>{SessionSlot.customer: 'c'});

    reply = byToken;
    await client.get<dynamic>('/auth/me');

    expect(adapter.requests.last.headers['Authorization'], 'Bearer c');
  });

  test('a refusal of a token that a new login has already replaced leaves the new session alone', () async {
    final ProviderContainer c = container();
    final Dio client = c.read(apiClientProvider);
    await c.read(sessionControllerProvider.future);

    reply = (RequestOptions options) {
      // A fresh staff login landed while this request was out.
      tokens.tokens[SessionSlot.staff] = 's2';
      return errorReply(401, 'authentication_required');
    };

    await expectLater(
      client.get<dynamic>('/orders'),
      throwsA(isA<DioException>()),
    );

    final SignedIn after = c.read(sessionControllerProvider).value as SignedIn;
    expect(after.staffUser?.id, 's');
    expect(tokens.tokens[SessionSlot.staff], 's2');
  });
}
