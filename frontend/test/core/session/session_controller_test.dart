import 'dart:async';
import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/platform/clock.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_stores.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  final StaffStep step = StaffStep(
    token: 'a' * 64,
    expiresAt: DateTime.utc(2026, 10, 15, 10, 5),
  );

  ProviderContainer container({DateTime Function()? clock}) {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        if (clock != null) clockProvider.overrideWithValue(clock),
        tokenStoreProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(repository),
        preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
        deviceLocaleProvider.overrideWithValue(const Locale('uz')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<SessionState> bootstrap(ProviderContainer c) =>
      c.read(sessionControllerProvider.future);

  SessionController controller(ProviderContainer c) =>
      c.read(sessionControllerProvider.notifier);

  SessionState current(ProviderContainer c) =>
      c.read(sessionControllerProvider).value!;

  /// A customer code verified for a phone that carries a staff step.
  Future<ProviderContainer> withPendingStep() async {
    repository.verifyResult = IssuedSession(
      token: 'new-customer',
      user: user(id: 'c', phone: '+998901111111'),
    );
    repository.staffSteps['+998901111111'] = step;
    final ProviderContainer c = container();
    await bootstrap(c);
    await controller(c)
        .verifyCustomerCode(phone: '+998901111111', code: '000000');
    return c;
  }

  /// Lets every queued microtask run, so a call that is waiting on the
  /// repository has reached its await.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  group('bootstrap', () {
    test('no token in either slot is signed out, and nothing is asked of the server', () async {
      final ProviderContainer c = container();

      expect(await bootstrap(c), isA<SignedOut>());
      expect(repository.calls, isEmpty);
      expect(controller(c).activeSlot, isNull);
    });

    test('a staff token is confirmed and opens the staff mode', () async {
      tokens.tokens[SessionSlot.staff] = 't';
      repository.identities[SessionSlot.staff] = user(role: UserRole.shopper);
      final ProviderContainer c = container();

      final SessionState state = await bootstrap(c);

      expect(state, isA<SignedIn>());
      final SignedIn signedIn = state as SignedIn;
      expect(signedIn.activeMode, SessionMode.staff);
      expect(signedIn.staffUser?.role, UserRole.shopper);
      expect(signedIn.customerUser, isNull);
      expect(controller(c).activeSlot, SessionSlot.staff);
    });

    test('both tokens are confirmed and the staff mode opens first', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      repository.identities[SessionSlot.customer] = user(id: 'c');
      final ProviderContainer c = container();

      final SignedIn state = await bootstrap(c) as SignedIn;

      expect(state.activeMode, SessionMode.staff);
      expect(state.staffUser?.id, 's');
      expect(state.customerUser?.id, 'c');
      expect(state.canOfferCustomerMode, isTrue);
    });

    test('a refused token is cleared alone', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = refusal(
        401,
        'account_blocked',
      );
      repository.identities[SessionSlot.customer] = user(id: 'c');
      final ProviderContainer c = container();

      final SignedIn state = await bootstrap(c) as SignedIn;

      expect(state.activeMode, SessionMode.customer);
      expect(state.staffUser, isNull);
      expect(tokens.tokens.keys, <SessionSlot>[SessionSlot.customer]);
    });

    test(
      'a token refused as the only session leaves the app signed out',
      () async {
        tokens.tokens[SessionSlot.customer] = 'c';
        repository.identities[SessionSlot.customer] = refusal(
          401,
          'authentication_required',
        );
        final ProviderContainer c = container();

        expect(await bootstrap(c), isA<SignedOut>());
        expect(tokens.tokens, isEmpty);
      },
    );

    testWidgets('an unreachable server keeps the token and can be retried', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      final ProviderContainer c = container();
      c.read(sessionControllerProvider);
      await tester.pump();

      expect(current(c), isA<SessionUnreachable>());
      expect(
        tokens.tokens[SessionSlot.staff],
        's',
        reason: 'the token is not thrown away',
      );

      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      unawaited(controller(c).retry());
      await tester.pump(SessionController.leastPressedCheck);

      expect(current(c), isA<SignedIn>());
    });

    testWidgets(
      'a retry keeps the previous answer while it runs, a second tap joins it, and a retry that throws leaves a way to retry again',
      (WidgetTester tester) async {
        tokens.tokens[SessionSlot.staff] = 's';
        repository.identities[SessionSlot.staff] = const NetworkFailure();
        final ProviderContainer c = container();
        c.read(sessionControllerProvider);
        await tester.pump();
        expect(current(c), isA<SessionUnreachable>());

        repository.holdAnswers = Completer<void>();
        final Future<void> retrying = controller(c).retry();
        await tester.pump();
        expect(
          c.read(sessionControllerProvider).value,
          isA<SessionUnreachable>().having(
            (SessionUnreachable s) => s.retrying,
            'retrying',
            isTrue,
          ),
          reason: 'the retry screen stays, marked as retrying',
        );
        expect(
          c.read(sessionControllerProvider).isLoading,
          isFalse,
          reason: 'never a loading state that would bounce the interface',
        );
        repository.calls.clear();
        unawaited(controller(c).retry());
        await tester.pump();
        expect(repository.calls, isEmpty, reason: 'a second tap joins');

        // No identity configured: the fake throws a plain StateError.
        final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
        final FlutterExceptionHandler? previous = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previous);
        repository.identities.remove(SessionSlot.staff);
        repository.holdAnswers!.complete();
        unawaited(retrying);
        await tester.pump(SessionController.leastPressedCheck);
        expect(reported.single.exception, isA<StateError>());
        expect(
          current(c),
          isA<SessionUnreachable>()
              .having((SessionUnreachable s) => s.retrying, 'retrying', isFalse)
              .having(
                (SessionUnreachable s) => s.cause,
                'cause',
                UnreachableCause.offline,
              ),
          reason: 'the retry screen is offered again',
        );
        expect(
          tokens.tokens[SessionSlot.staff],
          's',
          reason: 'the token stays',
        );

        repository.holdAnswers = null;
        repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
        unawaited(controller(c).retry());
        await tester.pump(SessionController.leastPressedCheck);
        expect(current(c), isA<SignedIn>());
      },
    );

    test('a session the server cannot confirm keeps its token and the whole bootstrap waits, so no stored session is ever shown as absent', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      repository.identities[SessionSlot.customer] = refusal(
        503,
        'service_unavailable',
      );
      final ProviderContainer c = container();

      final SessionState state = await bootstrap(c);
      expect(state, isA<SessionUnreachable>());
      expect((state as SessionUnreachable).cause, UnreachableCause.server);
      expect(tokens.tokens.keys, containsAll(SessionSlot.values));
    });
  });

  group('confirming the stored sessions (DL-136)', () {
    final DateTime start = DateTime.utc(2026, 11, 16, 10);

    /// Runs [body] in fake time with a clock that follows it; the widget
    /// test also fails when a timer is still pending at the end.
    void checking(
      String name,
      Future<void> Function(
        WidgetTester tester,
        ProviderContainer c,
        SessionController Function() session,
      )
      body,
    ) {
      testWidgets(name, (WidgetTester tester) async {
        final DateTime began = tester.binding.clock.now();
        final ProviderContainer c = container(
          clock: () => start.add(tester.binding.clock.now().difference(began)),
        );
        await body(tester, c, () => controller(c));
      });
    }

    SessionUnreachable unreachable(ProviderContainer c) =>
        current(c) as SessionUnreachable;

    Future<void> begin(WidgetTester tester, ProviderContainer c) async {
      c.read(sessionControllerProvider);
      await tester.pump();
    }

    void bothTokens() {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
    }

    checking('both slots are asked at once', (tester, c, session) async {
      bothTokens();
      repository.holdMe[SessionSlot.staff] = Completer<void>();
      repository.holdMe[SessionSlot.customer] = Completer<void>();
      repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
      repository.identities[SessionSlot.customer] = user(id: 'c');

      await begin(tester, c);

      expect(repository.calls, <String>['me:staff', 'me:customer']);
      for (final Completer<void> hold in repository.holdMe.values) {
        hold.complete();
      }
      await tester.pump();
      expect(current(c), isA<SignedIn>());
    });

    checking(
      'the cap keeps every token and a late refusal clears only its slot',
      (tester, c, session) async {
        bothTokens();
        repository.holdMe[SessionSlot.staff] = Completer<void>();
        repository.holdMe[SessionSlot.customer] = Completer<void>();
        repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
        repository.identities[SessionSlot.customer] = refusal(
          401,
          'authentication_required',
        );
        await begin(tester, c);

        await tester.pump(const Duration(seconds: 7, milliseconds: 999));
        expect(c.read(sessionControllerProvider).isLoading, isTrue);
        await tester.pump(const Duration(milliseconds: 1));

        expect(unreachable(c).cause, UnreachableCause.offline);
        expect(tokens.tokens.keys, containsAll(SessionSlot.values));

        await tester.pump(const Duration(seconds: 1));
        repository.holdMe[SessionSlot.customer]!.complete();
        await tester.pump();

        expect(tokens.tokens.keys, <SessionSlot>[SessionSlot.staff]);
        expect(current(c), isA<SessionUnreachable>());
      },
    );

    checking('a refusal that comes late keeps a newer token of its slot', (
      tester,
      c,
      session,
    ) async {
      bothTokens();
      repository.holdMe[SessionSlot.customer] = Completer<void>();
      repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
      repository.identities[SessionSlot.customer] = refusal(
        401,
        'authentication_required',
      );
      await begin(tester, c);
      await tester.pump(SessionController.checkCap);

      tokens.tokens[SessionSlot.customer] = 'c2';
      repository.holdMe[SessionSlot.customer]!.complete();
      await tester.pump();

      expect(tokens.tokens[SessionSlot.customer], 'c2');
    });

    checking('an answer after the cap opens the app by itself', (
      tester,
      c,
      session,
    ) async {
      bothTokens();
      repository.holdMe[SessionSlot.staff] = Completer<void>();
      repository.holdMe[SessionSlot.customer] = Completer<void>();
      repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
      repository.identities[SessionSlot.customer] = user(id: 'c');
      await begin(tester, c);

      await tester.pump(SessionController.checkCap);
      expect(current(c), isA<SessionUnreachable>());

      await tester.pump(const Duration(seconds: 2));
      for (final Completer<void> hold in repository.holdMe.values) {
        hold.complete();
      }
      await tester.pump();

      expect(current(c), isA<SignedIn>());
    });

    checking('a late failure after the cap changes nothing', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.holdMe[SessionSlot.staff] = Completer<void>();
      repository.identities[SessionSlot.staff] = refusal(500, 'server_error');
      await begin(tester, c);
      await tester.pump(SessionController.checkCap);
      final SessionUnreachable before = unreachable(c);

      repository.holdMe[SessionSlot.staff]!.complete();
      await tester.pump();

      expect(unreachable(c), same(before));
      expect(tokens.tokens[SessionSlot.staff], 's');
    });

    checking('a late answer while a pressed check is held opens the app once', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.holdMe[SessionSlot.staff] = Completer<void>();
      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      await begin(tester, c);
      await tester.pump(SessionController.checkCap);

      final List<SessionState> seen = <SessionState>[];
      c.listen<AsyncValue<SessionState>>(sessionControllerProvider, (_, next) {
        final SessionState? value = next.value;
        if (value != null) {
          seen.add(value);
        }
      });
      unawaited(session().retry());
      await tester.pump(const Duration(milliseconds: 100));
      repository.holdMe[SessionSlot.staff]!.complete();
      await tester.pump(const Duration(seconds: 1));

      expect(current(c), isA<SignedIn>());
      expect(seen.whereType<SignedIn>(), hasLength(1));
      repository.calls.clear();
      unawaited(session().retry());
      await tester.pump(const Duration(seconds: 1));
      expect(repository.calls, isEmpty, reason: 'no check is left held');
    });

    group('a start that threw', () {
      checking('is retried by a press', (tester, c, session) async {
        final ThrowingFirstReadStore store = ThrowingFirstReadStore()
          ..tokens[SessionSlot.staff] = 's';
        tokens = store;
        repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
        final ProviderContainer own = container();
        await begin(tester, own);
        expect(own.read(sessionControllerProvider).hasError, isTrue);

        unawaited(controller(own).retry());
        await tester.pump(SessionController.leastPressedCheck);

        expect(own.read(sessionControllerProvider).value, isA<SignedIn>());
      });

      checking('is retried by a quiet check', (tester, c, session) async {
        final ThrowingFirstReadStore store = ThrowingFirstReadStore()
          ..tokens[SessionSlot.staff] = 's';
        tokens = store;
        repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
        final ProviderContainer own = container();
        await begin(tester, own);

        unawaited(controller(own).retry(quiet: true));
        await tester.pump();

        expect(own.read(sessionControllerProvider).value, isA<SignedIn>());
      });
    });

    group('an answer that is not a user', () {
      final Map<String, (Object, UnreachableCause)> cases =
          <String, (Object, UnreachableCause)>{
            'an error answer': (
              refusal(500, 'server_error'),
              UnreachableCause.server,
            ),
            'an unreadable answer': (
              const MalformedResponseFailure(),
              UnreachableCause.server,
            ),
            'no answer': (const NetworkFailure(), UnreachableCause.offline),
          };
      for (final MapEntry<String, (Object, UnreachableCause)> entry
          in cases.entries) {
        checking('${entry.key} is ${entry.value.$2.name}', (
          tester,
          c,
          session,
        ) async {
          tokens.tokens[SessionSlot.staff] = 's';
          repository.identities[SessionSlot.staff] = entry.value.$1;

          await begin(tester, c);

          expect(unreachable(c).cause, entry.value.$2);
          expect(tokens.tokens[SessionSlot.staff], 's');
        });
      }
    });

    checking(
      'a refusal on one slot and a user on the other signs in with that one',
      (tester, c, session) async {
        bothTokens();
        repository.identities[SessionSlot.staff] = refusal(
          401,
          'authentication_required',
        );
        repository.identities[SessionSlot.customer] = user(id: 'c');

        await begin(tester, c);

        final SignedIn state = current(c) as SignedIn;
        expect(state.activeMode, SessionMode.customer);
        expect(state.staffUser, isNull);
        expect(tokens.tokens.keys, <SessionSlot>[SessionSlot.customer]);
      },
    );

    checking('a pressed retry holds 0.8 s and stamps the time when it fails', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      await begin(tester, c);
      expect(unreachable(c).checkedAt, isNull);

      repository.holdMe[SessionSlot.staff] = Completer<void>();
      unawaited(session().retry());
      await tester.pump();
      expect(unreachable(c).retrying, isTrue);

      await tester.pump(const Duration(milliseconds: 50));
      repository.holdMe[SessionSlot.staff]!.complete();
      await tester.pump(const Duration(milliseconds: 749));
      expect(unreachable(c).retrying, isTrue, reason: 'held until 0.8 s');

      await tester.pump(const Duration(milliseconds: 1));
      expect(unreachable(c).retrying, isFalse);
      expect(unreachable(c).cause, UnreachableCause.offline);
      expect(
        unreachable(c).checkedAt,
        start.add(const Duration(milliseconds: 800)),
      );
    });

    checking('a pressed retry that succeeds still holds 0.8 s', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      await begin(tester, c);

      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      unawaited(session().retry());
      await tester.pump(const Duration(milliseconds: 799));
      expect(unreachable(c).retrying, isTrue);

      await tester.pump(const Duration(milliseconds: 1));
      expect(current(c), isA<SignedIn>());
    });

    checking('a quiet retry shows nothing and refreshes only a shown time', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      await begin(tester, c);

      final List<bool> retrying = <bool>[];
      c.listen<AsyncValue<SessionState>>(sessionControllerProvider, (_, next) {
        final SessionState? value = next.value;
        if (value is SessionUnreachable) {
          retrying.add(value.retrying);
        }
      });

      repository.holdMe[SessionSlot.staff] = Completer<void>();
      unawaited(session().retry(quiet: true));
      await tester.pump();
      expect(retrying, isEmpty, reason: 'nothing changes while it runs');

      repository.holdMe[SessionSlot.staff]!.complete();
      await tester.pump();
      expect(unreachable(c).checkedAt, isNull, reason: 'none was shown');
      expect(retrying, everyElement(isFalse));

      unawaited(session().retry());
      await tester.pump(SessionController.leastPressedCheck);
      final DateTime shown = unreachable(c).checkedAt!;

      await tester.pump(const Duration(seconds: 5));
      unawaited(session().retry(quiet: true));
      await tester.pump();
      expect(
        unreachable(c).checkedAt,
        start.add(const Duration(milliseconds: 5800)),
      );
      expect(unreachable(c).checkedAt, isNot(shown));
      expect(unreachable(c).retrying, isFalse);
    });

    checking('a pressed retry joins a quiet check and holds 0.8 s', (
      tester,
      c,
      session,
    ) async {
      bothTokens();
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      repository.identities[SessionSlot.customer] = const NetworkFailure();
      await begin(tester, c);
      repository.calls.clear();

      repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
      repository.identities[SessionSlot.customer] = user(id: 'c');
      repository.holdMe[SessionSlot.staff] = Completer<void>();
      unawaited(session().retry(quiet: true));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));
      unawaited(session().retry());
      await tester.pump();
      expect(unreachable(c).retrying, isTrue);

      await tester.pump(const Duration(milliseconds: 100));
      repository.holdMe[SessionSlot.staff]!.complete();
      await tester.pump(const Duration(milliseconds: 699));
      expect(unreachable(c).retrying, isTrue, reason: '0.8 s from the press');

      await tester.pump(const Duration(milliseconds: 1));
      expect(current(c), isA<SignedIn>());
      expect(repository.meCalls(SessionSlot.staff), 1);
      expect(repository.meCalls(SessionSlot.customer), 1);
    });

    checking('a rebuilt provider retries as the first one did', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      await begin(tester, c);

      c.invalidate(sessionControllerProvider);
      await begin(tester, c);
      expect(current(c), isA<SessionUnreachable>());

      unawaited(session().retry());
      await tester.pump(SessionController.leastPressedCheck);

      expect(unreachable(c).retrying, isFalse);
      expect(unreachable(c).checkedAt, isNotNull);
    });

    checking('a retry does nothing unless the state is unreachable', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      await begin(tester, c);
      repository.calls.clear();

      unawaited(session().retry());
      await tester.pump(const Duration(seconds: 1));

      expect(repository.calls, isEmpty);
      expect(current(c), isA<SignedIn>());
    });

    checking('disposing mid-check leaves no timer', (tester, c, session) async {
      bothTokens();
      repository.holdMe[SessionSlot.staff] = Completer<void>();
      repository.holdMe[SessionSlot.customer] = Completer<void>();
      repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
      repository.identities[SessionSlot.customer] = user(id: 'c');
      await begin(tester, c);

      c.dispose();
    });

    checking('disposing mid pressed check leaves no timer', (
      tester,
      c,
      session,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      await begin(tester, c);
      repository.holdMe[SessionSlot.staff] = Completer<void>();
      unawaited(session().retry());
      await tester.pump();

      c.dispose();
    });
  });

  group('logins', () {
    test('beforeOpen runs before the state changes (DL-139)', () async {
      repository.verifyResult = IssuedSession(
        token: 'c',
        user: user(id: 'c'),
      );
      final ProviderContainer c = container();
      await bootstrap(c);
      SessionState? seenInHook;
      String? tokenInHook;

      await controller(c).verifyCustomerCode(
        phone: '+998901234567',
        code: '000000',
        beforeOpen: () async {
          seenInHook = current(c);
          tokenInHook = tokens.tokens[SessionSlot.customer];
        },
      );

      expect(repository.calls, contains('verify:+998901234567:000000'));
      expect(seenInHook, isA<SignedOut>());
      expect(tokenInHook, isNull);
      expect(current(c), isA<SignedIn>());
      expect(tokens.tokens[SessionSlot.customer], 'c');
    });

    test(
      'staff login stores the token in the staff slot and opens the staff mode',
      () async {
        repository.staffLoginResult = IssuedSession(
          token: 'new-staff',
          user: user(role: UserRole.operator),
        );
        final ProviderContainer c = container();
        await bootstrap(c);

        await controller(c).staffLogin(phone: '+998901234567', password: 'p');

        expect(tokens.tokens[SessionSlot.staff], 'new-staff');
        final SignedIn state = current(c) as SignedIn;
        expect(state.activeMode, SessionMode.staff);
        expect(state.staffUser?.role, UserRole.operator);
      },
    );

    test('a refused staff login changes nothing', () async {
      repository.staffLoginFailure = refusal(401, 'invalid_credentials');
      final ProviderContainer c = container();
      await bootstrap(c);

      await expectLater(
        controller(c).staffLogin(phone: '+998901234567', password: 'p'),
        throwsA(isA<ApiRefusal>()),
      );

      expect(tokens.tokens, isEmpty);
      expect(current(c), isA<SignedOut>());
    });

    test('a login after an unreachable start confirms the other stored session too', () async {
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = const NetworkFailure();
      final ProviderContainer c = container();
      expect(await bootstrap(c), isA<SessionUnreachable>());

      repository.identities[SessionSlot.customer] = user(id: 'c');
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      repository.staffLoginResult = IssuedSession(
        token: 's',
        user: user(id: 's', role: UserRole.courier),
      );

      await controller(c).staffLogin(phone: '+998901234567', password: 'p');

      final SignedIn state = current(c) as SignedIn;
      expect(state.activeMode, SessionMode.staff);
      expect(state.staffUser?.id, 's');
      expect(state.customerUser?.id, 'c', reason: 'confirmed, not hidden');
      expect(tokens.tokens.keys, containsAll(SessionSlot.values));
    });

    test('a customer code without a staff step opens a customer session and nothing more', () async {
      repository.verifyResult = IssuedSession(
        token: 'new-customer',
        user: user(id: 'c'),
      );
      final ProviderContainer c = container();
      await bootstrap(c);

      await controller(c)
          .verifyCustomerCode(phone: '+998901234567', code: '000000');

      expect(tokens.tokens[SessionSlot.customer], 'new-customer');
      final SignedIn state = current(c) as SignedIn;
      expect(state.activeMode, SessionMode.customer);
      expect(state.staffStep, isNull);
      expect(state.staffUser, isNull);
    });

    test('a customer code with a staff step keeps the customer session and holds the step', () async {
      final ProviderContainer c = await withPendingStep();

      expect(tokens.tokens[SessionSlot.customer], 'new-customer');
      expect(tokens.tokens.containsKey(SessionSlot.staff), isFalse);
      final SignedIn state = current(c) as SignedIn;
      expect(state.activeMode, SessionMode.customer);
      expect(state.customerUser?.id, 'c');
      expect(state.staffStep, same(step));
    });

    test('completing the staff step stores the staff token, activates staff and keeps both users', () async {
      final ProviderContainer c = await withPendingStep();
      repository.staffStepResult = IssuedSession(
        token: 'new-staff',
        user: user(id: 's', role: UserRole.courier),
      );

      await controller(c).completeStaffStep('secret');

      expect(repository.calls, contains('step:${step.token}'));
      expect(tokens.tokens[SessionSlot.staff], 'new-staff');
      expect(tokens.tokens[SessionSlot.customer], 'new-customer');
      final SignedIn state = current(c) as SignedIn;
      expect(state.activeMode, SessionMode.staff);
      expect(state.staffUser?.id, 's');
      expect(state.customerUser?.id, 'c');
      expect(state.staffStep, isNull);
    });

    test(
      'a refused password keeps the step so the person may try again',
      () async {
        final ProviderContainer c = await withPendingStep();
        repository.staffStepFailure = refusal(401, 'invalid_credentials');

        await expectLater(
          controller(c).completeStaffStep('wrong'),
          throwsA(isA<ApiRefusal>()),
        );

        final SignedIn state = current(c) as SignedIn;
        expect(state.staffStep, same(step));
        expect(state.activeMode, SessionMode.customer);
        expect(tokens.tokens.containsKey(SessionSlot.staff), isFalse);
      },
    );

    for (final String code in <String>[
      'staff_step_expired',
      'staff_step_invalid',
    ]) {
      test('$code clears the step and the person stays the customer', () async {
        final ProviderContainer c = await withPendingStep();
        repository.staffStepFailure = refusal(401, code);

        await expectLater(
          controller(c).completeStaffStep('secret'),
          throwsA(
            isA<ApiRefusal>().having((ApiRefusal f) => f.code, 'code', code),
          ),
        );

        final SignedIn state = current(c) as SignedIn;
        expect(state.staffStep, isNull);
        expect(state.activeMode, SessionMode.customer);
        expect(tokens.tokens.containsKey(SessionSlot.staff), isFalse);
      });
    }

    test('dismissing the step leaves the customer session', () async {
      final ProviderContainer c = await withPendingStep();

      controller(c).dismissStaffStep();

      final SignedIn state = current(c) as SignedIn;
      expect(state.staffStep, isNull);
      expect(state.activeMode, SessionMode.customer);
      expect(state.customerUser?.id, 'c');
    });

    test('a staff answer that arrives after the customer session was dropped is discarded', () async {
      final ProviderContainer c = await withPendingStep();
      repository.staffStepResult = IssuedSession(
        token: 'late-staff',
        user: user(id: 's', role: UserRole.courier),
      );
      repository.holdAnswers = Completer<void>();

      final Future<void> pending = controller(c).completeStaffStep('secret');
      await settle();
      await controller(c).dropSession(SessionSlot.customer);
      repository.holdAnswers!.complete();
      await pending;

      expect(current(c), isA<SignedOut>());
      expect(tokens.tokens, isEmpty);
    });

    test(
      'switching to customer needs no code once the customer session exists',
      () async {
        final ProviderContainer c = await withPendingStep();
        repository.staffStepResult = IssuedSession(
          token: 'new-staff',
          user: user(id: 's', role: UserRole.shopper),
        );
        await controller(c).completeStaffStep('secret');

        controller(c).switchMode(SessionMode.customer);

        final SignedIn state = current(c) as SignedIn;
        expect(state.activeMode, SessionMode.customer);
        expect(state.staffUser?.id, 's');
        expect(
          repository.calls.where((String x) => x.startsWith('request:')),
          isEmpty,
        );
        expect(controller(c).activeSlot, SessionSlot.customer);
      },
    );

    test('logging out of the staff slot keeps the customer', () async {
      final ProviderContainer c = await withPendingStep();
      repository.staffStepResult = IssuedSession(
        token: 'new-staff',
        user: user(id: 's', role: UserRole.shopper),
      );
      await controller(c).completeStaffStep('secret');

      await controller(c).logout(SessionMode.staff);

      final SignedIn state = current(c) as SignedIn;
      expect(state.activeMode, SessionMode.customer);
      expect(state.staffUser, isNull);
      expect(tokens.tokens[SessionSlot.customer], 'new-customer');
    });

    test(
      'replacing the customer user refreshes it, for the same account only',
      () async {
        repository.verifyResult = IssuedSession(
          token: 'new-customer',
          user: user(id: 'c', fullName: null),
        );
        final ProviderContainer c = container();
        await bootstrap(c);
        await controller(c)
            .verifyCustomerCode(phone: '+998901234567', code: '000000');

        controller(c).replaceCustomerUser(user(id: 'other', fullName: 'Other'));
        expect((current(c) as SignedIn).customerUser?.fullName, isNull);

        controller(c).replaceCustomerUser(user(id: 'c', fullName: 'Aziza'));
        expect((current(c) as SignedIn).customerUser?.fullName, 'Aziza');
      },
    );

    test('switching to a mode that has no session does nothing', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.shopper);
      final ProviderContainer c = container();
      await bootstrap(c);

      controller(c).switchMode(SessionMode.customer);

      expect((current(c) as SignedIn).activeMode, SessionMode.staff);
    });
  });

  group('logout and dropped sessions', () {
    test(
      'logging out of one mode leaves the other, which becomes active',
      () async {
        tokens.tokens[SessionSlot.staff] = 's';
        tokens.tokens[SessionSlot.customer] = 'c';
        repository.identities[SessionSlot.staff] = user(
          id: 's',
          role: UserRole.courier,
        );
        repository.identities[SessionSlot.customer] = user(id: 'c');
        final ProviderContainer c = container();
        await bootstrap(c);
        controller(c).switchMode(SessionMode.customer);

        await controller(c).logout(SessionMode.customer);

        expect(repository.calls, contains('logout:customer'));
        expect(tokens.tokens.keys, <SessionSlot>[SessionSlot.staff]);
        final SignedIn state = current(c) as SignedIn;
        expect(state.activeMode, SessionMode.staff);
        expect(state.customerUser, isNull);
      },
    );

    test('logging out of the only session signs the app out even when the server cannot be reached', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      repository.logoutFailure = const NetworkFailure();
      final ProviderContainer c = container();
      await bootstrap(c);

      await controller(c).logout(SessionMode.staff);

      expect(tokens.tokens, isEmpty);
      expect(current(c), isA<SignedOut>());
    });

    test(
      'a session the interceptor saw refused is dropped without a server call',
      () async {
        tokens.tokens[SessionSlot.staff] = 's';
        tokens.tokens[SessionSlot.customer] = 'c';
        repository.identities[SessionSlot.staff] = user(
          id: 's',
          role: UserRole.shopper,
        );
        repository.identities[SessionSlot.customer] = user(id: 'c');
        final ProviderContainer c = container();
        await bootstrap(c);
        repository.calls.clear();

        await controller(c).dropSession(SessionSlot.staff);

        expect(repository.calls, isEmpty);
        expect(tokens.tokens.keys, <SessionSlot>[SessionSlot.customer]);
        expect((current(c) as SignedIn).activeMode, SessionMode.customer);
      },
    );
  });

  group('password and language', () {
    test('a password change clears the gate on the staff user', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = user(id: 'c');
      repository.identities[SessionSlot.staff] = user(
        role: UserRole.shopper,
        mustChangePassword: true,
      );
      final ProviderContainer c = container();
      await bootstrap(c);
      expect((current(c) as SignedIn).canOfferCustomerMode, isFalse);

      await controller(c).changePassword(
        currentPassword: 'temporary 123',
        newPassword: 'brand new pass',
        newPasswordConfirmation: 'brand new pass',
      );

      expect(repository.calls, contains('change-password:staff'));
      final SignedIn state = current(c) as SignedIn;
      expect(state.staffUser?.mustChangePassword, isFalse);
      expect(state.canOfferCustomerMode, isTrue);
    });

    test('a password answer that arrives after the staff session was dropped does not bring it back', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(
        role: UserRole.shopper,
        mustChangePassword: true,
      );
      final ProviderContainer c = container();
      await bootstrap(c);
      repository.holdAnswers = Completer<void>();

      final Future<void> change = controller(c).changePassword(
        currentPassword: 'temporary 123',
        newPassword: 'brand new pass',
        newPasswordConfirmation: 'brand new pass',
      );
      await settle();
      await controller(c).dropSession(SessionSlot.staff);
      repository.holdAnswers!.complete();
      await change;

      expect(current(c), isA<SignedOut>());
    });

    test('a language is reported for every confirmed session', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      repository.identities[SessionSlot.customer] = user(id: 'c');
      final ProviderContainer c = container();
      await bootstrap(c);

      await c.read(languageControllerProvider.notifier).select(AppLanguage.ru);

      expect(
        repository.reportedLanguages.map((r) => r.$1),
        containsAll(<SessionSlot>[SessionSlot.staff, SessionSlot.customer]),
      );
      final SignedIn state = current(c) as SignedIn;
      expect(state.staffUser?.preferredLanguage, AppLanguage.ru);
      expect(state.customerUser?.preferredLanguage, AppLanguage.ru);
    });

    test('a language the server fails to take for one session is kept on the device, and that session keeps its old language', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      repository.identities[SessionSlot.customer] = user(id: 'c');
      repository.updateLanguageFailures[SessionSlot.customer] =
          const NetworkFailure();
      final ProviderContainer c = container();
      await bootstrap(c);

      await c.read(languageControllerProvider.notifier).select(AppLanguage.ru);

      expect(c.read(languageControllerProvider).value, AppLanguage.ru);
      final SignedIn state = current(c) as SignedIn;
      expect(state.staffUser?.preferredLanguage, AppLanguage.ru);
      expect(state.customerUser?.preferredLanguage, AppLanguage.uz);
    });

    test('a language answer that arrives after its session was dropped is discarded', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
      repository.identities[SessionSlot.customer] = user(id: 'c');
      final ProviderContainer c = container();
      await bootstrap(c);
      repository.holdAnswers = Completer<void>();

      final Future<void> select = c
          .read(languageControllerProvider.notifier)
          .select(AppLanguage.ru);
      await settle();
      await controller(c).dropSession(SessionSlot.staff);
      repository.holdAnswers!.complete();
      await select;

      final SignedIn state = current(c) as SignedIn;
      expect(state.staffUser, isNull, reason: 'not brought back');
      expect(state.activeMode, SessionMode.customer);
      expect(state.customerUser?.preferredLanguage, AppLanguage.ru);
    });
  });
}

/// A token store whose very first read fails, like a platform channel that
/// is not ready.
class ThrowingFirstReadStore extends InMemoryTokenStore {
  bool _failed = false;

  @override
  Future<String?> read(SessionSlot slot) async {
    if (!_failed) {
      _failed = true;
      throw StateError('storage not ready');
    }
    return super.read(slot);
  }
}
