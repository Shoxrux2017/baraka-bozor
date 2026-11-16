import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/quiet_icon.dart';
import 'package:baraka_bozor/features/legal/domain/legal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_legal_repository.dart';
import '../../../support/nonlinear_text_scaler.dart';

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
    TextScaler? textScaler,
  }) async {
    await tester.pumpWidget(
      appUnderTest(legal: legal, device: device, textScaler: textScaler),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push(AppPaths.legal(kind));
    await tester.pumpAndSettle();
  }

  testWidgets('a document shows its edition date and its blocks in order', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );

    await open(tester);

    expect(screen, findsOneWidget);
    expect(find.text('Условия использования'), findsNWidgets(2));
    const List<String> texts = <String>[
      'Редакция от 19 октября 2026',
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
    expect(find.byKey(const ValueKey<String>('legal-dot')), findsNWidgets(2));
  });

  testWidgets('the privacy policy has its own title', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.privacy, AppLanguage.ru)] = document(
      LegalDocumentKind.privacy,
      AppLanguage.ru,
    );

    await open(tester, kind: LegalDocumentKind.privacy);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey<String>('legal-title')))
          .data,
      'Политика конфиденциальности',
    );
  });

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  double barTitleOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(byKey('kit-bar-title')).opacity;

  List<String> announced(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));

  /// Opens the document without settling, so a skeleton that pulses or a held
  /// answer can be looked at.
  Future<void> openWithoutSettling(
    WidgetTester tester, {
    TextScaler? textScaler,
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        legal: legal,
        device: const Locale('ru'),
        textScaler: textScaler,
      ),
    );
    await tester.pumpAndSettle();
    router(tester).push(AppPaths.legal(LegalDocumentKind.terms));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  double textOpacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(byKey('legal-text-fade')).opacity.value;

  void publish() {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );
  }

  testWidgets(
    'a first open shows the title and a skeleton, then fades the text in',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      publish();
      final Completer<void> hold = Completer<void>();
      legal.documentHold = hold;

      await openWithoutSettling(tester);

      expect(byKey('legal-title'), findsOneWidget);
      expect(byKey('legal-skeleton'), findsOneWidget);
      expect(
        tester.getSemantics(byKey('legal-skeleton')).label,
        'Загружаем документ…',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(announced(tester), contains('Загружаем документ…'));
      expect(barTitleOpacity(tester), 0);
      expect(find.text('Первый абзац.'), findsNothing);

      hold.complete();
      await tester.pump();
      await tester.pump();
      expect(byKey('legal-skeleton'), findsNothing);
      expect(find.text('Первый абзац.'), findsOneWidget);
      expect(textOpacity(tester), lessThan(0.3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(textOpacity(tester), inInclusiveRange(0.3, 0.8));
      await tester.pump(const Duration(milliseconds: 100));
      expect(textOpacity(tester), 1);
      expect(announced(tester), isEmpty);
      handle.dispose();
    },
  );

  testWidgets('with reduced motion the text is there at once', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    publish();
    final Completer<void> hold = Completer<void>();
    legal.documentHold = hold;

    await openWithoutSettling(tester);
    expect(byKey('legal-skeleton'), findsOneWidget);
    hold.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Первый абзац.'), findsOneWidget);
    expect(textOpacity(tester), 1);
  });

  testWidgets('a second open is instant from the copy', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    publish();
    await open(tester);
    router(tester).pop();
    await tester.pumpAndSettle();
    announced(tester);
    final Completer<void> hold = Completer<void>();
    legal.documentHold = hold;

    router(tester).push(AppPaths.legal(LegalDocumentKind.terms));
    await tester.pump();
    await tester.pump();

    expect(find.text('Первый абзац.'), findsOneWidget);
    expect(byKey('legal-skeleton'), findsNothing);
    expect(textOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(announced(tester), isEmpty);
    hold.complete();
    await tester.pumpAndSettle();
    expect(find.text('Первый абзац.'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('offline without a copy shows the centred state', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    legal.documentFailure = const NetworkFailure();

    await open(tester);

    expect(byKey('legal-failed'), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('legal-failed'),
        matching: find.byType(QuietIcon),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('Документ не загрузился'), findsOneWidget);
    const String reason =
        'Нет связи с интернетом. Проверьте подключение и нажмите «Повторить».';
    expect(find.text(reason), findsOneWidget);
    expect(announced(tester), contains('Документ не загрузился. $reason'));
    expect(
      find.text('Условия использования'),
      findsOneWidget,
      reason: 'the bar title is whole when there is no large title',
    );
    expect(byKey('kit-bar-title'), findsNothing);

    final Completer<void> hold = Completer<void>();
    legal.documentHold = hold;
    legal.documentFailure = null;
    publish();
    await tester.tap(byKey('legal-retry'));
    await tester.pump();

    expect(find.text('Повторить'), findsNothing);
    expect(
      find.descendant(
        of: byKey('legal-retry'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('Загружаем…'), findsOneWidget);
    expect(announced(tester), <String>['Загружаем…']);
    await tester.tap(byKey('legal-retry'));
    await tester.pump();
    expect(legal.documentCalls, hasLength(2), reason: 'busy takes no tap');

    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('legal-failed'), findsNothing);
    expect(find.text('Первый абзац.'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a failure that is not the network says so', (
    WidgetTester tester,
  ) async {
    legal.documentFailure = const UnexpectedFailure();

    await open(tester);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsNothing);
    expect(
      find.text('Не удалось загрузить документ. Нажмите «Повторить».'),
      findsOneWidget,
    );
  });

  testWidgets('offline with a copy keeps it under a strip', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    publish();
    await open(tester);
    router(tester).pop();
    await tester.pumpAndSettle();
    announced(tester);
    legal.documentFailure = const NetworkFailure();

    router(tester).push(AppPaths.legal(LegalDocumentKind.terms));
    await tester.pumpAndSettle();

    expect(find.text('Первый абзац.'), findsOneWidget);
    expect(byKey('legal-stale'), findsOneWidget);
    expect(find.text('Нет связи — показана сохранённая копия'), findsOneWidget);
    expect(announced(tester), <String>[
      'Нет связи — показана сохранённая копия',
    ]);
    expect(
      tester.getTopLeft(byKey('legal-stale')).dy,
      greaterThan(tester.getBottomLeft(byKey('legal-title')).dy),
    );
    expect(
      tester.getTopLeft(byKey('legal-date')).dy,
      greaterThan(tester.getBottomLeft(byKey('legal-stale')).dy),
    );
    expect(
      tester.getTopLeft(byKey('legal-date')).dy -
          tester.getBottomLeft(byKey('legal-stale')).dy,
      16,
      reason: 'the strip keeps its 12 below it: 16 to the date',
    );

    final Completer<void> hold = Completer<void>();
    legal.documentHold = hold;
    legal.documentFailure = null;
    await tester.tap(byKey('legal-stale-retry'));
    await tester.pump();
    expect(
      find.descendant(
        of: byKey('legal-stale-retry'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(announced(tester), <String>['Загружаем…']);
    expect(find.text('Первый абзац.'), findsOneWidget);

    hold.complete();
    await tester.pumpAndSettle();
    expect(byKey('legal-stale'), findsNothing);
    expect(find.text('Первый абзац.'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a refresh that fails for another reason says so in the strip', (
    WidgetTester tester,
  ) async {
    publish();
    await open(tester);
    router(tester).pop();
    await tester.pumpAndSettle();
    legal.documentFailure = const UnexpectedFailure();

    router(tester).push(AppPaths.legal(LegalDocumentKind.terms));
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось обновить — показана сохранённая копия'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('an unpublished document says to come back later', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await open(tester);

    expect(byKey('legal-unpublished'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.text('Документ пока не опубликован'), findsOneWidget);
    expect(find.text('Загляните позже.'), findsOneWidget);
    expect(announced(tester), contains('Документ пока не опубликован'));
    final Material back = tester.widget<Material>(
      find
          .descendant(of: byKey('legal-back'), matching: find.byType(Material))
          .first,
    );
    expect(back.color, Colors.white);
    expect(
      (back.shape! as RoundedRectangleBorder).side.color,
      KitColors.outline,
    );

    await tester.tap(byKey('legal-back'));
    await tester.pumpAndSettle();
    expect(screen, findsNothing);
    handle.dispose();
  });

  testWidgets('back with nothing under the page goes to the start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      appUnderTest(legal: legal, device: const Locale('ru')),
    );
    await tester.pumpAndSettle();
    router(tester).go(AppPaths.legal(LegalDocumentKind.terms));
    await tester.pumpAndSettle();
    expect(byKey('legal-back'), findsOneWidget);

    await tester.tap(byKey('legal-back'));
    await tester.pumpAndSettle();

    expect(screen, findsNothing);
  });

  for (final (String, TextScaler) scale in <(String, TextScaler)>[
    ('100%', TextScaler.noScaling),
    ('x2', const NonlinearTextScaler(2)),
  ]) {
    group('every other face keeps its tap targets (${scale.$1})', () {
      void small(WidgetTester tester) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      testWidgets('the skeleton', (WidgetTester tester) async {
        small(tester);
        final SemanticsHandle handle = tester.ensureSemantics();
        legal.documentHold = Completer<void>();
        await openWithoutSettling(tester, textScaler: scale.$2);
        expect(byKey('legal-skeleton'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('failed and busy', (WidgetTester tester) async {
        small(tester);
        final SemanticsHandle handle = tester.ensureSemantics();
        legal.documentFailure = const NetworkFailure();
        await open(tester, textScaler: scale.$2);
        expect(byKey('legal-failed'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        legal.documentHold = Completer<void>();
        await tester.tap(byKey('legal-retry'));
        await tester.pump();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('unpublished', (WidgetTester tester) async {
        small(tester);
        final SemanticsHandle handle = tester.ensureSemantics();
        await open(tester, textScaler: scale.$2);
        expect(byKey('legal-unpublished'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('a copy under the strip', (WidgetTester tester) async {
        small(tester);
        final SemanticsHandle handle = tester.ensureSemantics();
        publish();
        await open(tester, textScaler: scale.$2);
        router(tester).pop();
        await tester.pumpAndSettle();
        legal.documentFailure = const NetworkFailure();
        router(tester).push(AppPaths.legal(LegalDocumentKind.terms));
        await tester.pumpAndSettle();
        expect(byKey('legal-stale'), findsOneWidget);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        legal.documentHold = Completer<void>();
        await tester.tap(byKey('legal-stale-retry'));
        await tester.pump();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    });
  }

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
    expect(find.text('Tahrir: 2026-yil 19-oktabr'), findsOneWidget);
  });

  LegalDocument longDocument({AppLanguage language = AppLanguage.ru}) =>
      document(
        LegalDocumentKind.terms,
        language,
        blocks: <LegalBlock>[
          for (int i = 0; i < 40; i++)
            LegalBlock(
              type: i % 7 == 0
                  ? LegalBlockType.heading
                  : LegalBlockType.paragraph,
              text: 'Блок $i ${'слово ' * 12}',
            ),
        ],
      );

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: byKey('legal-scroll'),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  double barEdgeOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(byKey('kit-bar-edge')).opacity;

  /// The large title's bottom in the scroll content, from the laid-out page.
  double titleBottom(WidgetTester tester) =>
      tester.getBottomLeft(byKey('legal-title')).dy -
      tester.getTopLeft(byKey('legal-column')).dy;

  /// How large the glyphs of [finder]'s text are drawn.
  double drawn(WidgetTester tester, Finder finder) {
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)),
    );
    return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
  }

  final Finder barTitleHidden = find.ancestor(
    of: find.byKey(const ValueKey<String>('kit-bar-title')),
    matching: find.byWidgetPredicate(
      (Widget w) => w is ExcludeSemantics && w.excluding,
    ),
  );

  testWidgets(
    'the large title is the heading and the bar title fades in on scroll',
    (WidgetTester tester) async {
      legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] =
          longDocument();
      final SemanticsHandle handle = tester.ensureSemantics();

      await open(tester);

      expect(barTitleOpacity(tester), 0);
      expect(barTitleHidden, findsOneWidget);
      expect(
        find.ancestor(
          of: byKey('legal-title'),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.header == true,
          ),
        ),
        findsOneWidget,
      );
      expect(barEdgeOpacity(tester), 0);

      final double bottom = titleBottom(tester);
      position(tester).jumpTo(bottom - 15);
      await tester.pump();
      expect(barTitleOpacity(tester), closeTo(0.5, 0.01));
      expect(barTitleHidden, findsOneWidget, reason: 'silent at any opacity');

      position(tester).jumpTo(bottom + 10);
      await tester.pump();
      expect(barTitleOpacity(tester), 1);
      expect(barTitleHidden, findsOneWidget, reason: 'silent at full opacity');
      expect(barEdgeOpacity(tester), 1);

      position(tester).jumpTo(4);
      await tester.pump();
      expect(barEdgeOpacity(tester), closeTo(0.5, 0.001));
      position(tester).jumpTo(8);
      await tester.pump();
      expect(barEdgeOpacity(tester), 1);
      handle.dispose();
    },
  );

  testWidgets('the title grows slower than the body at large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    legal.documents[(LegalDocumentKind.privacy, AppLanguage.ru)] = document(
      LegalDocumentKind.privacy,
      AppLanguage.ru,
    );

    await open(
      tester,
      kind: LegalDocumentKind.privacy,
      textScaler: const TextScaler.linear(2),
    );

    expect(drawn(tester, byKey('legal-title')), 38);
    expect(drawn(tester, find.text('Общие положения')), 36);
    expect(drawn(tester, find.text('Первый абзац.')), 32);
    expect(
      tester.getSize(byKey('legal-title')).height,
      greaterThan(38 * 1.2 * 1.5),
      reason: 'the long name wraps',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the profile name of the document is its large title', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );

    await open(tester);

    expect(
      tester.widget<Text>(byKey('legal-title')).data,
      'Условия использования',
    );
  });

  testWidgets('the date reads in words', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );

    await open(tester);

    expect(find.text('Редакция от 19 октября 2026'), findsOneWidget);
    expect(
      tester.getSemantics(byKey('legal-date')).label,
      'Редакция от 19 октября 2026 года',
    );
    handle.dispose();
  });

  testWidgets('landscape keeps the text clear of the cutout in a 600 column', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(700, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 48);
    tester.view.viewPadding = const FakeViewPadding(left: 48);
    addTearDown(tester.view.reset);
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );

    await open(tester);

    final Rect column = tester.getRect(byKey('legal-column'));
    expect(column.width, lessThanOrEqualTo(600));
    expect(column.center.dx, closeTo(48 + (700 - 48) / 2, 0.5));
    expect(
      tester.getTopLeft(find.text('Первый абзац.')).dx,
      greaterThanOrEqualTo(48 + 20),
    );
  });

  testWidgets('a document in another language says so', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.uz)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );

    await open(tester, device: const Locale('uz'));

    expect(
      tester.widget<Text>(byKey('legal-language-note')).data,
      'Bu hujjat hozircha faqat rus tilida.',
    );
    expect(
      tester.getTopLeft(byKey('legal-language-note')).dy,
      greaterThan(tester.getBottomLeft(byKey('legal-date')).dy),
    );
  });

  testWidgets('a document in the interface language has no note', (
    WidgetTester tester,
  ) async {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );

    await open(tester);

    expect(byKey('legal-language-note'), findsNothing);
  });

  testWidgets('scrolling shows a thin indicator', (WidgetTester tester) async {
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = longDocument();
    await open(tester);
    expect(byKey('scroll-indicator'), findsNothing);

    await tester.drag(byKey('legal-scroll'), const Offset(0, -200));
    await tester.pump();

    expect(byKey('scroll-indicator'), findsOneWidget);
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: byKey('scroll-indicator'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    expect(opacity(), 1);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(opacity(), 0);
  });

  testWidgets('text can be selected and copied', (WidgetTester tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
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
    legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
      LegalDocumentKind.terms,
      AppLanguage.ru,
    );
    await open(tester);

    await tester.longPress(find.text('Первый абзац.'));
    await tester.pumpAndSettle();

    expect(find.text('Копировать'), findsOneWidget);
    expect(find.text('Выделить всё'), findsOneWidget);

    await tester.tap(find.text('Выделить всё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Копировать'));
    await tester.pumpAndSettle();

    expect(copied, contains('Общие положения'));
    expect(copied, contains('Второй пункт'));
  });

  for (final (String, TextScaler) scale in <(String, TextScaler)>[
    ('100%', TextScaler.noScaling),
    ('x2', const NonlinearTextScaler(2)),
  ]) {
    testWidgets('the loaded page keeps every tap target (${scale.$1})', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final SemanticsHandle handle = tester.ensureSemantics();
      legal.documents[(LegalDocumentKind.terms, AppLanguage.ru)] = document(
        LegalDocumentKind.terms,
        AppLanguage.ru,
      );

      await open(tester, textScaler: scale.$2);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  }

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
