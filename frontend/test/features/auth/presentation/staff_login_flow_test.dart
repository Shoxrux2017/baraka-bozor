import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// `docs/04-user-flows.md` section 3 through the real router, session
/// controller and screens.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  final Finder phoneField = find.byKey(const ValueKey<String>('phone-field'));
  final Finder passwordField = find.byKey(
    const ValueKey<String>('password-field'),
  );
  final Finder loginButton = find.byKey(const ValueKey<String>('login-button'));
  final Finder currentPassword = find.byKey(
    const ValueKey<String>('current-password-field'),
  );
  final Finder newPassword = find.byKey(
    const ValueKey<String>('new-password-field'),
  );
  final Finder confirmPassword = find.byKey(
    const ValueKey<String>('confirm-password-field'),
  );
  final Finder saveButton = find.byKey(
    const ValueKey<String>('save-password-button'),
  );

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  /// The password change is taller than the test window: scroll to a button
  /// before tapping it, as a person does.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  /// The panel shows the user card, with the role, in its side menu from
  /// 1200 wide; the default test window is narrower.
  void useWidePanelWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  Future<void> openStaffLogin(
    WidgetTester tester, {
    Surface surface = Surface.mobile,
  }) async {
    if (surface == Surface.web) {
      useWidePanelWindow(tester);
    }
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository, surface: surface),
    );
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(phoneField, '901234567');
    await tester.enterText(passwordField, 'temporary pass');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }

  /// A Shopper or Courier on the gate, with the staff session already stored:
  /// on mobile they arrive through the staff step, not through this form.
  Future<void> openGate(WidgetTester tester, UserRole role) async {
    tokens.tokens[SessionSlot.staff] = 's';
    repository.identities[SessionSlot.staff] = user(
      role: role,
      mustChangePassword: true,
    );
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wrong credentials show their text and keep the form usable', (
    WidgetTester tester,
  ) async {
    repository.staffLoginFailure = refusal(401, 'invalid_credentials');
    await openStaffLogin(tester, surface: Surface.web);

    await login(tester);

    expect(find.text(l10n(tester).errorInvalidCredentials), findsOneWidget);
    expect(tester.widget<FilledButton>(loginButton).onPressed, isNotNull);
    expect(tokens.tokens, isEmpty);
  });

  testWidgets('an Admin lands in the admin shell on the web panel', (
    WidgetTester tester,
  ) async {
    repository.staffLoginResult = IssuedSession(
      token: 's',
      user: user(role: UserRole.admin),
    );
    await openStaffLogin(tester, surface: Surface.web);

    await login(tester);

    expect(repository.calls, contains('login:+998901234567'));
    expect(tokens.tokens[SessionSlot.staff], 's');
    expect(find.text(l10n(tester).roleAdmin), findsOneWidget);
  });

  testWidgets(
    'the first-login gate opens the password change, and only a matching pair of the right length is sent',
    (WidgetTester tester) async {
      await openGate(tester, UserRole.shopper);

      expect(currentPassword, findsOneWidget);
      expect(find.text(l10n(tester).myOrders), findsNothing);

      await tester.enterText(currentPassword, 'temporary pass');
      await tester.enterText(newPassword, 'short');
      await tester.enterText(confirmPassword, 'short');
      await tapVisible(tester, saveButton);
      await tester.pumpAndSettle();
      expect(repository.calls, isNot(contains('change-password:staff')));
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: newPassword,
                matching: find.byType(TextField),
              ),
            )
            .decoration
            ?.errorText,
        l10n(tester).passwordRuleHint,
        reason: 'the rule is shown as the field error',
      );

      await tester.enterText(newPassword, 'long enough one');
      await tester.enterText(confirmPassword, 'long enough two');
      await tapVisible(tester, saveButton);
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).passwordsDoNotMatch), findsOneWidget);
      expect(repository.calls, isNot(contains('change-password:staff')));

      await tester.enterText(confirmPassword, 'long enough one');
      await tapVisible(tester, saveButton);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('change-password:staff'));
      expect(find.text(l10n(tester).passwordChanged), findsOneWidget);
      expect(find.text(l10n(tester).myOrders), findsOneWidget);
    },
  );

  testWidgets('a new password over the maximum length names the maximum', (
    WidgetTester tester,
  ) async {
    await openGate(tester, UserRole.shopper);

    final String tooLong = 'a' * 129;
    await tester.enterText(currentPassword, 'temporary pass');
    await tester.enterText(newPassword, tooLong);
    await tester.enterText(confirmPassword, tooLong);
    await tapVisible(tester, saveButton);
    await tester.pumpAndSettle();

    expect(repository.calls, isNot(contains('change-password:staff')));
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: newPassword, matching: find.byType(TextField)),
          )
          .decoration
          ?.errorText,
      l10n(tester).fieldTooLong(128),
    );
  });

  testWidgets('a wrong current password shows its text and stays on the gate', (
    WidgetTester tester,
  ) async {
    repository.changePasswordFailure = refusal(401, 'invalid_credentials');
    await openGate(tester, UserRole.courier);

    await tester.enterText(currentPassword, 'wrong');
    await tester.enterText(newPassword, 'long enough one');
    await tester.enterText(confirmPassword, 'long enough one');
    await tapVisible(tester, saveButton);
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).errorInvalidCredentials), findsOneWidget);
    expect(currentPassword, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('logging out from the gate returns to the login', (
    WidgetTester tester,
  ) async {
    await openGate(tester, UserRole.courier);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('logout-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, contains('logout:staff'));
    expect(tokens.tokens, isEmpty);
    expect(phoneField, findsOneWidget);
  });

  testWidgets('while the login runs the button waits', (
    WidgetTester tester,
  ) async {
    repository.staffLoginResult = IssuedSession(
      token: 's',
      user: user(role: UserRole.admin),
    );
    repository.holdAnswers = Completer<void>();
    await openStaffLogin(tester, surface: Surface.web);

    await tester.enterText(phoneField, '901234567');
    await tester.enterText(passwordField, 'temporary pass');
    await tester.tap(loginButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(loginButton).onPressed, isNull);

    repository.holdAnswers!.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n(tester).roleAdmin), findsOneWidget);
  });

  testWidgets('a stored staff session opens its shell without a login', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.staff] = 's';
    repository.identities[SessionSlot.staff] = user(role: UserRole.operator);
    useWidePanelWindow(tester);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: repository,
        surface: Surface.web,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).roleOperator), findsOneWidget);
    expect(phoneField, findsNothing);
  });

  testWidgets('the web /auth is the staff login, with no customer phone flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: repository,
        surface: Surface.web,
      ),
    );
    await tester.pumpAndSettle();

    expect(passwordField, findsOneWidget);
    expect(loginButton, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('continue-button')), findsNothing);
  });

  testWidgets(
    'a Shopper who signs in on the web is told the account works in the app',
    (WidgetTester tester) async {
      repository.staffLoginFailure = refusal(403, 'staff_code_required');
      await openStaffLogin(tester, surface: Surface.web);

      await login(tester);

      expect(find.text(l10n(tester).wrongSurfaceWeb), findsOneWidget);
      expect(tokens.tokens, isEmpty);
    },
  );

  group('the staff step on the phone', () {
    const String staffPhone = '+998902222222';
    final Finder codeField = find.byKey(const ValueKey<String>('code-field'));
    final Finder stepPassword = find.byKey(
      const ValueKey<String>('staff-password-field'),
    );
    final Finder stepSubmit = find.byKey(
      const ValueKey<String>('staff-password-submit'),
    );
    final Finder catalog = find.byKey(const ValueKey<String>('catalog-search'));

    setUp(() {
      repository
        ..verifyResult = IssuedSession(
          token: 'c',
          user: user(id: 'c', phone: staffPhone),
        )
        ..staffSteps[staffPhone] = StaffStep(
          token: 't' * 64,
          expiresAt: DateTime.utc(2100),
        )
        ..staffStepResult = IssuedSession(
          token: 's',
          user: user(id: 's', phone: staffPhone, role: UserRole.shopper),
        );
    });

    Future<void> signInWithCode(WidgetTester tester) async {
      await tester.pumpWidget(
        appUnderTest(tokens: tokens, repository: repository),
      );
      await tester.pumpAndSettle();
      await tester.enterText(phoneField, '902222222');
      await tester.tap(find.byKey(const ValueKey<String>('continue-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('confirm-phone-send')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(codeField, '482913');
      await tester.tap(find.byKey(const ValueKey<String>('verify-button')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a Shopper test phone: code, then the password, then the Shopper area; Customer mode needs no code',
      (WidgetTester tester) async {
        await signInWithCode(tester);

        expect(stepPassword, findsOneWidget);
        expect(find.text(l10n(tester).staffPasswordTitle), findsOneWidget);
        expect(find.text(l10n(tester).myOrders), findsNothing);

        await tester.enterText(stepPassword, 'staff pass');
        await tester.tap(stepSubmit);
        await tester.pumpAndSettle();

        expect(repository.calls, contains('step:${'t' * 64}'));
        expect(tokens.tokens[SessionSlot.staff], 's');
        expect(find.text(l10n(tester).myOrders), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey<String>('staff-menu')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('switch-to-customer-button')),
        );
        await tester.pumpAndSettle();

        expect(catalog, findsOneWidget);
        expect(
          repository.calls.where((String c) => c.startsWith('verify:')),
          hasLength(1),
          reason: 'no second code',
        );
      },
    );

    testWidgets('the eye shows and hides the password', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester);

      bool obscured() => tester
          .widget<TextField>(
            find.descendant(of: stepPassword, matching: find.byType(TextField)),
          )
          .obscureText;
      expect(obscured(), isTrue);

      await tester.tap(find.byKey(const ValueKey<String>('password-eye')));
      await tester.pump();
      expect(obscured(), isFalse);
    });

    testWidgets('the back arrow continues as the customer', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester);

      await tester.tap(find.byKey(const ValueKey<String>('auth-back-button')));
      await tester.pumpAndSettle();

      expect(catalog, findsOneWidget);
      expect(tokens.tokens.containsKey(SessionSlot.staff), isFalse);
    });

    testWidgets('a wrong password says so and stays on the step', (
      WidgetTester tester,
    ) async {
      repository.staffStepFailure = refusal(401, 'invalid_credentials');
      await signInWithCode(tester);

      await tester.enterText(stepPassword, 'wrong');
      await tester.tap(stepSubmit);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).staffPasswordWrong), findsOneWidget);
      expect(stepPassword, findsOneWidget);
      expect(tester.widget<FilledButton>(stepSubmit).onPressed, isNotNull);
    });

    testWidgets('the staff password field carries the Password hint', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester);

      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: stepPassword,
                matching: find.byType(TextField),
              ),
            )
            .decoration
            ?.hintText,
        l10n(tester).passwordLabel,
      );
    });

    testWidgets(
      'a blocked account at the step clears it and says so, not that the step expired',
      (WidgetTester tester) async {
        repository.staffStepFailure = refusal(401, 'account_blocked');
        await signInWithCode(tester);

        await tester.enterText(stepPassword, 'staff pass');
        await tester.tap(stepSubmit);
        await tester.pumpAndSettle();

        expect(stepPassword, findsNothing);
        expect(catalog, findsOneWidget);
        expect(find.text(l10n(tester).errorAccountBlocked), findsOneWidget);
        expect(find.text(l10n(tester).staffStepExpired), findsNothing);
      },
    );

    testWidgets('an empty password is refused before anything is sent', (
      WidgetTester tester,
    ) async {
      await signInWithCode(tester);

      await tester.tap(stepSubmit);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).passwordRequired), findsOneWidget);
      expect(
        repository.calls.where((String c) => c.startsWith('step:')),
        isEmpty,
      );
    });

    testWidgets(
      'an expired step continues as the customer with a way to get a new code',
      (WidgetTester tester) async {
        repository.staffStepFailure = refusal(401, 'staff_step_expired');
        await signInWithCode(tester);

        await tester.enterText(stepPassword, 'staff pass');
        await tester.tap(stepSubmit);
        await tester.pumpAndSettle();

        expect(catalog, findsOneWidget);
        expect(find.text(l10n(tester).staffStepExpired), findsOneWidget);

        await tester.tap(find.text(l10n(tester).getNewCodeButton));
        await tester.pumpAndSettle();

        expect(repository.calls, contains('logout:customer'));
        expect(phoneField, findsOneWidget);
      },
    );
  });
}
