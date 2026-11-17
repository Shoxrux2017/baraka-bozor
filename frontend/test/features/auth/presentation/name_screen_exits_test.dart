import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/application/welcome_notice.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

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

  group('the name step (DL-139)', () {
    final Finder continueButton = find.byKey(
      const ValueKey<String>('customer-name-continue'),
    );
    final Finder banner = find.byKey(const ValueKey<String>('welcome-banner'));
    final Finder authNotice = find.byKey(const ValueKey<String>('auth-notice'));
    final Finder home = find.byKey(const ValueKey<String>('catalog-search'));
    late FakeProfileRepository profiles;

    setUp(() {
      profiles = FakeProfileRepository();
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = user(
        id: 'c',
        fullName: null,
      );
    });

    Future<void> openName(WidgetTester tester, {TextScaler? scaler}) async {
      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: repository,
          profile: profiles,
          textScaler: scaler,
        ),
      );
      await tester.pumpAndSettle();
    }

    bool pressable(WidgetTester tester) =>
        tester.widget<FilledButton>(continueButton).onPressed != null;

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

    testWidgets('the name has a label and the button waits for a letter', (
      WidgetTester tester,
    ) async {
      await openName(tester);
      final AppLocalizations l = l10n(tester);

      expect(find.text(l.nameLabel), findsOneWidget);
      expect(find.text(l.nameExample), findsOneWidget);
      expect(pressable(tester), isFalse);
      for (final String text in <String>['  ', '123', '+ 7 -']) {
        await tester.enterText(nameField, text);
        await tester.pump();
        expect(pressable(tester), isFalse, reason: '"$text" holds no letter');
      }
      await tester.enterText(nameField, ' Азиза ');
      await tester.pump();
      expect(pressable(tester), isTrue);
    });

    testWidgets('saving shows ✓ Готово, then the home with the strip', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      profiles.hold = Completer<void>();
      await openName(tester);
      final AppLocalizations l = l10n(tester);

      await tester.enterText(nameField, 'Aziza');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();
      expect(find.text(l.nameSaving), findsOneWidget);
      expect(pressable(tester), isFalse);

      profiles.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(profiles.renames, <String>['Aziza']);
      expect(find.text(l.nameSaved), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 499));
      expect(nameField, findsOneWidget, reason: 'the ✓ holds for 500 ms');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);
      expect(nameField, findsNothing);
      expect(home, findsOneWidget);
      expect(banner, findsOneWidget);
      expect(find.text(l.welcomeTitle('Aziza')), findsOneWidget);
      expect(find.text(l.welcomeBody), findsOneWidget);
      expect(
        tester.takeAnnouncements().map(
          (CapturedAccessibilityAnnouncement a) => a.message,
        ),
        contains('${l.welcomeTitle('Aziza')} ${l.welcomeBody}'),
      );

      await tester.pump(const Duration(milliseconds: 4400));
      expect(banner, findsNothing);
      handle.dispose();
    });

    testWidgets('the welcome strip shows once for its account', (
      WidgetTester tester,
    ) async {
      await openName(tester);
      await tester.enterText(nameField, 'Aziza');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(banner, findsOneWidget);
      expect(
        container(tester).read(welcomeNoticeProvider),
        isNull,
        reason: 'the home took it',
      );
    });

    testWidgets('a notice for another account shows nothing and is dropped', (
      WidgetTester tester,
    ) async {
      await openName(tester);
      container(tester)
          .read(welcomeNoticeProvider.notifier)
          .show(const Welcome(accountId: 'other', name: 'Bobur'));

      await tester.enterText(nameField, 'Aziza');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(home, findsOneWidget);
      expect(find.text(l10n(tester).welcomeTitle('Bobur')), findsNothing);
      expect(banner, findsOneWidget, reason: 'the notice of the saved name');
      expect(container(tester).read(welcomeNoticeProvider), isNull);
    });

    testWidgets('a lost connection keeps the name and retries', (
      WidgetTester tester,
    ) async {
      profiles.renameFailure = const NetworkFailure();
      await openName(tester);
      await tester.enterText(nameField, 'Aziza');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(authNotice, findsOneWidget);
      expect(find.text(l10n(tester).authNoInternet), findsOneWidget);
      expect(find.text('Aziza'), findsOneWidget);
      expect(pressable(tester), isTrue);

      await tester.tap(
        find.byKey(const ValueKey<String>('auth-notice-action')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(profiles.renames, <String>['Aziza', 'Aziza']);
      expect(home, findsOneWidget);
    });

    testWidgets('Войти с другим номером signs out at once', (
      WidgetTester tester,
    ) async {
      await openName(tester);
      expect(find.text(l10n(tester).nameOtherNumber), findsOneWidget);

      await tester.ensureVisible(logout);
      await tester.pump();
      await tester.tap(logout);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(repository.calls, contains('logout:customer'));
      expect(find.byKey(const ValueKey<String>('phone-field')), findsOneWidget);
    });

    for (final double scale in <double>[1, 2]) {
      testWidgets('every tap target holds at text x$scale', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await openName(
          tester,
          scaler: scale == 1 ? null : NonlinearTextScaler(scale),
        );
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await tester.enterText(nameField, 'Aziza');
        await tester.pump();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }
  });
}
