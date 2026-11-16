import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/brand_wordmark.dart';
import 'package:baraka_bozor/core/widgets/wordmark_landing.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/catalog/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_auth_repository.dart';
import '../support/fake_catalog_repository.dart';
import '../support/in_memory_stores.dart';
import '../support/nonlinear_text_scaler.dart';

/// The launch curtain and the handoff to the first page (`DL-136` (11), (12),
/// (17)).
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;

  final Finder curtain = find.byKey(const ValueKey<String>('launch-curtain'));
  final Finder launchWordmark = find.byKey(
    const ValueKey<String>('launch-wordmark'),
  );
  final Finder hint = find.byKey(const ValueKey<String>('launch-hint'));
  final Finder ghost = find.byKey(const ValueKey<String>('handoff-ghost'));
  final Finder landingWordmark = find.descendant(
    of: find.byType(WordmarkLanding),
    matching: find.byType(BrandWordmark),
  );

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
  });

  double fade(WidgetTester tester, Finder finder) =>
      tester.widget<FadeTransition>(finder).opacity.value;

  double landingOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .descendant(
              of: find.byType(WordmarkLanding),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  /// Takes the app down, so no timer of the session is left pending.
  Future<void> leave(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  /// Pumps until the curtain has begun to leave, and one frame more so the
  /// leave's clock has started: the next pump counts from its first moment.
  Future<void> untilLeaving(WidgetTester tester) async {
    for (int i = 0; i < 30; i++) {
      await tester.pump();
      if (curtain.evaluate().isNotEmpty) {
        final Iterable<IgnorePointer> blockers = tester
            .widgetList<IgnorePointer>(
              find.ancestor(of: curtain, matching: find.byType(IgnorePointer)),
            );
        if (blockers.any((IgnorePointer b) => b.ignoring)) {
          await tester.pump();
          return;
        }
      }
    }
    fail('the curtain never began to leave');
  }

  Future<void> open(
    WidgetTester tester, {
    Surface surface = Surface.mobile,
    TextScaler? textScaler,
    FakeCatalogRepository? catalog,
  }) async {
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: surface,
        device: const Locale('ru'),
        textScaler: textScaler,
        catalog: catalog,
      ),
    );
  }

  testWidgets('the start says Подключаемся… after 1.5 s', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth
      ..identities[SessionSlot.customer] = user()
      ..holdAnswers = Completer<void>();
    await open(tester);
    await tester.pump();
    tester.takeAnnouncements();

    expect(curtain, findsOneWidget);
    expect(fade(tester, launchWordmark), lessThan(1));
    await tester.pump(const Duration(milliseconds: 150));
    expect(fade(tester, launchWordmark), 1);

    await tester.pump(const Duration(milliseconds: 1250));
    expect(hint, findsNothing);
    expect(tester.takeAnnouncements(), isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    expect(hint, findsOneWidget);
    final CircularProgressIndicator spinner = tester
        .widget<CircularProgressIndicator>(
          find.descendant(
            of: hint,
            matching: find.byType(CircularProgressIndicator),
          ),
        );
    expect(spinner.color, KitColors.muted);
    expect(
      find.descendant(of: hint, matching: find.text('Подключаемся…')),
      findsOneWidget,
    );
    expect(
      tester
          .takeAnnouncements()
          .map((CapturedAccessibilityAnnouncement a) => a.message)
          .toList(),
      <String>['Подключаемся…'],
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeAnnouncements(), isEmpty);
    await leave(tester);
  });

  testWidgets('the wordmark glides to the sign-in', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await untilLeaving(tester);

    final Offset screen = tester.getCenter(find.byType(MaterialApp));
    final Offset landing = tester.getCenter(landingWordmark.first);
    expect(landing.dy, lessThan(screen.dy));

    await tester.pump(const Duration(milliseconds: 225));
    expect(ghost, findsOneWidget);
    final double y = tester.getCenter(ghost).dy;
    expect(y, greaterThan(landing.dy));
    expect(y, lessThan(screen.dy));
    expect(landingOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(curtain, findsNothing);
    expect(ghost, findsNothing);
    expect(landingOpacity(tester), 1);
  });

  testWidgets('other first pages cross-fade', (WidgetTester tester) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user();
    await open(tester);
    await untilLeaving(tester);

    expect(ghost, findsNothing);
    await tester.pump(const Duration(milliseconds: 125));
    final double middle = fade(tester, curtain);
    expect(middle, greaterThan(0.3));
    expect(middle, lessThan(0.7));
    expect(ghost, findsNothing);
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(curtain, findsNothing);
  });

  testWidgets('taps reach the page while the curtain leaves', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user();
    await open(tester);
    await untilLeaving(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(curtain, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('catalog-search')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('reduced motion fades instead of gliding', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester);
    await untilLeaving(tester);

    expect(ghost, findsNothing);
    await tester.pump(const Duration(milliseconds: 125));
    final double middle = fade(tester, curtain);
    expect(middle, greaterThan(0));
    expect(middle, lessThan(1));
    expect(ghost, findsNothing);
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(curtain, findsNothing);
    expect(landingOpacity(tester), 1);
  });

  testWidgets('the wordmark keeps its size at large text', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tokens.tokens[SessionSlot.customer] = 'c';
    auth
      ..identities[SessionSlot.customer] = user()
      ..holdAnswers = Completer<void>();
    await open(tester);
    await tester.pump();

    final Finder text = find.descendant(
      of: launchWordmark,
      matching: find.text('BarakaBozor'),
    );
    expect(tester.getSize(text).height, lessThan(50));
    expect(find.bySemanticsLabel('BarakaBozor'), findsOneWidget);
    await leave(tester);

    tokens.tokens.clear();
    auth.holdAnswers = null;
    await open(tester);
    await tester.pumpAndSettle();
    expect(curtain, findsNothing);
    final Finder word = find.text('BarakaBozor');
    expect(word, findsOneWidget);
    expect(tester.getSize(word).height, lessThan(40));
    expect(find.bySemanticsLabel('BarakaBozor'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('leaving Нет связи fades its last picture over the app', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = const NetworkFailure();
    await open(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(curtain, findsNothing);
    expect(find.text('Нет связи'), findsOneWidget);

    auth.identities[SessionSlot.customer] = user();
    await tester.tap(find.byKey(const ValueKey<String>('retry-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await untilLeaving(tester);

    expect(curtain, findsOneWidget);
    expect(find.text('Нет связи'), findsOneWidget);
    expect(find.text('Проверяем…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('catalog-search')),
      findsOneWidget,
    );
    expect(ghost, findsNothing);
    await tester.pump(const Duration(milliseconds: 125));
    expect(fade(tester, curtain), lessThan(1));
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(curtain, findsNothing);
    expect(find.text('Нет связи'), findsNothing);
    await leave(tester);
  });

  testWidgets('a first answer of Нет связи fades to the retry screen', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = const NetworkFailure();
    await open(tester);
    await untilLeaving(tester);

    expect(ghost, findsNothing);
    expect(find.text('Нет связи'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    expect(curtain, findsNothing);
    expect(find.text('Нет связи'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a reload into a panel page fades the curtain', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        AppPaths.operations;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(role: UserRole.operator);
    await open(tester, surface: Surface.web);
    await untilLeaving(tester);

    expect(ghost, findsNothing);
    await tester.pump(const Duration(milliseconds: 125));
    expect(ghost, findsNothing);
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(curtain, findsNothing);
    expect(
      find.byKey(const ValueKey<String>('operations-board')),
      findsOneWidget,
    );
    await leave(tester);
  });

  for (final (String name, TextScaler? scaler) in <(String, TextScaler?)>[
    ('at 100 %', null),
    ('at NonlinearTextScaler(2)', const NonlinearTextScaler(2)),
  ]) {
    testWidgets('the curtain with the hint meets the tap guideline $name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tokens.tokens[SessionSlot.customer] = 'c';
      auth
        ..identities[SessionSlot.customer] = user()
        ..holdAnswers = Completer<void>();
      await open(tester, textScaler: scaler);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(hint, findsOneWidget);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await leave(tester);
      semantics.dispose();
    });
  }
}
