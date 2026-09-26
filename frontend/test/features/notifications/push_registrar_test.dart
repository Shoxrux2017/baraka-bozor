import 'dart:async';
import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_end_hook.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/notifications/application/push_registrar.dart';
import 'package:baraka_bozor/features/notifications/domain/push.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_stores.dart';

class _FakeSource implements PushTokenSource {
  PushToken? token = const PushToken(
    platform: PushPlatform.android,
    value: 'fcm-token',
  );

  /// While set, the token is given only once it completes.
  Completer<void>? hold;

  @override
  Future<PushToken?> current() async {
    await hold?.future;
    return token;
  }
}

/// Records into the same call list as the auth repository, so a test sees
/// the order of a revoke and a logout.
class _FakeDevices implements PushDevicesRepository {
  _FakeDevices(this.calls);

  final List<String> calls;
  ApiFailure? revokeFailure;
  int _next = 0;

  @override
  Future<String> register(SessionSlot slot, PushToken token) async {
    final String id = 'd-${_next++}';
    calls.add('register:${slot.name}:${token.value}:$id');
    return id;
  }

  @override
  Future<void> revoke(SessionSlot slot, String deviceId) async {
    calls.add('revoke:${slot.name}:$deviceId');
    final ApiFailure? failure = revokeFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

/// W1-14: the device is registered once for each signed-in account and
/// revoked at that account's logout (`DL-26`).
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late _FakeSource source;
  late _FakeDevices devices;

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    source = _FakeSource();
    devices = _FakeDevices(auth.calls);
  });

  Future<ProviderContainer> start() async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(auth),
        preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
        deviceLocaleProvider.overrideWithValue(const Locale('uz')),
        pushTokenSourceProvider.overrideWithValue(source),
        pushDevicesRepositoryProvider.overrideWithValue(devices),
        sessionEndHooksProvider.overrideWithValue(
          SessionEndHooks(limit: const Duration(milliseconds: 50)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(pushRegistrarProvider);
    await container.read(sessionControllerProvider.future);
    await pumpEventQueue();
    return container;
  }

  List<String> pushCalls() => auth.calls
      .where((String c) => c.startsWith('register') || c.startsWith('revoke'))
      .toList();

  test('each signed-in account is registered once', () async {
    tokens.tokens[SessionSlot.staff] = 's';
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.staff] = user(id: 's', role: UserRole.shopper);
    auth.identities[SessionSlot.customer] = user(id: 'c');
    final ProviderContainer container = await start();

    expect(pushCalls(), <String>[
      'register:staff:fcm-token:d-0',
      'register:customer:fcm-token:d-1',
    ]);

    container
        .read(sessionControllerProvider.notifier)
        .switchMode(SessionMode.customer);
    await pumpEventQueue();
    expect(
      pushCalls(),
      hasLength(2),
      reason: 'a mode switch is no new account',
    );
  });

  test(
    'a staff account behind the password gate is registered once past it',
    () async {
      tokens.tokens[SessionSlot.staff] = 's';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
        mustChangePassword: true,
      );
      final ProviderContainer container = await start();
      expect(pushCalls(), isEmpty);

      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      await container
          .read(sessionControllerProvider.notifier)
          .changePassword(
            currentPassword: 'Tmp7pQx9KmT3',
            newPassword: 'MyNewSecret1',
            newPasswordConfirmation: 'MyNewSecret1',
          );
      await pumpEventQueue();

      expect(pushCalls(), <String>['register:staff:fcm-token:d-0']);
    },
  );

  test(
    'a logout revokes that session\'s device first and leaves the other',
    () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.shopper,
      );
      auth.identities[SessionSlot.customer] = user(id: 'c');
      final ProviderContainer container = await start();

      await container
          .read(sessionControllerProvider.notifier)
          .logout(SessionMode.customer);

      final List<String> tail = auth.calls.sublist(auth.calls.length - 2);
      expect(tail, <String>['revoke:customer:d-1', 'logout:customer']);

      await container
          .read(sessionControllerProvider.notifier)
          .logout(SessionMode.staff);
      expect(auth.calls.sublist(auth.calls.length - 2), <String>[
        'revoke:staff:d-0',
        'logout:staff',
      ]);
    },
  );

  test('a token source that never answers does not hold the logout', () async {
    source.hold = Completer<void>();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
    final ProviderContainer container = await start();

    await container
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.customer);

    expect(auth.calls, contains('logout:customer'));
    expect(container.read(sessionControllerProvider).value, isA<SignedOut>());
    expect(pushCalls(), isEmpty);
  });

  test('a revoke that fails does not stop the logout', () async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
    devices.revokeFailure = const NetworkFailure();
    final ProviderContainer container = await start();

    await container
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.customer);

    expect(auth.calls, contains('logout:customer'));
    expect(tokens.tokens, isEmpty);
    expect(container.read(sessionControllerProvider).value, isA<SignedOut>());
  });

  test(
    'with no token nothing is registered and a logout revokes nothing',
    () async {
      source.token = null;
      tokens.tokens[SessionSlot.customer] = 'c';
      auth.identities[SessionSlot.customer] = user(id: 'c');
      final ProviderContainer container = await start();

      await container
          .read(sessionControllerProvider.notifier)
          .logout(SessionMode.customer);

      expect(pushCalls(), isEmpty);
      expect(auth.calls, contains('logout:customer'));
    },
  );

  test('a session the server ended is forgotten, not revoked', () async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
    final ProviderContainer container = await start();

    await container
        .read(sessionControllerProvider.notifier)
        .dropSession(SessionSlot.customer);
    await pumpEventQueue();

    expect(pushCalls(), <String>['register:customer:fcm-token:d-0']);
  });
}
