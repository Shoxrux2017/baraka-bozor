import 'dart:async';
import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_end_hook.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/notifications/application/push_registrar.dart';
import 'package:baraka_bozor/features/notifications/domain/push.dart';
import 'package:flutter/foundation.dart';
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
/// the order of a revoke and a logout. While [registerHold] is set, a
/// registration answers only once it completes; [registerFailures] answer a
/// slot's next registration with a failure.
class _FakeDevices implements PushDevicesRepository {
  _FakeDevices(this.calls);

  final List<String> calls;
  ApiFailure? revokeFailure;
  Completer<void>? registerHold;
  final Map<SessionSlot, ApiFailure> registerFailures =
      <SessionSlot, ApiFailure>{};
  int _next = 0;

  @override
  Future<String> register(SessionSlot slot, PushToken token) async {
    await registerHold?.future;
    final ApiFailure? failure = registerFailures.remove(slot);
    if (failure != null) {
      calls.add('register-failed:${slot.name}');
      throw failure;
    }
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

  ProviderContainer containerWith({bool shortBound = true}) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(auth),
        preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
        deviceLocaleProvider.overrideWithValue(const Locale('uz')),
        pushTokenSourceProvider.overrideWithValue(source),
        pushDevicesRepositoryProvider.overrideWithValue(devices),
        if (shortBound)
          sessionEndHooksProvider.overrideWithValue(
            SessionEndHooks(limit: const Duration(milliseconds: 50)),
          ),
      ],
    );
    addTearDown(container.dispose);
    container.read(pushRegistrarProvider);
    return container;
  }

  void signInCustomer(String id) {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: id);
  }

  List<String> revokes() =>
      auth.calls.where((String c) => c.startsWith('revoke')).toList();

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

  test(
    'a token answered after its slot was logged out sends nothing',
    () async {
      source.hold = Completer<void>();
      signInCustomer('c');
      final ProviderContainer container = await start();

      await container
          .read(sessionControllerProvider.notifier)
          .logout(SessionMode.customer);
      source.hold!.complete();
      await pumpEventQueue();

      expect(pushCalls(), isEmpty);
    },
  );

  test(
    'a revoke answered after its logout ended is not sent on the next account',
    () async {
      devices.registerHold = Completer<void>();
      signInCustomer('c');
      final ProviderContainer container = await start();
      final SessionController session = container.read(
        sessionControllerProvider.notifier,
      );

      // The registration is on its way; the logout stops waiting for it.
      await session.logout(SessionMode.customer);
      auth.verifyResult = IssuedSession(
        token: 'c2',
        user: user(id: 'c2'),
      );
      await session.verifyCustomerCode(phone: '+998901234567', code: '123456');
      await pumpEventQueue();
      devices.registerHold!.complete();
      await pumpEventQueue();

      expect(revokes(), isEmpty);
      expect(pushCalls(), hasLength(2), reason: 'both registrations answered');
    },
  );

  test('two logouts at once revoke once and log out once', () async {
    devices.registerHold = Completer<void>();
    signInCustomer('c');
    final ProviderContainer container = await start();
    final SessionController session = container.read(
      sessionControllerProvider.notifier,
    );

    final Future<void> first = session.logout(SessionMode.customer);
    final Future<void> second = session.logout(SessionMode.customer);
    devices.registerHold!.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(revokes(), <String>['revoke:customer:d-0']);
    expect(
      auth.calls.where((String c) => c == 'logout:customer'),
      hasLength(1),
    );
    expect(
      auth.calls.indexOf('revoke:customer:d-0'),
      lessThan(auth.calls.indexOf('logout:customer')),
    );
  });

  test(
    'a failed registration is tried again at the next session change',
    () async {
      tokens.tokens[SessionSlot.staff] = 's';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.shopper,
      );
      signInCustomer('c');
      devices.registerFailures[SessionSlot.customer] = const NetworkFailure();
      final ProviderContainer container = await start();
      expect(pushCalls(), contains('register-failed:customer'));

      final SessionController session = container.read(
        sessionControllerProvider.notifier,
      );
      session
        ..switchMode(SessionMode.staff)
        ..switchMode(SessionMode.customer);
      await pumpEventQueue();

      expect(pushCalls().last, startsWith('register:customer:fcm-token:'));
      expect(
        pushCalls().where((String c) => c.startsWith('register:customer')),
        hasLength(1),
        reason: 'once, not in a loop',
      );
    },
  );

  test(
    'an account that replaces another in a slot is registered anew',
    () async {
      signInCustomer('c');
      final ProviderContainer container = await start();
      final SessionController session = container.read(
        sessionControllerProvider.notifier,
      );

      await session.dropSession(SessionSlot.customer);
      auth.verifyResult = IssuedSession(
        token: 'c2',
        user: user(id: 'c2'),
      );
      await session.verifyCustomerCode(phone: '+998901234567', code: '123456');
      await pumpEventQueue();

      expect(pushCalls(), <String>[
        'register:customer:fcm-token:d-0',
        'register:customer:fcm-token:d-1',
      ]);
    },
  );

  test('a hook that throws is reported and the logout goes on', () async {
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    signInCustomer('c');
    final ProviderContainer container = await start();
    container.read(sessionEndHooksProvider).add(_ThrowingHook());

    await container
        .read(sessionControllerProvider.notifier)
        .logout(SessionMode.customer);

    expect(auth.calls, contains('logout:customer'));
    expect(reported.single.exception, isA<StateError>());
  });

  test('a registrar that ends takes its hook with it', () async {
    final ProviderContainer container = await start();

    container.invalidate(pushRegistrarProvider);
    container.read(pushRegistrarProvider);

    expect(container.read(sessionEndHooksProvider).all, hasLength(1));
  });

  testWidgets('a logout waits for a hook five seconds and no longer', (
    WidgetTester tester,
  ) async {
    devices.registerHold = Completer<void>();
    signInCustomer('c');
    final ProviderContainer container = containerWith(shortBound: false);
    await container.read(sessionControllerProvider.future);
    await tester.pump();

    bool done = false;
    unawaited(
      container
          .read(sessionControllerProvider.notifier)
          .logout(SessionMode.customer)
          .then((_) => done = true),
    );
    await tester.pump(const Duration(milliseconds: 4900));
    expect(done, isFalse);
    expect(auth.calls, isNot(contains('logout:customer')));

    await tester.pump(const Duration(milliseconds: 200));
    expect(done, isTrue);
    expect(revokes(), isEmpty);
    devices.registerHold!.complete();
  });

  testWidgets('a hook that answers inside the bound is waited for', (
    WidgetTester tester,
  ) async {
    devices.registerHold = Completer<void>();
    signInCustomer('c');
    final ProviderContainer container = containerWith(shortBound: false);
    await container.read(sessionControllerProvider.future);
    await tester.pump();

    bool done = false;
    unawaited(
      container
          .read(sessionControllerProvider.notifier)
          .logout(SessionMode.customer)
          .then((_) => done = true),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(done, isFalse);
    devices.registerHold!.complete();
    await tester.pump();
    await tester.pump();

    expect(done, isTrue);
    expect(auth.calls.sublist(auth.calls.length - 2), <String>[
      'revoke:customer:d-0',
      'logout:customer',
    ]);
  });
}

/// A hook that fails before it starts.
class _ThrowingHook implements SessionEndHook {
  @override
  Future<void> beforeLogout(SessionSlot slot) => throw StateError('broken');
}
