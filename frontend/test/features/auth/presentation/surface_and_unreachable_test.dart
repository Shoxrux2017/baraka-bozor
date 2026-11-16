import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/kit/quiet_icon.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository repository;

  final Finder wrongSurfaceText = find.byKey(
    const ValueKey<String>('wrong-surface-text'),
  );
  final Finder logoutButton = find.byKey(
    const ValueKey<String>('logout-button'),
  );
  final Finder signInButton = find.byKey(
    const ValueKey<String>('wrong-surface-button'),
  );
  final Finder retryButton = find.byKey(const ValueKey<String>('retry-button'));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    repository = FakeAuthRepository();
  });

  Future<void> openApp(WidgetTester tester, Surface surface) async {
    await tester.pumpWidget(
      appUnderTest(tokens: tokens, repository: repository, surface: surface),
    );
    await tester.pumpAndSettle();
  }

  group('the wrong surface (docs/02 section 10, DL-136)', () {
    Finder quiet(IconData icon) =>
        find.byWidgetPredicate((Widget w) => w is QuietIcon && w.icon == icon);

    Future<void> openRu(
      WidgetTester tester,
      Surface surface, {
      TextScaler? textScaler,
      Size size = const Size(360, 640),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // A fresh app each time, so the session is read again.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        appUnderTest(
          tokens: tokens,
          repository: repository,
          surface: surface,
          device: const Locale('ru'),
          textScaler: textScaler,
        ),
      );
      await tester.pumpAndSettle();
    }

    String bodyText(WidgetTester tester) =>
        tester.widget<Text>(wrongSurfaceText).data!;

    testWidgets('an Operator on a phone is told who and where', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(
        role: UserRole.operator,
        fullName: 'Азиз Каримов',
      );

      await openRu(tester, Surface.mobile);

      expect(find.text('Откройте панель на компьютере'), findsOneWidget);
      expect(
        bodyText(tester),
        'Вы вошли как оператор — Азиз Каримов. Оператор работает в панели '
        'управления, в браузере на компьютере.',
      );
      expect(
        find.text(
          'На этом телефоне можно делать покупки — войдите как покупатель с '
          'тем же номером.',
        ),
        findsOneWidget,
      );
      expect(quiet(Icons.computer), findsOneWidget);
      expect(find.text('Войти как покупатель'), findsOneWidget);
      expect(logoutButton, findsNothing);
    });

    testWidgets('an Admin, a Manager and a nameless Operator get their words', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.admin);
      await openRu(tester, Surface.mobile);
      expect(
        bodyText(tester),
        'Вы вошли как администратор — Aziza Karimova. Администратор работает '
        'в панели управления, в браузере на компьютере.',
      );

      repository.identities[SessionSlot.staff] = user(role: UserRole.manager);
      await openRu(tester, Surface.mobile);
      expect(bodyText(tester), startsWith('Вы вошли как менеджер — '));
      expect(bodyText(tester), contains('. Менеджер работает в панели'));

      repository.identities[SessionSlot.staff] = user(
        role: UserRole.operator,
        fullName: ' ',
      );
      await openRu(tester, Surface.mobile);
      expect(
        bodyText(tester),
        'Вы вошли как оператор. Оператор работает в панели управления, в '
        'браузере на компьютере.',
      );
    });

    testWidgets('Войти как покупатель ends the staff session and opens the '
        'sign-in', (WidgetTester tester) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(role: UserRole.operator);
      await openRu(tester, Surface.mobile);

      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(tokens.tokens, isEmpty);
      expect(find.byKey(const ValueKey<String>('phone-field')), findsOneWidget);
    });

    testWidgets('with a Customer session on the phone it opens the shop', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.staff] = user(role: UserRole.operator);
      repository.identities[SessionSlot.customer] = user(id: 'c');
      await openRu(tester, Surface.mobile);
      expect(signInButton, findsOneWidget);

      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(tokens.tokens.containsKey(SessionSlot.staff), isFalse);
      expect(tokens.tokens[SessionSlot.customer], 'c');
      expect(signInButton, findsNothing);
      expect(find.byKey(const ValueKey<String>('phone-field')), findsNothing);
    });

    testWidgets('a Shopper in a browser is told to open the phone app', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.staff] = 's';
      repository.identities[SessionSlot.staff] = user(
        role: UserRole.shopper,
        fullName: 'Азиз Каримов',
      );

      await openRu(tester, Surface.web, size: const Size(900, 700));

      expect(find.text('Откройте приложение на телефоне'), findsOneWidget);
      expect(
        bodyText(tester),
        'Вы вошли как сборщик — Азиз Каримов. Сборщик работает в приложении '
        'BarakaBozor на телефоне.',
      );
      expect(quiet(Icons.smartphone), findsOneWidget);
      expect(find.text('Войти другим аккаунтом'), findsOneWidget);
      expect(
        find.text(
          'На этом телефоне можно делать покупки — войдите как покупатель с '
          'тем же номером.',
        ),
        findsNothing,
      );

      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(tokens.tokens, isEmpty);
      expect(
        find.byKey(const ValueKey<String>('password-field')),
        findsOneWidget,
      );
    });

    testWidgets('a Customer in a browser gets the покупатель sentence', (
      WidgetTester tester,
    ) async {
      tokens.tokens[SessionSlot.customer] = 'c';
      repository.identities[SessionSlot.customer] = user();

      await openRu(tester, Surface.web, size: const Size(900, 700));

      expect(
        bodyText(tester),
        'Вы вошли как покупатель — Aziza Karimova. Покупатель делает заказы '
        'в приложении BarakaBozor на телефоне.',
      );
    });

    for (final Surface surface in Surface.values) {
      testWidgets('${surface.name}: the guideline holds at 100 % and at text '
          'x2, with no overflow', (WidgetTester tester) async {
        tokens.tokens[SessionSlot.staff] = 's';
        repository.identities[SessionSlot.staff] = user(
          role: surface == Surface.mobile ? UserRole.admin : UserRole.courier,
        );
        final SemanticsHandle handle = tester.ensureSemantics();
        final Size size = surface == Surface.mobile
            ? const Size(360, 640)
            : const Size(900, 700);

        await openRu(tester, surface, size: size);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await openRu(
          tester,
          surface,
          size: size,
          textScaler: NonlinearTextScaler(2),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('an unreachable server', () {
    testWidgets(
      'keeps the token, offers a retry, and opens the shell once the server answers',
      (WidgetTester tester) async {
        tokens.tokens[SessionSlot.staff] = 's';
        repository.identities[SessionSlot.staff] = const NetworkFailure();

        await openApp(tester, Surface.mobile);

        expect(find.text(l10n(tester).unreachableOfflineTitle), findsOneWidget);
        expect(tokens.tokens[SessionSlot.staff], 's');

        await tester.tap(retryButton);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n(tester).unreachableOfflineTitle),
          findsOneWidget,
          reason: 'still unreachable',
        );

        repository.identities[SessionSlot.staff] = user(role: UserRole.courier);
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        expect(find.text(l10n(tester).myDeliveries), findsOneWidget);
      },
    );
  });
}
