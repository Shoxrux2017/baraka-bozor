import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

/// `docs/04-user-flows.md` section 2 through the real router, session
/// controller and screens, with the repository faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  final Finder phoneField = find.byKey(const ValueKey<String>('phone-field'));
  final Finder continueButton = find.byKey(
    const ValueKey<String>('continue-button'),
  );
  final Finder codeField = find.byKey(const ValueKey<String>('code-field'));
  final Finder verifyButton = find.byKey(
    const ValueKey<String>('verify-button'),
  );
  final Finder resendButton = find.byKey(
    const ValueKey<String>('resend-button'),
  );
  final Finder failure = find.byKey(const ValueKey<String>('failure-message'));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository()
      ..requestResult = const RequestedCode(
        channel: 'telegram',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 60,
      )
      ..verifyResult = IssuedSession(
        token: 'c',
        user: user(id: 'c'),
      );
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository),
    );
    await tester.pumpAndSettle();
  }

  Future<void> requestCode(WidgetTester tester, String digits) async {
    await tester.enterText(phoneField, digits);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
  }

  testWidgets('an incomplete phone is refused before anything is sent', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    await requestCode(tester, '9012345');

    expect(find.text(l10n(tester).phoneInvalid), findsOneWidget);
    expect(repository.calls, isEmpty);
    expect(codeField, findsNothing);
  });

  testWidgets(
    'the phone goes as +998 and nine digits; the code screen names the channel and the phone',
    (WidgetTester tester) async {
      await openApp(tester);

      await requestCode(tester, '901234567');

      expect(repository.calls, <String>['request:+998901234567']);
      expect(codeField, findsOneWidget);
      expect(find.text(l10n(tester).codeSentTelegram), findsOneWidget);
      expect(
        find.text(l10n(tester).codeSentToPhone('+998 90 123 45 67')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a refused request shows its text and keeps the phone screen', (
    WidgetTester tester,
  ) async {
    repository.requestFailure = refusal(429, 'rate_limited');
    await openApp(tester);

    await requestCode(tester, '901234567');

    expect(failure, findsOneWidget);
    expect(find.text(l10n(tester).errorRateLimited), findsOneWidget);
    expect(codeField, findsNothing);
    expect(
      tester.widget<FilledButton>(continueButton).onPressed,
      isNotNull,
      reason: 'the form is usable again after a failure',
    );
  });

  testWidgets(
    'the right code opens the customer shell; a wrong one shows its text',
    (WidgetTester tester) async {
      repository.verifyFailure = refusal(422, 'code_invalid');
      await openApp(tester);
      await requestCode(tester, '901234567');

      await tester.enterText(codeField, '000000');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).errorCodeInvalid), findsOneWidget);
      expect(codeField, findsOneWidget);

      repository.verifyFailure = null;
      await tester.enterText(codeField, '482913');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      expect(repository.calls.last, 'verify:+998901234567:482913');
      expect(tokens.tokens[SessionSlot.customer], 'c');
      expect(find.text(l10n(tester).shellCustomer), findsOneWidget);
      expect(find.text(l10n(tester).shellPlaceholder), findsOneWidget);
    },
  );

  testWidgets('a resend waits for the server timer, then sends again', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    await requestCode(tester, '901234567');

    expect(tester.widget<TextButton>(resendButton).onPressed, isNull);
    expect(find.text(l10n(tester).resendIn(60)), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text(l10n(tester).resendIn(1)), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(l10n(tester).resendCode), findsOneWidget);
    expect(tester.widget<TextButton>(resendButton).onPressed, isNotNull);

    await tester.tap(resendButton);
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((String c) => c.startsWith('request:')),
      hasLength(2),
    );
    expect(find.text(l10n(tester).resendIn(60)), findsOneWidget);

    // Leave no timer behind.
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets(
    'changing the phone returns to the phone screen with it filled in',
    (WidgetTester tester) async {
      await openApp(tester);
      await requestCode(tester, '901234567');

      await tester.tap(find.byKey(const ValueKey<String>('change-phone-link')));
      await tester.pumpAndSettle();

      expect(phoneField, findsOneWidget);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '901234567',
      );
    },
  );

  testWidgets('the staff login link leads to the staff login and back', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('staff-login-link')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('password-field')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('customer-login-link')));
    await tester.pumpAndSettle();
    expect(phoneField, findsOneWidget);
  });

  testWidgets('the language switch changes every string at once', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    final String uzTitle = l10n(tester).customerLoginTitle;

    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<AppLanguage>).last);
    await tester.pumpAndSettle();

    expect(find.text(uzTitle), findsNothing);
    expect(find.text(l10n(tester).customerLoginTitle), findsOneWidget);
    expect(l10n(tester).localeName, 'ru');
  });
}
