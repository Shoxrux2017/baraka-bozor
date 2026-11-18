import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/auth/presentation/auth_notice.dart';
import 'package:baraka_bozor/features/profile/application/account_deletion_controller.dart';
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/catalog/application/recent_searches.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/presentation/delete_account_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_account_deletion_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_sign_in_device.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeAccountDeletionRepository deletion;
  late InMemoryPreferenceStore preferences;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext host(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(host(tester));

  // The page on top, a pushed one included.
  String location(WidgetTester tester) =>
      GoRouter.of(host(tester))
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;

  final String searchesKey = RecentSearches.preferenceKey('c');

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    deletion = FakeAccountDeletionRepository();
    preferences = InMemoryPreferenceStore(<String, String>{
      searchesKey: '["sut"]',
    });
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    Locale device = const Locale('ru'),
    double textScale = 1,
    TextScaler? textScaler,
    FakeClipboardCode? clipboard,
    FakeTelegramLauncher? telegram,
    FakeAccountDeletionRepository? repository,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        preferences: preferences,
        textScaler: textScaler,
        clipboard: clipboard,
        telegram: telegram,
        overrides: [
          accountDeletionRepositoryProvider.overrideWithValue(
            repository ?? deletion,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    Locale device = const Locale('ru'),
    double textScale = 1,
    TextScaler? textScaler,
    FakeClipboardCode? clipboard,
    FakeTelegramLauncher? telegram,
    FakeAccountDeletionRepository? repository,
  }) async {
    await pumpApp(
      tester,
      size: size,
      device: device,
      textScale: textScale,
      textScaler: textScaler,
      clipboard: clipboard,
      telegram: telegram,
      repository: repository,
    );
    unawaited(showDeleteAccountSheet(host(tester)));
    await tester.pumpAndSettle();
  }

  Future<void> openCodeScreen(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    Locale device = const Locale('ru'),
    double textScale = 1,
    TextScaler? textScaler,
    FakeClipboardCode? clipboard,
    FakeTelegramLauncher? telegram,
    FakeAccountDeletionRepository? repository,
  }) async {
    await openSheet(
      tester,
      size: size,
      device: device,
      textScale: textScale,
      textScaler: textScaler,
      clipboard: clipboard,
      telegram: telegram,
      repository: repository,
    );
    await tester.ensureVisible(byKey('delete-confirm'));
    await tester.pump();
    await tester.tap(byKey('delete-confirm'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String code) async {
    await tester.enterText(byKey('code-field'), code);
    await tester.pump();
    await tester.tap(byKey('delete-submit'));
    await tester.pumpAndSettle();
  }

  // Drops the app so a countdown still ticking does not outlive the test.
  Future<void> finish(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  group('sheet', () {
    const Size phone = Size(390, 844);
    const String nbspPhone = '+998 90 123 45 67';

    List<String> announced(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message)
        .toList();

    testWidgets('the sheet says it is forever and what is erased and kept', (
      tester,
    ) async {
      await openSheet(tester);

      expect(byKey('delete-account-sheet'), findsOneWidget);
      expect(find.text('Удалить аккаунт?'), findsOneWidget);
      expect(byKey('delete-subtitle'), findsOneWidget);
      expect(
        find.text('Это навсегда — вернуть аккаунт нельзя.'),
        findsOneWidget,
      );
      for (final String row in <String>[
        'Имя и номер телефона',
        'Адреса',
        'Избранное',
        'Корзина',
        'Заказы — без имени, телефона и адреса, для учёта',
      ]) {
        expect(
          find.descendant(
            of: byKey('delete-account-sheet'),
            matching: find.text(row),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.text('С этим номером можно войти снова — как новый покупатель.'),
        findsOneWidget,
      );
      expect(find.textContaining('Вернуть аккаунт нельзя.'), findsNothing);
      await finish(tester);
    });

    testWidgets('the buttons say what happens', (tester) async {
      await openSheet(tester);

      expect(
        find.descendant(
          of: byKey('delete-confirm'),
          matching: find.text('Получить код для удаления'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('delete-cancel'),
          matching: find.text('Оставить аккаунт'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(byKey('delete-confirm')).dy,
        lessThan(tester.getTopLeft(byKey('delete-cancel')).dy),
      );
      expect(
        find.textContaining('Код для удаления придёт в Telegram на'),
        findsOneWidget,
      );
      expect(find.textContaining(nbspPhone), findsOneWidget);
      await finish(tester);
    });

    // Repro del-3: on main the sheet cannot be dragged shut.
    testWidgets('a fling down closes the sheet', (tester) async {
      await openSheet(tester, size: phone);

      await tester.fling(
        byKey('delete-account-sheet'),
        const Offset(0, 500),
        1500,
      );
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsNothing);
      expect(deletion.requests, 0);
      await finish(tester);
    });

    testWidgets(
      'while sending a drag springs back but Оставить аккаунт leaves',
      (tester) async {
        final Completer<void> hold = Completer<void>();
        deletion.hold = hold;
        await openSheet(tester, size: phone);

        await tester.tap(byKey('delete-confirm'));
        await tester.pump();
        expect(find.text('Отправляем код…'), findsOneWidget);

        await tester.fling(
          byKey('delete-account-sheet'),
          const Offset(0, 500),
          1500,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(byKey('delete-account-sheet'), findsOneWidget);
        expect(find.text('Отправляем код…'), findsOneWidget);

        await tester.tap(byKey('delete-cancel'));
        await tester.pumpAndSettle();
        expect(byKey('delete-account-sheet'), findsNothing);

        hold.complete();
        await tester.pumpAndSettle();

        expect(byKey('delete-account-screen'), findsNothing);
        expect(byKey('delete-account-sheet'), findsNothing);
        expect(byKey('delete-unfinished-sheet'), findsNothing);
        await finish(tester);
      },
    );

    testWidgets('a late answer of a closed sheet changes nothing', (
      tester,
    ) async {
      final Completer<void> hold = Completer<void>();
      deletion.hold = hold;
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pump();
      await tester.tap(byKey('delete-cancel'));
      await tester.pumpAndSettle();
      unawaited(showDeleteAccountSheet(host(tester)));
      await tester.pumpAndSettle();

      hold.complete();
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsOneWidget);
      expect(byKey('delete-account-screen'), findsNothing);
      expect(
        ProviderScope.containerOf(host(tester))
            .read(accountDeletionControllerProvider)
            .requested,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(byKey('delete-confirm')).onPressed,
        isNotNull,
      );
      expect(deletion.requests, 1);
      await finish(tester);
    });

    testWidgets('Оставить аккаунт sends nothing', (tester) async {
      await openSheet(tester);

      await tester.tap(byKey('delete-cancel'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsNothing);
      expect(deletion.requests, 0);
      await finish(tester);
    });

    testWidgets('two quick taps request one code', (tester) async {
      final Completer<void> hold = Completer<void>();
      deletion.hold = hold;
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pump();
      await tester.tap(byKey('delete-confirm'), warnIfMissed: false);
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();

      expect(deletion.requests, 1);
      await finish(tester);
    });

    testWidgets('after a late answer is ignored the new sheet requests and '
        'opens the code screen', (tester) async {
      final Completer<void> hold = Completer<void>();
      deletion.hold = hold;
      await openSheet(tester, size: phone);

      await tester.tap(byKey('delete-confirm'));
      await tester.pump();
      await tester.tap(byKey('delete-cancel'));
      await tester.pumpAndSettle();
      unawaited(showDeleteAccountSheet(host(tester)));
      await tester.pumpAndSettle();

      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('delete-account-screen'), findsNothing);
      expect(byKey('delete-account-sheet'), findsOneWidget);

      deletion.hold = null;
      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      expect(deletion.requests, 2);
      expect(byKey('delete-account-screen'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a late 409 of a closed sheet does not block the new one', (
      tester,
    ) async {
      final Completer<void> hold = Completer<void>();
      deletion.hold = hold;
      deletion.requestFailures.add(unfinishedRefusal());
      await openSheet(tester, size: phone);

      await tester.tap(byKey('delete-confirm'));
      await tester.pump();
      await tester.tap(byKey('delete-cancel'));
      await tester.pumpAndSettle();
      unawaited(showDeleteAccountSheet(host(tester)));
      await tester.pumpAndSettle();

      hold.complete();
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsOneWidget);
      expect(byKey('delete-unfinished-sheet'), findsNothing);
      expect(
        tester.widget<FilledButton>(byKey('delete-confirm')).onPressed,
        isNotNull,
      );
      await finish(tester);
    });

    for (final String road in <String>['the scrim', 'system back']) {
      testWidgets('while sending $road closes the sheet and the late answer '
          'changes nothing', (tester) async {
        final Completer<void> hold = Completer<void>();
        deletion.hold = hold;
        await openSheet(tester, size: phone);

        await tester.tap(byKey('delete-confirm'));
        await tester.pump();
        expect(find.text('Отправляем код…'), findsOneWidget);

        if (road == 'the scrim') {
          await tester.tapAt(const Offset(195, 20));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(byKey('delete-account-sheet'), findsNothing);

        hold.complete();
        await tester.pumpAndSettle();

        expect(byKey('delete-account-screen'), findsNothing);
        expect(byKey('delete-account-sheet'), findsNothing);
        expect(byKey('delete-unfinished-sheet'), findsNothing);
        await finish(tester);
      });
    }

    testWidgets('offline the strip offers Повторить', (tester) async {
      deletion.requestFailures.add(const NetworkFailure());
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      expect(byKey('delete-send-strip'), findsOneWidget);
      expect(find.text('Нет связи — код не отправлен'), findsOneWidget);
      expect(announced(tester), contains('Нет связи — код не отправлен'));

      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      expect(deletion.requests, 2);
      expect(byKey('delete-account-screen'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a 409 turns the same sheet into the blocked face', (
      tester,
    ) async {
      deletion.requestFailures.add(
        unfinishedRefusal(status: 'shopping', itemCount: 2),
      );
      await openSheet(tester);
      final ModalRoute<Object?>? route = ModalRoute.of(
        tester.element(byKey('delete-account-sheet')),
      );
      expect(route, isA<ModalBottomSheetRoute<Object?>>());

      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsNothing);
      expect(byKey('delete-unfinished-sheet'), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(byKey('delete-unfinished-sheet'))),
        same(route),
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      final AppLocalizations t = l10n(tester);
      expect(
        find.descendant(
          of: byKey('delete-order-card'),
          matching: find.text('Заказ № 1021'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('delete-order-card'),
          matching: find.text(
            '${OrderLabels.customerStatus(t, OrderStatus.shopping)} · '
            '${t.orderItemCount(2)}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        announced(tester),
        contains('${t.deleteBlockedTitle}. ${t.deleteBlockedBody(1021)}'),
      );

      await tester.tap(byKey('delete-order-card'));
      await tester.pumpAndSettle();

      expect(byKey('delete-unfinished-sheet'), findsNothing);
      expect(location(tester), AppPaths.customerOrder('o-1'));
      await finish(tester);
    });

    testWidgets('the blocked face: К заказу opens the order, Понятно closes', (
      tester,
    ) async {
      deletion.requestFailures.add(unfinishedRefusal());
      await openSheet(tester);
      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      await tester.tap(byKey('delete-understood'));
      await tester.pumpAndSettle();
      expect(byKey('delete-unfinished-sheet'), findsNothing);
      expect(location(tester), isNot(AppPaths.customerOrder('o-1')));

      deletion.requestFailures.add(unfinishedRefusal());
      unawaited(showDeleteAccountSheet(host(tester)));
      await tester.pumpAndSettle();
      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('delete-to-order'));
      await tester.pumpAndSettle();
      expect(location(tester), AppPaths.customerOrder('o-1'));
      await finish(tester);
    });

    testWidgets('a status the app does not know leaves only the count', (
      tester,
    ) async {
      deletion.requestFailures.add(
        unfinishedRefusal(status: 'something_new', itemCount: 3),
      );
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: byKey('delete-order-card'),
          matching: find.text(l10n(tester).orderItemCount(3)),
        ),
        findsOneWidget,
      );
      expect(find.textContaining(' · '), findsNothing);
      await finish(tester);
    });

    // Repro del-11: on main the rows are separate nodes.
    testWidgets('the erased things are one phrase', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openSheet(tester);

      final SemanticsNode erased = tester.getSemantics(
        byKey('delete-erased-group'),
      );
      final SemanticsNode kept = tester.getSemantics(
        byKey('delete-kept-group'),
      );
      final AppLocalizations t = l10n(tester);

      expect(erased.label, t.deleteErasedSpoken);
      expect(kept.label, t.deleteKeptSpoken);
      expect(erased.childrenCount, 0);
      expect(kept.childrenCount, 0);
      handle.dispose();
      await finish(tester);
    });

    testWidgets('a sent code is announced and opens the code screen', (
      tester,
    ) async {
      await openSheet(tester);
      tester.takeAnnouncements();

      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      final AppLocalizations t = l10n(tester);
      expect(
        announced(tester),
        containsAllInOrder(<String>[
          t.sendingCode,
          t.codeSentSpoken('+998 90 123 45 67'),
        ]),
      );
      expect(byKey('delete-account-screen'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('another refusal shows its notice and keeps the sheet', (
      tester,
    ) async {
      deletion.requestFailures.add(
        const ApiRefusal(ApiError(status: 500, code: 'server_error')),
      );
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsOneWidget);
      expect(find.byType(AuthNotice), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a locked phone at the request shows the lock, button off', (
      tester,
    ) async {
      deletion.requestFailures.add(lockedRefusal(retryAfter: 30));
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pump();
      await tester.pump();

      expect(byKey('lock-message'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('delete-confirm')).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(byKey('lock-message'), findsNothing);
      expect(
        tester.widget<FilledButton>(byKey('delete-confirm')).onPressed,
        isNotNull,
      );
      await finish(tester);
    });

    testWidgets('both languages render', (tester) async {
      await openSheet(tester, device: const Locale('uz'));

      expect(find.text("O'chirish uchun kod olish"), findsOneWidget);
      expect(find.text('Akkauntni qoldirish'), findsOneWidget);
      expect(find.text('Savat'), findsOneWidget);
      await finish(tester);
    });

    for (final double scale in <double>[1, 2]) {
      group('tap targets at x$scale', () {
        final TextScaler scaler = scale == 1
            ? TextScaler.noScaling
            : NonlinearTextScaler(scale);
        final Size size = scale == 1 ? phone : const Size(360, 640);

        testWidgets('idle', (tester) async {
          await openSheet(tester, size: size, textScaler: scaler);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await finish(tester);
        });

        testWidgets('sending', (tester) async {
          deletion.hold = Completer<void>();
          await openSheet(tester, size: size, textScaler: scaler);
          await tester.ensureVisible(byKey('delete-confirm'));
          await tester.pump();
          await tester.tap(byKey('delete-confirm'));
          await tester.pump();
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await finish(tester);
        });

        testWidgets('offline', (tester) async {
          deletion.requestFailures.add(const NetworkFailure());
          await openSheet(tester, size: size, textScaler: scaler);
          await tester.ensureVisible(byKey('delete-confirm'));
          await tester.pump();
          await tester.tap(byKey('delete-confirm'));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await finish(tester);
        });

        testWidgets('blocked', (tester) async {
          deletion.requestFailures.add(
            unfinishedRefusal(status: 'shopping', itemCount: 2),
          );
          await openSheet(tester, size: size, textScaler: scaler);
          await tester.ensureVisible(byKey('delete-confirm'));
          await tester.pump();
          await tester.tap(byKey('delete-confirm'));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await finish(tester);
        });
      });
    }
  });

  group('the code screen (36а)', () {
    testWidgets('a wrong code shows the refusal and clears the boxes', (
      tester,
    ) async {
      await openCodeScreen(tester);
      deletion.deleteFailures.add(wrongCodeRefusal());

      await submit(tester, '111111');

      expect(find.text(l10n(tester).errorCodeInvalid), findsOneWidget);
      expect(
        tester.widget<TextField>(byKey('code-field')).controller!.text,
        isEmpty,
      );
      expect(byKey('delete-account-screen'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('three wrong codes show the lock card and disable the button', (
      tester,
    ) async {
      await openCodeScreen(tester);
      deletion.deleteFailures
        ..add(wrongCodeRefusal())
        ..add(wrongCodeRefusal())
        ..add(lockedRefusal(retryAfter: 60));

      await submit(tester, '111111');
      await submit(tester, '222222');
      await submit(tester, '333333');

      expect(byKey('code-lock-card'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('delete-submit')).onPressed,
        isNull,
      );
      await finish(tester);
    });

    testWidgets('the button waits for six digits', (tester) async {
      await openCodeScreen(tester);

      expect(
        tester.widget<FilledButton>(byKey('delete-submit')).onPressed,
        isNull,
      );
      await tester.enterText(byKey('code-field'), '12345');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(byKey('delete-submit')).onPressed,
        isNull,
      );
      await tester.enterText(byKey('code-field'), '123456');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(byKey('delete-submit')).onPressed,
        isNotNull,
      );
      await finish(tester);
    });

    testWidgets('test_two_quick_taps_delete_once', (tester) async {
      await openCodeScreen(tester);
      final Completer<void> hold = Completer<void>();
      deletion.hold = hold;

      await tester.enterText(byKey('code-field'), '123456');
      await tester.pump();
      await tester.tap(byKey('delete-submit'));
      await tester.pump();
      await tester.tap(byKey('delete-submit'), warnIfMissed: false);
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();

      expect(deletion.deletes, <String>['123456']);
      await finish(tester);
    });

    testWidgets('test_a_409_on_delete_shows_the_unfinished_order', (
      tester,
    ) async {
      await openCodeScreen(tester);
      deletion.deleteFailures.add(unfinishedRefusal(number: 1055));

      await submit(tester, '123456');

      expect(byKey('delete-unfinished-sheet'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('delete-order-card'),
          matching: find.text('Заказ № 1055'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-screen'), findsNothing);
      expect(byKey('delete-unfinished-sheet'), findsNothing);
      await finish(tester);
    });

    testWidgets('a right code ends the session, forgets the searches and '
        'Готово leads to the phone screen', (tester) async {
      await openCodeScreen(tester);

      await submit(tester, '123456');

      expect(byKey('account-deleted'), findsOneWidget);
      expect(find.text('Аккаунт удалён'), findsOneWidget);
      expect(tokens.tokens.containsKey(SessionSlot.customer), isFalse);
      final ProviderContainer container = ProviderScope.containerOf(
        host(tester),
      );
      expect(container.read(sessionControllerProvider).value, isA<SignedOut>());
      expect(preferences.values.containsKey(searchesKey), isFalse);

      await tester.tap(byKey('account-deleted-done'));
      await tester.pumpAndSettle();

      expect(byKey('continue-button'), findsOneWidget);
      expect(location(tester), AppPaths.auth);
      await finish(tester);
    });

    testWidgets('back is blocked while the delete runs', (tester) async {
      await openCodeScreen(tester);
      final Completer<void> hold = Completer<void>();
      deletion.hold = hold;
      await tester.enterText(byKey('code-field'), '123456');
      await tester.pump();
      await tester.tap(byKey('delete-submit'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(byKey('delete-account-screen'), findsOneWidget);
      expect(location(tester), AppPaths.customerDeleteAccount);

      hold.complete();
      await tester.pumpAndSettle();

      expect(byKey('account-deleted'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('system back on "Аккаунт удалён" leads to the phone screen', (
      tester,
    ) async {
      await openCodeScreen(tester);
      await submit(tester, '123456');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(location(tester), AppPaths.auth);
      await finish(tester);
    });
  });

  group('code screen', () {
    const Size phone = Size(390, 844);

    List<String> announced(WidgetTester tester) => tester
        .takeAnnouncements()
        .map((CapturedAccessibilityAnnouncement a) => a.message)
        .toList();

    List<String> buzzes(WidgetTester tester) {
      final List<String> calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
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
      return calls;
    }

    String typed(WidgetTester tester) =>
        tester.widget<TextField>(byKey('code-field')).controller!.text;

    Future<void> type(WidgetTester tester, String code) async {
      await tester.enterText(byKey('code-field'), code);
      await tester.pump();
    }

    Finder buttonText(String text) =>
        find.descendant(of: byKey('delete-submit'), matching: find.text(text));

    ApiRefusal wrong({int? left}) => ApiRefusal(
      ApiError(
        status: 422,
        code: 'code_invalid',
        details: <String, Object?>{'attempts_left': ?left},
      ),
    );

    const ApiRefusal gone = ApiRefusal(
      ApiError(status: 401, code: 'authentication_required'),
    );

    Color edgeOf(WidgetTester tester, int i) {
      final Container box = tester.widget<Container>(
        find
            .descendant(
              of: byKey('code-box-$i'),
              matching: find.byType(Container),
            )
            .first,
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    testWidgets('the boxes are green while typing', (tester) async {
      await openCodeScreen(tester, size: phone);

      await type(tester, '12');

      expect(edgeOf(tester, 0), KitColors.primary);
      await finish(tester);
    });

    testWidgets('the sixth digit deletes nothing', (tester) async {
      await openCodeScreen(tester, size: phone);

      await type(tester, '123456');
      await tester.pump(const Duration(seconds: 1));

      expect(deletion.deletes, isEmpty);
      expect(buttonText('Удалить аккаунт'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('delete-submit')).onPressed,
        isNotNull,
      );
      await finish(tester);
    });

    testWidgets('the grey button says what is missing', (tester) async {
      await openCodeScreen(tester, size: phone);

      expect(buttonText('Введите код из Telegram'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('delete-submit')).onPressed,
        isNull,
      );
      await type(tester, '123');
      expect(buttonText('Введите ещё 3 цифры'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a channel other than Telegram says only Введите код', (
      tester,
    ) async {
      deletion.answer = const RequestedCode(
        channel: 'sms',
        expiresInSeconds: 300,
        resendAvailableInSeconds: 60,
      );
      await openCodeScreen(tester, size: phone);

      expect(buttonText('Введите код'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a wrong code shakes red, buzzes and says the tries left', (
      tester,
    ) async {
      final List<String> calls = buzzes(tester);
      await openCodeScreen(tester, size: phone);
      deletion.deleteFailures.add(wrong(left: 2));
      tester.takeAnnouncements();

      await type(tester, '111111');
      await tester.tap(byKey('delete-submit'));
      await tester.pump();
      await tester.pump();

      expect(byKey('code-attempts'), findsOneWidget);
      expect(find.text('Неверный код. Осталось 2 попытки'), findsOneWidget);
      expect(calls, <String>['HapticFeedbackType.errorNotification']);
      expect(announced(tester), contains('Неверный код. Осталось 2 попытки'));
      expect(typed(tester), '111111');
      expect(edgeOf(tester, 0), KitColors.danger);

      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump();

      expect(typed(tester), isEmpty);
      await finish(tester);
    });

    testWidgets('three wrong codes show the lock card, then Получить новый '
        'код', (tester) async {
      await openCodeScreen(tester, size: phone);
      deletion.deleteFailures
        ..add(wrong(left: 2))
        ..add(wrong(left: 1))
        ..add(lockedRefusal(retryAfter: 2));
      for (final String code in <String>['111111', '222222', '333333']) {
        await type(tester, code);
        await tester.tap(byKey('delete-submit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(byKey('code-lock-card'), findsOneWidget);
      expect(byKey('code-field'), findsNothing);
      expect(byKey('code-open-telegram'), findsNothing);
      expect(byKey('code-no-code'), findsNothing);
      expect(buttonText('Удалить аккаунт'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('delete-submit')).onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));

      expect(buttonText('Получить новый код'), findsOneWidget);
      expect(byKey('code-open-telegram'), findsNothing);
      expect(byKey('code-no-code'), findsNothing);
      tester.takeAnnouncements();

      await tester.tap(byKey('delete-submit'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(deletion.requests, 2);
      expect(byKey('code-field'), findsOneWidget);
      expect(
        announced(tester).any((String m) => m.contains('Код отправлен')),
        isTrue,
      );
      await finish(tester);
    });

    testWidgets('deleting says Удаляем аккаунт… and blocks back', (
      tester,
    ) async {
      await openCodeScreen(tester, size: phone);
      final Completer<void> hold = Completer<void>();
      deletion.hold = hold;
      tester.takeAnnouncements();

      await type(tester, '123456');
      await tester.tap(byKey('delete-submit'));
      await tester.pump();

      expect(buttonText('Удаляем аккаунт…'), findsOneWidget);
      expect(announced(tester), contains('Удаляем аккаунт…'));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(byKey('delete-account-screen'), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(byKey('account-deleted'), findsOneWidget);
      await finish(tester);
    });

    // Repro del-9: on main the lost answer shows «Нет связи» though the
    // account is already gone.
    testWidgets('a lost answer checks itself and shows Аккаунт удалён', (
      tester,
    ) async {
      final _SlowCheck slow = _SlowCheck()..exists = false;
      await openCodeScreen(tester, size: phone, repository: slow);
      slow.deleteFailures.add(const NetworkFailure());
      tester.takeAnnouncements();

      await type(tester, '123456');
      await tester.tap(byKey('delete-submit'));
      await tester.pump();
      await tester.pump();

      expect(buttonText('Проверяем…'), findsOneWidget);
      expect(announced(tester), contains('Проверяем, удалён ли аккаунт…'));

      slow.checkHold.complete();
      await tester.pumpAndSettle();

      expect(byKey('account-deleted'), findsOneWidget);
      expect(find.text('Аккаунт удалён'), findsOneWidget);
      expect(slow.deletes, <String>['123456']);
      await finish(tester);
    });

    testWidgets('offline the strip keeps the code', (tester) async {
      await openCodeScreen(tester, size: phone);
      deletion.deleteFailures.add(const NetworkFailure());
      deletion.exists = true;
      tester.takeAnnouncements();

      await type(tester, '123456');
      await tester.tap(byKey('delete-submit'));
      await tester.pumpAndSettle();

      expect(byKey('delete-offline-strip'), findsOneWidget);
      expect(find.text('Нет связи — аккаунт не удалён'), findsOneWidget);
      expect(typed(tester), '123456');
      expect(announced(tester), contains('Нет связи — аккаунт не удалён'));
      await finish(tester);
    });

    testWidgets('Повторить after a lost answer deletes once with the kept '
        'code', (tester) async {
      await openCodeScreen(tester, size: phone);
      deletion.deleteFailures.add(const NetworkFailure());
      deletion.exists = true;

      await type(tester, '123456');
      await tester.tap(byKey('delete-submit'));
      await tester.pumpAndSettle();
      expect(deletion.deletes, <String>['123456']);

      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      expect(deletion.deletes, <String>['123456', '123456']);
      expect(byKey('account-deleted'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a deletion read from a 401 lands on Аккаунт удалён, not on '
        'Вход', (tester) async {
      await openCodeScreen(tester, size: phone);
      final GoRouter router = GoRouter.of(host(tester));
      final List<String> seen = <String>[];
      void record() => seen.add(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
      );
      router.routerDelegate.addListener(record);
      addTearDown(() => router.routerDelegate.removeListener(record));
      deletion.deleteFailures.add(gone);

      await type(tester, '123456');
      await tester.tap(byKey('delete-submit'));
      await tester.pumpAndSettle();

      expect(seen, contains(AppPaths.accountDeleted));
      expect(seen.contains(AppPaths.auth), isFalse);
      expect(byKey('account-deleted'), findsOneWidget);
      expect(tokens.tokens.containsKey(SessionSlot.customer), isFalse);
      await finish(tester);
    });

    testWidgets('the paste chip fills the boxes without deleting', (
      tester,
    ) async {
      await openCodeScreen(
        tester,
        size: phone,
        clipboard: FakeClipboardCode(code: '654321'),
      );

      expect(byKey('code-paste'), findsOneWidget);
      await tester.tap(byKey('code-paste'));
      await tester.pump(const Duration(seconds: 1));

      expect(typed(tester), '654321');
      expect(deletion.deletes, isEmpty);
      await finish(tester);
    });

    testWidgets('Открыть Telegram falls back to the no-code sheet', (
      tester,
    ) async {
      final FakeTelegramLauncher telegram = FakeTelegramLauncher(opens: false);
      await openCodeScreen(tester, size: phone, telegram: telegram);

      await tester.tap(byKey('code-open-telegram'));
      await tester.pumpAndSettle();

      expect(telegram.calls, 1);
      expect(byKey('delete-no-code-sheet'), findsOneWidget);
      expect(find.text('Изменить номер'), findsNothing);
      expect(
        find.textContaining('Откройте Telegram на этом телефоне'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Если Telegram на другом номере'),
        findsNothing,
      );
      expect(find.textContaining('Отправить ещё раз через'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Отправить ещё раз через'), findsOneWidget);
      await finish(tester);
    });

    // Repro del-11: on main the field is just «Код».
    testWidgets('the field is named Код из Telegram with the count', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openCodeScreen(tester, size: phone);
      await type(tester, '123');

      final SemanticsNode field = tester.getSemantics(byKey('code-semantics'));

      expect(field.label, 'Код из Telegram, 6 цифр');
      expect(field.value, 'введено 3 из 6: 1 2 3');
      handle.dispose();
      await finish(tester);
    });

    testWidgets('a 409 on delete opens the blocked face and Понятно leaves '
        'the screen', (tester) async {
      await openCodeScreen(tester, size: phone);
      deletion.deleteFailures.add(unfinishedRefusal(number: 1055));

      await type(tester, '123456');
      await tester.tap(byKey('delete-submit'));
      await tester.pumpAndSettle();

      expect(byKey('delete-unfinished-sheet'), findsOneWidget);
      await tester.tap(byKey('delete-understood'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-screen'), findsNothing);
      await finish(tester);
    });

    testWidgets('a resend answered 409 shows the blocked face', (tester) async {
      await openCodeScreen(tester, size: phone);
      deletion.deleteFailures.add(lockedRefusal(retryAfter: 1));
      await type(tester, '123456');
      await tester.tap(byKey('delete-submit'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(buttonText('Получить новый код'), findsOneWidget);

      deletion.requestFailures.add(unfinishedRefusal(number: 1077));
      await tester.tap(byKey('delete-submit'));
      await tester.pumpAndSettle();

      expect(byKey('delete-unfinished-sheet'), findsOneWidget);
      expect(find.text('Заказ № 1077'), findsOneWidget);
      await tester.tap(byKey('delete-understood'));
      await tester.pumpAndSettle();
      expect(byKey('delete-account-screen'), findsNothing);
      await finish(tester);
    });

    testWidgets('a resend of the no-code sheet answered 409 shows one '
        'blocked face', (tester) async {
      await openCodeScreen(tester, size: phone);
      await tester.tap(byKey('code-no-code'));
      await tester.pumpAndSettle();
      expect(byKey('delete-no-code-sheet'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      await tester.pump(const Duration(milliseconds: 300));

      deletion.requestFailures.add(unfinishedRefusal(number: 1077));
      await tester.tap(byKey('resend-button'));
      await tester.pumpAndSettle();

      expect(byKey('delete-no-code-sheet'), findsNothing);
      expect(byKey('delete-unfinished-sheet'), findsOneWidget);
      expect(find.text('Заказ № 1077'), findsOneWidget);
      await finish(tester);
    });

    for (final double scale in <double>[1, 2]) {
      group('tap targets at x$scale', () {
        final TextScaler scaler = scale == 1
            ? TextScaler.noScaling
            : NonlinearTextScaler(scale);
        final Size size = scale == 1 ? phone : const Size(360, 640);

        Future<void> open(
          WidgetTester tester, {
          FakeClipboardCode? clipboard,
        }) => openCodeScreen(
          tester,
          size: size,
          textScaler: scaler,
          clipboard: clipboard,
        );

        Future<void> meets(WidgetTester tester) async {
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await finish(tester);
        }

        testWidgets('entry', (tester) async {
          await open(tester);
          await meets(tester);
        });

        testWidgets('six digits', (tester) async {
          await open(tester);
          await type(tester, '123456');
          await meets(tester);
        });

        testWidgets('wrong', (tester) async {
          await open(tester);
          deletion.deleteFailures.add(wrong(left: 2));
          await type(tester, '123456');
          await tester.tap(byKey('delete-submit'));
          await tester.pump();
          await tester.pump();
          await meets(tester);
        });

        testWidgets('locked', (tester) async {
          await open(tester);
          deletion.deleteFailures.add(lockedRefusal(retryAfter: 30));
          await type(tester, '123456');
          await tester.tap(byKey('delete-submit'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await meets(tester);
        });

        testWidgets('lock over', (tester) async {
          await open(tester);
          deletion.deleteFailures.add(lockedRefusal(retryAfter: 1));
          await type(tester, '123456');
          await tester.tap(byKey('delete-submit'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(milliseconds: 400));
          await meets(tester);
        });

        testWidgets('offline', (tester) async {
          await open(tester);
          deletion.deleteFailures.add(const NetworkFailure());
          deletion.exists = true;
          await type(tester, '123456');
          await tester.tap(byKey('delete-submit'));
          await tester.pumpAndSettle();
          await meets(tester);
        });

        testWidgets('paste chip', (tester) async {
          await open(tester, clipboard: FakeClipboardCode(code: '654321'));
          expect(byKey('code-paste'), findsOneWidget);
          await meets(tester);
        });
      });
    }
  });

  group('done', () {
    const Size phone = Size(390, 844);

    Future<void> startDeleting(WidgetTester tester) async {
      await tester.enterText(byKey('code-field'), '123456');
      await tester.pump();
      await tester.tap(byKey('delete-submit'));
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    double fade(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: byKey('account-deleted'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('the done page fades in over the code screen', (tester) async {
      await openCodeScreen(tester, size: phone);
      await startDeleting(tester);

      expect(byKey('account-deleted'), findsOneWidget);
      expect(fade(tester), lessThan(0.1));
      await tester.pump(const Duration(milliseconds: 160));

      expect(byKey('delete-account-screen'), findsOneWidget);
      expect(byKey('account-deleted'), findsOneWidget);
      expect(fade(tester), inExclusiveRange(0.3, 1));

      await tester.pump(const Duration(milliseconds: 200));
      expect(fade(tester), 1);
      await tester.pumpAndSettle();
      await finish(tester);
    });

    testWidgets('a calm grey check and the true words', (tester) async {
      await openCodeScreen(tester, size: phone);
      await submit(tester, '123456');

      final Finder circle = byKey('account-deleted-check');
      expect(tester.getSize(circle), const Size(84, 84));
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(of: circle, matching: find.byType(DecoratedBox)).first,
      );
      expect((box.decoration as BoxDecoration).color, KitColors.chip);
      final Icon icon = tester.widget<Icon>(
        find.descendant(of: circle, matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.check);
      expect(icon.size, 40);
      expect(icon.color, KitColors.ink2);
      expect(
        find.descendant(
          of: byKey('account-deleted'),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == KitColors.primary,
          ),
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Имя, номер телефона, адреса и избранное стёрты. '
          'Заказы остались — без имени, для учёта.',
        ),
        findsOneWidget,
      );
      expect(find.text('Спасибо, что были с нами.'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('the title is announced', (tester) async {
      await openCodeScreen(tester, size: phone);
      tester.takeAnnouncements();
      await submit(tester, '123456');

      expect(
        tester.takeAnnouncements().map(
          (CapturedAccessibilityAnnouncement a) => a.message,
        ),
        contains('Аккаунт удалён'),
      );
      await finish(tester);
    });

    testWidgets('a deletion forgets the address and the searches of that '
        'account only', (tester) async {
      final String addressKey = DeliveryAddressChoice.preferenceKey('c');
      preferences.values[addressKey] = 'a1';
      preferences.values[DeliveryAddressChoice.preferenceKey('other')] = 'a2';
      preferences.values[RecentSearches.preferenceKey('other')] = '["x"]';
      await openCodeScreen(tester, size: phone);

      await submit(tester, '123456');

      expect(preferences.values.containsKey(addressKey), isFalse);
      expect(preferences.values.containsKey(searchesKey), isFalse);
      expect(
        preferences.values[DeliveryAddressChoice.preferenceKey('other')],
        'a2',
      );
      expect(
        preferences.values[RecentSearches.preferenceKey('other')],
        '["x"]',
      );
      await finish(tester);
    });

    testWidgets('Готово leads to sign-in', (tester) async {
      await openCodeScreen(tester, size: phone);
      await submit(tester, '123456');
      await tester.tap(byKey('account-deleted-done'));
      await tester.pumpAndSettle();
      expect(location(tester), AppPaths.auth);
      await finish(tester);
    });

    testWidgets('system back leads to sign-in', (tester) async {
      await openCodeScreen(tester, size: phone);
      await submit(tester, '123456');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(location(tester), AppPaths.auth);
      await finish(tester);
    });

    testWidgets('the check circle scales and fades in', (tester) async {
      await openCodeScreen(tester, size: phone);
      await submit(tester, '123456');

      final Finder scale = find.ancestor(
        of: byKey('account-deleted-check'),
        matching: find.byType(ScaleTransition),
      );
      expect(scale, findsOneWidget);
      expect(tester.widget<ScaleTransition>(scale).scale.value, 1);
      await finish(tester);
    });

    testWidgets('with reduced motion the check only fades', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openCodeScreen(tester, size: phone);
      await submit(tester, '123456');

      expect(
        find.ancestor(
          of: byKey('account-deleted-check'),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      await finish(tester);
    });

    for (final double scale in <double>[1, 2]) {
      testWidgets('tap targets at x$scale', (tester) async {
        await openCodeScreen(
          tester,
          size: scale == 1 ? phone : const Size(360, 640),
          textScaler: scale == 1
              ? TextScaler.noScaling
              : NonlinearTextScaler(scale),
        );
        await submit(tester, '123456');

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await finish(tester);
      });
    }
  });

  group('large text at 320x640', () {
    const Size small = Size(320, 640);
    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      final String lang = device.languageCode;

      testWidgets('the confirm sheet ($lang)', (tester) async {
        await openSheet(tester, size: small, device: device, textScale: 2);

        expect(byKey('delete-account-sheet'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      });

      testWidgets('the code screen ($lang)', (tester) async {
        await openCodeScreen(tester, size: small, device: device, textScale: 2);

        expect(byKey('delete-account-screen'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      });

      testWidgets('the unfinished-order sheet ($lang)', (tester) async {
        deletion.requestFailures.add(unfinishedRefusal());
        await openCodeScreen(tester, size: small, device: device, textScale: 2);

        expect(byKey('delete-unfinished-sheet'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      });

      testWidgets('"Аккаунт удалён" ($lang)', (tester) async {
        await pumpApp(tester, size: small, device: device, textScale: 2);
        GoRouter.of(host(tester)).go(AppPaths.accountDeleted);
        await tester.pumpAndSettle();

        expect(byKey('account-deleted'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      });
    }
  });
}

/// A repository whose existence check waits until [checkHold] completes.
class _SlowCheck extends FakeAccountDeletionRepository {
  final Completer<void> checkHold = Completer<void>();

  @override
  Future<bool> stillExists() async {
    await checkHold.future;
    return super.stillExists();
  }
}
