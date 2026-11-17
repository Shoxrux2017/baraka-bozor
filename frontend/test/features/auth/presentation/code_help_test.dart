import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/auth/application/code_login_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_sign_in_device.dart';
import '../../../support/nonlinear_text_scaler.dart';

/// The code page's help of `DL-139`: the paste chip, Telegram, the «Не пришёл
/// код?» sheet and the refusals as notices.
void main() {
  late FakeAuthRepository repository;
  late FakeClipboardCode clipboard;
  late FakeTelegramLauncher telegram;

  final Finder phoneField = find.byKey(const ValueKey<String>('phone-field'));
  final Finder continueButton = find.byKey(
    const ValueKey<String>('continue-button'),
  );
  final Finder codeField = find.byKey(const ValueKey<String>('code-field'));
  final Finder chip = find.byKey(const ValueKey<String>('code-paste'));
  final Finder openTelegram = find.byKey(
    const ValueKey<String>('code-open-telegram'),
  );
  final Finder noCode = find.byKey(const ValueKey<String>('code-no-code'));
  final Finder sheet = find.byKey(const ValueKey<String>('no-code-sheet'));
  final Finder resendButton = find.byKey(
    const ValueKey<String>('resend-button'),
  );
  final Finder sheetChange = find.byKey(
    const ValueKey<String>('no-code-change-phone'),
  );
  final Finder notice = find.byKey(const ValueKey<String>('auth-notice'));
  final Finder noticeAction = find.byKey(
    const ValueKey<String>('auth-notice-action'),
  );

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    repository = FakeAuthRepository()
      ..requestResult = const RequestedCode(
        channel: 'telegram',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 0,
      )
      ..verifyResult = IssuedSession(
        token: 'c',
        user: user(id: 'c'),
      );
    clipboard = FakeClipboardCode(code: '482913');
    telegram = FakeTelegramLauncher();
  });

  Future<void> openCodePage(
    WidgetTester tester, {
    double scale = 1,
    bool pump = true,
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        repository: repository,
        clipboard: clipboard,
        telegram: telegram,
        device: const Locale('ru'),
        textScaler: scale == 1 ? null : NonlinearTextScaler(scale),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(phoneField, '901234567');
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(codeField, findsOneWidget);
  }

  String codeText(WidgetTester tester) =>
      tester.widget<TextField>(codeField).controller!.text;

  testWidgets('a code in the clipboard is pasted and verified', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pump();
    await tester.pump();
    expect(codeText(tester), '482913');
    expect(clipboard.reads, 1);

    await tester.pump(const Duration(milliseconds: 160));
    expect(repository.calls, contains('verify:+998901234567:482913'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  });

  testWidgets('the chip never reads the clipboard by itself', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);

    expect(chip, findsOneWidget);
    expect(clipboard.checks, greaterThan(0));
    expect(clipboard.reads, 0);

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(clipboard.reads, 1);
  });

  testWidgets('a clipboard without a code hides the chip', (
    WidgetTester tester,
  ) async {
    clipboard.code = null;
    await openCodePage(tester);

    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(chip, findsNothing);
    expect(codeText(tester), isEmpty);
    expect(
      repository.calls.where((String c) => c.startsWith('verify')),
      isEmpty,
    );
  });

  testWidgets('no chip while the clipboard holds no text', (
    WidgetTester tester,
  ) async {
    clipboard.holds = false;
    await openCodePage(tester);

    expect(chip, findsNothing);
    expect(clipboard.reads, 0);
  });

  testWidgets('the chip comes back after the app resumes', (
    WidgetTester tester,
  ) async {
    clipboard.holds = false;
    await openCodePage(tester);
    expect(chip, findsNothing);

    clipboard.holds = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(chip, findsOneWidget);
    expect(clipboard.reads, 0);
  });

  testWidgets('the chip goes once six digits stand in the boxes', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    await tester.enterText(codeField, '12345');
    await tester.pump();
    expect(chip, findsOneWidget);
    repository.verifyFailure = refusal(422, 'code_invalid');
    await tester.enterText(codeField, '123456');
    await tester.pump();
    expect(chip, findsNothing);
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
  });

  testWidgets('Открыть Telegram opens Telegram', (WidgetTester tester) async {
    await openCodePage(tester);

    await tester.ensureVisible(openTelegram);
    await tester.tap(openTelegram);
    await tester.pumpAndSettle();

    expect(telegram.calls, 1);
    expect(sheet, findsNothing);
  });

  testWidgets('when Telegram does not open the sheet does', (
    WidgetTester tester,
  ) async {
    telegram.opens = false;
    await openCodePage(tester);

    await tester.ensureVisible(openTelegram);
    await tester.tap(openTelegram);
    await tester.pumpAndSettle();

    expect(telegram.calls, 1);
    expect(sheet, findsOneWidget);
    expect(
      find.text(l10n(tester).codeNotArrivedText('+998 90 123 45 67')),
      findsOneWidget,
    );
  });

  testWidgets('no Telegram button for an SMS code', (
    WidgetTester tester,
  ) async {
    repository.requestResult = const RequestedCode(
      channel: 'sms',
      expiresInSeconds: 300,
      resendAvailableInSeconds: 0,
    );
    await openCodePage(tester);

    expect(openTelegram, findsNothing);
    expect(noCode, findsOneWidget);
    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();
    expect(
      find.text(l10n(tester).codeNotArrivedTextOther('+998 90 123 45 67')),
      findsOneWidget,
    );
  });

  testWidgets('the sheet resends and closes', (WidgetTester tester) async {
    await openCodePage(tester);
    await tester.enterText(codeField, '123');
    await tester.pump();

    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(find.text(l10n(tester).codeNotArrived), findsWidgets);
    tester.takeAnnouncements();

    await tester.tap(resendButton);
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(
      repository.calls.where((String c) => c.startsWith('request')),
      hasLength(2),
    );
    expect(codeText(tester), isEmpty);
    expect(
      tester.takeAnnouncements().map((a) => a.message),
      contains(l10n(tester).codeSentSpoken('+998 90 123 45 67')),
    );
  });

  testWidgets('the sheet shows the wait and the button stays off', (
    WidgetTester tester,
  ) async {
    repository.requestResult = const RequestedCode(
      channel: 'telegram',
      expiresInSeconds: 300,
      resendAvailableInSeconds: 45,
    );
    await openCodePage(tester);
    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();

    expect(find.textContaining('Отправить ещё раз через'), findsOneWidget);
    expect(tester.widget<FilledButton>(resendButton).onPressed, isNull);
    await tester.pump(const Duration(seconds: 45));
    expect(find.text(l10n(tester).resendCode), findsOneWidget);
    expect(tester.widget<FilledButton>(resendButton).onPressed, isNotNull);
  });

  testWidgets('the sheet cannot be changed away from while a resend runs', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();

    repository.holdAnswers = Completer<void>();
    await tester.tap(resendButton);
    await tester.pump();
    expect(find.text(l10n(tester).sendingCode), findsOneWidget);

    await tester.tap(sheetChange);
    await tester.pump();
    expect(sheet, findsOneWidget);
    expect(codeField, findsOneWidget);

    repository.holdAnswers!.complete();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets("the sheet's hour limit turns the button off", (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();

    repository.requestFailure = ApiRefusal(
      const ApiError(
        status: 429,
        code: 'rate_limited',
        details: <String, Object?>{'limit': 'phone_hourly', 'max_sends': 5},
      ),
      retryAfterSeconds: 1800,
    );
    await tester.tap(resendButton);
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: notice), findsOneWidget);
    expect(find.text(l10n(tester).authHourLimit(5, '30 мин')), findsOneWidget);
    expect(tester.widget<FilledButton>(resendButton).onPressed, isNull);
  });

  testWidgets('the sheet changes the number', (WidgetTester tester) async {
    await openCodePage(tester);
    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();

    await tester.tap(sheetChange);
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(codeField, findsNothing);
    expect(phoneField, findsOneWidget);
  });

  testWidgets('a lost connection while checking retries the same code', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    repository.verifyFailure = const NetworkFailure();
    await tester.enterText(codeField, '482913');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    expect(notice, findsOneWidget);
    expect(find.text(l10n(tester).authNoInternet), findsOneWidget);

    repository.verifyFailure = null;
    await tester.ensureVisible(noticeAction);
    await tester.tap(noticeAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      repository.calls.where((String c) => c == 'verify:+998901234567:482913'),
      hasLength(2),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  });

  testWidgets('retry after a lost check sends the digits on screen', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    repository.verifyFailure = const NetworkFailure();
    await tester.enterText(codeField, '482913');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);

    repository.verifyFailure = null;
    await tester.enterText(codeField, '482914');
    await tester.pump();
    expect(notice, findsNothing, reason: 'a changed code drops the failure');

    await tester.tap(find.byKey(const ValueKey<String>('verify-button')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.calls.last, 'verify:+998901234567:482914');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  });

  testWidgets('a retry with the same digits repeats the check', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    repository.verifyFailure = const NetworkFailure();
    await tester.enterText(codeField, '482913');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    repository.verifyFailure = null;
    await tester.ensureVisible(noticeAction);
    await tester.tap(noticeAction);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      repository.calls.where((String c) => c == 'verify:+998901234567:482913'),
      hasLength(2),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  });

  testWidgets('while locked a failed Telegram launch opens no sheet', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    repository.verifyFailure = ApiRefusal(
      const ApiError(status: 429, code: 'code_locked'),
      retryAfterSeconds: 60,
    );
    await tester.enterText(codeField, '482913');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('code-lock-card')),
      findsOneWidget,
    );

    telegram.opens = false;
    await tester.ensureVisible(openTelegram);
    await tester.tap(openTelegram);
    await tester.pumpAndSettle();

    expect(telegram.calls, 1);
    expect(sheet, findsNothing);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets("the sheet's resend is off while locked", (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(resendButton).onPressed, isNotNull);

    repository.verifyFailure = ApiRefusal(
      const ApiError(status: 429, code: 'code_locked'),
      retryAfterSeconds: 60,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(sheet),
    );
    await container.read(codeLoginControllerProvider.notifier).verify('482913');
    await tester.pump();

    expect(container.read(codeLoginControllerProvider).locked, isTrue);
    expect(tester.widget<FilledButton>(resendButton).onPressed, isNull);
    await tester.pump(const Duration(seconds: 60));
  });

  testWidgets('closing the sheet does not announce the old notice again', (
    WidgetTester tester,
  ) async {
    await openCodePage(tester);
    repository.verifyFailure = const NetworkFailure();
    await tester.enterText(codeField, '482913');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);

    await tester.ensureVisible(noCode);
    await tester.tap(noCode);
    await tester.pumpAndSettle();
    expect(notice, findsNothing, reason: 'hidden while the sheet is open');
    tester.takeAnnouncements();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(notice, findsOneWidget);
    expect(
      tester.takeAnnouncements().map((a) => a.message),
      isNot(contains(l10n(tester).authNoInternet)),
    );
  });

  testWidgets('an expired code offers a new one', (WidgetTester tester) async {
    await openCodePage(tester);
    repository.verifyFailure = refusal(422, 'code_expired');
    await tester.enterText(codeField, '482913');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    expect(notice, findsOneWidget);
    repository.verifyFailure = null;
    await tester.ensureVisible(noticeAction);
    await tester.tap(noticeAction);
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((String c) => c.startsWith('request')),
      hasLength(2),
    );
    expect(notice, findsNothing);
  });

  for (final double scale in <double>[1, 2]) {
    testWidgets('the page with the chip and the sheet meet the tap size at '
        '${scale * 100} %', (WidgetTester tester) async {
      await openCodePage(tester, scale: scale);
      expect(chip, findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.ensureVisible(noCode);
      await tester.tap(noCode);
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });
  }
}
