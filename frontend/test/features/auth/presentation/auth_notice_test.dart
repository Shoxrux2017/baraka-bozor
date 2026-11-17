import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/auth/presentation/auth_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/nonlinear_text_scaler.dart';

void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  const String phone = '+998901234567';

  ApiRefusal refusal(
    int status,
    String code, {
    Map<String, Object?> details = const <String, Object?>{},
    int? retryAfter,
  }) => ApiRefusal(
    ApiError(status: status, code: code, details: details),
    retryAfterSeconds: retryAfter,
  );

  AuthNoticeView of(ApiFailure f, AuthNoticePlace place) =>
      authNoticeOf(ru, f, phone: phone, place: place);

  ApiRefusal hourLimit() => refusal(
    429,
    'rate_limited',
    details: <String, Object?>{'limit': 'phone_hourly', 'max_sends': 5},
    retryAfter: 2520,
  );

  test('a lost connection asks to retry everywhere', () {
    for (final AuthNoticePlace place in AuthNoticePlace.values) {
      final AuthNoticeView v = of(const NetworkFailure(), place);
      expect(v.tone, AuthNoticeTone.danger);
      expect(v.icon, Icons.wifi_off);
      expect(v.text, ru.authNoInternet);
      expect(v.action, AuthNoticeAction.retry);
    }
  });

  test('a number not in Telegram offers another number', () {
    final ApiRefusal f = refusal(422, 'code_delivery_unavailable');
    final AuthNoticeView p = of(f, AuthNoticePlace.phone);
    expect(p.tone, AuthNoticeTone.warning);
    expect(p.icon, Icons.person_search);
    expect(p.text, ru.authNotInTelegram('+998 90 123 45 67'));
    expect(p.action, AuthNoticeAction.otherNumber);
    expect(of(f, AuthNoticePlace.code).action, AuthNoticeAction.changeNumber);
    expect(of(f, AuthNoticePlace.name).action, isNull);
  });

  test('the hour limit says how long', () {
    final AuthNoticeView v = of(hourLimit(), AuthNoticePlace.phone);
    expect(v.tone, AuthNoticeTone.warning);
    expect(v.icon, Icons.schedule);
    expect(v.text, ru.authHourLimit(5, '42 мин'));
    expect(v.text, contains('через 42 мин.'));
    expect(v.action, AuthNoticeAction.otherNumber);
    expect(
      of(hourLimit(), AuthNoticePlace.code).action,
      AuthNoticeAction.changeNumber,
    );
  });

  test('the address limit has no action', () {
    final AuthNoticeView v = of(
      refusal(
        429,
        'rate_limited',
        details: <String, Object?>{'limit': 'address'},
        retryAfter: 90,
      ),
      AuthNoticePlace.phone,
    );
    expect(v.text, ru.authAddressLimit('2 мин'));
    expect(v.action, isNull);
  });

  test(
    'another rate limit says too many, or the server text without a wait',
    () {
      final AuthNoticeView withWait = of(
        refusal(429, 'rate_limited', retryAfter: 30),
        AuthNoticePlace.phone,
      );
      expect(withWait.text, ru.authTooMany('30 с'));
      expect(withWait.action, isNull);
      final AuthNoticeView without = of(
        refusal(429, 'rate_limited'),
        AuthNoticePlace.phone,
      );
      expect(without.text, ru.errorRateLimited);
    },
  );

  test('an expired code offers a new one on the code page', () {
    for (final String code in <String>[
      'code_expired',
      'code_attempts_exhausted',
    ]) {
      final ApiRefusal f = refusal(401, code);
      final AuthNoticeView v = of(f, AuthNoticePlace.code);
      expect(v.tone, AuthNoticeTone.warning);
      expect(v.icon, Icons.timer_off);
      expect(v.action, AuthNoticeAction.newCode);
      expect(of(f, AuthNoticePlace.phone).action, isNull);
      expect(of(f, AuthNoticePlace.name).action, isNull);
    }
  });

  test('an unavailable provider or a 5xx offers a retry', () {
    for (final ApiRefusal f in <ApiRefusal>[
      refusal(503, 'provider_unavailable'),
      refusal(503, 'service_unavailable'),
      refusal(500, 'whatever'),
    ]) {
      final AuthNoticeView v = of(f, AuthNoticePlace.phone);
      expect(v.tone, AuthNoticeTone.danger);
      expect(v.icon, Icons.cloud_off);
      expect(v.action, AuthNoticeAction.retry);
    }
  });

  test('an unknown refusal says the server text and offers nothing', () {
    final AuthNoticeView v = of(
      refusal(403, 'account_blocked'),
      AuthNoticePlace.phone,
    );
    expect(v.tone, AuthNoticeTone.danger);
    expect(v.icon, Icons.error_outline);
    expect(v.text, ru.errorAccountBlocked);
    expect(v.action, isNull);
  });

  test('waitWords counts minutes upward and seconds below a minute', () {
    expect(waitWords(ru, 2520), '42 мин');
    expect(waitWords(ru, 60), '1 мин');
    expect(waitWords(ru, 61), '2 мин');
    expect(waitWords(ru, 59), '59 с');
    expect(waitWords(ru, 1), '1 с');
  });

  Widget host(
    AuthNoticeView view,
    ValueChanged<AuthNoticeAction> onAction, {
    TextScaler scaler = TextScaler.noScaling,
  }) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: const Size(360, 640), textScaler: scaler),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AuthNotice(view: view, onAction: onAction),
        ),
      ),
    ),
  );

  const AuthNoticeView offline = AuthNoticeView(
    tone: AuthNoticeTone.danger,
    icon: Icons.wifi_off,
    text: 'Нет интернета. Проверьте связь и повторите.',
    action: AuthNoticeAction.retry,
  );

  testWidgets('the notice reads as one stop and announces itself', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(host(offline, (_) {}));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .toList(),
      <String>[offline.text],
    );
    expect(tester.getSemantics(find.text(offline.text)).label, offline.text);
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const Key('auth-notice')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, KitColors.dangerWash);

    const AuthNoticeView changed = AuthNoticeView(
      tone: AuthNoticeTone.warning,
      icon: Icons.schedule,
      text: 'Другой текст',
    );
    await tester.pumpWidget(host(changed, (_) {}));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .toList(),
      <String>['Другой текст'],
    );
    expect(find.byKey(const Key('auth-notice-action')), findsNothing);
    handle.dispose();
  });

  testWidgets('the action is a 44 tall button that reports its action', (
    WidgetTester tester,
  ) async {
    final List<AuthNoticeAction> taps = <AuthNoticeAction>[];
    await tester.pumpWidget(host(offline, taps.add));
    await tester.pump(const Duration(milliseconds: 300));
    final Finder button = find.byKey(const Key('auth-notice-action'));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    expect(
      find.descendant(of: button, matching: find.text('Повторить')),
      findsOneWidget,
    );
    await tester.tap(button);
    expect(taps, <AuthNoticeAction>[AuthNoticeAction.retry]);
  });

  for (final (String, TextScaler) scale in <(String, TextScaler)>[
    ('100 %', TextScaler.noScaling),
    ('NonlinearTextScaler(2)', const NonlinearTextScaler(2)),
  ]) {
    testWidgets('the notice meets the tap guideline at ${scale.$1}', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(host(offline, (_) {}, scaler: scale.$2));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  }
}
