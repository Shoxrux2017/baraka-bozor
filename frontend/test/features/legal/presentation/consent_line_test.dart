import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_legal_repository.dart';

void main() {
  late FakeLegalRepository legal;

  final Finder line = find.byKey(const ValueKey<String>('consent-line'));
  final Finder phoneField = find.byKey(const ValueKey<String>('phone-field'));

  setUp(() {
    legal = FakeLegalRepository();
  });

  Future<void> openPhone(
    WidgetTester tester, {
    Locale device = const Locale('ru'),
  }) async {
    await tester.pumpWidget(appUnderTest(legal: legal, device: device));
    await tester.pumpAndSettle();
  }

  TextSpan spanOf(WidgetTester tester) =>
      tester.widget<Text>(line).textSpan! as TextSpan;

  String plain(WidgetTester tester) => spanOf(tester).toPlainText();

  testWidgets('both published: one line names both documents', (
    WidgetTester tester,
  ) async {
    legal.publishBoth();

    await openPhone(tester);

    expect(
      plain(tester),
      'Продолжая, вы принимаете Условия использования и '
      'Политику конфиденциальности',
    );
  });

  testWidgets('only the terms: no privacy link', (WidgetTester tester) async {
    legal.publishOnly(LegalDocumentKind.terms);

    await openPhone(tester);

    expect(plain(tester), 'Продолжая, вы принимаете Условия использования');
  });

  testWidgets('only the privacy policy: no terms link', (
    WidgetTester tester,
  ) async {
    legal.publishOnly(LegalDocumentKind.privacy);

    await openPhone(tester);

    expect(
      plain(tester),
      'Продолжая, вы принимаете Политику конфиденциальности',
    );
  });

  testWidgets('Uzbek names both documents', (WidgetTester tester) async {
    legal.publishBoth();

    await openPhone(tester, device: const Locale('uz'));

    expect(
      plain(tester),
      'Davom etib, siz Foydalanish shartlari va Maxfiylik siyosatini '
      'qabul qilasiz',
    );
  });

  testWidgets('nothing published: no line', (WidgetTester tester) async {
    await openPhone(tester);

    expect(line, findsNothing);
  });

  testWidgets('a failing index: no line', (WidgetTester tester) async {
    legal.publishBoth();
    legal.indexFailure = const NetworkFailure();

    await openPhone(tester);

    expect(line, findsNothing);
  });

  testWidgets('while the index loads: no line', (WidgetTester tester) async {
    legal.publishBoth();

    await tester.pumpWidget(appUnderTest(legal: legal));
    await tester.pump();

    expect(line, findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a consent link opens the document and back keeps the phone', (
    WidgetTester tester,
  ) async {
    legal.publishBoth();

    await openPhone(tester);
    await tester.enterText(phoneField, '901234567');
    await tester.pump();
    String typed() =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(typed(), '90 123 45 67');

    final TextSpan terms = spanOf(tester).children!
        .whereType<TextSpan>()
        .firstWhere((TextSpan s) => s.recognizer != null);
    expect(terms.text, 'Условия использования');
    (terms.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('legal-screen')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(phoneField, findsOneWidget);
    expect(typed(), '90 123 45 67');
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('the phone screen with the line holds at 320x640 with text x2 '
        '(${device.languageCode})', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      legal.publishBoth();

      await openPhone(tester, device: device);

      expect(line, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
