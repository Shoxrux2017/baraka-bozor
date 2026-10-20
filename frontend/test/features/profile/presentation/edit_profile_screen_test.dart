import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:baraka_bozor/features/profile/presentation/initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  CustomerProfile named(String name) => CustomerProfile(
    id: 'c',
    phone: '+998901234567',
    fullName: name,
    supportPhone: null,
  );

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> openEditor(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    Locale device = const Locale('uz'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        overrides: [profileRepositoryProvider.overrideWithValue(profile)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(AppPaths.customerEditProfile);
    await tester.pumpAndSettle();
  }

  String nameText(WidgetTester tester) =>
      tester.widget<TextField>(byKey('profile-name-field')).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(byKey('profile-save'));
    await tester.pumpAndSettle();
  }

  group('the name editor', () {
    testWidgets('shows the name and the phone read-only', (tester) async {
      profile.current = named('Aziza');
      await openEditor(tester);

      expect(byKey('edit-profile'), findsOneWidget);
      expect(nameText(tester), 'Aziza');
      final TextField phone = tester.widget<TextField>(
        byKey('profile-phone-field'),
      );
      expect(phone.readOnly, isTrue);
      expect(phone.controller!.text, '+998 90 123 45 67');
      expect(find.text(l10n(tester).profilePhoneLocked), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('an empty name shows the message and disables the button', (
      tester,
    ) async {
      profile.current = named('Aziza');
      await openEditor(tester);

      await tester.enterText(byKey('profile-name-field'), '   ');
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).profileNameRequired), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('profile-save')).onPressed,
        isNull,
      );
    });

    testWidgets('a trimmed name renames once, closes and says saved', (
      tester,
    ) async {
      await openEditor(tester);

      await tester.enterText(byKey('profile-name-field'), '  Aziza  ');
      await save(tester);

      expect(profile.renames, <String>['Aziza']);
      expect(byKey('edit-profile'), findsNothing);
      expect(find.text(l10n(tester).profileSaved), findsOneWidget);
    });

    testWidgets('an unchanged name closes with no rename', (tester) async {
      profile.current = named('Aziza');
      await openEditor(tester);

      await tester.enterText(byKey('profile-name-field'), ' Aziza ');
      await save(tester);

      expect(profile.renames, isEmpty);
      expect(byKey('edit-profile'), findsNothing);
    });

    testWidgets('a failed rename keeps the screen and shows the failure', (
      tester,
    ) async {
      profile.renameFailure = const NetworkFailure();
      await openEditor(tester);

      await tester.enterText(byKey('profile-name-field'), 'Aziza');
      await save(tester);

      expect(byKey('edit-profile'), findsOneWidget);
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);
    });

    testWidgets('two quick taps rename once', (tester) async {
      final Completer<void> hold = Completer<void>();
      await openEditor(tester);
      profile.hold = hold;

      await tester.enterText(byKey('profile-name-field'), 'Aziza');
      await tester.tap(byKey('profile-save'));
      await tester.pump();
      await tester.tap(byKey('profile-save'), warnIfMissed: false);
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();

      expect(profile.renames, <String>['Aziza']);
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets('holds at 320x640 with text x2 (${device.languageCode})', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        profile.current = named('Aziza');
        await openEditor(tester, size: const Size(320, 640), device: device);
        await tester.enterText(byKey('profile-name-field'), '');
        await tester.pumpAndSettle();

        expect(byKey('profile-save'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('initialsOf takes the first letters of the first two words', () {
    expect(initialsOf('Дилноза Каримова'), 'ДК');
    expect(initialsOf('aziza'), 'A');
    expect(initialsOf('a b c'), 'AB');
    expect(initialsOf(null), isNull);
    expect(initialsOf('   '), isNull);
  });
}
