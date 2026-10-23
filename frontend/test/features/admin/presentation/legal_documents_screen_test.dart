import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_pills.dart';
import 'package:baraka_bozor/features/admin/application/legal_documents_controllers.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_legal_documents_api.dart';
import '../../../support/in_memory_stores.dart';

/// The Admin's documents page through the real router, session and screens,
/// against the documents in memory. The device speaks Russian unless a test
/// says otherwise.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeLegalDocumentsApi api;

  const LegalDocumentKind terms = LegalDocumentKind.terms;
  const LegalDocumentKind privacy = LegalDocumentKind.privacy;
  const AppLanguage ru = AppLanguage.ru;
  const AppLanguage uz = AppLanguage.uz;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));
  Finder field(LegalDocumentKind kind, AppLanguage language) =>
      byKey('legal-${kind.code}-${language.code}');
  // Offstage too: the other language's button is built, not shown.
  Finder save(LegalDocumentKind kind, AppLanguage language) => find.byKey(
    ValueKey<String>('legal-save-${kind.code}-${language.code}'),
    skipOffstage: false,
  );
  Finder tab(LegalDocumentKind kind, AppLanguage language) =>
      byKey('legal-tab-${kind.code}-${language.code}');
  Finder pill(LegalDocumentKind kind) => byKey('legal-doc-${kind.code}');
  Finder preview(LegalDocumentKind kind, AppLanguage language) =>
      byKey('legal-preview-${kind.code}-${language.code}');

  bool enabled(WidgetTester tester, Finder finder) =>
      tester.widget<FilledButton>(finder).onPressed != null;

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    // A field that still has the focus scrolls its window back to its caret,
    // so the button the test scrolls to would slide away again.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Color? dotOf(WidgetTester tester, Finder segment) {
    final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
      find.descendant(of: segment, matching: find.byType(DecoratedBox)),
    );
    for (final DecoratedBox box in boxes) {
      final Decoration decoration = box.decoration;
      if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
        return decoration.color;
      }
    }
    return null;
  }

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    api = FakeLegalDocumentsApi();
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
  });

  Future<void> openDocuments(
    WidgetTester tester, {
    Size size = const Size(1400, 2600),
    Locale device = const Locale('ru'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        device: device,
        overrides: [legalDocumentsApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go(AdminPaths.legalDocuments);
    await tester.pumpAndSettle();
  }

  Future<void> openRussian(WidgetTester tester, LegalDocumentKind kind) async {
    await tester.tap(pill(kind));
    await tester.pumpAndSettle();
    await tester.tap(tab(kind, ru));
    await tester.pumpAndSettle();
  }

  testWidgets('the documents are pills and each has its language switch', (
    WidgetTester tester,
  ) async {
    api.set(terms, ru, '## Условия');

    await openDocuments(tester);

    expect(tester.widget<PanelPill>(pill(terms)).selected, isTrue);
    expect(tester.widget<PanelPill>(pill(privacy)).selected, isFalse);
    expect(
      find.text('Клиенты читают их в приложении и на сайте'),
      findsOneWidget,
    );
    expect(
      byKey('legal-editor-terms-uz'),
      findsOneWidget,
      reason: 'the terms are shown first, in Uzbek',
    );
    expect(byKey('legal-editor-privacy-uz'), findsNothing);
    expect(dotOf(tester, tab(terms, uz)), KitColors.warning);
    expect(dotOf(tester, tab(terms, ru)), KitColors.primary);
    expect(
      find.text('Не опубликовано — в приложении строки нет'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      find.text('## — заголовок, - — пункт списка, каждая строка — абзац'),
      findsOneWidget,
    );

    await openRussian(tester, terms);

    expect(
      find.text('Опубликовано 19.10.2026 15:00, Admin Adminov'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(pill(privacy));
    await tester.pumpAndSettle();

    expect(tester.widget<PanelPill>(pill(privacy)).selected, isTrue);
    expect(byKey('legal-editor-privacy-uz'), findsOneWidget);
    expect(byKey('legal-editor-terms-ru'), findsNothing);
    expect(dotOf(tester, tab(privacy, uz)), KitColors.warning);
    expect(dotOf(tester, tab(privacy, ru)), KitColors.warning);
  });

  testWidgets('typed text survives switching documents and languages', (
    WidgetTester tester,
  ) async {
    await openDocuments(tester);
    await openRussian(tester, terms);
    await tester.enterText(field(terms, ru), 'Набранный текст');
    await tester.pump();

    await tester.tap(pill(privacy));
    await tester.pumpAndSettle();
    await tester.tap(tab(privacy, uz));
    await tester.pumpAndSettle();
    await tester.tap(pill(terms));
    await tester.pumpAndSettle();
    await tester.tap(tab(terms, uz));
    await tester.pumpAndSettle();
    await tester.tap(tab(terms, ru));
    await tester.pumpAndSettle();

    final EditableText editor = tester.widget<EditableText>(
      find.descendant(
        of: field(terms, ru),
        matching: find.byType(EditableText),
      ),
    );
    expect(editor.controller.text, 'Набранный текст');
    expect(
      find.text(
        'Есть неопубликованные изменения — клиенты пока видят прежний текст',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the preview shows the text as the app will', (
    WidgetTester tester,
  ) async {
    await openDocuments(tester);

    expect(
      find.descendant(
        of: preview(terms, uz),
        matching: find.text(
          'Пока пусто. В профиле клиента строки «Условия использования» нет.',
        ),
      ),
      findsOneWidget,
    );

    await tester.enterText(field(terms, uz), '## Цены\n- Один');
    await tester.pump();

    final Finder heading = find.descendant(
      of: preview(terms, uz),
      matching: find.text('Цены'),
    );
    expect(heading, findsOneWidget);
    expect(tester.widget<Text>(heading).style?.fontWeight, FontWeight.w700);
    expect(
      find.descendant(of: preview(terms, uz), matching: find.text('Один')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview(terms, uz), matching: find.text('•')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview(terms, uz),
        matching: find.textContaining('Пока пусто'),
      ),
      findsNothing,
    );
  });

  for (final (int width, bool beside) in <(int, bool)>[
    (900, true),
    (899, false),
  ]) {
    testWidgets('the preview stands ${beside ? 'beside' : 'under'} '
        'a document card of $width', (WidgetTester tester) async {
      // Under 1200 the panel has no side menu and 24 of padding each side.
      await openDocuments(tester, size: Size(width + 48.0, 1000));

      expect(
        tester.getSize(byKey('legal-editor-terms-uz')).width,
        width.toDouble(),
      );
      final Rect editor = tester.getRect(field(terms, uz));
      final Rect shown = tester.getRect(preview(terms, uz));
      if (beside) {
        expect(shown.left, greaterThanOrEqualTo(editor.right));
        expect(shown.width, 380);
      } else {
        expect(shown.top, greaterThanOrEqualTo(editor.bottom));
      }
    });
  }

  testWidgets('the counter counts against 50 000', (WidgetTester tester) async {
    await openDocuments(tester);

    await tester.enterText(field(terms, uz), '123456789012');
    await tester.pump();

    expect(find.text('12 / 50 000'), findsOneWidget);
  });

  testWidgets('editing one text enables only its own publish button', (
    WidgetTester tester,
  ) async {
    await openDocuments(tester);
    await openRussian(tester, terms);

    expect(enabled(tester, save(terms, ru)), isFalse);
    expect(enabled(tester, save(privacy, uz)), isFalse);

    await tester.enterText(field(terms, ru), 'Новый текст');
    await tester.pump();

    expect(enabled(tester, save(terms, ru)), isTrue);
    expect(enabled(tester, save(privacy, uz)), isFalse);
    expect(enabled(tester, save(privacy, ru)), isFalse);
  });

  testWidgets('publishing sends once and confirms', (
    WidgetTester tester,
  ) async {
    await openDocuments(tester);
    await openRussian(tester, terms);

    await tester.enterText(field(terms, ru), 'Новый текст');
    await tester.pump();
    await tapAndSettle(tester, save(terms, ru));

    expect(api.published, <(LegalDocumentKind, AppLanguage, String?)>[
      (terms, ru, 'Новый текст'),
    ]);
    expect(find.text('Документ опубликован'), findsOneWidget);
    expect(
      find.text('Опубликовано 19.10.2026 17:00, Admin Adminov'),
      findsOneWidget,
    );
    expect(enabled(tester, save(terms, ru)), isFalse);
  });

  testWidgets(
    'clearing a published text asks first; cancelling sends nothing',
    (WidgetTester tester) async {
      api.set(privacy, ru, 'Текст');
      await openDocuments(tester);
      await openRussian(tester, privacy);

      await tester.enterText(field(privacy, ru), '');
      await tester.pump();
      await tapAndSettle(tester, save(privacy, ru));

      expect(byKey('legal-unpublish-dialog'), findsOneWidget);
      expect(find.text('Снять документ с публикации?'), findsOneWidget);

      await tapAndSettle(tester, byKey('action-cancel'));

      expect(api.published, isEmpty);
      expect(byKey('legal-unpublish-dialog'), findsNothing);
      expect(enabled(tester, save(privacy, ru)), isTrue);
    },
  );

  testWidgets('confirming the question takes the document down', (
    WidgetTester tester,
  ) async {
    api.set(privacy, ru, 'Текст');
    await openDocuments(tester);
    await openRussian(tester, privacy);

    await tester.enterText(field(privacy, ru), '');
    await tester.pump();
    await tapAndSettle(tester, save(privacy, ru));

    expect(
      find.text(
        'Текст пустой. Строка «Политика конфиденциальности» на этом языке '
        'исчезнет из приложения.',
      ),
      findsOneWidget,
    );
    final FilledButton confirm = tester.widget<FilledButton>(
      byKey('legal-unpublish-confirm'),
    );
    expect(
      confirm.style?.backgroundColor?.resolve(<WidgetState>{}),
      KitColors.danger,
    );
    expect(
      find.descendant(
        of: byKey('legal-unpublish-confirm'),
        matching: find.text('Снять с публикации'),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('legal-unpublish-confirm'));

    expect(api.published, <(LegalDocumentKind, AppLanguage, String?)>[
      (privacy, ru, null),
    ]);
  });

  testWidgets('markup typed into a document is shown as it is', (
    WidgetTester tester,
  ) async {
    api.set(terms, ru, '<script>alert(1)</script>');
    await openDocuments(tester);
    await openRussian(tester, terms);

    final EditableText editor = tester.widget<EditableText>(
      find.descendant(
        of: field(terms, ru),
        matching: find.byType(EditableText),
      ),
    );
    expect(editor.controller.text, '<script>alert(1)</script>');
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
      testWidgets('the documents page holds at the extremes '
          '(${device.languageCode} ${size.width.toInt()})', (
        WidgetTester tester,
      ) async {
        final String long = List<String>.generate(
          2000,
          (int i) =>
              i % 7 == 0 ? '## Sarlavha ${'uzun ' * 20}$i' : '- Qator $i',
        ).join('\n');
        api.set(terms, uz, long);
        api.set(terms, ru, long);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await openDocuments(tester, size: size, device: device);
        expect(tester.takeException(), isNull);

        await tester.tap(tab(terms, ru));
        await tester.pumpAndSettle();
        await tester.enterText(field(terms, ru), 'x' * 60000);
        await tester.pump();
        await tester.ensureVisible(save(terms, ru));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tapAndSettle(tester, pill(privacy));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
