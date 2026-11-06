import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/submit_button.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:baraka_bozor/features/profile/presentation/initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  /// What the editor handed back to whoever opened it.
  late Future<bool?> pushed;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  CustomerProfile named(String name) => CustomerProfile(
    id: 'c',
    phone: '+998901234567',
    fullName: name,
    supportPhone: null,
  );

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> openEditor(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    Locale device = const Locale('uz'),
    TextScaler? textScaler,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        textScaler: textScaler,
        overrides: [profileRepositoryProvider.overrideWithValue(profile)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
    pushed = GoRouter.of(tester.element(find.byType(Scaffold).first))
        .push<bool>(AppPaths.customerEditProfile);
    await tester.pumpAndSettle();
  }

  String nameText(WidgetTester tester) =>
      tester.widget<TextField>(byKey('profile-name-field')).controller!.text;

  EditableText nameEditable(WidgetTester tester) => tester.widget<EditableText>(
    find.descendant(
      of: byKey('profile-name-field'),
      matching: find.byType(EditableText),
    ),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(byKey('profile-save'));
    await tester.pumpAndSettle();
  }

  group('the name editor', () {
    testWidgets('the field is ready on open', (tester) async {
      profile.current = named('Aziza');
      await openEditor(tester);

      expect(nameEditable(tester).focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        nameEditable(tester).controller.selection,
        const TextSelection.collapsed(offset: 5),
      );
      expect(byKey('profile-name-clear'), findsOneWidget);

      tester.takeAnnouncements();
      await tester.tap(byKey('profile-name-clear'));
      await tester.pumpAndSettle();

      expect(nameText(tester), isEmpty);
      expect(nameEditable(tester).focusNode.hasFocus, isTrue);
      expect(byKey('profile-name-clear'), findsNothing);
      expect(
        tester.takeAnnouncements().map(
          (CapturedAccessibilityAnnouncement a) => a.message,
        ),
        <String>[l10n(tester).profileNameCleared],
      );
    });

    testWidgets('the frame is grey and green only while focused, never red', (
      tester,
    ) async {
      profile.current = named('Aziza');
      await openEditor(tester, device: const Locale('ru'));

      InputDecoration decoration() =>
          tester.widget<TextField>(byKey('profile-name-field')).decoration!;

      expect(decoration().focusedBorder!.borderSide.color, KitColors.primary);
      expect(decoration().focusedBorder!.borderSide.width, 2);

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      expect(nameEditable(tester).focusNode.hasFocus, isFalse);
      expect(decoration().enabledBorder!.borderSide.color, KitColors.fieldEdge);
      expect(decoration().enabledBorder!.borderSide.width, 1);

      await tester.enterText(byKey('profile-name-field'), '');
      await tester.pumpAndSettle();
      expect(
        find.text('Введите имя — без него заказ не оформить.'),
        findsNothing,
      );
      final InputDecoration d = decoration();
      expect(d.errorText, isNull);
      for (final InputBorder? b in <InputBorder?>[
        d.border,
        d.enabledBorder,
        d.focusedBorder,
        d.errorBorder,
        d.focusedErrorBorder,
        d.disabledBorder,
      ]) {
        expect(b?.borderSide.color, isNot(KitColors.danger));
      }
      expect(find.text('Так вас назовут сборщик и курьер'), findsOneWidget);
    });

    testWidgets('save is grey until the name differs', (tester) async {
      profile.current = named('Aziza');
      await openEditor(tester, device: const Locale('ru'));

      SubmitFace face() =>
          tester.widget<SubmitButton>(find.byType(SubmitButton)).face;
      VoidCallback? pressed() =>
          tester.widget<FilledButton>(byKey('profile-save')).onPressed;

      expect(face(), SubmitFace.off);
      expect(find.text('Сохранить'), findsOneWidget);
      await tester.tap(byKey('profile-save'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(profile.renames, isEmpty);
      expect(byKey('edit-profile'), findsOneWidget);

      await tester.enterText(byKey('profile-name-field'), 'Aziza K');
      await tester.pumpAndSettle();
      expect(face(), SubmitFace.ready);
      expect(pressed(), isNotNull);

      await tester.enterText(byKey('profile-name-field'), '  Aziza  ');
      await tester.pumpAndSettle();
      expect(face(), SubmitFace.off);
      expect(pressed(), isNull);
      expect(find.text('Сохранить'), findsOneWidget);
      expect(profile.renames, isEmpty);

      await tester.enterText(byKey('profile-name-field'), '   ');
      await tester.pumpAndSettle();
      expect(face(), SubmitFace.off);
      expect(find.text('Введите имя'), findsOneWidget);
    });

    testWidgets('the title follows the saved name', (tester) async {
      profile.current = named('Aziza');
      await openEditor(tester, device: const Locale('ru'));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Изменить имя'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the title without a saved name asks to set one', (
      tester,
    ) async {
      await openEditor(tester, device: const Locale('ru'));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Указать имя'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the phone is a text block that takes no focus', (
      tester,
    ) async {
      profile.current = named('Aziza');
      await openEditor(tester, device: const Locale('ru'));

      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(byKey('profile-phone-block'));
      await tester.pumpAndSettle();
      expect(nameEditable(tester).focusNode.hasFocus, isTrue);

      for (final String text in <String>[
        'Номер телефона',
        '+998 90 123 45 67',
        'По этому номеру вы входите — изменить его нельзя.',
      ]) {
        expect(
          find.descendant(
            of: byKey('profile-phone-block'),
            matching: find.text(text),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: byKey('profile-phone-block'),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a reader meets the field and its helper as one stop', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      profile.current = named('Дилноза Каримова');
      await openEditor(tester, device: const Locale('ru'));

      const String helper = 'Так вас назовут сборщик и курьер';
      final List<SemanticsNode> nodes = <SemanticsNode>[];
      void walk(SemanticsNode n) {
        nodes.add(n);
        n.visitChildren((SemanticsNode c) {
          walk(c);
          return true;
        });
      }

      walk(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      String words(SemanticsNode n) {
        final SemanticsData d = n.getSemanticsData();
        return '${d.label}|${d.hint}|${d.value}';
      }

      final SemanticsNode field = tester.getSemantics(
        byKey('profile-name-field'),
      );
      expect(words(field), contains('Имя'));
      expect(words(field), contains(helper));
      expect(
        nodes.where((SemanticsNode n) => words(n).contains(helper)),
        <SemanticsNode>[field],
      );
      expect(
        nodes.where((SemanticsNode n) => words(n).contains('ДК')),
        isEmpty,
      );

      final List<SemanticsNode> phone = nodes
          .where((SemanticsNode n) => words(n).contains('+998 90 123 45 67'))
          .toList();
      expect(phone, hasLength(1));
      expect(
        phone.single.getSemanticsData().label,
        'Номер телефона: +998 90 123 45 67. '
        'По этому номеру вы входите — изменить его нельзя.',
      );

      final SemanticsData save = tester
          .getSemantics(byKey('profile-save'))
          .getSemanticsData();
      expect(save.label, 'Сохранить');
      expect(save.hint, 'имя не изменилось');
      expect(save.flagsCollection.isEnabled, isNot(Tristate.isTrue));
      handle.dispose();
    });

    testWidgets('a trimmed name renames once, says saved and closes', (
      tester,
    ) async {
      await openEditor(tester);

      await tester.enterText(byKey('profile-name-field'), '  Aziza  ');
      await save(tester);

      expect(profile.renames, <String>['Aziza']);
      expect(byKey('edit-profile'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(await pushed, isTrue);
    });

    testWidgets('a failed rename keeps the screen and says it is not saved', (
      tester,
    ) async {
      profile.renameFailure = const NetworkFailure();
      await openEditor(tester, device: const Locale('ru'));

      await tester.enterText(byKey('profile-name-field'), 'Aziza');
      await save(tester);

      expect(byKey('edit-profile'), findsOneWidget);
      expect(find.text('Нет связи — имя не сохранено'), findsOneWidget);
    });

    testWidgets('two quick taps rename once', (tester) async {
      final Completer<void> hold = Completer<void>();
      await openEditor(tester);
      profile.hold = hold;

      await tester.enterText(byKey('profile-name-field'), 'Aziza');
      await tester.tap(byKey('profile-save'));
      await tester.pump();
      await tester.tap(byKey('profile-save'), warnIfMissed: false);
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();

      expect(profile.renames, <String>['Aziza']);
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets('holds at 360x640 with the keyboard up at x$scale '
            '(${device.languageCode})', (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          profile.current = named('Aziza');
          await openEditor(
            tester,
            size: const Size(360, 640),
            device: device,
            textScaler: NonlinearTextScaler(scale),
          );
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

          await tester.enterText(byKey('profile-name-field'), 'Aziza K');
          await tester.pumpAndSettle();
          expect(byKey('profile-save'), findsOneWidget);
          expect(
            tester.getRect(byKey('profile-save')).bottom,
            lessThanOrEqualTo(640 - 300),
          );
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          expect(tester.takeException(), isNull);
          handle.dispose();
        });
      }
    }
  });

  group('saving, failing and leaving', () {
    const Locale ru = Locale('ru');
    final Duration pause = const Duration(milliseconds: 650);

    List<String> spoken(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message)
        .toList();

    /// A name typed over [named] «Дилноза Каримова», saved with the answer held.
    Future<Completer<void>> startSaving(
      WidgetTester tester, {
      String name = 'Диля',
    }) async {
      profile.current = named('Дилноза Каримова');
      await openEditor(tester, device: ru);
      final Completer<void> hold = Completer<void>();
      profile.hold = hold;
      await tester.enterText(byKey('profile-name-field'), name);
      await tester.pump();
      tester.takeAnnouncements();
      await tester.tap(byKey('profile-save'));
      await tester.pump();
      return hold;
    }

    /// The rename answered, the reload held: the form is checking.
    Future<Completer<void>> startChecking(WidgetTester tester) async {
      final Completer<void> first = await startSaving(tester);
      final Completer<void> second = Completer<void>();
      profile.hold = second;
      first.complete();
      await tester.pump();
      await tester.pump();
      return second;
    }

    Future<void> settleSaved(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    testWidgets('saving keeps the field focused and the keyboard up', (
      tester,
    ) async {
      await startSaving(tester);

      expect(nameEditable(tester).focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(byKey('profile-name-field'), 'Диля К');
      await tester.pump();
      expect(nameText(tester), 'Диля');
      expect(byKey('profile-name-clear'), findsNothing);
      expect(nameEditable(tester).focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Сохраняем…'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('profile-save'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(spoken(tester), <String>['Сохраняем имя…']);
    });

    testWidgets('a saved name shows the check then leaves', (tester) async {
      final List<String> haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
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
      final Completer<void> hold = await startSaving(tester);
      hold.complete();
      await settleSaved(tester);

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('profile-save'),
          matching: find.text('Имя сохранено'),
        ),
        findsOneWidget,
      );
      expect(haptics, <String>['HapticFeedbackType.lightImpact']);
      expect(spoken(tester), contains('Имя сохранено'));
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      expect(byKey('edit-profile'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(byKey('edit-profile'), findsNothing);
      expect(await pushed, isTrue);
      expect(find.text('Диля'), findsOneWidget);
    });

    testWidgets('no connection says the name is not saved', (tester) async {
      profile.current = named('Дилноза Каримова');
      profile.renameFailure = const NetworkFailure(mayHaveArrived: false);
      await openEditor(tester, device: ru);
      await tester.enterText(byKey('profile-name-field'), 'Диля');
      await tester.pump();
      tester.takeAnnouncements();
      await tester.tap(byKey('profile-save'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: byKey('profile-strip'),
          matching: find.text('Нет связи — имя не сохранено'),
        ),
        findsOneWidget,
      );
      expect(spoken(tester), contains('Нет связи — имя не сохранено'));
      expect(nameText(tester), 'Диля');
      expect(byKey('edit-profile'), findsOneWidget);

      await tester.enterText(byKey('profile-name-field'), 'Диля К');
      await tester.pumpAndSettle();
      expect(byKey('profile-strip'), findsNothing);

      profile.renameFailure = const NetworkFailure(mayHaveArrived: false);
      await tester.tap(byKey('profile-save'));
      await tester.pumpAndSettle();
      expect(byKey('profile-strip'), findsOneWidget);

      await tester.tap(byKey('profile-retry'));
      await tester.pump();
      await tester.pump(pause);
      await tester.pumpAndSettle();
      expect(profile.renames, <String>['Диля', 'Диля К', 'Диля К']);
      expect(byKey('edit-profile'), findsNothing);
      expect(await pushed, isTrue);
    });

    testWidgets('a lost answer whose name landed ends as saved', (
      tester,
    ) async {
      profile.loseAnswer = true;
      final Completer<void> first = await startSaving(tester);
      final Completer<void> second = Completer<void>();
      profile.hold = second;
      first.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('Проверяем…'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('profile-save'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      second.complete();
      await settleSaved(tester);
      expect(find.text('Имя сохранено'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.pump(pause);
      await tester.pumpAndSettle();

      expect(byKey('edit-profile'), findsNothing);
      expect(await pushed, isTrue);
      expect(profile.renames, <String>['Диля']);
    });

    testWidgets('a server failure that did not save says so', (tester) async {
      profile.renameFailure = const UnexpectedFailure();
      final Completer<void> second = await startChecking(tester);

      expect(find.text('Проверяем…'), findsOneWidget);
      second.complete();
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: byKey('profile-strip'),
          matching: find.text('Не удалось сохранить имя'),
        ),
        findsOneWidget,
      );
      expect(byKey('edit-profile'), findsOneWidget);
      expect(nameText(tester), 'Диля');
    });

    testWidgets('an unsure save can be repeated and ends as saved', (
      tester,
    ) async {
      profile.loseAnswer = true;
      final Completer<void> second = await startChecking(tester);
      profile.loadFailure = const NetworkFailure();
      second.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('Нет связи — не удалось проверить, сохранилось ли имя'),
        findsOneWidget,
      );
      expect(byKey('profile-name-field'), findsOneWidget);

      profile.hold = null;
      await tester.tap(byKey('profile-retry'));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.pump(pause);
      await tester.pumpAndSettle();
      expect(profile.renames, <String>['Диля', 'Диля']);
      expect(await pushed, isTrue);
    });

    testWidgets('back with a new name asks first', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openEditor(tester, device: ru);
      await tester.enterText(byKey('profile-name-field'), 'Диля');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('name-leave-sheet'), findsOneWidget);
      expect(find.text('Сохранить новое имя?'), findsOneWidget);
      expect(find.text('«Диля» вместо «Дилноза Каримова»'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(byKey('name-leave-sheet'), findsNothing);
      expect(byKey('edit-profile'), findsOneWidget);
      expect(nameEditable(tester).focusNode.hasFocus, isTrue);
      expect(
        nameEditable(tester).controller.selection,
        const TextSelection.collapsed(offset: 4),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(byKey('name-leave-drop'));
      await tester.pumpAndSettle();
      expect(byKey('edit-profile'), findsNothing);
      expect(find.text('Дилноза Каримова'), findsOneWidget);
      expect(profile.renames, isEmpty);
      expect(await pushed, isNull);
    });

    testWidgets('back with a new name can save it', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openEditor(tester, device: ru);
      await tester.enterText(byKey('profile-name-field'), 'Диля');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(byKey('name-leave-save'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.pump(pause);
      await tester.pumpAndSettle();

      expect(profile.renames, <String>['Диля']);
      expect(byKey('edit-profile'), findsNothing);
      expect(await pushed, isTrue);
    });

    testWidgets('the sheet without a saved name says only the new one', (
      tester,
    ) async {
      await openEditor(tester, device: ru);
      await tester.enterText(byKey('profile-name-field'), 'Диля');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Имя: «Диля»'), findsOneWidget);
    });

    testWidgets('back with nothing changed leaves at once', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openEditor(tester, device: ru);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('edit-profile'), findsNothing);
      expect(byKey('name-leave-sheet'), findsNothing);
    });

    testWidgets('back with the field emptied leaves at once', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openEditor(tester, device: ru);
      await tester.enterText(byKey('profile-name-field'), '  ');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('edit-profile'), findsNothing);
      expect(byKey('name-leave-sheet'), findsNothing);
      expect(profile.renames, isEmpty);
    });

    testWidgets('back is held while saving and the editor pops once', (
      tester,
    ) async {
      final Completer<void> hold = await startSaving(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(byKey('edit-profile'), findsOneWidget);
      expect(byKey('name-leave-sheet'), findsNothing);

      hold.complete();
      await settleSaved(tester);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(byKey('edit-profile'), findsOneWidget);
      await tester.pump(pause);
      await tester.pumpAndSettle();

      expect(byKey('edit-profile'), findsNothing);
      expect(await pushed, isTrue);
      expect(find.text('Диля'), findsOneWidget);
    });

    for (final double scale in <double>[1, 2]) {
      for (final String scenario in <String>[
        'saving',
        'saved',
        'offline',
        'unsure',
        'failed',
        'leave',
      ]) {
        testWidgets('holds at 360x640 with the keyboard up at x$scale: '
            '$scenario', (tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          profile.current = named('Дилноза Каримова');
          await openEditor(
            tester,
            size: const Size(360, 640),
            device: ru,
            textScaler: NonlinearTextScaler(scale),
          );
          Future<void> typeAndSave() async {
            await tester.enterText(byKey('profile-name-field'), 'Диля');
            await tester.pump();
            await tester.tap(byKey('profile-save'));
          }

          switch (scenario) {
            case 'saving':
              profile.hold = Completer<void>();
              await typeAndSave();
              await tester.pump();
            case 'saved':
              await typeAndSave();
              await tester.pump();
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 500));
            case 'offline':
              profile.renameFailure = const NetworkFailure(
                mayHaveArrived: false,
              );
              await typeAndSave();
              await tester.pumpAndSettle();
            case 'unsure':
              profile.loseAnswer = true;
              profile.loadFailure = const NetworkFailure();
              await typeAndSave();
              await tester.pumpAndSettle();
            case 'failed':
              profile.renameFailure = ApiRefusal(
                const ApiError(status: 422, code: 'validation_failed'),
              );
              await typeAndSave();
              await tester.pumpAndSettle();
            case 'leave':
              await tester.enterText(byKey('profile-name-field'), 'Диля');
              await tester.pump();
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
              expect(byKey('name-leave-sheet'), findsOneWidget);
              final Rect save = tester.getRect(byKey('name-leave-save'));
              final Rect drop = tester.getRect(byKey('name-leave-drop'));
              expect(drop.top, greaterThanOrEqualTo(save.bottom));
          }
          if (<String>['offline', 'unsure', 'failed'].contains(scenario)) {
            expect(byKey('profile-strip'), findsOneWidget);
            final Rect strip = tester.getRect(byKey('profile-strip'));
            final Rect retry = tester.getRect(byKey('profile-retry'));
            if (scale == 2) {
              final Rect words = tester.getRect(
                find
                    .descendant(
                      of: byKey('profile-strip'),
                      matching: find.byType(Text),
                    )
                    .first,
              );
              expect(retry.top, greaterThanOrEqualTo(words.bottom));
            }
            expect(retry.right, lessThanOrEqualTo(strip.right));
          }
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          profile.hold?.complete();
          await tester.pumpAndSettle();
          handle.dispose();
        });
      }
    }
  });

  test('initialsOf takes the first letters of the first two words', () {
    expect(initialsOf('Дилноза Каримова'), 'ДК');
    expect(initialsOf('aziza'), 'A');
    expect(initialsOf('a b c'), 'AB');
    expect(initialsOf(null), isNull);
    expect(initialsOf('   '), isNull);
  });
}
