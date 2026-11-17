import 'dart:async';

import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/app_theme.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/auth/application/code_login_controller.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/auth/presentation/lock_message.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/fake_legal_repository.dart';
import '../../../support/fake_sign_in_device.dart';
import '../../../support/nonlinear_text_scaler.dart';
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
  final Finder failure = find.byKey(const ValueKey<String>('failure-message'));
  final Finder lockMessage = find.byKey(const ValueKey<String>('lock-message'));
  final Finder authNotice = find.byKey(const ValueKey<String>('auth-notice'));
  final Finder noticeAction = find.byKey(
    const ValueKey<String>('auth-notice-action'),
  );
  final Finder digitsHint = find.byKey(
    const ValueKey<String>('phone-digits-hint'),
  );
  final Finder phoneClear = find.byKey(const ValueKey<String>('phone-clear'));

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
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
  }

  testWidgets('an incomplete phone is refused before anything is sent', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    await requestCode(tester, '9012345');

    expect(find.text(l10n(tester).phoneDigitsLeft(2)), findsOneWidget);
    expect(find.text(l10n(tester).phoneInvalid), findsNothing);
    expect(repository.calls, isEmpty);
    expect(codeField, findsNothing);
  });

  testWidgets(
    'getting a code sends at once and opens the code page: no confirmation',
    (WidgetTester tester) async {
      await openApp(tester);

      await tester.enterText(phoneField, '901234567');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(repository.calls, <String>['request:+998901234567']);
      expect(codeField, findsOneWidget);
    },
  );

  testWidgets(
    'while the request runs the button says so and a second tap sends nothing, then the code page opens',
    (WidgetTester tester) async {
      repository.holdAnswers = Completer<void>();
      await openApp(tester);

      await tester.enterText(phoneField, '901234567');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();

      expect(find.text(l10n(tester).sendingCode), findsOneWidget);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      await tester.tap(continueButton, warnIfMissed: false);
      await tester.pump();
      expect(repository.calls, <String>['request:+998901234567']);

      repository.holdAnswers!.complete();
      await tester.pumpAndSettle();
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
      expect(find.text(l10n(tester).codeSentLead), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey<String>('code-phone')))
            .data,
        '+998 90 123 45 67',
      );
    },
  );

  testWidgets('a refused request shows its text and keeps the phone screen', (
    WidgetTester tester,
  ) async {
    repository.requestFailure = refusal(429, 'rate_limited');
    await openApp(tester);

    await requestCode(tester, '901234567');

    expect(authNotice, findsOneWidget);
    expect(failure, findsNothing);
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
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();

      expect(find.text(l10n(tester).errorCodeInvalid), findsOneWidget);
      expect(codeField, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 520));

      repository.verifyFailure = null;
      await tester.enterText(codeField, '482913');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
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

  testWidgets('a number not in Telegram offers another number', (
    WidgetTester tester,
  ) async {
    repository.requestFailure = refusal(409, 'code_delivery_unavailable');
    await openApp(tester);

    await requestCode(tester, '901234567');

    expect(authNotice, findsOneWidget);
    expect(
      find.text(l10n(tester).authNotInTelegram('+998 90 123 45 67')),
      findsOneWidget,
    );
    expect(codeField, findsNothing);

    await tester.tap(noticeAction);
    await tester.pumpAndSettle();

    expect(authNotice, findsNothing);
    expect(tester.widget<TextFormField>(phoneField).controller?.text, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('a lost connection retries the same number', (
    WidgetTester tester,
  ) async {
    repository.requestFailure = const NetworkFailure();
    await openApp(tester);

    await requestCode(tester, '901234567');

    expect(find.text(l10n(tester).authNoInternet), findsOneWidget);

    repository.requestFailure = null;
    await tester.tap(noticeAction);
    await tester.pumpAndSettle();

    expect(repository.calls, <String>[
      'request:+998901234567',
      'request:+998901234567',
    ]);
    expect(authNotice, findsNothing);
    expect(codeField, findsOneWidget);
  });

  testWidgets(
    'the code page carries no resend link; the server wait is kept for the sheet',
    (WidgetTester tester) async {
      await openApp(tester);
      await requestCode(tester, '901234567');

      expect(find.byKey(const ValueKey<String>('resend-button')), findsNothing);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(
        container.read(codeLoginControllerProvider).resendInSeconds,
        45,
        reason: 'the server timer, not a constant',
      );

      await tester.pump(const Duration(seconds: 45));
      expect(
        container.read(codeLoginControllerProvider).canResend,
        isTrue,
        reason: 'a resend opens when the server wait ends',
      );
    },
  );

  testWidgets(
    'three wrong codes lock the screen: the card counts down, the boxes go, the button waits, then a new code is asked for',
    (WidgetTester tester) async {
      repository.requestResult = const RequestedCode(
        channel: 'telegram',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 0,
      );
      repository.verifyFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 60,
      );
      await openApp(tester);
      await requestCode(tester, '901234567');

      await tester.enterText(codeField, '000000');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();

      expect(find.text('1:00'), findsOneWidget);
      expect(failure, findsNothing, reason: 'the lock is not printed twice');
      expect(codeField, findsNothing);
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:59'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      expect(find.text(l10n(tester).codeLockDoneTime), findsOneWidget);
      expect(codeField, findsNothing, reason: 'the spent code is not typed');
      expect(find.text(l10n(tester).codeNewCode), findsOneWidget);
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);

      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).codeLockDoneTime), findsNothing);
      expect(codeField, findsOneWidget);
      expect(
        repository.calls.where((String c) => c.startsWith('request:')),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'during the lock there are no boxes: the keyboard action sends no verify',
    (WidgetTester tester) async {
      repository.verifyFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 60,
      );
      await openApp(tester);
      await requestCode(tester, '901234567');
      await tester.enterText(codeField, '000000');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();
      int verifyCalls() => repository.calls
          .where((String call) => call.startsWith('verify:'))
          .length;
      expect(verifyCalls(), 1);

      expect(codeField, findsNothing, reason: 'the card replaces the boxes');
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(verifyCalls(), 1);

      await tester.pump(const Duration(seconds: 60));
    },
  );

  testWidgets('the phone screen refuses a locked phone with the seconds left', (
    WidgetTester tester,
  ) async {
    repository.requestFailure = ApiRefusal(
      const ApiError(status: 429, code: 'code_locked'),
      retryAfterSeconds: 42,
    );
    await openApp(tester);

    await requestCode(tester, '901234567');

    expect(find.text(l10n(tester).codeLocked('0:42')), findsOneWidget);
    expect(failure, findsNothing);
    expect(codeField, findsNothing);
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.pump(const Duration(seconds: 42));
    expect(lockMessage, findsNothing);
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
  });

  testWidgets('the end of a lock on the phone screen is announced once', (
    WidgetTester tester,
  ) async {
    repository.requestFailure = ApiRefusal(
      const ApiError(status: 429, code: 'code_locked'),
      retryAfterSeconds: 3,
    );
    await openApp(tester);
    await requestCode(tester, '901234567');
    tester.takeAnnouncements();

    await tester.pump(const Duration(seconds: 3));

    expect(
      tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .toList(),
      <String>[l10n(tester).codeLockOver],
    );
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
  });

  testWidgets(
    'the lock binds only its own phone: another number is free, the locked one waits',
    (WidgetTester tester) async {
      repository.requestFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 42,
      );
      await openApp(tester);
      await requestCode(tester, '901234567');
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.enterText(phoneField, '931112233');
      await tester.pump();
      expect(lockMessage, findsNothing);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

      await tester.enterText(phoneField, '901234567');
      await tester.pump();
      expect(find.text(l10n(tester).codeLocked('0:42')), findsOneWidget);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.pump(const Duration(seconds: 42));
    },
  );

  testWidgets(
    'the lock is announced once, and its ticking card is not a live region',
    (WidgetTester tester) async {
      repository.verifyFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 60,
      );
      await openApp(tester);
      await requestCode(tester, '901234567');
      await tester.enterText(codeField, '000000');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();

      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pump(const Duration(seconds: 5));
      final SemanticsNode node = tester.getSemantics(
        find.byKey(const ValueKey<String>('code-lock-card')),
      );
      expect(node.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      handle.dispose();

      final List<CapturedAccessibilityAnnouncement> announced = tester
          .takeAnnouncements()
          .where(
            (CapturedAccessibilityAnnouncement a) => a.message.startsWith(
              l10n(tester).codeLocked('').substring(0, 10),
            ),
          )
          .toList();
      expect(announced, hasLength(1));
      expect(announced.single.message, l10n(tester).codeLocked('1:00'));

      await tester.pump(const Duration(seconds: 55));
      final List<String> atTheEnd = tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .toList();
      expect(atTheEnd, <String>[l10n(tester).codeLockDoneSpoken]);
    },
  );

  testWidgets(
    'the phone screen keeps the lock running and shows the seconds left after leaving a locked code screen',
    (WidgetTester tester) async {
      repository.verifyFailure = ApiRefusal(
        const ApiError(status: 429, code: 'code_locked'),
        retryAfterSeconds: 60,
      );
      await openApp(tester);
      await requestCode(tester, '901234567');
      await tester.enterText(codeField, '000000');
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 25));

      await tester.tap(find.byKey(const ValueKey<String>('code-change-phone')));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).codeLocked('0:35')), findsOneWidget);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      final int requests = repository.calls
          .where((String call) => call.startsWith('request:'))
          .length;
      expect(requests, 1, reason: 'no second request is needed to learn it');

      await tester.enterText(phoneField, '931112233');
      await tester.pump();
      expect(lockMessage, findsNothing);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

      await tester.enterText(phoneField, '901234567');
      await tester.pump();
      await tester.pump(const Duration(seconds: 35));
    },
  );

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
      expect(find.text(l10n(tester).codeSentLeadSms), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsOneWidget);

      repository.requestResult = const RequestedCode(
        channel: 'test',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 0,
      );
      await tester.tap(find.byKey(const ValueKey<String>('code-change-phone')));
      await tester.pumpAndSettle();
      await requestCode(tester, '901234567');

      expect(find.text(l10n(tester).codeSentLeadOther), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsOneWidget);
    },
  );

  testWidgets(
    'a code that is not six digits is refused before anything is sent',
    (WidgetTester tester) async {
      await openApp(tester);
      await requestCode(tester, '901234567');

      await tester.enterText(codeField, '12345');
      await tester.pump();
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
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

      await tester.tap(find.byKey(const ValueKey<String>('code-change-phone')));
      await tester.pumpAndSettle();

      expect(phoneField, findsOneWidget);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '90 123 45 67',
      );
    },
  );

  testWidgets('the phone is grouped while it is typed and sent as E.164', (
    WidgetTester tester,
  ) async {
    await openApp(tester);

    await tester.enterText(phoneField, '900000031');
    await tester.pump();

    expect(
      tester.widget<TextFormField>(phoneField).controller?.text,
      '90 000 00 31',
    );

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(repository.calls, <String>['request:+998900000031']);
  });

  testWidgets(
    'six digits pasted into a partly filled code become the whole code',
    (WidgetTester tester) async {
      await openApp(tester);
      await requestCode(tester, '901234567');

      await tester.enterText(codeField, '1');
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '1123456',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();

      expect(tester.widget<TextField>(codeField).controller?.text, '123456');
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

  testWidgets('the code page button is set in the interface font', (
    WidgetTester tester,
  ) async {
    await openApp(tester);
    await requestCode(tester, '901234567');

    final Finder text = find.descendant(
      of: verifyButton,
      matching: find.byType(Text),
    );
    expect(
      DefaultTextStyle.of(tester.element(text)).style.fontFamily,
      appFontFamily,
    );
    expect(tester.widget<Text>(text).data, l10n(tester).verifyButton);

    // Leave no timer behind.
    await tester.pump(const Duration(seconds: 61));
  });

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
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
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
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
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

  group('the phone page (DL-139)', () {
    Future<void> openRussian(
      WidgetTester tester, {
      FakePhoneNumberHint? hint,
      FakeLegalRepository? legal,
      List<Override> extra = const <Override>[],
    }) async {
      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: repository,
          legal: legal,
          phoneHint: hint,
          device: const Locale('ru'),
          overrides: extra,
        ),
      );
      await tester.pumpAndSettle();
    }

    bool hasFocus(WidgetTester tester) => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;

    testWidgets('the phone field is named and the example is not read', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openRussian(tester);

      final String label = tester.getSemantics(phoneField).label;
      expect(label, contains('Номер телефона'));
      expect(label, contains('+998'));
      expect(find.bySemanticsLabel(RegExp('90 123 45 67')), findsNothing);
      handle.dispose();
    });

    testWidgets(
      'the button is grey until nine digits and says how many are missing',
      (WidgetTester tester) async {
        await openRussian(tester);
        expect(digitsHint, findsNothing);

        await tester.enterText(phoneField, '901234');
        await tester.pump();
        expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
        expect(digitsHint, findsNothing);
        tester.takeAnnouncements();

        await tester.tap(continueButton);
        await tester.pump();

        expect(find.text('Введите ещё 3 цифры'), findsOneWidget);
        expect(
          tester.takeAnnouncements().map(
            (CapturedAccessibilityAnnouncement a) => a.message,
          ),
          contains('Введите ещё 3 цифры'),
        );
        expect(repository.calls, isEmpty);

        await tester.enterText(phoneField, '9012345');
        await tester.pump();
        expect(digitsHint, findsNothing, reason: 'any edit hides it');

        await tester.enterText(phoneField, '901234567');
        await tester.pump();
        expect(
          tester.widget<FilledButton>(continueButton).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('the keyboard Done with fewer digits says the same', (
      WidgetTester tester,
    ) async {
      await openRussian(tester);

      await tester.enterText(phoneField, '90123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Введите ещё 1 цифру'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('the clear button empties the field and keeps focus', (
      WidgetTester tester,
    ) async {
      await openRussian(tester);
      expect(phoneClear, findsNothing);

      await tester.enterText(phoneField, '901234567');
      await tester.pump();
      expect(phoneClear, findsOneWidget);
      expect(tester.getSize(phoneClear), const Size(44, 44));

      await tester.tap(phoneClear);
      await tester.pump();

      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        isEmpty,
      );
      expect(phoneClear, findsNothing);
      expect(hasFocus(tester), isTrue);
    });

    testWidgets('the own-number sheet fills the field once', (
      WidgetTester tester,
    ) async {
      final FakePhoneNumberHint hint = FakePhoneNumberHint('901234567');
      await openRussian(tester, hint: hint);

      expect(hint.calls, 1);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '90 123 45 67',
      );
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

      await tester.tap(phoneClear);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(phoneField);
      await tester.pump();

      expect(hint.calls, 1, reason: 'a second focus asks nothing');
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        isEmpty,
      );
    });

    testWidgets('a cancelled own-number sheet leaves the field empty', (
      WidgetTester tester,
    ) async {
      final FakePhoneNumberHint hint = FakePhoneNumberHint();
      await openRussian(tester, hint: hint);

      expect(hint.calls, 1);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        isEmpty,
      );
    });

    testWidgets('the consent sits under the button', (
      WidgetTester tester,
    ) async {
      await openRussian(tester, legal: FakeLegalRepository()..publishBoth());

      final Finder consent = find.byKey(const ValueKey<String>('consent-line'));
      expect(consent, findsOneWidget);
      // The line's box keeps 13 above its text for the 44 tall link targets,
      // so the text stands 14 below the button.
      expect(
        tester.getTopLeft(consent).dy - tester.getBottomLeft(continueButton).dy,
        closeTo(1, 0.5),
      );
    });

    testWidgets(
      'large text with the keyboard up keeps «Получить код» in view',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          appUnderTest(
            tokens: tokens,
            repository: repository,
            device: const Locale('ru'),
            textScaler: const NonlinearTextScaler(2),
          ),
        );
        await tester.pumpAndSettle();

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(phoneField);
        await tester.pumpAndSettle();

        expect(tester.getBottomLeft(continueButton).dy, lessThanOrEqualTo(328));
      },
    );

    for (final double scale in <double>[1, 2]) {
      testWidgets('every tap target holds at text x$scale, empty and with a '
          'notice', (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          appUnderTest(
            tokens: tokens,
            repository: repository,
            device: const Locale('ru'),
            textScaler: scale == 1 ? null : NonlinearTextScaler(scale),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        repository.requestFailure = refusal(409, 'code_delivery_unavailable');
        await tester.enterText(phoneField, '901234567');
        await tester.ensureVisible(continueButton);
        await tester.pump();
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
        expect(authNotice, findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('a failure of another call never shows on the phone page', (
      WidgetTester tester,
    ) async {
      await openRussian(
        tester,
        extra: [codeLoginControllerProvider.overrideWith(_SettableLogin.new)],
      );
      final _SettableLogin login = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      ).read(codeLoginControllerProvider.notifier) as _SettableLogin;

      login.put(
        const CodeLoginState(
          phone: '+998901234567',
          failure: NetworkFailure(),
          failedAction: CodeLoginAction.resend,
        ),
      );
      await tester.pump();
      expect(authNotice, findsNothing);

      login.put(
        const CodeLoginState(
          phone: '+998901234567',
          failure: NetworkFailure(),
          failedAction: CodeLoginAction.request,
        ),
      );
      await tester.pump();
      expect(authNotice, findsOneWidget);
    });

    testWidgets(
      'a page under another route tells its lock message not to speak',
      (WidgetTester tester) async {
        await openRussian(tester);
        final BuildContext context = tester.element(
          find.byType(Scaffold).first,
        );
        final Finder lock = find.byType(LockMessage, skipOffstage: false);
        expect(tester.widget<LockMessage>(lock).speaks, isTrue);

        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const Scaffold(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.widget<LockMessage>(lock).speaks, isFalse);
      },
    );

    testWidgets('a lock message told not to speak announces nothing', (
      WidgetTester tester,
    ) async {
      Future<void> show({required bool speaks, required int seconds}) =>
          tester.pumpWidget(
            MaterialApp(
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: LockMessage(
                  lockedSeconds: seconds,
                  lockOver: seconds == 0,
                  speaks: speaks,
                ),
              ),
            ),
          );

      await show(speaks: false, seconds: 0);
      await show(speaks: false, seconds: 5);
      await show(speaks: false, seconds: 0);
      expect(tester.takeAnnouncements(), isEmpty);

      await show(speaks: true, seconds: 5);
      expect(tester.takeAnnouncements(), hasLength(1));
    });
  });

  group('the code page (DL-139)', () {
    final Finder attempts = find.byKey(const ValueKey<String>('code-attempts'));
    final Finder lockCard = find.byKey(
      const ValueKey<String>('code-lock-card'),
    );
    final Finder backArrow = find.byKey(
      const ValueKey<String>('auth-back-button'),
    );
    final Finder changeNumber = find.byKey(
      const ValueKey<String>('code-change-phone'),
    );
    final Finder catalog = find.byKey(const ValueKey<String>('catalog-search'));

    ApiRefusal wrong({int? left}) => ApiRefusal(
      ApiError(
        status: 422,
        code: 'code_invalid',
        details: <String, Object?>{'attempts_left': ?left},
      ),
    );

    ApiRefusal locked(int seconds) => ApiRefusal(
      const ApiError(status: 429, code: 'code_locked'),
      retryAfterSeconds: seconds,
    );

    Future<void> openRussian(WidgetTester tester) async {
      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: repository,
          device: const Locale('ru'),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<String> haptics(WidgetTester tester) {
      final List<String> calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return calls;
    }

    List<String> spoken(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message)
        .toList();

    int verifies() => repository.calls
        .where((String call) => call.startsWith('verify:'))
        .length;

    /// Types the sixth digit last, after the first five, as a person does.
    Future<void> typeCode(WidgetTester tester, String code) async {
      await tester.enterText(codeField, code.substring(0, code.length - 1));
      await tester.pump();
      await tester.enterText(codeField, code);
      await tester.pump();
    }

    const Duration typedWait = Duration(milliseconds: 140);

    testWidgets('system back from the code returns to the number, kept', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await requestCode(tester, '901234567');
      expect(codeField, findsOneWidget);

      final bool handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(codeField, findsNothing);
      expect(phoneField, findsOneWidget);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '90 123 45 67',
      );
    });

    testWidgets('the arrow and Изменить return to the number', (
      WidgetTester tester,
    ) async {
      await openRussian(tester);
      await requestCode(tester, '901234567');
      expect(find.text('Изменить'), findsOneWidget);

      await tester.tap(backArrow);
      await tester.pumpAndSettle();
      expect(codeField, findsNothing);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '90 123 45 67',
      );

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(codeField, findsOneWidget);

      await tester.tap(changeNumber);
      await tester.pumpAndSettle();
      expect(codeField, findsNothing);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '90 123 45 67',
      );
    });

    testWidgets('the header names the channel and shows the number big', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openRussian(tester);
      await requestCode(tester, '901234567');

      expect(find.text('Отправили код в Telegram на номер'), findsOneWidget);
      final Text number = tester.widget<Text>(
        find.byKey(const ValueKey<String>('code-phone')),
      );
      expect(number.data, '+998 90 123 45 67');
      expect(number.style?.fontSize, 17);
      expect(number.style?.fontWeight, FontWeight.w700);
      expect(
        tester.getSemantics(changeNumber).label,
        contains('Изменить номер'),
      );
      expect(
        tester.getSemantics(backArrow).tooltip,
        'Назад, к номеру телефона',
      );
      handle.dispose();
    });

    testWidgets('back keeps the number and the lock', (
      WidgetTester tester,
    ) async {
      repository.verifyFailure = locked(60);
      await openApp(tester);
      await requestCode(tester, '901234567');
      await typeCode(tester, '000000');
      await tester.pump(typedWait);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 25));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(phoneField, findsOneWidget);
      expect(
        tester.widget<TextFormField>(phoneField).controller?.text,
        '90 123 45 67',
      );
      expect(find.text(l10n(tester).codeLocked('0:35')), findsOneWidget);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      await tester.pump(const Duration(seconds: 35));
    });

    testWidgets('back while checking does nothing', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await requestCode(tester, '901234567');
      repository.holdAnswers = Completer<void>();
      await typeCode(tester, '482913');
      await tester.pump(typedWait);
      await tester.pump();
      expect(verifies(), 1);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(backArrow, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(codeField, findsOneWidget);

      repository.holdAnswers!.complete();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(codeField, findsOneWidget, reason: 'nor during the check mark');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(catalog, findsOneWidget);
    });

    testWidgets('the code page slides in over the number', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await tester.enterText(phoneField, '901234567');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey<String>('phone-field'), skipOffstage: false),
        findsOneWidget,
      );
      expect(codeField, findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the sixth digit verifies by itself', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await requestCode(tester, '901234567');
      await tester.enterText(codeField, '48291');
      await tester.pump();
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);
      expect(find.text(l10n(tester).verifyButton), findsOneWidget);

      await tester.enterText(codeField, '482913');
      await tester.pump(const Duration(milliseconds: 139));
      expect(verifies(), 0);
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(repository.calls.last, 'verify:+998901234567:482913');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(catalog, findsOneWidget);
    });

    testWidgets('six digits and a tap send one verify', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await requestCode(tester, '901234567');
      repository.holdAnswers = Completer<void>();

      await typeCode(tester, '482913');
      await tester.tap(verifyButton);
      await tester.pump();
      expect(verifies(), 1);
      expect(find.text(l10n(tester).codeChecking), findsOneWidget);

      await tester.pump(typedWait);
      await tester.tap(verifyButton, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(verifies(), 1);

      repository.holdAnswers!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(verifies(), 1);
    });

    testWidgets('a right code shows ✓ before the home', (
      WidgetTester tester,
    ) async {
      final List<String> buzzes = haptics(tester);
      await openRussian(tester);
      await requestCode(tester, '901234567');
      repository.holdAnswers = Completer<void>();
      await typeCode(tester, '482913');
      await tester.pump(typedWait);
      await tester.pump();
      expect(find.text('Проверяем…'), findsOneWidget);
      expect(buzzes, isEmpty);
      tester.takeAnnouncements();

      repository.holdAnswers!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Код верный'), findsOneWidget);
      expect(buzzes, <String>['HapticFeedbackType.successNotification']);
      expect(spoken(tester), contains('Код верный'));
      expect(codeField, findsOneWidget);
      expect(catalog, findsNothing);

      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(catalog, findsOneWidget);
    });

    testWidgets('a wrong code shakes red, says the tries left and clears', (
      WidgetTester tester,
    ) async {
      final List<String> buzzes = haptics(tester);
      repository.verifyFailure = wrong(left: 2);
      await openRussian(tester);
      await requestCode(tester, '901234567');
      tester.takeAnnouncements();

      await typeCode(tester, '000000');
      await tester.pump(typedWait);
      await tester.pump();

      expect(find.text('Неверный код. Осталось 2 попытки'), findsOneWidget);
      expect(buzzes, <String>['HapticFeedbackType.errorNotification']);
      expect(spoken(tester), contains('Неверный код. Осталось 2 попытки'));
      expect(
        tester.widget<TextField>(codeField).controller?.text,
        '000000',
        reason: 'the digits stay while the boxes are red',
      );
      final BoxDecoration box =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byKey(const ValueKey<String>('code-box-0')),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect((box.border! as Border).top.color, KitColors.danger);

      await tester.pump(const Duration(milliseconds: 519));
      expect(tester.widget<TextField>(codeField).controller?.text, '000000');
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.widget<TextField>(codeField).controller?.text, isEmpty);
      expect(attempts, findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a wrong code without a count says only that it is wrong', (
      WidgetTester tester,
    ) async {
      repository.verifyFailure = wrong();
      await openRussian(tester);
      await requestCode(tester, '901234567');

      await typeCode(tester, '000000');
      await tester.pump(typedWait);
      await tester.pump();

      expect(
        find.descendant(of: attempts, matching: find.text('Неверный код')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pumpAndSettle();
    });

    testWidgets('input during the red shake is refused, then the boxes clear', (
      WidgetTester tester,
    ) async {
      repository.verifyFailure = wrong(left: 1);
      await openApp(tester);
      await requestCode(tester, '901234567');
      await typeCode(tester, '000000');
      await tester.pump(typedWait);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(codeField, '00000');
      await tester.pump();
      expect(tester.widget<TextField>(codeField).controller?.text, '000000');
      expect(verifies(), 1);

      await tester.pump(const Duration(milliseconds: 320));
      expect(tester.widget<TextField>(codeField).controller?.text, isEmpty);
      await tester.pumpAndSettle();
      expect(verifies(), 1);
    });

    testWidgets('the third wrong code shows the countdown card', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      repository.verifyFailure = locked(60);
      await openRussian(tester);
      await requestCode(tester, '901234567');
      tester.takeAnnouncements();

      await typeCode(tester, '000000');
      await tester.pump(typedWait);
      await tester.pumpAndSettle();

      expect(lockCard, findsOneWidget);
      expect(
        find.descendant(of: lockCard, matching: find.text('1:00')),
        findsOneWidget,
      );
      expect(codeField, findsNothing);
      expect(spoken(tester), contains(l10n(tester).codeLocked('1:00')));
      expect(
        tester.getSemantics(lockCard).label,
        contains('Пауза 1:00. Код введён неверно 3 раза'),
      );
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);

      await tester.pump(const Duration(seconds: 59));
      expect(
        find.descendant(of: lockCard, matching: find.text('0:01')),
        findsOneWidget,
      );
      expect(spoken(tester), isEmpty, reason: 'nothing ticks aloud');
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Можно снова'), findsOneWidget);
      expect(
        tester.getSemantics(lockCard).label,
        contains('Можно получить новый код'),
      );
      expect(spoken(tester), <String>['Можно получить новый код']);
      expect(
        find.descendant(
          of: verifyButton,
          matching: find.text('Получить новый код'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNotNull);
      handle.dispose();
    });

    testWidgets('a new code after the lock opens the boxes again', (
      WidgetTester tester,
    ) async {
      repository.verifyFailure = locked(3);
      await openApp(tester);
      await requestCode(tester, '901234567');
      await typeCode(tester, '000000');
      await tester.pump(typedWait);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      tester.takeAnnouncements();

      repository.verifyFailure = null;
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();

      expect(
        repository.calls.where((String c) => c.startsWith('request:')),
        hasLength(2),
      );
      expect(lockCard, findsNothing);
      expect(codeField, findsOneWidget);
      expect(tester.widget<TextField>(codeField).controller?.text, isEmpty);
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);
      expect(spoken(tester), <String>[
        l10n(tester).codeSentSpoken('+998 90 123 45 67'),
      ]);
    });

    testWidgets('a Shopper\'s code also shows ✓ before the password', (
      WidgetTester tester,
    ) async {
      repository
        ..verifyResult = IssuedSession(
          token: 'c',
          user: user(id: 'c', phone: '+998902222222'),
        )
        ..staffSteps['+998902222222'] = StaffStep(
          token: 't' * 64,
          expiresAt: DateTime.utc(2100),
        );
      await openRussian(tester);
      await requestCode(tester, '902222222');
      await typeCode(tester, '482913');
      await tester.pump(typedWait);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Код верный'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('staff-password-field')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('staff-password-field')),
        findsOneWidget,
      );
    });

    testWidgets('the page under the code page stays quiet', (
      WidgetTester tester,
    ) async {
      repository.verifyFailure = locked(60);
      await openRussian(tester);
      await requestCode(tester, '901234567');
      await typeCode(tester, '000000');
      await tester.pump(typedWait);
      await tester.pumpAndSettle();
      tester.takeAnnouncements();

      await tester.pump(const Duration(seconds: 60));
      expect(spoken(tester), <String>[
        'Можно получить новый код',
      ], reason: 'only the page on top speaks');

      repository.requestFailure = const NetworkFailure();
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('auth-notice'), skipOffstage: false),
        findsNothing,
        reason: 'a failed resend shows on the code page only',
      );
    });

    for (final double scale in <double>[1, 2]) {
      testWidgets('every tap target holds at text x$scale on the code page', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        repository.verifyFailure = wrong(left: 2);
        await tester.pumpWidget(
          appUnderTest(
            tokens: tokens,
            repository: repository,
            device: const Locale('ru'),
            textScaler: scale == 1 ? null : NonlinearTextScaler(scale),
          ),
        );
        await tester.pumpAndSettle();
        await requestCode(tester, '901234567');
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await typeCode(tester, '000000');
        await tester.pump(typedWait);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await tester.pump(const Duration(milliseconds: 520));
        await tester.pumpAndSettle();

        repository.verifyFailure = locked(5);
        await typeCode(tester, '111111');
        await tester.pump(typedWait);
        await tester.pumpAndSettle();
        expect(lockCard, findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }
  });
}

/// A code-login controller a test can put any state into.
class _SettableLogin extends CodeLoginController {
  void put(CodeLoginState next) => state = next;
}
