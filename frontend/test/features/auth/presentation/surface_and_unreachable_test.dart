import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  final Finder wrongSurfaceText = find.byKey(
    const ValueKey<String>('wrong-surface-text'),
  );
  final Finder logoutButton = find.byKey(
    const ValueKey<String>('logout-button'),
  );
  final Finder retryButton = find.byKey(const ValueKey<String>('retry-button'));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  Future<void> openApp(WidgetTester tester, Surface surface) async {
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository, surface: surface),
    );
    await tester.pumpAndSettle();
  }

  group('the wrong surface (docs/02 section 10)', () {
    testWidgets('an Admin on a phone is told to use the web panel', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);

      await openApp(tester, Surface.mobile);

      expect(wrongSurfaceText, findsOneWidget);
      expect(find.text(l10n(tester).wrongSurfaceMobile), findsOneWidget);
      expect(find.text(l10n(tester).shellAdmin), findsNothing);
    });

    testWidgets(
      'a Shopper in a browser is told to use the app, and can log out',
      (WidgetTester tester) async {
        tokens.tokens[SessionSlot.staff] = 's';
        repository.identities[SessionSlot.staff] = user(role: UserRole.shopper);

        await openApp(tester, Surface.web);

        expect(find.text(l10n(tester).wrongSurfaceWeb), findsOneWidget);

        await tester.tap(logoutButton);
        await tester.pumpAndSettle();

        expect(tokens.tokens, isEmpty);
        expect(
          find.byKey(const ValueKey<String>('phone-field')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a Customer in a browser is on the wrong surface too', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = user();

      await openApp(tester, Surface.web);

      expect(find.text(l10n(tester).wrongSurfaceWeb), findsOneWidget);
    });
  });

  group('an unreachable server', () {
    testWidgets(
      'keeps the token, offers a retry, and opens the shell once the server answers',
      (WidgetTester tester) async {
        tokens.tokens[SessionSlot.staff] = 's';
        repository.identities[SessionSlot.staff] = const NetworkFailure();

        await openApp(tester, Surface.mobile);

        expect(find.text(l10n(tester).sessionUnreachableTitle), findsOneWidget);
        expect(tokens.tokens[SessionSlot.staff], 's');

        await tester.tap(retryButton);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n(tester).sessionUnreachableTitle),
          findsOneWidget,
          reason: 'still unreachable',
        );

        repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        expect(find.text(l10n(tester).shellCourier), findsOneWidget);
      },
    );
  });
}
