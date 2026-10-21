import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// The name screen is never a dead end: a person can leave it, and a Shopper
/// or Courier who has not given a Customer name can go back to the staff mode.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  final Finder logout = find.byKey(
    const ValueKey<String>('customer-name-logout'),
  );
  final Finder toStaff = find.byKey(
    const ValueKey<String>('customer-name-to-staff'),
  );
  final Finder nameField = find.byKey(
    const ValueKey<String>('customer-name-field'),
  );

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a nameless customer can sign out from the name screen', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    repository.identities[SessionSlot.customer] = user(id: 'c', fullName: null);
    await open(tester);

    expect(nameField, findsOneWidget);
    expect(toStaff, findsNothing, reason: 'no staff session to return to');

    await tester.ensureVisible(logout);
    await tester.pump();
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('logout:customer'));
    expect(nameField, findsNothing);
    expect(find.byKey(const ValueKey<String>('phone-field')), findsOneWidget);
  });

  testWidgets(
    'a Shopper in the nameless customer mode can go back to the staff mode',
    (WidgetTester tester) async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.shopper,
      );
      repository.identities[SessionSlot.customer] = user(
        id: 'c',
        fullName: null,
      );
      await open(tester);
      await tester.tap(find.byKey(const ValueKey<String>('staff-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('switch-to-customer-button')),
      );
      await tester.pumpAndSettle();
      expect(nameField, findsOneWidget);

      await tester.ensureVisible(toStaff);
      await tester.pump();
      await tester.tap(toStaff);
      await tester.pumpAndSettle();

      expect(nameField, findsNothing);
      expect(find.text(l10n(tester).myOrders), findsOneWidget);
    },
  );
}
