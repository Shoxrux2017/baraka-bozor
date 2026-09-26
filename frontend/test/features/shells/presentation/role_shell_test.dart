import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// Customer mode of `docs/02-user-roles.md` section 10 through the real
/// shells, router and session controller.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  final Finder switchToCustomer = find.byKey(
    const ValueKey<String>('switch-to-customer-button'),
  );
  final Finder switchToStaff = find.byKey(
    const ValueKey<String>('switch-to-staff-button'),
  );
  final Finder modeChip = find.byKey(
    const ValueKey<String>('active-mode-chip'),
  );
  final Finder logoutButton = find.byKey(
    const ValueKey<String>('logout-button'),
  );
  final Finder codeField = find.byKey(const ValueKey<String>('code-field'));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a Courier enters Customer mode with a code sent to their own phone, then switches back and forth',
    (WidgetTester tester) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
        phone: '+998901111111',
      );
      repository.verifyResult = IssuedSession(
        token: 'c',
        user: user(id: 'c', phone: '+998901111111'),
      );
      await openApp(tester);

      expect(find.text(l10n(tester).shellCourier), findsOneWidget);
      expect(modeChip, findsNothing, reason: 'one session, nothing to show');

      await tester.tap(switchToCustomer);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('request:+998901111111'));
      expect(find.text(l10n(tester).customerModeIntro), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('phone-field')), findsNothing);

      await tester.enterText(codeField, '123456');
      await tester.tap(find.byKey(const ValueKey<String>('verify-button')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('verify:+998901111111:123456'));
      expect(find.text(l10n(tester).shellCustomer), findsOneWidget);
      expect(modeChip, findsOneWidget);
      expect(find.text(l10n(tester).customerModeLabel), findsOneWidget);
      expect(tokens.tokens.keys, containsAll(SessionSlot.values));

      await tester.tap(switchToStaff);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).shellCourier), findsOneWidget);
      expect(find.text(l10n(tester).staffModeLabel), findsOneWidget);

      // With both sessions the switch needs no code.
      repository.calls.clear();
      await tester.tap(switchToCustomer);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).shellCustomer), findsOneWidget);
      expect(repository.calls, isEmpty);
    },
  );

  testWidgets('cancelling the Customer-mode entry returns to the staff shell', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.staff] = 's';
    repository.identities[SessionSlot.staff] = user(role: UserRole.shopper);
    await openApp(tester);

    await tester.tap(switchToCustomer);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('cancel-button')));
    await tester.pumpAndSettle();

    expect(find.text(l10n(tester).shellShopper), findsOneWidget);
  });

  testWidgets('logging out of Customer mode keeps the staff session', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.staff] = 's';
    tokens.tokens[SessionSlot.customer] = 'c';
    repository.identities[SessionSlot.staff] = user(
      id: 's',
      role: UserRole.shopper,
    );
    repository.identities[SessionSlot.customer] = user(id: 'c');
    await openApp(tester);

    expect(find.text(l10n(tester).shellShopper), findsOneWidget);
    await tester.tap(switchToCustomer);
    await tester.pumpAndSettle();
    expect(find.text(l10n(tester).shellCustomer), findsOneWidget);

    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('logout:customer'));
    expect(tokens.tokens.keys, <SessionSlot>[SessionSlot.staff]);
    expect(find.text(l10n(tester).shellShopper), findsOneWidget);
    expect(modeChip, findsNothing);
  });

  testWidgets(
    'a Customer, an Operator, an Admin and a Manager see no mode switch',
    (WidgetTester tester) async {
      for (final UserRole role in <UserRole>[
        UserRole.operator,
        UserRole.admin,
        UserRole.manager,
      ]) {
        tokens = InMemoryTokenStore(<SessionSlot, String>{
          SessionSlot.staff: 's',
        });
        repository = FakeAuthRepository()
          ..identities[SessionSlot.staff] = user(role: role);
        await tester.pumpWidget(
          appUnderTest(
            tokens: tokens,
            repository: repository,
            surface: Surface.web,
          ),
        );
        await tester.pumpAndSettle();

        expect(switchToCustomer, findsNothing, reason: '$role');
        expect(switchToStaff, findsNothing, reason: '$role');
      }

      tokens = InMemoryTokenStore(<SessionSlot, String>{
        SessionSlot.customer: 'c',
      });
      repository = FakeAuthRepository()
        ..identities[SessionSlot.customer] = user();
      await openApp(tester);

      expect(switchToStaff, findsNothing);
      expect(switchToCustomer, findsNothing);
    },
  );
}
