import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/routing/session_redirect.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  String? redirect(
    AsyncValue<SessionState> session,
    String location, {
    Surface surface = Surface.mobile,
  }) => sessionRedirect(session: session, surface: surface, location: location);

  const AsyncValue<SessionState> signedOut = AsyncData<SessionState>(
    SignedOut(),
  );

  AsyncValue<SessionState> signedIn({
    AppUser? staff,
    AppUser? customer,
    SessionMode? active,
  }) => AsyncData<SessionState>(
    SignedIn(
      activeMode:
          active ?? (staff != null ? SessionMode.staff : SessionMode.customer),
      staffUser: staff,
      customerUser: customer,
    ),
  );

  group('before the bootstrap answers', () {
    test('everything waits on the bootstrap screen', () {
      const AsyncValue<SessionState> loading = AsyncLoading<SessionState>();

      expect(redirect(loading, AppPaths.bootstrap), isNull);
      expect(redirect(loading, AppPaths.customer), AppPaths.bootstrap);
      expect(redirect(loading, AppPaths.auth), AppPaths.bootstrap);
    });

    test('a bootstrap that threw offers the retry screen, not a spinner', () {
      final AsyncValue<SessionState> failed = AsyncError<SessionState>(
        StateError('boom'),
        StackTrace.empty,
      );

      expect(redirect(failed, AppPaths.bootstrap), AppPaths.unreachable);
      expect(redirect(failed, AppPaths.unreachable), isNull);
    });
  });

  group('signed out', () {
    test('only the public auth screens are reachable', () {
      for (final String public in <String>[
        AppPaths.auth,
        AppPaths.customerCode,
        AppPaths.staffLogin,
      ]) {
        expect(redirect(signedOut, public), isNull, reason: public);
      }
      for (final String closed in <String>[
        AppPaths.bootstrap,
        AppPaths.customer,
        AppPaths.admin,
        AppPaths.changePassword,
        AppPaths.customerMode,
        AppPaths.wrongSurface,
        AppPaths.unreachable,
        '/customer/orders',
      ]) {
        expect(redirect(signedOut, closed), AppPaths.auth, reason: closed);
      }
    });
  });

  group('unreachable', () {
    test('only the retry screen is reachable and the tokens stay', () {
      const AsyncValue<SessionState> unreachable = AsyncData<SessionState>(
        SessionUnreachable(),
      );

      expect(redirect(unreachable, AppPaths.unreachable), isNull);
      expect(redirect(unreachable, AppPaths.auth), AppPaths.unreachable);
      expect(redirect(unreachable, AppPaths.shopper), AppPaths.unreachable);
    });
  });

  group('signed in', () {
    test('each role is sent to its own area and nowhere else', () {
      final Map<UserRole, String> areas = <UserRole, String>{
        UserRole.customer: AppPaths.customer,
        UserRole.shopper: AppPaths.shopper,
        UserRole.courier: AppPaths.courier,
        UserRole.operator: AppPaths.operations,
        UserRole.admin: AppPaths.admin,
        UserRole.manager: AppPaths.manager,
      };

      for (final MapEntry<UserRole, String> entry in areas.entries) {
        final AsyncValue<SessionState> session = entry.key == UserRole.customer
            ? signedIn(customer: user(role: entry.key))
            : signedIn(staff: user(role: entry.key));
        final Surface surface = entry.key.surface;

        expect(
          redirect(session, AppPaths.bootstrap, surface: surface),
          entry.value,
          reason: '${entry.key} from bootstrap',
        );
        expect(
          redirect(session, AppPaths.auth, surface: surface),
          entry.value,
          reason: '${entry.key} from the login',
        );
        expect(
          redirect(session, entry.value, surface: surface),
          isNull,
          reason: '${entry.key} in its area',
        );
        expect(
          redirect(session, '${entry.value}/anything', surface: surface),
          isNull,
          reason: '${entry.key} inside its area',
        );
        for (final String other in areas.values) {
          if (other != entry.value) {
            expect(
              redirect(session, other, surface: surface),
              entry.value,
              reason: '${entry.key} typing $other',
            );
          }
        }
      }
    });

    test('a role on the wrong surface sees only the surface screen', () {
      final AsyncValue<SessionState> admin = signedIn(
        staff: user(role: UserRole.admin),
      );
      final AsyncValue<SessionState> shopper = signedIn(
        staff: user(role: UserRole.shopper),
      );

      expect(
        redirect(admin, AppPaths.admin, surface: Surface.mobile),
        AppPaths.wrongSurface,
      );
      expect(
        redirect(admin, AppPaths.wrongSurface, surface: Surface.mobile),
        isNull,
      );
      expect(
        redirect(shopper, AppPaths.shopper, surface: Surface.web),
        AppPaths.wrongSurface,
      );
      expect(
        redirect(shopper, AppPaths.wrongSurface, surface: Surface.mobile),
        AppPaths.shopper,
        reason: 'the right surface leaves the screen at once',
      );
    });

    test('the first-login gate admits only the password change', () {
      final AsyncValue<SessionState> gated = signedIn(
        staff: user(role: UserRole.courier, mustChangePassword: true),
      );

      expect(redirect(gated, AppPaths.courier), AppPaths.changePassword);
      expect(redirect(gated, AppPaths.changePassword), isNull);
      expect(redirect(gated, AppPaths.customerMode), AppPaths.changePassword);
      expect(
        redirect(gated, AppPaths.admin, surface: Surface.web),
        AppPaths.wrongSurface,
        reason: 'the surface is checked before the gate',
      );
    });

    test('the Customer-mode entry is open to a Shopper or Courier without a customer session', () {
      expect(
        redirect(
          signedIn(staff: user(role: UserRole.shopper)),
          AppPaths.customerMode,
        ),
        isNull,
      );
      expect(
        redirect(
          signedIn(staff: user(role: UserRole.admin)),
          AppPaths.customerMode,
          surface: Surface.web,
        ),
        AppPaths.admin,
        reason: 'an Admin has no Customer mode',
      );
      expect(
        redirect(
          signedIn(
            staff: user(id: 's', role: UserRole.shopper),
            customer: user(id: 'c'),
          ),
          AppPaths.customerMode,
        ),
        AppPaths.shopper,
        reason: 'with a customer session the switch needs no code',
      );
      expect(
        redirect(
          signedIn(
            staff: user(id: 's', role: UserRole.shopper),
            customer: user(id: 'c'),
            active: SessionMode.customer,
          ),
          AppPaths.customerMode,
        ),
        AppPaths.customer,
        reason: 'not from Customer mode itself',
      );
    });

    test('the active mode decides the area when two sessions exist', () {
      final AppUser staff = user(id: 's', role: UserRole.courier);
      final AppUser customer = user(id: 'c');

      expect(
        redirect(signedIn(staff: staff, customer: customer), AppPaths.customer),
        AppPaths.courier,
      );
      expect(
        redirect(
          signedIn(
            staff: staff,
            customer: customer,
            active: SessionMode.customer,
          ),
          AppPaths.courier,
        ),
        AppPaths.customer,
      );
    });
  });
}
