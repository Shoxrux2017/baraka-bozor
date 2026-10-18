import 'dart:async';
import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/application/code_login_controller.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  ProviderContainer container() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(repository),
        preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
        deviceLocaleProvider.overrideWithValue(const Locale('uz')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  CodeLoginController controller(ProviderContainer c) =>
      c.read(codeLoginControllerProvider.notifier);

  CodeLoginState state(ProviderContainer c) =>
      c.read(codeLoginControllerProvider);

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  test(
    'requesting a code records the phone, the channel and the resend timer',
    () async {
      repository.requestResult = const RequestedCode(
        channel: 'telegram',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 45,
      );
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);

      expect(await controller(c).requestCode('+998901234567'), isTrue);

      final CodeLoginState s = state(c);
      expect(s.phone, '+998901234567');
      expect(s.requested?.channel, 'telegram');
      expect(s.resendInSeconds, 45, reason: 'the server timer, not a constant');
      expect(s.canResend, isFalse);
      expect(s.busy, isFalse);
      expect(repository.calls, contains('request:+998901234567'));
    },
  );

  // The countdown itself is proved in the widget test of the login flow,
  // where the test clock drives the timer.

  test('a refused request keeps the failure and stays on the phone', () async {
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    repository.requestFailure = refusal(429, 'rate_limited');

    expect(await controller(c).requestCode('+998901234567'), isFalse);

    expect(state(c).failure?.code, 'rate_limited');
    expect(state(c).hasCode, isFalse);
    expect(state(c).busy, isFalse);
  });

  test('a wrong code keeps the failure; the right one opens the session and clears the flow', () async {
    repository.verifyFailure = refusal(422, 'code_invalid');
    repository.verifyResult = IssuedSession(
      token: 'c',
      user: user(id: 'c'),
    );
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901234567');

    expect(await controller(c).verify('000000'), isFalse);
    expect(state(c).failure?.code, 'code_invalid');
    expect(state(c).hasCode, isTrue, reason: 'the code screen stays');

    repository.verifyFailure = null;
    expect(await controller(c).verify('482913'), isTrue);

    expect(repository.calls, contains('verify:+998901234567:482913'));
    expect(state(c).hasCode, isFalse);
    expect(c.read(sessionControllerProvider).value, isA<SignedIn>());
    expect(tokens.tokens[SessionSlot.customer], 'c');
  });

  test(
    'a request superseded by a reset is discarded when it answers',
    () async {
      repository.holdAnswers = null;
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);

      // The fake answers synchronously after a microtask; a reset in between
      // makes the answer stale.
      final Future<bool> stale = controller(c).requestCode('+998901234567');
      controller(c).reset();

      expect(await stale, isFalse);
      expect(state(c).hasCode, isFalse);
      expect(state(c).phone, isNull);
    },
  );

  test('a verified code for a Shopper or Courier phone opens the customer session with a pending staff step', () async {
    repository.verifyResult = IssuedSession(
      token: 'c',
      user: user(id: 'c', phone: '+998901111111'),
    );
    repository.staffSteps['+998901111111'] = StaffStep(
      token: 'a' * 64,
      expiresAt: DateTime.utc(2026, 10, 15, 10, 5),
    );
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);

    expect(await controller(c).requestCode('+998901111111'), isTrue);
    expect(await controller(c).verify('123456'), isTrue);

    expect(repository.calls, contains('verify:+998901111111:123456'));
    final SignedIn session =
        c.read(sessionControllerProvider).value as SignedIn;
    expect(session.activeMode, SessionMode.customer);
    expect(session.staffStep?.token, 'a' * 64);
    expect(session.staffUser, isNull);
    expect(state(c).hasCode, isFalse, reason: 'the flow is over');
  });

  test(
    'a refused resend keeps the code already on its way and shows why',
    () async {
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);
      await controller(c).requestCode('+998901234567');
      repository.requestFailure = refusal(429, 'rate_limited');

      expect(await controller(c).resend(), isFalse);

      expect(state(c).hasCode, isTrue);
      expect(state(c).phone, '+998901234567');
      expect(state(c).failure?.code, 'rate_limited');
      expect(state(c).busy, isFalse);
    },
  );

  test('a new request starts clean: nothing of an earlier flow shows while it runs', () async {
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901111111');
    expect(state(c).hasCode, isTrue);

    repository.holdAnswers = Completer<void>();
    final Future<bool> pending = controller(c).requestCode('+998902222222');

    expect(state(c).hasCode, isFalse, reason: 'the old code is not shown');
    expect(state(c).phone, '+998902222222');
    expect(state(c).busy, isTrue);

    repository.holdAnswers!.complete();
    expect(await pending, isTrue);
    expect(state(c).hasCode, isTrue);
  });

  test('an error the application cannot explain re-enables the screen and is reported', () async {
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901234567');

    // The fake has no verify answer configured, so it throws a plain error.
    expect(await controller(c).verify('482913'), isFalse);

    expect(state(c).busy, isFalse);
    expect(state(c).failure, isA<UnexpectedFailure>());
    expect(reported, hasLength(1));
  });

  test(
    'a refused resend keeps the code already on its way and shows why',
    () async {
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);
      await controller(c).requestCode('+998901234567');
      repository.requestFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 42,
      );

      expect(await controller(c).resend(), isFalse);

      expect(state(c).hasCode, isTrue, reason: 'the code screen stays');
      expect(state(c).lockedSeconds, 42);
      expect(state(c).failure, isNull, reason: 'the lock has its own sentence');
      expect(state(c).canResend, isFalse);
      expect(state(c).busy, isFalse);
    },
  );

  test('a new request starts clean: nothing of an earlier flow shows while it runs', () async {
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901111111');
    expect(state(c).hasCode, isTrue);

    repository.holdAnswers = Completer<void>();
    final Future<bool> pending = controller(c).requestCode('+998902222222');

    expect(state(c).hasCode, isFalse, reason: 'the old code is not shown');
    expect(state(c).phone, '+998902222222');
    expect(state(c).busy, isTrue);

    repository.holdAnswers!.complete();
    expect(await pending, isTrue);
    expect(state(c).hasCode, isTrue);
  });

  test('an error the application cannot explain re-enables the screen and is reported', () async {
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901234567');

    // The fake has no verify answer configured, so it throws a plain error.
    expect(await controller(c).verify('482913'), isFalse);

    expect(state(c).busy, isFalse);
    expect(state(c).failure, isA<UnexpectedFailure>());
    expect(reported, hasLength(1));
  });

  testWidgets('a resend can be sent at once', (WidgetTester tester) async {
    repository.requestResult = const RequestedCode(
      channel: 'telegram',
      expiresInSeconds: 300,
      resendAvailableInSeconds: 0,
    );
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);

    await controller(c).requestCode('+998901234567');

    expect(state(c).canResend, isTrue);
    expect(state(c).locked, isFalse);
    expect(await controller(c).resend(), isTrue);
    expect(
      repository.calls.where((String call) => call.startsWith('request:')),
      hasLength(2),
    );
  });

  testWidgets(
    'code_locked from verify locks for the header seconds and counts down',
    (WidgetTester tester) async {
      final ProviderContainer c = container();
      await c.read(sessionControllerProvider.future);
      await controller(c).requestCode('+998901234567');
      repository.verifyFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 60,
      );

      expect(await controller(c).verify('000000'), isFalse);

      expect(state(c).locked, isTrue);
      expect(state(c).lockedSeconds, 60);
      expect(state(c).canResend, isFalse);
      expect(state(c).failure, isNull, reason: 'shown as the lock sentence');
      expect(state(c).busy, isFalse);

      await tester.pump(const Duration(seconds: 59));
      expect(state(c).lockedSeconds, 1);
      expect(state(c).canResend, isFalse);
      expect(state(c).lockOver, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(state(c).locked, isFalse);
      expect(state(c).lockOver, isTrue);
      expect(state(c).canResend, isTrue);
    },
  );

  testWidgets('code_locked without a header locks for 60', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901234567');
    repository.verifyFailure = refusal(429, 'code_locked');

    await controller(c).verify('000000');

    expect(state(c).lockedSeconds, 60);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets('code_locked from request on the phone screen locks too', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    repository.requestFailure = ApiRefusal(
      const ApiError(status: 429, code: 'code_locked'),
      retryAfterSeconds: 37,
    );

    expect(await controller(c).requestCode('+998901234567'), isFalse);

    expect(state(c).hasCode, isFalse);
    expect(state(c).phone, '+998901234567');
    expect(state(c).lockedSeconds, 37);
    expect(state(c).failure, isNull);
    await tester.pump(const Duration(seconds: 37));
    expect(state(c).locked, isFalse);
  });

  testWidgets('changing the phone clears the lock', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901234567');
    repository.verifyFailure = refusal(429, 'code_locked');
    await controller(c).verify('000000');

    controller(c).changePhone();

    expect(state(c).locked, isFalse);
    expect(state(c).phone, '+998901234567');
    await tester.pump(const Duration(seconds: 61));
    expect(state(c).locked, isFalse);
  });

  test('a network failure on verify is shown, not swallowed', () async {
    repository.verifyFailure = const NetworkFailure();
    final ProviderContainer c = container();
    await c.read(sessionControllerProvider.future);
    await controller(c).requestCode('+998901234567');

    expect(await controller(c).verify('482913'), isFalse);
    expect(state(c).failure, isA<NetworkFailure>());
  });
}
