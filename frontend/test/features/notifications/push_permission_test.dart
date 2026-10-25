import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/notifications/application/push_ports.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_push.dart';
import '../../support/in_memory_stores.dart';

/// The notification permission is asked once per install, after the session
/// passes its gates (`DL-115` (8)).
void main() {
  const String key = 'push_permission_asked';

  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakePushInbox inbox;
  late InMemoryPreferenceStore preferences;

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    inbox = FakePushInbox();
    preferences = InMemoryPreferenceStore();
  });

  void signIn(SessionSlot slot, AppUser person) {
    tokens.tokens[slot] = 't';
    auth.identities[slot] = person;
  }

  Future<void> open(
    WidgetTester tester, {
    Surface surface = Surface.mobile,
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        preferences: preferences,
        surface: surface,
        overrides: [pushInboxProvider.overrideWithValue(inbox)],
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));

  testWidgets(
    'asks once after the first sign-in into a role that receives pushes',
    (WidgetTester tester) async {
      signIn(SessionSlot.customer, user(id: 'c'));
      await open(tester);

      expect(inbox.permissionRequests, 1);
      expect(preferences.values[key], 'yes');

      await tester.pumpWidget(const SizedBox());
      await open(tester);

      expect(inbox.permissionRequests, 1);
    },
  );

  testWidgets('never asks a panel role', (WidgetTester tester) async {
    signIn(SessionSlot.staff, user(id: 'o', role: UserRole.operator));
    await open(tester, surface: Surface.web);

    expect(inbox.permissionRequests, 0);
    expect(preferences.values[key], isNull);
  });

  testWidgets('waits past the first-login password change', (
    WidgetTester tester,
  ) async {
    signIn(
      SessionSlot.staff,
      user(id: 's', role: UserRole.shopper, mustChangePassword: true),
    );
    await open(tester);

    expect(inbox.permissionRequests, 0);
    expect(preferences.values[key], isNull);

    await containerOf(tester)
        .read(sessionControllerProvider.notifier)
        .changePassword(
          currentPassword: 'old',
          newPassword: 'new-password-1',
          newPasswordConfirmation: 'new-password-1',
        );
    await tester.pumpAndSettle();

    expect(inbox.permissionRequests, 1);
  });

  testWidgets("waits for the Customer's name", (WidgetTester tester) async {
    signIn(SessionSlot.customer, user(id: 'c', fullName: null));
    await open(tester);

    expect(inbox.permissionRequests, 0);
    expect(preferences.values[key], isNull);

    containerOf(tester)
        .read(sessionControllerProvider.notifier)
        .replaceCustomerUser(user(id: 'c'));
    await tester.pumpAndSettle();

    expect(inbox.permissionRequests, 1);
  });

  testWidgets('a build without push neither asks nor marks it asked', (
    WidgetTester tester,
  ) async {
    inbox.receivesPushes = false;
    signIn(SessionSlot.customer, user(id: 'c'));
    await open(tester);

    expect(inbox.permissionRequests, 0);
    expect(preferences.values[key], isNull);
  });

  testWidgets(
    'a phone already signed in when push arrives is asked at the next start',
    (WidgetTester tester) async {
      inbox.receivesPushes = false;
      signIn(SessionSlot.customer, user(id: 'c'));
      await open(tester);
      expect(inbox.permissionRequests, 0);

      await tester.pumpWidget(const SizedBox());
      inbox.receivesPushes = true;
      await open(tester);

      expect(inbox.permissionRequests, 1);
      expect(preferences.values[key], 'yes');
    },
  );
}
