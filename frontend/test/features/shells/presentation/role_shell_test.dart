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
  final Finder modeChip = find.byKey(const ValueKey<String>('active-mode'));
  // The Shopper's and the Courier's areas keep their mode switch and their
  // way out in one menu.
  final Finder staffMenu = find.byKey(const ValueKey<String>('staff-menu'));
  final Finder logoutButton = find.byKey(
    const ValueKey<String>('logout-button'),
  );
  // The Customer area's home is the catalog.
  final Finder customerHome = find.byKey(
    const ValueKey<String>('catalog-search'),
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
    'a Courier with both sessions switches to Customer mode and back with no code',
    (WidgetTester tester) async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
        phone: '+998901111111',
      );
      repository.identities[SessionSlot.customer] = user(
        id: 'c',
        phone: '+998901111111',
      );
      await openApp(tester);

      expect(find.text(l10n(tester).myDeliveries), findsOneWidget);
      expect(modeChip, findsOneWidget);

      await tester.tap(staffMenu);
      await tester.pumpAndSettle();
      await tester.tap(switchToCustomer);
      await tester.pumpAndSettle();

      expect(customerHome, findsOneWidget);
      expect(find.text(l10n(tester).customerModeLabel), findsOneWidget);
      expect(
        repository.calls.where(
          (String call) =>
              call.startsWith('request:') || call.startsWith('verify:'),
        ),
        isEmpty,
        reason: 'no code is asked for',
      );
      expect(codeField, findsNothing);

      await tester.tap(switchToStaff);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).myDeliveries), findsOneWidget);
      expect(find.text(l10n(tester).staffModeLabel), findsOneWidget);
    },
  );

  testWidgets(
    'a staff session without a customer session, from before the change, is offered no switch',
    (WidgetTester tester) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.shopper);
      await openApp(tester);

      await tester.tap(staffMenu);
      await tester.pumpAndSettle();

      expect(switchToCustomer, findsNothing);
      expect(logoutButton, findsOneWidget);
    },
  );

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

    expect(find.text(l10n(tester).myOrders), findsOneWidget);
    await tester.tap(staffMenu);
    await tester.pumpAndSettle();
    await tester.tap(switchToCustomer);
    await tester.pumpAndSettle();
    expect(customerHome, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('open-profile')));
    await tester.pumpAndSettle();
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('logout:customer'));
    expect(tokens.tokens.keys, <SessionSlot>[SessionSlot.staff]);
    expect(find.text(l10n(tester).myOrders), findsOneWidget);
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
