import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/admin/application/legal_documents_controllers.dart';
import 'package:baraka_bozor/features/admin/presentation/admin_paths.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_legal_documents_api.dart';
import '../../../support/in_memory_stores.dart';

/// The Admin's documents page through the real router, session and screens,
/// against the documents in memory. The device speaks Russian.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeLegalDocumentsApi api;

  const LegalDocumentKind terms = LegalDocumentKind.terms;
  const LegalDocumentKind privacy = LegalDocumentKind.privacy;
  const AppLanguage ru = AppLanguage.ru;
  const AppLanguage uz = AppLanguage.uz;

  Finder field(LegalDocumentKind kind, AppLanguage language) =>
      find.byKey(ValueKey<String>('legal-${kind.code}-${language.code}'));
  // Offstage too: the other language's button is built, not shown.
  Finder save(LegalDocumentKind kind, AppLanguage language) => find.byKey(
    ValueKey<String>('legal-save-${kind.code}-${language.code}'),
    skipOffstage: false,
  );
  Finder tab(LegalDocumentKind kind, AppLanguage language) =>
      find.byKey(ValueKey<String>('legal-tab-${kind.code}-${language.code}'));

  bool enabled(WidgetTester tester, Finder finder) =>
      tester.widget<FilledButton>(finder).onPressed != null;

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    api = FakeLegalDocumentsApi();
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.admin);
  });

  Future<void> openDocuments(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        device: const Locale('ru'),
        overrides: [legalDocumentsApiProvider.overrideWithValue(api)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('panel-section-${AdminPaths.legalDocuments}'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRussian(WidgetTester tester, LegalDocumentKind kind) async {
    await tester.tap(tab(kind, ru));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'an unpublished document says so, a published one shows its author and date',
    (WidgetTester tester) async {
      api.set(terms, ru, '## Условия');

      await openDocuments(tester);

      expect(find.text('Условия использования'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(
        find.text('Не опубликовано — в приложении строки нет'),
        findsNWidgets(2),
        reason: 'the Uzbek terms and the Uzbek privacy policy',
      );
      expect(
        find.text('## — заголовок, - — пункт списка, каждая строка — абзац'),
        findsNWidgets(2),
      );

      await openRussian(tester, terms);

      expect(
        find.text('Опубликовано 19.10.2026 15:00, Admin Adminov'),
        findsOneWidget,
      );
    },
  );

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
    await tester.tap(save(terms, ru));
    await tester.pumpAndSettle();

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
      await tester.tap(save(privacy, ru));
      await tester.pumpAndSettle();

      expect(find.text('Снять документ с публикации?'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(api.published, isEmpty);
      expect(find.text('Снять документ с публикации?'), findsNothing);
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
    await tester.tap(save(privacy, ru));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Опубликовать'),
      ),
    );
    await tester.pumpAndSettle();

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
}
