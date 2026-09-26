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

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  Future<void> openStaffLogin(
    WidgetTester tester, {
    Surface surface = Surface.mobile,
  }) async {
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository, surface: surface),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('staff-login-link')));
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(phoneField, '901234567');
    await tester.enterText(passwordField, 'temporary pass');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }

  testWidgets('wrong credentials show their text and keep the form usable', (
    WidgetTester tester,
  ) async {
    repository.staffLoginFailure = refusal(401, 'invalid_credentials');
    await openStaffLogin(tester);

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
    expect(find.text(l10n(tester).shellAdmin), findsOneWidget);
  });

  testWidgets(
    'the first-login gate opens the password change, and only a matching pair of the right length is sent',
    (WidgetTester tester) async {
      repository.staffLoginResult = IssuedSession(
        token: 's',
        user: user(role: UserRole.shopper, mustChangePassword: true),
      );
      await openStaffLogin(tester);
      await login(tester);

      expect(currentPassword, findsOneWidget);
      expect(find.text(l10n(tester).shellShopper), findsNothing);

      await tester.enterText(currentPassword, 'temporary pass');
      await tester.enterText(newPassword, 'short');
      await tester.enterText(confirmPassword, 'short');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(repository.calls, isNot(contains('change-password:staff')));

      await tester.enterText(newPassword, 'long enough one');
      await tester.enterText(confirmPassword, 'long enough two');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).passwordsDoNotMatch), findsOneWidget);
      expect(repository.calls, isNot(contains('change-password:staff')));

      await tester.enterText(confirmPassword, 'long enough one');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('change-password:staff'));
      expect(find.text(l10n(tester).passwordChanged), findsOneWidget);
      expect(find.text(l10n(tester).shellShopper), findsOneWidget);
    },
  );

  testWidgets('a wrong current password shows its text and stays on the gate', (
    WidgetTester tester,
  ) async {
    repository.staffLoginResult = IssuedSession(
      token: 's',
      user: user(role: UserRole.courier, mustChangePassword: true),
    );
    repository.changePasswordFailure = refusal(401, 'invalid_credentials');
    await openStaffLogin(tester);
    await login(tester);

    await tester.enterText(currentPassword, 'wrong');
    await tester.enterText(newPassword, 'long enough one');
    await tester.enterText(confirmPassword, 'long enough one');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).errorInvalidCredentials), findsOneWidget);
    expect(currentPassword, findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('logging out from the gate returns to the login', (
    WidgetTester tester,
  ) async {
    repository.staffLoginResult = IssuedSession(
      token: 's',
      user: user(role: UserRole.courier, mustChangePassword: true),
    );
    await openStaffLogin(tester);
    await login(tester);

    await tester.tap(find.byKey(const ValueKey<String>('logout-button')));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('logout:staff'));
    expect(tokens.tokens, isEmpty);
    expect(phoneField, findsOneWidget);
  });

  testWidgets('a stored staff session opens its shell without a login', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.staff] = 's';
    repository.identities[SessionSlot.staff] = user(role: UserRole.operator);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: repository,
        surface: Surface.web,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).shellOperations), findsOneWidget);
    expect(phoneField, findsNothing);
  });
}
