import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
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
  }) => sessionRedirect(
    session: session,
    surface: surface,
    uri: Uri.parse(location),
  );

  const AsyncValue<SessionState> signedOut = AsyncData<SessionState>(
    SignedOut(),
  );

  AsyncValue<SessionState> signedIn({
    AppUser? staff,
    AppUser? customer,
    SessionMode? active,
    StaffStep? step,
  }) => AsyncData<SessionState>(
    SignedIn(
      activeMode:
          active ?? (staff != null ? SessionMode.staff : SessionMode.customer),
      staffUser: staff,
      customerUser: customer,
      staffStep: step,
    ),
  );

  final StaffStep pendingStep = StaffStep(
    token: 'a' * 64,
    expiresAt: DateTime.utc(2026, 10, 15, 10, 5),
  );

  // A customer who has already given a name: the name step is behind them.
  AppUser named({String id = 'c'}) => user(id: id, fullName: 'Aziza');

  group('before the bootstrap answers', () {
    test(
      'everything waits on the bootstrap screen, which remembers the page',
      () {
        const AsyncValue<SessionState> loading = AsyncLoading<SessionState>();

        expect(redirect(loading, AppPaths.bootstrap), isNull);
        expect(
          redirect(loading, '${AppPaths.bootstrap}?next=%2Fadmin'),
          isNull,
          reason: 'the remembering bootstrap screen is the bootstrap screen',
        );
        expect(
          redirect(loading, AppPaths.customer),
          '${AppPaths.bootstrap}?next=%2Fcustomer',
        );
        expect(
          redirect(loading, '/admin/products/p-1?page=2'),
          '${AppPaths.bootstrap}?next=%2Fadmin%2Fproducts%2Fp-1%3Fpage%3D2',
        );
        expect(
          redirect(loading, AppPaths.auth),
          '${AppPaths.bootstrap}?next=%2Fauth',
        );
      },
    );

    test('a bootstrap that threw offers the retry screen, not a spinner', () {
      final AsyncValue<SessionState> failed = AsyncError<SessionState>(
        StateError('boom'),
        StackTrace.empty,
      );

      expect(redirect(failed, AppPaths.bootstrap), AppPaths.unreachable);
      expect(redirect(failed, AppPaths.unreachable), isNull);
      expect(
        redirect(failed, '${AppPaths.bootstrap}?next=%2Fadmin%2Fstaff'),
        '${AppPaths.unreachable}?next=%2Fadmin%2Fstaff',
        reason: 'the retry screen keeps the page',
      );
    });
  });

  group('signed out', () {
    test('on mobile only the phone and the code screens are reachable', () {
      for (final String public in <String>[
        AppPaths.auth,
        AppPaths.customerCode,
      ]) {
        expect(redirect(signedOut, public), isNull, reason: public);
      }
      for (final String closed in <String>[
        AppPaths.bootstrap,
        AppPaths.customer,
        AppPaths.admin,
        AppPaths.staffLogin,
        AppPaths.staffPassword,
        AppPaths.customerName,
        AppPaths.changePassword,
        AppPaths.wrongSurface,
        AppPaths.unreachable,
        '/customer/orders',
      ]) {
        expect(redirect(signedOut, closed), AppPaths.auth, reason: closed);
      }
    });

    test(
      'on the web the sign-in is /auth, and the code routes are not reachable',
      () {
        expect(
          redirect(signedOut, AppPaths.auth, surface: Surface.web),
          isNull,
        );
        expect(
          redirect(signedOut, AppPaths.customerCode, surface: Surface.web),
          AppPaths.auth,
        );
        expect(
          redirect(signedOut, AppPaths.staffPassword, surface: Surface.web),
          AppPaths.auth,
        );
        expect(
          redirect(signedOut, AppPaths.customerName, surface: Surface.web),
          AppPaths.auth,
        );
      },
    );
  });

  group('open pages', () {
    const List<String> documents = <String>[
      AppPaths.legalTerms,
      AppPaths.legalPrivacy,
    ];

    test('the documents are open pages', () {
      expect(AppPaths.openPages, containsAll(documents));
      expect(AppPaths.legal(LegalDocumentKind.terms), AppPaths.legalTerms);
      expect(AppPaths.legal(LegalDocumentKind.privacy), AppPaths.legalPrivacy);
    });

    test('they pass signed out on mobile, and the web goes to its sign-in', () {
      for (final String page in documents) {
        expect(redirect(signedOut, page), isNull, reason: page);
        expect(
          redirect(signedOut, page, surface: Surface.web),
          AppPaths.auth,
          reason: '$page on the web',
        );
      }
    });

    test('they pass for a named Customer on mobile', () {
      for (final String page in documents) {
        expect(
          redirect(signedIn(customer: named()), page),
          isNull,
          reason: page,
        );
      }
    });

    test('the other gates still come first', () {
      for (final String page in documents) {
        expect(
          redirect(signedIn(customer: user(id: 'c', fullName: null)), page),
          AppPaths.customerName,
          reason: '$page without a name',
        );
        expect(
          redirect(
            signedIn(staff: user(role: UserRole.admin)),
            page,
            surface: Surface.mobile,
          ),
          AppPaths.wrongSurface,
          reason: '$page on the wrong surface',
        );
      }
      expect(
        redirect(
          signedIn(
            staff: user(role: UserRole.courier, mustChangePassword: true),
          ),
          AppPaths.legalTerms,
        ),
        AppPaths.changePassword,
      );
    });
  });

  group('unreachable', () {
    test('only the retry screen is reachable and the tokens stay', () {
      const AsyncValue<SessionState> unreachable = AsyncData<SessionState>(
        SessionUnreachable(),
      );

      expect(redirect(unreachable, AppPaths.unreachable), isNull);
      expect(
        redirect(unreachable, '${AppPaths.bootstrap}?next=%2Foperations'),
        '${AppPaths.unreachable}?next=%2Foperations',
      );
      expect(
        redirect(unreachable, '${AppPaths.unreachable}?next=%2Foperations'),
        isNull,
      );
      expect(redirect(unreachable, AppPaths.auth), AppPaths.unreachable);
      expect(redirect(unreachable, AppPaths.shopper), AppPaths.unreachable);
    });
  });

  group('signed in', () {
    test('each role lands on its home and moves only inside its areas', () {
      // The Admin lands on the board and works in both the board and its
      // own area; every other role has one area, which is its home.
      final Map<UserRole, (String, List<String>)> roles =
          <UserRole, (String, List<String>)>{
            UserRole.customer: (AppPaths.customer, <String>[AppPaths.customer]),
            UserRole.shopper: (AppPaths.shopper, <String>[AppPaths.shopper]),
            UserRole.courier: (AppPaths.courier, <String>[AppPaths.courier]),
            UserRole.operator: (
              AppPaths.operations,
              <String>[AppPaths.operations],
            ),
            UserRole.admin: (
              AppPaths.operations,
              <String>[AppPaths.admin, AppPaths.operations],
            ),
            UserRole.manager: (AppPaths.manager, <String>[AppPaths.manager]),
          };
      const List<String> everyArea = <String>[
        AppPaths.customer,
        AppPaths.shopper,
        AppPaths.courier,
        AppPaths.operations,
        AppPaths.admin,
        AppPaths.manager,
      ];

      for (final MapEntry<UserRole, (String, List<String>)> entry
          in roles.entries) {
        final UserRole role = entry.key;
        final (String home, List<String> areas) = entry.value;
        final AsyncValue<SessionState> session = role == UserRole.customer
            ? signedIn(
                customer: user(role: role, fullName: 'Aziza'),
              )
            : signedIn(staff: user(role: role));
        final Surface surface = role.surface;

        expect(
          redirect(session, AppPaths.bootstrap, surface: surface),
          home,
          reason: '$role from bootstrap',
        );
        expect(
          redirect(session, AppPaths.auth, surface: surface),
          home,
          reason: '$role from the login',
        );
        for (final String area in everyArea) {
          final bool own = areas.contains(area);
          expect(
            redirect(session, area, surface: surface),
            own ? isNull : home,
            reason: '$role typing $area',
          );
          expect(
            redirect(session, '$area/anything', surface: surface),
            own ? isNull : home,
            reason: '$role typing a page inside $area',
          );
        }
      }
    });

    test('the page a reload asked for opens once the session is known, inside the role\'s areas only', () {
      String? after(UserRole role, String next) => redirect(
        role == UserRole.customer
            ? signedIn(
                customer: user(role: role, fullName: 'Aziza'),
              )
            : signedIn(staff: user(role: role)),
        Uri(
          path: AppPaths.bootstrap,
          queryParameters: <String, String>{'next': next},
        ).toString(),
        surface: role.surface,
      );

      expect(
        after(UserRole.admin, '/admin/products/p-1'),
        '/admin/products/p-1',
      );
      expect(after(UserRole.admin, '/operations'), '/operations');
      expect(
        after(UserRole.operator, '/operations/orders/o-1?tab=history'),
        '/operations/orders/o-1?tab=history',
      );
      expect(
        after(UserRole.customer, AppPaths.customerAddresses),
        AppPaths.customerAddresses,
      );

      // A page the role may not see goes to its home.
      expect(after(UserRole.operator, '/admin/staff'), AppPaths.operations);
      expect(after(UserRole.admin, '/customer'), AppPaths.operations);
      expect(after(UserRole.customer, '/admin'), AppPaths.customer);
      expect(after(UserRole.admin, AppPaths.auth), AppPaths.operations);

      // Nothing but a page of this app is ever opened.
      for (final String foreign in <String>[
        'https://evil.example/operations',
        '//evil.example/operations',
        'http:/operations',
        'javascript:alert(1)',
        'operations',
        '',
      ]) {
        expect(
          after(UserRole.admin, foreign),
          AppPaths.operations,
          reason: foreign,
        );
      }

      // A retry that succeeded opens the page the retry screen kept.
      expect(
        redirect(
          signedIn(staff: user(role: UserRole.admin)),
          '${AppPaths.unreachable}?next=%2Fadmin%2Fstaff',
          surface: Surface.web,
        ),
        '/admin/staff',
      );

      // Signed out, the login.
      expect(redirect(signedOut, '/?next=%2Fadmin'), AppPaths.auth);
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
      expect(redirect(gated, AppPaths.staffPassword), AppPaths.changePassword);
      expect(
        redirect(gated, AppPaths.admin, surface: Surface.web),
        AppPaths.wrongSurface,
        reason: 'the surface is checked before the gate',
      );
    });

    test('a pending staff step admits only the staff password screen', () {
      final AsyncValue<SessionState> pending = signedIn(
        customer: user(id: 'c', fullName: 'Aziza'),
        step: pendingStep,
      );

      expect(redirect(pending, AppPaths.staffPassword), isNull);
      for (final String other in <String>[
        AppPaths.customer,
        AppPaths.bootstrap,
        AppPaths.auth,
        AppPaths.customerName,
        '/customer/orders',
      ]) {
        expect(redirect(pending, other), AppPaths.staffPassword, reason: other);
      }
    });

    test('a pending step wins over the missing name', () {
      final AsyncValue<SessionState> pending = signedIn(
        customer: user(id: 'c', fullName: null),
        step: pendingStep,
      );

      expect(redirect(pending, AppPaths.customerName), AppPaths.staffPassword);
    });

    test('without a step the staff password screen leads to the role home', () {
      expect(
        redirect(signedIn(customer: named()), AppPaths.staffPassword),
        AppPaths.customer,
      );
    });

    test('a customer without a name sees only the name screen; with a name, the home', () {
      final AsyncValue<SessionState> unnamed = signedIn(
        customer: user(id: 'c', fullName: null),
      );

      expect(redirect(unnamed, AppPaths.customerName), isNull);
      for (final String other in <String>[
        AppPaths.customer,
        AppPaths.bootstrap,
        AppPaths.auth,
        '/customer/orders',
      ]) {
        expect(redirect(unnamed, other), AppPaths.customerName, reason: other);
      }
      expect(
        redirect(signedIn(customer: named()), AppPaths.customerName),
        AppPaths.customer,
      );
    });

    test(
      'a staff user in Customer mode without a name also gives it first',
      () {
        final AsyncValue<SessionState> session = signedIn(
          staff: user(id: 's', role: UserRole.shopper),
          customer: user(id: 'c', fullName: null),
          active: SessionMode.customer,
        );

        expect(redirect(session, AppPaths.customer), AppPaths.customerName);
        expect(
          redirect(
            signedIn(
              staff: user(id: 's', role: UserRole.shopper),
              customer: user(id: 'c', fullName: null),
            ),
            AppPaths.shopper,
          ),
          isNull,
          reason: 'the staff mode is not held up by the customer name',
        );
      },
    );

    test('the customer-mode path is gone', () {
      expect(
        redirect(
          signedIn(staff: user(role: UserRole.shopper)),
          '/auth/customer-mode',
        ),
        AppPaths.shopper,
      );
    });

    test('the active mode decides the area when two sessions exist', () {
      final AppUser staff = user(id: 's', role: UserRole.courier);
      final AppUser customer = named();

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
