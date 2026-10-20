import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:baraka_bozor/features/profile/presentation/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/fake_legal_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeLegalRepository legal;
  late FakePhoneCalls calls;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  const List<String> allRows = <String>[
    'profile-edit',
    'profile-addresses',
    'profile-language',
    'profile-support',
    'profile-privacy',
    'profile-terms',
    'profile-delete',
  ];

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    legal = FakeLegalRepository();
    calls = FakePhoneCalls();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  CustomerProfile named(String name, {String? support = '+998712000000'}) =>
      CustomerProfile(
        id: 'c',
        phone: '+998901234567',
        fullName: name,
        supportPhone: support,
      );

  Future<void> openProfile(
    WidgetTester tester, {
    Size size = const Size(800, 2000),
    Locale device = const Locale('ru'),
    double textScale = 1,
    bool staff = false,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (staff) {
      tokens.tokens[SessionSlot.staff] = 's';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
    }
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        legal: legal,
        phoneCalls: calls,
        overrides: [profileRepositoryProvider.overrideWithValue(profile)],
      ),
    );
    await tester.pumpAndSettle();
    if (staff) {
      await tester.tap(byKey('staff-menu'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('switch-to-customer-button'));
      await tester.pumpAndSettle();
    }
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
  }

  group('the profile tab', () {
    testWidgets('a named Customer sees the header and the seven rows', (
      tester,
    ) async {
      profile.current = named('Дилноза Каримова');
      legal.publishBoth();
      await openProfile(tester);

      expect(find.text('ДК'), findsOneWidget);
      expect(find.text('Дилноза Каримова'), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsOneWidget);
      expect(find.text('Редактировать профиль'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('+998 71 200 00 00'), findsOneWidget);
      double previous = -1;
      for (final String key in allRows) {
        final double top = tester.getTopLeft(byKey(key)).dy;
        expect(top, greaterThan(previous), reason: key);
        previous = top;
      }
      expect(byKey('logout-button'), findsOneWidget);
    });

    testWidgets('no name and no support phone is drawing 32a', (tester) async {
      await openProfile(tester);

      expect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.byIcon(Icons.person),
        ),
        findsOneWidget,
      );
      expect(find.text('Как вас зовут?'), findsOneWidget);
      expect(find.text('Указать имя'), findsOneWidget);
      expect(byKey('profile-support'), findsNothing);
    });

    testWidgets('the language row value follows the language', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, device: const Locale('uz'));

      expect(find.text("O'zbekcha"), findsOneWidget);
      expect(find.text('Til'), findsOneWidget);
    });

    testWidgets('values and chevrons sit on the right edge on a phone', (
      tester,
    ) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, size: const Size(360, 2000));

      double chevronRight(String row) => tester
          .getTopRight(
            find.descendant(
              of: byKey(row),
              matching: find.byIcon(Icons.chevron_right),
            ),
          )
          .dx;
      expect(chevronRight('profile-language'), chevronRight('profile-edit'));
      expect(
        tester.getTopRight(find.text('+998 71 200 00 00')).dx,
        tester.getTopRight(byKey('profile-support')).dx,
      );
    });

    testWidgets('test_the_legal_rows_follow_the_documents', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);
      expect(byKey('profile-privacy'), findsNothing);
      expect(byKey('profile-terms'), findsNothing);
    });

    testWidgets('only the published document has its row', (tester) async {
      profile.current = named('Дилноза Каримова');
      legal.publishOnly(LegalDocumentKind.privacy);
      await openProfile(tester);
      expect(find.text('Конфиденциальность'), findsOneWidget);
      expect(byKey('profile-terms'), findsNothing);
    });

    testWidgets('a failed index shows neither document row', (tester) async {
      profile.current = named('Дилноза Каримова');
      legal.indexFailure = const NetworkFailure();
      await openProfile(tester);
      expect(byKey('profile-privacy'), findsNothing);
      expect(byKey('profile-terms'), findsNothing);
    });

    testWidgets('a document row opens its document', (tester) async {
      profile.current = named('Дилноза Каримова');
      legal.publishBoth();
      await openProfile(tester);

      await tester.tap(byKey('profile-terms'));
      await tester.pumpAndSettle();
      expect(byKey('legal-screen'), findsOneWidget);
      expect(legal.documentCalls.last, (
        LegalDocumentKind.terms,
        AppLanguage.ru,
      ));
    });

    testWidgets('a support tap calls the number once', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-support'));
      await tester.pumpAndSettle();
      expect(calls.calls, <String>['+998712000000']);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed dial shows the number', (tester) async {
      profile.current = named('Дилноза Каримова');
      calls.opens = false;
      await openProfile(tester);

      await tester.tap(byKey('profile-support'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('+998 71 200 00 00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('test_a_staff_session_has_no_delete_row', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, staff: true);
      expect(byKey('profile-addresses'), findsOneWidget);
      expect(byKey('profile-delete'), findsNothing);
    });

    testWidgets('a Customer alone opens the delete sheet', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-delete'));
      await tester.pumpAndSettle();
      expect(byKey('delete-account-sheet'), findsOneWidget);
    });

    testWidgets("choosing O'zbekcha closes the sheet and reads Til", (
      tester,
    ) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-language'));
      await tester.pumpAndSettle();
      expect(byKey('language-sheet'), findsOneWidget);
      await tester.tap(byKey('language-uz'));
      await tester.pumpAndSettle();

      expect(byKey('language-sheet'), findsNothing);
      expect(find.text('Til'), findsOneWidget);
      expect(auth.calls, contains('language:customer:uz'));
    });

    testWidgets('the edit row opens the editor', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-edit'));
      await tester.pumpAndSettle();
      expect(byKey('edit-profile'), findsOneWidget);
    });

    testWidgets('the logout button signs the Customer out', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('logout-button'));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('logout:customer'));
      expect(byKey('profile-list'), findsNothing);
    });

    testWidgets('a failed profile keeps the retry, the language and logout', (
      tester,
    ) async {
      profile.loadFailure = const NetworkFailure();
      await openProfile(tester);

      expect(byKey('profile-language'), findsOneWidget);
      expect(byKey('logout-button'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'test_the_profile_holds_at_the_extremes in ${locale.languageCode}',
        (tester) async {
          profile.current = named('Ж' * 120);
          legal.publishBoth();
          await openProfile(
            tester,
            size: const Size(320, 640),
            device: locale,
            textScale: 2,
          );
          expect(tester.takeException(), isNull);

          await tester.drag(byKey('profile-list'), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(byKey('profile-language'));
          await tester.pumpAndSettle();
          expect(byKey('language-sheet'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
