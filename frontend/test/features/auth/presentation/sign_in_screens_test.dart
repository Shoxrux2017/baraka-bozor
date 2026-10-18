import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';

/// Every sign-in screen of `kit/01-vhod` on the smallest phone, with the
/// largest text, in both languages: it lays out without an exception, and
/// what does not fit scrolls.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;
  late FakeProfileRepository profiles;

  Key key(String name) => ValueKey<String>(name);

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository()
      ..verifyResult = IssuedSession(
        token: 'c',
        user: user(id: 'c', phone: '+998902222222'),
      )
      ..staffSteps['+998902222222'] = StaffStep(
        token: 't' * 64,
        expiresAt: DateTime.utc(2100),
      );
    profiles = FakeProfileRepository();
  });

  Future<void> open(
    WidgetTester tester,
    String language, {
    Surface surface = Surface.mobile,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: repository,
        surface: surface,
        device: Locale(language),
        overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What a person does on a small screen: scroll to the button, then tap it.
  Future<void> tapKey(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.byKey(key(name)));
    await tester.pump();
    await tester.tap(find.byKey(key(name)));
  }

  Future<void> toCodeScreen(WidgetTester tester) async {
    await tester.enterText(find.byKey(key('phone-field')), '902222222');
    await tapKey(tester, 'continue-button');
    await tester.pumpAndSettle();
    await tapKey(tester, 'confirm-phone-send');
    await tester.pumpAndSettle();
  }

  Future<void> toStaffPassword(WidgetTester tester) async {
    await toCodeScreen(tester);
    await tester.enterText(find.byKey(key('code-field')), '482913');
    await tapKey(tester, 'verify-button');
    await tester.pumpAndSettle();
  }

  final Map<String, Future<void> Function(WidgetTester, String)>
  screens = <String, Future<void> Function(WidgetTester, String)>{
    'phone': (WidgetTester tester, String language) async {
      await open(tester, language);
      expect(find.byKey(key('continue-button')), findsOneWidget);
    },
    'confirm dialog': (WidgetTester tester, String language) async {
      await open(tester, language);
      await tester.enterText(find.byKey(key('phone-field')), '902222222');
      await tapKey(tester, 'continue-button');
      await tester.pumpAndSettle();
      expect(find.byKey(key('confirm-phone-send')), findsOneWidget);
    },
    'code': (WidgetTester tester, String language) async {
      await open(tester, language);
      await toCodeScreen(tester);
      expect(find.byKey(key('code-boxes')), findsOneWidget);
      await tester.enterText(find.byKey(key('code-field')), '4815');
      await tester.pump();
      await tester.pump(const Duration(seconds: 61));
    },
    'code, locked': (WidgetTester tester, String language) async {
      repository.verifyFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 59,
      );
      await open(tester, language);
      await toCodeScreen(tester);
      await tester.enterText(find.byKey(key('code-field')), '000000');
      await tapKey(tester, 'verify-button');
      await tester.pumpAndSettle();
      expect(find.byKey(key('lock-message')), findsOneWidget);
      await tester.pump(const Duration(seconds: 59));
    },
    'phone, locked': (WidgetTester tester, String language) async {
      repository.requestFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 59,
      );
      await open(tester, language);
      await toCodeScreen(tester);
      expect(find.byKey(key('lock-message')), findsOneWidget);
      await tester.pump(const Duration(seconds: 59));
    },
    'name': (WidgetTester tester, String language) async {
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = user(
        id: 'c',
        fullName: null,
      );
      await open(tester, language);
      expect(find.byKey(key('customer-name-field')), findsOneWidget);
    },
    'name with an error': (WidgetTester tester, String language) async {
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = user(
        id: 'c',
        fullName: null,
      );
      profiles.renameFailure = const NetworkFailure();
      await open(tester, language);
      await tester.enterText(find.byKey(key('customer-name-field')), 'Aziza');
      await tapKey(tester, 'customer-name-continue');
      await tester.pumpAndSettle();
      expect(find.byKey(key('failure-message')), findsOneWidget);
    },
    'welcome dialog': (WidgetTester tester, String language) async {
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = user(
        id: 'c',
        fullName: null,
      );
      await open(tester, language);
      await tester.enterText(find.byKey(key('customer-name-field')), 'Aziza');
      await tapKey(tester, 'customer-name-continue');
      await tester.pumpAndSettle();
      expect(find.byKey(key('welcome-button')), findsOneWidget);
    },
    'staff password': (WidgetTester tester, String language) async {
      await open(tester, language);
      await toStaffPassword(tester);
      expect(find.byKey(key('staff-password-field')), findsOneWidget);
    },
    'staff password, wrong': (WidgetTester tester, String language) async {
      repository.staffStepFailure = ApiRefusal(
        const ApiError(status: 401, code: 'invalid_credentials'),
      );
      await open(tester, language);
      await toStaffPassword(tester);
      await tester.enterText(find.byKey(key('staff-password-field')), 'wrong');
      await tapKey(tester, 'staff-password-submit');
      await tester.pumpAndSettle();
    },
    'change password': (WidgetTester tester, String language) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(
        role: UserRole.courier,
        mustChangePassword: true,
      );
      await open(tester, language);
      expect(find.byKey(key('save-password-button')), findsOneWidget);
      await tapKey(tester, 'save-password-button');
      await tester.pumpAndSettle();
    },
    'unreachable': (WidgetTester tester, String language) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = const NetworkFailure();
      await open(tester, language);
      expect(find.byKey(key('retry-button')), findsOneWidget);
    },
    'wrong surface on the phone': (WidgetTester tester, String language) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      await open(tester, language);
      expect(find.byKey(key('wrong-surface-text')), findsOneWidget);
    },
    'wrong surface on the web': (WidgetTester tester, String language) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.shopper);
      await open(tester, language, surface: Surface.web);
      expect(find.byKey(key('wrong-surface-text')), findsOneWidget);
    },
    'web staff login': (WidgetTester tester, String language) async {
      repository.staffLoginFailure = ApiRefusal(
        const ApiError(status: 403, code: 'staff_code_required'),
      );
      await open(tester, language, surface: Surface.web);
      await tester.enterText(find.byKey(key('phone-field')), '902222222');
      await tester.enterText(find.byKey(key('password-field')), 'x');
      await tapKey(tester, 'login-button');
      await tester.pumpAndSettle();
      expect(find.byKey(key('failure-message')), findsOneWidget);
    },
  };

  for (final MapEntry<String, Future<void> Function(WidgetTester, String)> e
      in screens.entries) {
    for (final String language in <String>['uz', 'ru']) {
      testWidgets(
        '${e.key} at 320x640, text x2, $language, lays out without an exception',
        (WidgetTester tester) async {
          await e.value(tester, language);

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
