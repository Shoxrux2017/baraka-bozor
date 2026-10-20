import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/features/legal/domain/legal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_legal_repository.dart';

void main() {
  late FakeLegalRepository legal;

  final Finder screen = find.byKey(const ValueKey<String>('legal-screen'));

  LegalDocument document(
    LegalDocumentKind kind,
    AppLanguage language, {
    List<LegalBlock>? blocks,
  }) => LegalDocument(
    kind: kind,
    language: language,
    updatedAt: DateTime.utc(2026, 10, 18, 20, 30),
    blocks:
        blocks ??
        const <LegalBlock>[
          LegalBlock(type: LegalBlockType.heading, text: 'Общие положения'),
          LegalBlock(type: LegalBlockType.paragraph, text: 'Первый абзац.'),
          LegalBlock(type: LegalBlockType.paragraph, text: 'Второй абзац.'),
          LegalBlock(type: LegalBlockType.item, text: 'Первый пункт'),
          LegalBlock(type: LegalBlockType.item, text: 'Второй пункт'),
        ],
  );

  setUp(() {
    legal = FakeLegalRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    LegalDocumentKind kind = LegalDocumentKind.terms,
    Locale device = const Locale('ru'),
  }) async {
    await tester.pumpWidget(appUnderTest(legal: legal, device: device));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(AppPaths.legal(kind));
    await tester.pumpAndSettle();
  }

  Finder inAppBar(String title) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(title));

  testWidgets('a document shows its edition date and its blocks in order', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );

    await open(tester);

    expect(screen, findsOneWidget);
    expect(inAppBar('Условия использования'), findsOneWidget);
    const List<String> texts = <String>[
      'Редакция от 19.10.2026',
      'Общие положения',
      'Первый абзац.',
      'Второй абзац.',
      'Первый пункт',
      'Второй пункт',
    ];
    double previous = -1;
    for (final String text in texts) {
      expect(find.text(text), findsOneWidget, reason: text);
      final double top = tester.getTopLeft(find.text(text)).dy;
      expect(top, greaterThan(previous), reason: '$text in order');
      previous = top;
    }
    expect(
      find.ancestor(
        of: find.text('Общие положения'),
        matching: find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.header == true,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('•'), findsNWidgets(2));
  });

  testWidgets('the privacy policy has its own title', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.privacy, AppLanguage.ru)] = document(
      LegalDocumentKind.privacy,
      AppLanguage.ru,
    );

    await open(tester, kind: LegalDocumentKind.privacy);

    expect(inAppBar('Политика конфиденциальности'), findsOneWidget);
  });

  testWidgets('a document that is not published says so', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.text('Документ пока не опубликован.'), findsOneWidget);
  });

  testWidgets('a failure offers a retry that loads again', (
    WidgetTester tester,
  ) async {
    legal.documentFailure = const NetworkFailure();

    await open(tester);

    expect(find.byKey(const ValueKey<String>('retry-load')), findsOneWidget);
    expect(legal.documentCalls, hasLength(1));

    legal.documentFailure = null;
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );
    await tester.tap(find.byKey(const ValueKey<String>('retry-load')));
    await tester.pumpAndSettle();

    expect(legal.documentCalls, hasLength(2));
    expect(find.text('Общие положения'), findsOneWidget);
  });

  testWidgets('switching the interface to Uzbek loads the uz document', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );
    legal.documents[(LegalDocumentKind.terms, AppLanguage.uz)] = document(
      LegalDocumentKind.terms,
      AppLanguage.uz,
      blocks: const <LegalBlock>[
        LegalBlock(type: LegalBlockType.heading, text: 'Umumiy qoidalar'),
      ],
    );

    await open(tester);
    expect(find.text('Общие положения'), findsOneWidget);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(screen),
    );
    await container
        .read(languageControllerProvider.notifier)
        .select(AppLanguage.uz);
    await tester.pumpAndSettle();

    expect(legal.documentCalls.last, (LegalDocumentKind.terms, AppLanguage.uz));
    expect(find.text('Umumiy qoidalar'), findsOneWidget);
    expect(find.text('Tahrir: 19.10.2026'), findsOneWidget);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('a long document holds at 320x640 with text x2 '
        '(${device.languageCode})', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final AppLanguage language = AppLanguage.forDevice(device);
      legal.documents[(LegalDocumentKind.terms, language)] = document(
        LegalDocumentKind.terms,
        language,
        blocks: <LegalBlock>[
          for (int i = 0; i < 40; i++)
            LegalBlock(
              type: LegalBlockType.values[i % 3],
              text: 'Блок $i ${'слово ' * 12}',
            ),
        ],
      );

      await open(tester, device: device);

      expect(screen, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
