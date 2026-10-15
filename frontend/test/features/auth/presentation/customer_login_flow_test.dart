import 'dart:async';

import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
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
  final Finder confirmSend = find.byKey(
    const ValueKey<String>('confirm-phone-send'),
  );
  final Finder confirmEdit = find.byKey(
    const ValueKey<String>('confirm-phone-edit'),
  );

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository()
      ..requestResult = const RequestedCode(
        channel: 'telegram',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 45,
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
    if (confirmSend.evaluate().isNotEmpty) {
      await tester.tap(confirmSend);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('an incomplete phone is refused before anything is sent', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    await requestCode(tester, '9012345');

    expect(find.text(l10n(tester).phoneInvalid), findsOneWidget);
    expect(repository.calls, isEmpty);
    expect(codeField, findsNothing);
    expect(confirmSend, findsNothing, reason: 'nothing to confirm yet');
  });

  testWidgets(
    'the number is shown formatted in a confirmation, and Edit closes it without a request',
    (WidgetTester tester) async {
      await openApp(tester);

      await tester.enterText(phoneField, '901234567');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).confirmPhoneTitle), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsOneWidget);
      expect(repository.calls, isEmpty);

      await tester.tap(confirmEdit);
      await tester.pumpAndSettle();

      expect(confirmSend, findsNothing);
      expect(phoneField, findsOneWidget);
      expect(repository.calls, isEmpty);
    },
  );

  testWidgets(
    'while the confirmed request runs the dialog cannot be left, then the code screen opens',
    (WidgetTester tester) async {
      repository.holdAnswers = Completer<void>();
      await openApp(tester);

      await tester.enterText(phoneField, '901234567');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmSend);
      await tester.pump();

      expect(tester.widget<FilledButton>(confirmSend).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(confirmEdit).onPressed, isNull);
      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      expect(confirmSend, findsOneWidget, reason: 'the barrier is inert');

      repository.holdAnswers!.complete();
      await tester.pumpAndSettle();
      expect(confirmSend, findsNothing);
      expect(codeField, findsOneWidget);
    },
  );

  testWidgets(
    'the phone goes as +998 and nine digits; the code screen names the channel and the phone',
    (WidgetTester tester) async {
      await openApp(tester);

      await requestCode(tester, '901234567');

      expect(repository.calls, <String>['request:+998901234567']);
      expect(codeField, findsOneWidget);
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
    expect(confirmSend, findsNothing, reason: 'the dialog closed');
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
      // The Customer area's home: the catalog.
      expect(
        find.byKey(const ValueKey<String>('catalog-search')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a resend waits for the server timer, then sends again', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    await requestCode(tester, '901234567');

    expect(tester.widget<TextButton>(resendButton).onPressed, isNull);
    expect(find.text(l10n(tester).resendIn('0:45')), findsOneWidget);

    await tester.pump(const Duration(seconds: 44));
    expect(find.text(l10n(tester).resendIn('0:01')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(l10n(tester).resendCode), findsOneWidget);
    expect(tester.widget<TextButton>(resendButton).onPressed, isNotNull);

    await tester.tap(resendButton);
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((String c) => c.startsWith('request:')),
      hasLength(2),
    );
    expect(find.text(l10n(tester).resendIn('0:45')), findsOneWidget);

    // Leave no timer behind.
    await tester.pump(const Duration(seconds: 45));
  });

  testWidgets(
    'the code screen names SMS, and says only that a code was sent for the other channels',
    (WidgetTester tester) async {
      repository.requestResult = const RequestedCode(
        channel: 'sms',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 45,
      );
      await openApp(tester);
      await requestCode(tester, '901234567');
      expect(find.textContaining(l10n(tester).codeSentSms), findsOneWidget);
      expect(find.textContaining('+998 90 123 45 67'), findsOneWidget);

      repository.requestResult = const RequestedCode(
        channel: 'test',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 0,
      );
      await tester.tap(find.byKey(const ValueKey<String>('change-phone-link')));
      await tester.pumpAndSettle();
      await requestCode(tester, '901234567');

      expect(find.textContaining(l10n(tester).codeSentGeneric), findsOneWidget);
      expect(
        tester.widget<TextButton>(resendButton).onPressed,
        isNotNull,
        reason: 'a zero timer allows a resend at once',
      );
    },
  );

  testWidgets(
    'a code that is not six digits is refused before anything is sent',
    (WidgetTester tester) async {
      await openApp(tester);
      await requestCode(tester, '901234567');

      await tester.enterText(codeField, '12345');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).codeInvalidFormat), findsOneWidget);
      expect(
        repository.calls.where((String c) => c.startsWith('verify:')),
        isEmpty,
      );
    },
  );

  testWidgets('a pasted full number is sent as the same nine digits', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    await requestCode(tester, '+998 90 123 45 67');

    expect(repository.calls, <String>['request:+998901234567']);
  });

  testWidgets(
    'the code screen entered directly, with no code on its way, hands back to the phone screen',
    (WidgetTester tester) async {
      await openApp(tester);

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go(AppPaths.customerCode);
      await tester.pumpAndSettle();

      expect(phoneField, findsOneWidget);
      expect(codeField, findsNothing);
    },
  );

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

  testWidgets(
    'a code is typed into the boxes, and a pasted code fills all six',
    (WidgetTester tester) async {
      await openApp(tester);
      await requestCode(tester, '901234567');

      await tester.enterText(codeField, '12ab34');
      await tester.pump();
      expect(
        tester.widget<TextField>(codeField).controller?.text,
        '1234',
        reason: 'digits only',
      );

      await tester.enterText(codeField, '123456');
      await tester.pump();
      for (final String digit in '123456'.split('')) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('code-boxes')),
            matching: find.text(digit),
          ),
          findsOneWidget,
        );
      }

      await tester.enterText(codeField, '');
      await tester.enterText(codeField, '98765432');
      await tester.pump();
      expect(
        tester.widget<TextField>(codeField).controller?.text,
        '987654',
        reason: 'at most six',
      );

      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(repository.calls.last, 'verify:+998901234567:987654');
    },
  );

  testWidgets('the code field offers the one-time-code autofill', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    await requestCode(tester, '901234567');

    expect(
      tester.widget<TextField>(codeField).autofillHints,
      contains(AutofillHints.oneTimeCode),
    );
  });

  testWidgets(
    'a new customer gives a name, is welcomed, and lands on the catalog',
    (WidgetTester tester) async {
      repository.verifyResult = IssuedSession(
        token: 'c',
        user: user(id: 'c', fullName: null),
      );
      final FakeProfileRepository profiles = FakeProfileRepository();
      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: repository,
          overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
        ),
      );
      await tester.pumpAndSettle();
      await requestCode(tester, '901234567');

      await tester.enterText(codeField, '482913');
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      final Finder nameField = find.byKey(
        const ValueKey<String>('customer-name-field'),
      );
      final Finder nameContinue = find.byKey(
        const ValueKey<String>('customer-name-continue'),
      );
      expect(nameField, findsOneWidget);
      expect(find.text(l10n(tester).nameTitle), findsOneWidget);

      await tester.tap(nameContinue);
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
      expect(profiles.renames, isEmpty);

      await tester.enterText(nameField, 'Aziza');
      await tester.tap(nameContinue);
      await tester.pumpAndSettle();

      expect(profiles.renames, <String>['Aziza']);
      expect(find.text(l10n(tester).welcomeTitle('Aziza')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('catalog-search')),
        findsNothing,
        reason: 'the welcome waits for the button',
      );

      await tester.tap(find.byKey(const ValueKey<String>('welcome-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('catalog-search')),
        findsOneWidget,
      );
      expect(find.text(l10n(tester).welcomeTitle('Aziza')), findsNothing);
    },
  );

  testWidgets('a failed name save shows its text and keeps the name screen', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    repository.identities[SessionSlot.customer] = user(id: 'c', fullName: null);
    final FakeProfileRepository profiles = FakeProfileRepository()
      ..renameFailure = refusal(422, 'validation_failed');
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: repository,
        overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('customer-name-field')),
      'Aziza',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('customer-name-continue')),
    );
    await tester.pumpAndSettle();

    expect(failure, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('customer-name-field')),
      findsOneWidget,
    );
  });

  testWidgets('a returning customer with a name goes straight to the catalog', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    await requestCode(tester, '901234567');

    await tester.enterText(codeField, '482913');
    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('customer-name-field')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('catalog-search')),
      findsOneWidget,
    );
  });

  testWidgets('on mobile there is no separate staff login to reach', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    expect(
      find.byKey(const ValueKey<String>('staff-login-link')),
      findsNothing,
    );
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
