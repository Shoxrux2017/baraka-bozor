import 'dart:async';
import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
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

    test('an unreachable server keeps the token and can be retried', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      final ProviderContainer c = container();

      expect(await bootstrap(c), isA<SessionUnreachable>());
      expect(
        tokens.tokens[SessionSlot.staff],
        's',
        reason: 'the token is not thrown away',
      );

      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      await controller(c).retry();

      expect(current(c), isA<SignedIn>());
    });

    test('a retry keeps the previous answer while it runs, and a retry that throws leaves a way to retry again', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      final ProviderContainer c = container();
      expect(await bootstrap(c), isA<SessionUnreachable>());

      repository.holdAnswers = Completer<void>();
      final Future<void> retrying = controller(c).retry();
      await settle();
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
      await controller(c).retry();
      expect(repository.calls, isEmpty, reason: 'a second tap waits');

      // No identity configured: the fake throws a plain StateError.
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      repository.identities.remove(SessionSlot.staff);
      repository.holdAnswers!.complete();
      await retrying;
      expect(reported.single.exception, isA<StateError>());
      expect(
        current(c),
        isA<SessionUnreachable>().having(
          (SessionUnreachable s) => s.retrying,
          'retrying',
          isFalse,
        ),
        reason: 'the retry screen is offered again',
      );
      expect(tokens.tokens[SessionSlot.staff], 's', reason: 'the token stays');

      repository.holdAnswers = null;
      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      await controller(c).retry();
      expect(current(c), isA<SignedIn>());
    });

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

      expect(await bootstrap(c), isA<SessionUnreachable>());
      expect(tokens.tokens.keys, containsAll(SessionSlot.values));
    });
  });

  group('logins', () {
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
