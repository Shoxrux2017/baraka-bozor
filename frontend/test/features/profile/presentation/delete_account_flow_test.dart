import 'dart:async';

import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/catalog/application/recent_searches.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/presentation/delete_account_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_account_deletion_repository.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';

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
        overrides: [
          accountDeletionRepositoryProvider.overrideWithValue(deletion),
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
  }) async {
    await pumpApp(tester, size: size, device: device, textScale: textScale);
    unawaited(showDeleteAccountSheet(host(tester)));
    await tester.pumpAndSettle();
  }

  Future<void> openCodeScreen(
    WidgetTester tester, {
    Size size = const Size(800, 1200),
    Locale device = const Locale('ru'),
    double textScale = 1,
  }) async {
    await openSheet(tester, size: size, device: device, textScale: textScale);
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

  group('the confirm sheet (36)', () {
    testWidgets('lists what is erased and kept, and the note', (tester) async {
      await openSheet(tester);

      expect(byKey('delete-account-sheet'), findsOneWidget);
      expect(find.text('Удалить аккаунт?'), findsOneWidget);
      expect(find.text('Имя и номер телефона'), findsOneWidget);
      expect(find.text('Адреса'), findsOneWidget);
      expect(find.text('Избранное и корзину'), findsOneWidget);
      expect(
        find.text('История заказов — без имени и телефона, для учёта'),
        findsOneWidget,
      );
      expect(find.textContaining('Вернуть аккаунт нельзя.'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Отмена sends nothing', (tester) async {
      await openSheet(tester);

      await tester.tap(byKey('delete-cancel'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsNothing);
      expect(deletion.requests, 0);
      await finish(tester);
    });

    testWidgets('test_two_quick_taps_request_one_code', (tester) async {
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

    testWidgets('a sent code opens the code screen with the phone', (
      tester,
    ) async {
      await openCodeScreen(tester);

      expect(byKey('delete-account-sheet'), findsNothing);
      expect(byKey('delete-account-screen'), findsOneWidget);
      expect(location(tester), AppPaths.customerDeleteAccount);
      expect(find.textContaining('+998 90 123 45 67'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('another failure shows its text above the buttons', (
      tester,
    ) async {
      deletion.requestFailures.add(wrongCodeRefusal());
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsOneWidget);
      expect(find.text(l10n(tester).errorCodeInvalid), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a 409 at the request opens the unfinished-order sheet and '
        '"К заказу" opens that order', (tester) async {
      deletion.requestFailures.add(unfinishedRefusal());
      await openSheet(tester);

      await tester.tap(byKey('delete-confirm'));
      await tester.pumpAndSettle();

      expect(byKey('delete-account-sheet'), findsNothing);
      expect(byKey('delete-unfinished-sheet'), findsOneWidget);
      expect(find.textContaining('Заказ № 1021'), findsOneWidget);

      await tester.tap(find.text('К заказу'));
      await tester.pumpAndSettle();

      expect(byKey('delete-unfinished-sheet'), findsNothing);
      expect(location(tester), AppPaths.customerOrder('o-1'));
      await finish(tester);
    });
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

    testWidgets('three wrong codes show the lock line and disable the button', (
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

      expect(byKey('lock-message'), findsOneWidget);
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
      expect(find.textContaining('Заказ № 1055'), findsOneWidget);

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
      expect(preferences.values[searchesKey], '[]');

      await tester.tap(byKey('account-deleted-done'));
      await tester.pumpAndSettle();

      expect(byKey('continue-button'), findsOneWidget);
      expect(location(tester), AppPaths.auth);
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
