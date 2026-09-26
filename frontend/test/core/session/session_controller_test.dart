import 'dart:ui' show Locale;

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_controller.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/in_memory_stores.dart';

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

  Future<SessionState> bootstrap(ProviderContainer c) =>
      c.read(sessionControllerProvider.future);

  SessionController controller(ProviderContainer c) =>
      c.read(sessionControllerProvider.notifier);

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

      expect(c.read(sessionControllerProvider).value, isA<SignedIn>());
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
        final SignedIn state =
            c.read(sessionControllerProvider).value as SignedIn;
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
      expect(c.read(sessionControllerProvider).value, isA<SignedOut>());
    });

    test('verifying a customer code from the staff interface adds the customer session and switches to it', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.shopper,
      );
      repository.verifyResult = IssuedSession(
        token: 'new-customer',
        user: user(id: 'c'),
      );
      final ProviderContainer c = container();
      await bootstrap(c);

      await controller(c)
          .verifyCustomerCode(phone: '+998901234567', code: '000000');

      expect(tokens.tokens[SessionSlot.customer], 'new-customer');
      SignedIn state = c.read(sessionControllerProvider).value as SignedIn;
      expect(state.activeMode, SessionMode.customer);
      expect(state.staffUser?.id, 's', reason: 'the staff session is kept');

      controller(c).switchMode(SessionMode.staff);
      state = c.read(sessionControllerProvider).value as SignedIn;
      expect(state.activeMode, SessionMode.staff);
      expect(controller(c).activeSlot, SessionSlot.staff);
    });

    test('switching to a mode that has no session does nothing', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.shopper);
      final ProviderContainer c = container();
      await bootstrap(c);

      controller(c).switchMode(SessionMode.customer);

      expect(
        (c.read(sessionControllerProvider).value as SignedIn).activeMode,
        SessionMode.staff,
      );
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
        final SignedIn state =
            c.read(sessionControllerProvider).value as SignedIn;
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
      expect(c.read(sessionControllerProvider).value, isA<SignedOut>());
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
        expect(
          (c.read(sessionControllerProvider).value as SignedIn).activeMode,
          SessionMode.customer,
        );
      },
    );
  });

  group('password and language', () {
    test('a password change clears the gate on the staff user', () async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(
        role: UserRole.shopper,
        mustChangePassword: true,
      );
      final ProviderContainer c = container();
      await bootstrap(c);
      expect(
        (c.read(sessionControllerProvider).value as SignedIn)
            .canOfferCustomerMode,
        isFalse,
      );

      await controller(c).changePassword(
        currentPassword: 'temporary 123',
        newPassword: 'brand new pass',
      );

      expect(repository.calls, contains('change-password:staff'));
      final SignedIn state =
          c.read(sessionControllerProvider).value as SignedIn;
      expect(state.staffUser?.mustChangePassword, isFalse);
      expect(state.canOfferCustomerMode, isTrue);
    });

    test('a language is reported for every confirmed session and kept when the server fails', () async {
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
      final SignedIn state =
          c.read(sessionControllerProvider).value as SignedIn;
      expect(state.staffUser?.preferredLanguage.code, 'ru');
      expect(state.customerUser?.preferredLanguage.code, 'ru');
    });
  });
}
