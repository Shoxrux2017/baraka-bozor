import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_address_map.dart';
import '../../support/fake_address_search.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/in_memory_stores.dart';
import '../../support/nonlinear_text_scaler.dart';

/// The new-address form's steps over each other: the map shrinking into the
/// preview and growing back, the preview as one button, and leaving without
/// saving (`DL-138`).
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeAddressesRepository addresses;
  late FakeAddressSearch search;

  const PointAddress door = PointAddress(
    line: "Navoiy ko'chasi, 12",
    houseKnown: true,
  );

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    addresses = FakeAddressesRepository();
    search = FakeAddressSearch()..places[fakeDoor] = door;
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  /// The new address's map step, opened from the list.
  Future<void> openNew(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    TextScaler? textScaler,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: const Locale('ru'),
        textScaler: textScaler,
        addresses: addresses,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profile),
          addressSearchRepositoryProvider.overrideWithValue(search),
          addressMapProvider.overrideWithValue(FakeAddressMap()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('profile-addresses'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(byKey('address-new'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('address-new'));
    await tester.pumpAndSettle();
  }

  /// The pin placed and the lookup answered; the map area's height.
  Future<double> placePin(WidgetTester tester) async {
    await tester.tap(byKey('fake-map-move'));
    await tester.pumpAndSettle();
    return tester.getSize(byKey('address-point-map')).height;
  }

  /// Confirms and shows the first frame of the morph.
  Future<void> confirmNow(WidgetTester tester) async {
    await tester.tap(byKey('address-point-confirm'));
    await tester.pump();
  }

  double previewHeight(WidgetTester tester) =>
      tester.getSize(byKey('address-preview')).height;

  double fieldsOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .ancestor(of: byKey('field-street'), matching: find.byType(Opacity))
            .first,
      )
      .opacity;

  Future<void> toDetails(WidgetTester tester) async {
    await placePin(tester);
    await tester.tap(byKey('address-point-confirm'));
    await tester.pumpAndSettle();
  }

  Future<void> sendWords(WidgetTester tester, String words) async {
    await tester.enterText(byKey('address-search-field'), words);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('the morph', () {
    testWidgets('confirming shrinks the map into the preview', (
      WidgetTester tester,
    ) async {
      await openNew(tester);
      final double map = await placePin(tester);

      await confirmNow(tester);
      expect(previewHeight(tester), closeTo(map, 0.5));
      expect(fieldsOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 80));
      expect(fieldsOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 95));
      expect(previewHeight(tester), inExclusiveRange(118, map));
      await tester.pump(const Duration(milliseconds: 175));
      expect(previewHeight(tester), closeTo(118, 0.5));
      await tester.pump(const Duration(milliseconds: 50));
      expect(fieldsOpacity(tester), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('Изменить точку grows the preview back into the map', (
      WidgetTester tester,
    ) async {
      await openNew(tester);
      final double map = await placePin(tester);
      await tester.tap(byKey('address-point-confirm'));
      await tester.pumpAndSettle();

      await tester.tap(byKey('address-preview'));
      await tester.pump();
      expect(previewHeight(tester), closeTo(118, 0.5));
      await tester.pump(const Duration(milliseconds: 160));
      expect(previewHeight(tester), inExclusiveRange(118, map));
      expect(byKey('address-point-confirm'), findsNothing);

      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(milliseconds: 1));
      expect(byKey('address-point-confirm'), findsOneWidget);
      final double first = tester.getTopLeft(byKey('address-point-confirm')).dy;
      await tester.pump(const Duration(milliseconds: 300));
      final double rest = tester.getTopLeft(byKey('address-point-confirm')).dy;
      expect(rest, lessThan(first));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(byKey('address-point-confirm')).dy, rest);
    });

    testWidgets('reduced motion fades between the steps', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openNew(tester);
      await placePin(tester);

      await confirmNow(tester);
      expect(previewHeight(tester), closeTo(118, 0.5), reason: 'no resizing');
      expect(fieldsOpacity(tester), 1);
      final Finder fade = byKey('address-details-fade');
      expect(tester.widget<Opacity>(fade).opacity, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(fade).opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 101));
      expect(tester.widget<Opacity>(fade).opacity, 1);

      await tester.tap(byKey('address-preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<Opacity>(fade).opacity, inExclusiveRange(0, 1));
      expect(previewHeight(tester), closeTo(118, 0.5));
      await tester.pump(const Duration(milliseconds: 81));
      await tester.pump();
      expect(byKey('address-point-confirm'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Opacity>(byKey('address-map-fade')).opacity,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(byKey('address-point-confirm'), findsOneWidget);
    });

    testWidgets('a second confirm during the morph does nothing', (
      WidgetTester tester,
    ) async {
      await openNew(tester);
      await placePin(tester);
      final VoidCallback confirm = tester
          .widget<FilledButton>(byKey('address-point-confirm'))
          .onPressed!;

      confirm();
      confirm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(byKey('address-save'), findsOneWidget, reason: 'back is ignored');
      expect(byKey('address-leave-sheet'), findsNothing);
      await tester.pumpAndSettle();
      expect(byKey('address-save'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('address-form')), findsOne);
      expect(byKey('address-point-confirm'), findsNothing);
    });
  });

  group('the preview', () {
    testWidgets('the whole preview is a button with a 44 pill', (
      WidgetTester tester,
    ) async {
      await openNew(tester);
      await toDetails(tester);

      final Rect preview = tester.getRect(byKey('address-preview'));
      final Rect pill = tester.getRect(byKey('address-change-point'));
      expect(pill.height, greaterThanOrEqualTo(44));
      expect(pill.right, closeTo(preview.right - 10, 0.5));
      expect(pill.bottom, closeTo(preview.bottom - 10, 0.5));
      final Text label = tester.widget<Text>(
        find.descendant(
          of: byKey('address-change-point'),
          matching: find.text(l10n(tester).addressChangePoint),
        ),
      );
      expect(label.style!.fontSize, 14);

      final SemanticsHandle handle = tester.ensureSemantics();
      final SemanticsNode node = tester.getSemantics(byKey('address-preview'));
      expect(node.label, "Изменить точку на карте. Метка: Navoiy ko'chasi, 12");
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();

      await tester.tapAt(
        Offset(preview.left + preview.width * 0.2, preview.center.dy),
      );
      await tester.pumpAndSettle();
      expect(byKey('address-point-confirm'), findsOneWidget);
    });

    testWidgets('the place shows under the preview', (
      WidgetTester tester,
    ) async {
      await openNew(tester);
      await toDetails(tester);
      expect(
        find.descendant(
          of: byKey('address-preview-place'),
          matching: find.text("Метка: Navoiy ko'chasi, 12"),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no place shows when the lookup failed', (
      WidgetTester tester,
    ) async {
      search.places.clear();
      await openNew(tester);
      await toDetails(tester);
      expect(byKey('address-preview-place'), findsNothing);
      expect(find.textContaining('Метка:'), findsNothing);
    });
  });

  group('leaving', () {
    testWidgets('back from a filled map asks before leaving', (
      WidgetTester tester,
    ) async {
      search.answers['Chilonzor 9-kvartal'] = fakeDoor;
      await openNew(tester);
      await sendWords(tester, 'Chilonzor 9-kvartal');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(byKey('address-leave-sheet'), findsOneWidget);
      expect(find.text('Выйти без сохранения?'), findsOneWidget);
      expect(
        find.text(
          'Адрес не сохранится — «Chilonzor 9-kvartal», '
          'и всё, что вы ввели, пропадёт.',
        ),
        findsOneWidget,
      );

      await tester.tap(byKey('address-leave-stay'));
      await tester.pumpAndSettle();
      expect(byKey('address-leave-sheet'), findsNothing);
      expect(
        tester
            .widget<TextField>(byKey('address-search-field'))
            .controller!
            .text,
        'Chilonzor 9-kvartal',
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(byKey('address-leave-go'));
      await tester.pumpAndSettle();
      expect(byKey('address-new'), findsOneWidget, reason: 'the list');
      expect(addresses.saved, isEmpty);
    });

    testWidgets('the sheet names the street once the details are filled', (
      WidgetTester tester,
    ) async {
      await openNew(tester);
      await toDetails(tester);
      await tester.enterText(byKey('field-street'), 'Navoiy');

      await systemBack(tester);
      expect(byKey('address-point-confirm'), findsOneWidget, reason: 'step 1');
      await systemBack(tester);
      expect(
        find.text(
          'Адрес не сохранится — «Navoiy», и всё, что вы ввели, пропадёт.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('system back asks too', (WidgetTester tester) async {
      await openNew(tester);
      await tester.enterText(byKey('address-search-field'), 'Chil');
      await tester.pump();

      await systemBack(tester);
      expect(byKey('address-leave-sheet'), findsOneWidget);
      expect(find.text('Выйти без сохранения?'), findsOneWidget);
      expect(
        find.text(
          'Адрес не сохранится — «Chil», и всё, что вы ввели, пропадёт.',
        ),
        findsOneWidget,
      );
      await systemBack(tester);
      expect(byKey('address-leave-sheet'), findsNothing, reason: 'the sheet');
      expect(byKey('address-point-confirm'), findsOneWidget, reason: 'stays');
    });

    testWidgets('back from an untouched map closes at once', (
      WidgetTester tester,
    ) async {
      await openNew(tester);
      await systemBack(tester);
      expect(byKey('address-leave-sheet'), findsNothing);
      expect(byKey('address-new'), findsOneWidget);
    });

    testWidgets('back while saving does nothing', (WidgetTester tester) async {
      await openNew(tester);
      await toDetails(tester);
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      addresses.hold = Completer<void>();
      await tester.tap(byKey('address-save'));
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(byKey('address-save'), findsOneWidget);
      expect(byKey('address-leave-sheet'), findsNothing);
      expect(byKey('address-point-confirm'), findsNothing);

      addresses.hold!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(addresses.saved, hasLength(1));
      expect(byKey('address-save'), findsNothing, reason: 'the form closed');
    });
  });

  group('large text', () {
    testWidgets('every face fits at large text and meets the tap target '
        'guideline', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openNew(
        tester,
        size: const Size(360, 640),
        textScaler: const NonlinearTextScaler(2),
      );
      await toDetails(tester);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await systemBack(tester);
      await systemBack(tester);
      expect(byKey('address-leave-sheet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });
}
