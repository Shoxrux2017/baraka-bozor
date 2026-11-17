import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/legal/application/legal_providers.dart';
import 'package:baraka_bozor/features/legal/presentation/consent_line.dart';
import 'package:baraka_bozor/main.dart' show noAutomaticRetry;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_legal_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  late SemanticsHandle semantics;

  setUp(() {
    semantics = TestWidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  });

  tearDown(() => semantics.dispose());

  Finder sentence() => find.bySemanticsLabel(RegExp(r'^(Продолжая|Davom)'));

  /// The sentence the screen reader reads: the one stop that is no link.
  String plain(WidgetTester tester) => tester.getSemantics(sentence()).label;

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

  testWidgets('"Получить код" reads a failed index again', (
    WidgetTester tester,
  ) async {
    legal.publishBoth();
    legal.indexFailure = const NetworkFailure();
    await openPhone(tester);
    expect(line, findsNothing);
    final int calls = legal.indexCalls;

    legal.indexFailure = null;
    await tester.tap(find.byKey(const ValueKey<String>('continue-button')));
    await tester.pumpAndSettle();

    expect(legal.indexCalls, calls + 1);
    expect(line, findsOneWidget);
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

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey<String>('consent-terms'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('legal-screen')), findsOneWidget);
    expect(legal.documentCalls.last.$1, LegalDocumentKind.terms);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(phoneField, findsOneWidget);
    expect(typed(), '90 123 45 67');
  });

  /// The line alone on a page, at the given text size.
  Future<void> openAlone(WidgetTester tester, {TextScaler? scaler}) async {
    legal.publishBoth();
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
          deviceLocaleProvider.overrideWithValue(const Locale('ru')),
          legalRepositoryProvider.overrideWithValue(legal),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: scaler ?? TextScaler.noScaling),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConsentLine(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a tap 12 px above the words of a link opens it', (
    WidgetTester tester,
  ) async {
    legal.publishBoth();
    await openPhone(tester);
    final Rect target = tester.getRect(
      find.byKey(const ValueKey<String>('consent-terms')),
    );

    // The words are one line (18.6 px) centred in the 44 px target.
    await tester.tapAt(Offset(target.center.dx, target.center.dy - 9.3 - 12));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('legal-screen')), findsOneWidget);
  });

  testWidgets('each link is a 44 tall reader stop', (
    WidgetTester tester,
  ) async {
    await openAlone(tester);

    for (final (String key, String words) in const <(String, String)>[
      ('consent-terms', 'Условия использования'),
      ('consent-privacy', 'Политику конфиденциальности'),
    ]) {
      final Finder target = find.byKey(ValueKey<String>(key));
      final SemanticsNode node = tester.getSemantics(target);
      expect(node.label, words);
      expect(node.flagsCollection.isLink, isTrue);
      expect(tester.getRect(target).height, 44);
      expect(node.rect.height, 44);
    }
  });

  testWidgets('the sentence is one stop', (WidgetTester tester) async {
    await openAlone(tester);

    expect(sentence(), findsOneWidget);
    expect(
      plain(tester),
      'Продолжая, вы принимаете Условия использования и '
      'Политику конфиденциальности',
    );
  });

  testWidgets('nothing published draws nothing', (WidgetTester tester) async {
    await openPhone(tester);

    expect(line, findsNothing);
    expect(sentence(), findsNothing);
    expect(find.byKey(const ValueKey<String>('consent-terms')), findsNothing);
  });

  for (final (String name, TextScaler scaler) in <(String, TextScaler)>[
    ('100 %', TextScaler.noScaling),
    ('200 %', const NonlinearTextScaler(2)),
  ]) {
    testWidgets('the line meets the tap target guideline at $name', (
      WidgetTester tester,
    ) async {
      await openAlone(tester, scaler: scaler);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });
  }

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
