import 'dart:async';

import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/cart/presentation/cart_screen.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/active_mode_bar.dart';
import 'package:baraka_bozor/features/profile/presentation/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_repositories.dart';
import '../../../support/fake_legal_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';

void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeLegalRepository legal;
  late FakePhoneCalls calls;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  const List<String> allRows = <String>[
    'profile-addresses',
    'profile-language',
    'profile-support',
    'profile-privacy',
    'profile-terms',
    'profile-delete',
  ];

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    legal = FakeLegalRepository();
    calls = FakePhoneCalls();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  CustomerProfile named(String name, {String? support = '+998712000000'}) =>
      CustomerProfile(
        id: 'c',
        phone: '+998901234567',
        fullName: name,
        supportPhone: support,
      );

  Future<void> openProfile(
    WidgetTester tester, {
    Size size = const Size(800, 2000),
    Locale device = const Locale('ru'),
    double textScale = 1,
    bool staff = false,
    bool settle = true,
    TextScaler? textScaler,
    FakeCartRepository? cart,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (staff) {
      tokens.tokens[SessionSlot.staff] = 's';
      auth.identities[SessionSlot.staff] = user(
        id: 's',
        role: UserRole.courier,
      );
    }
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: device,
        legal: legal,
        phoneCalls: calls,
        cart: cart,
        textScaler: textScaler,
        overrides: [profileRepositoryProvider.overrideWithValue(profile)],
      ),
    );
    await tester.pumpAndSettle();
    if (staff) {
      await tester.tap(byKey('staff-menu'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('switch-to-customer-button'));
      await tester.pumpAndSettle();
    }
    await tester.tap(byKey('open-profile'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A skeleton pulses for ever, so it never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('the profile tab', () {
    testWidgets('a named Customer sees the header and the six rows', (
      tester,
    ) async {
      profile.current = named('Дилноза Каримова');
      legal.publishBoth();
      await openProfile(tester);

      expect(find.text('ДК'), findsOneWidget);
      expect(find.text('Дилноза Каримова'), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('+998 71 200 00 00'), findsOneWidget);
      double previous = -1;
      for (final String key in allRows) {
        final double top = tester.getTopLeft(byKey(key)).dy;
        expect(top, greaterThan(previous), reason: key);
        previous = top;
      }
      expect(byKey('logout-button'), findsOneWidget);
    });

    testWidgets('no name and no support phone is drawing 32a', (tester) async {
      await openProfile(tester);

      expect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.byIcon(Icons.person),
        ),
        findsOneWidget,
      );
      expect(find.text('Как вас зовут?'), findsOneWidget);
      expect(find.text('Указать имя'), findsOneWidget);
      expect(byKey('profile-support'), findsNothing);
    });

    testWidgets(
      'the header has a white cart button with its count, which opens the cart',
      (tester) async {
        profile.current = named('Дилноза Каримова');
        await openProfile(
          tester,
          size: const Size(400, 900),
          cart: FakeCartRepository(
            cart: cartOf(<Map<String, Object?>>[
              cartLineJson(),
              cartLineJson(
                id: breadLine,
                productId: breadProduct,
                unit: 'piece',
              ),
            ]),
          ),
        );

        final Finder header = find.byType(ProfileHeader);
        expect(
          find.descendant(of: header, matching: byKey('open-cart')),
          findsOneWidget,
        );
        expect(tester.getSize(byKey('open-cart')), const Size(44, 44));
        expect(
          400 - tester.getTopRight(byKey('open-cart')).dx,
          10,
          reason: '10 px from the edge, as drawn',
        );
        expect(tester.widget<Text>(byKey('cart-count')).data, '2');
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: byKey('open-cart'),
                  matching: find.byIcon(Icons.shopping_bag_outlined),
                ),
              )
              .color,
          Colors.white,
        );
        expect(
          tester
              .getCenter(
                find.descendant(of: header, matching: find.text('Профиль')),
              )
              .dx,
          closeTo(200, 1),
          reason: 'the title stays centred',
        );

        await tester.tap(byKey('open-cart'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileHeader), findsNothing);
        expect(find.byType(CartScreen), findsOneWidget);
      },
    );

    testWidgets('the header keeps its height', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, size: const Size(400, 900));

      expect(tester.getSize(find.byType(ProfileHeader)).height, 152);
    });

    testWidgets('every target meets iOSTapTargetGuideline', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      profile.current = named('Дилноза Каримова');
      legal.publishBoth();
      await openProfile(tester, size: const Size(400, 900));

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the language row value follows the language', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, device: const Locale('uz'));

      expect(find.text("O'zbekcha"), findsOneWidget);
      expect(find.text('Til'), findsOneWidget);
    });

    testWidgets('values and chevrons sit on the right edge on a phone', (
      tester,
    ) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, size: const Size(360, 2000));

      double chevronRight(String row) => tester
          .getTopRight(
            find.descendant(
              of: byKey(row),
              matching: find.byIcon(Icons.chevron_right),
            ),
          )
          .dx;
      expect(
        chevronRight('profile-language'),
        chevronRight('profile-addresses'),
      );
      expect(
        tester.getTopRight(find.text('+998 71 200 00 00')).dx,
        tester.getTopRight(byKey('profile-support')).dx,
      );
    });

    testWidgets('test_the_legal_rows_follow_the_documents', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);
      expect(byKey('profile-privacy'), findsNothing);
      expect(byKey('profile-terms'), findsNothing);
    });

    testWidgets('only the published document has its row', (tester) async {
      profile.current = named('Дилноза Каримова');
      legal.publishOnly(LegalDocumentKind.privacy);
      await openProfile(tester);
      expect(find.text('Конфиденциальность'), findsOneWidget);
      expect(byKey('profile-terms'), findsNothing);
    });

    testWidgets('a failed index shows neither document row', (tester) async {
      profile.current = named('Дилноза Каримова');
      legal.indexFailure = const NetworkFailure();
      await openProfile(tester);
      expect(byKey('profile-privacy'), findsNothing);
      expect(byKey('profile-terms'), findsNothing);
    });

    testWidgets('a document row opens its document', (tester) async {
      profile.current = named('Дилноза Каримова');
      legal.publishBoth();
      await openProfile(tester);

      await tester.tap(byKey('profile-terms'));
      await tester.pumpAndSettle();
      expect(byKey('legal-screen'), findsOneWidget);
      expect(legal.documentCalls.last, (
        LegalDocumentKind.terms,
        AppLanguage.ru,
      ));
    });

    testWidgets('a support tap calls the number once', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-support'));
      await tester.pumpAndSettle();
      expect(calls.calls, <String>['+998712000000']);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed dial shows the number', (tester) async {
      profile.current = named('Дилноза Каримова');
      calls.opens = false;
      await openProfile(tester);

      await tester.tap(byKey('profile-support'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('+998 71 200 00 00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('test_a_staff_session_has_no_delete_row', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, staff: true);
      expect(byKey('profile-addresses'), findsOneWidget);
      expect(byKey('profile-delete'), findsNothing);
    });

    testWidgets('a Customer alone opens the delete sheet', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-delete'));
      await tester.pumpAndSettle();
      expect(byKey('delete-account-sheet'), findsOneWidget);
    });

    testWidgets("choosing O'zbekcha closes the sheet and reads Til", (
      tester,
    ) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-language'));
      await tester.pumpAndSettle();
      expect(byKey('language-sheet'), findsOneWidget);
      await tester.tap(byKey('language-uz'));
      await tester.pumpAndSettle();

      expect(byKey('language-sheet'), findsNothing);
      expect(find.text('Til'), findsOneWidget);
      expect(auth.calls, contains('language:customer:uz'));
    });

    testWidgets('the logout button signs the Customer out', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('logout-button'));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('logout:customer'));
      expect(byKey('profile-list'), findsNothing);
    });

    testWidgets('a failed profile keeps the retry, the language and logout', (
      tester,
    ) async {
      profile.loadFailure = const NetworkFailure();
      await openProfile(tester);

      expect(byKey('profile-language'), findsOneWidget);
      expect(byKey('logout-button'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets(
      'while the profile loads the rows stand and the header holds a skeleton',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        profile.current = named('Дилноза Каримова');
        profile.hold = Completer<void>();
        await openProfile(tester, settle: false);

        expect(byKey('profile-addresses'), findsOneWidget);
        expect(byKey('profile-language'), findsOneWidget);
        expect(byKey('logout-button'), findsOneWidget);
        expect(byKey('profile-header-skeleton'), findsOneWidget);
        expect(
          tester.getSemantics(byKey('profile-header-skeleton')).label,
          'Загружаем профиль',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        profile.hold!.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 130));
        final double opacity = _opacityOf(tester, byKey('profile-name'));
        expect(opacity, greaterThan(0.3));
        expect(opacity, lessThan(0.7));
        await tester.pumpAndSettle();
        expect(find.text('Дилноза Каримова'), findsOneWidget);
        expect(_opacityOf(tester, byKey('profile-name')), 1);
        handle.dispose();
      },
    );

    testWidgets(
      'offline the header says it could not load and offers a retry',
      (tester) async {
        profile.current = named('Дилноза Каримова');
        profile.loadFailure = const NetworkFailure();
        await openProfile(tester);

        expect(find.text('Не удалось загрузить профиль'), findsOneWidget);
        expect(
          find.text('Нет связи. Адреса, язык и выход работают.'),
          findsOneWidget,
        );
        expect(byKey('profile-addresses'), findsOneWidget);
        expect(byKey('profile-language'), findsOneWidget);
        expect(byKey('logout-button'), findsOneWidget);

        await tester.tap(byKey('profile-header-retry'));
        await tester.pumpAndSettle();
        expect(byKey('profile-header-failure'), findsNothing);
        expect(find.text('Дилноза Каримова'), findsOneWidget);
      },
    );

    testWidgets('another failure leaves out the connection', (tester) async {
      profile.loadFailure = const UnexpectedFailure();
      await openProfile(tester);

      expect(find.text('Адреса, язык и выход работают.'), findsOneWidget);
      expect(find.textContaining('Нет связи'), findsNothing);
    });

    testWidgets('a reader meets the header as one button', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      final SemanticsNode node = tester.getSemantics(byKey('profile-identity'));
      expect(node.label, 'Дилноза Каримова, +998 90 123 45 67. Изменить имя');
      expect(node.flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel('ДК'), findsNothing);
      handle.dispose();
    });

    testWidgets('a reader meets an unnamed header as one button', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openProfile(tester);

      final SemanticsNode node = tester.getSemantics(byKey('profile-identity'));
      expect(node.label, 'Имя не указано, +998 90 123 45 67. Указать имя');
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('the header opens the name editor', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      expect(byKey('profile-edit'), findsNothing);
      expect(
        find.descendant(
          of: byKey('profile-identity'),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
      await tester.tap(byKey('profile-identity'));
      await tester.pumpAndSettle();
      expect(byKey('edit-profile'), findsOneWidget);
    });

    testWidgets('without a name the header asks and offers a pill', (
      tester,
    ) async {
      await openProfile(tester);

      expect(find.text('Как вас зовут?'), findsOneWidget);
      expect(find.text('Указать имя'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey('profile-identity'),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
        reason: 'only the pill has a chevron',
      );
      await tester.tap(byKey('profile-identity'));
      await tester.pumpAndSettle();
      expect(byKey('edit-profile'), findsOneWidget);
    });

    testWidgets('the header is dark green with a 15 px phone', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ProfileHeader),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, KitColors.primaryDark);
      expect(
        tester.widget<ColoredBox>(byKey('profile-status-band')).color,
        KitColors.primaryDark,
      );
      expect(tester.widget<Text>(byKey('profile-phone')).style?.fontSize, 15);
    });

    testWidgets('two sessions put the mode pill in the header', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester, staff: true);

      expect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: byKey('active-mode'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ActiveModeBar), findsNothing);
      final DecoratedBox pill = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: byKey('active-mode'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((pill.decoration as BoxDecoration).color, KitColors.headerPill);
    });

    testWidgets('a saved name rises and the header flashes', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-identity'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(byKey('edit-profile'))).pop(true);
      await tester.pump();
      await tester.pump();

      expect(_flashColor(tester), KitColors.headerFlash);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(_flashColor(tester).a, 0);
    });

    testWidgets('a closed editor does not flash the header', (tester) async {
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-identity'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(byKey('edit-profile'))).pop();
      await tester.pump();
      await tester.pump();
      expect(_flashColor(tester).a, 0);
    });

    testWidgets('with reduced motion a saved name does not flash', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      profile.current = named('Дилноза Каримова');
      await openProfile(tester);

      await tester.tap(byKey('profile-identity'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(byKey('edit-profile'))).pop(true);
      await tester.pump();
      await tester.pump();
      expect(_flashColor(tester).a, 0);
      expect(_opacityOf(tester, byKey('profile-name')), 1);
    });

    testWidgets('at large text the name and phone wrap', (tester) async {
      profile.current = named('Ж' * 40);
      await openProfile(
        tester,
        size: const Size(360, 640),
        textScaler: const NonlinearTextScaler(2),
      );

      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(byKey('profile-name')).maxLines, isNull);
      expect(tester.widget<Text>(byKey('profile-phone')).maxLines, isNull);
      expect(tester.getSize(byKey('profile-name')).height, greaterThan(60));
    });

    testWidgets('at 100 % the name and phone keep one line', (tester) async {
      profile.current = named('Ж' * 40);
      await openProfile(tester, size: const Size(360, 640));

      expect(tester.widget<Text>(byKey('profile-name')).maxLines, 1);
      expect(tester.widget<Text>(byKey('profile-phone')).maxLines, 1);
    });

    for (final (String, double?) scale in <(String, double?)>[
      ('100 %', null),
      ('200 %', 2),
    ]) {
      for (final String face in <String>[
        'loaded',
        'loading',
        'failed',
        'unnamed',
        'two sessions',
      ]) {
        testWidgets('the $face profile meets the tap targets at ${scale.$1}', (
          tester,
        ) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          if (face != 'unnamed') {
            profile.current = named('Дилноза Каримова');
          }
          if (face == 'loading') {
            profile.hold = Completer<void>();
          }
          if (face == 'failed') {
            profile.loadFailure = const NetworkFailure();
          }
          legal.publishBoth();
          await openProfile(
            tester,
            size: const Size(360, 640),
            staff: face == 'two sessions',
            settle: face != 'loading',
            textScaler: scale.$2 == null
                ? null
                : NonlinearTextScaler(scale.$2!),
          );

          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          handle.dispose();
        });
      }
    }

    for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'test_the_profile_holds_at_the_extremes in ${locale.languageCode}',
        (tester) async {
          profile.current = named('Ж' * 120);
          legal.publishBoth();
          await openProfile(
            tester,
            size: const Size(320, 640),
            device: locale,
            textScale: 2,
          );
          expect(tester.takeException(), isNull);

          await tester.drag(byKey('profile-list'), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(byKey('profile-language'));
          await tester.pumpAndSettle();
          expect(byKey('language-sheet'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

/// The product of every opacity above [finder] — what the eye sees.
double _opacityOf(WidgetTester tester, Finder finder) {
  double product = 1;
  final Iterable<Element> above = find
      .ancestor(
        of: finder,
        matching: find.byWidgetPredicate(
          (Widget w) => w is Opacity || w is FadeTransition,
        ),
      )
      .evaluate();
  for (final Element element in above) {
    final Widget w = element.widget;
    product *= w is Opacity ? w.opacity : (w as FadeTransition).opacity.value;
  }
  return product;
}

/// The colour of the identity button's flash layer.
Color _flashColor(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey<String>('profile-identity-flash')),
  );
  return (box.decoration as BoxDecoration).color ?? Colors.transparent;
}
