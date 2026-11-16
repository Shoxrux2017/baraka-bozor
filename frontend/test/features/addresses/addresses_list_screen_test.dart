import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_harness.dart';
import '../../support/fake_address_map.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/in_memory_stores.dart';
import '../../support/nonlinear_text_scaler.dart';

/// «Мои адреса» in the kit (`DL-137`), opened through the profile as a
/// Customer does.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeAddressesRepository addresses;
  late InMemoryPreferenceStore preferences;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    addresses = FakeAddressesRepository();
    preferences = InMemoryPreferenceStore();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  /// The profile, with the first load of the addresses already answered as
  /// [addresses] is set up.
  Future<void> openProfile(
    WidgetTester tester, {
    Size size = const Size(400, 800),
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
        addresses: addresses,
        preferences: preferences,
        textScaler: textScaler,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profile),
          addressMapProvider.overrideWithValue(FakeAddressMap()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
  }

  /// The list, settled; a list that cannot settle (a skeleton pulses) is
  /// left after one frame.
  Future<void> openList(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    TextScaler? textScaler,
  }) async {
    await openProfile(tester, size: size, textScaler: textScaler);
    // The row may sit under the tab bar at large text: go the way it goes.
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).last))
          .push<void>(AppPaths.customerAddresses),
    );
    await tester.pumpAndSettle();
  }

  /// The list failed to load first: the kit block stands there.
  Future<void> openFailed(
    WidgetTester tester, {
    ApiFailure failure = const NetworkFailure(),
    Size size = const Size(400, 800),
    TextScaler? textScaler,
  }) async {
    addresses.loadFailure = failure;
    await openList(tester, size: size, textScaler: textScaler);
  }

  /// Retries from the failure block while the next load is held: the
  /// skeleton stands there.
  Future<void> retryHeld(WidgetTester tester) async {
    addresses.loadHold = Completer<void>();
    await tester.ensureVisible(byKey('addresses-retry'));
    await tester.pump();
    await tester.tap(byKey('addresses-retry'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> release(WidgetTester tester) async {
    addresses.loadHold!.complete();
    addresses.loadHold = null;
    await tester.pump();
    await tester.pump();
  }

  /// Records `HapticFeedback` calls of the platform channel.
  List<String> hapticsOf(WidgetTester tester) {
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

  double fadeOpacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(byKey('addresses-fade')).opacity.value;

  testWidgets('the list is the kit: white bar, cards, a full-width add '
      'button', (WidgetTester tester) async {
    await openList(tester);

    final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.backgroundColor, Colors.white);
    expect(bar.centerTitle, isTrue);
    expect(
      tester.getCenter(find.text('Мои адреса')).dx,
      closeTo(200, 1),
      reason: 'the title is centred',
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
      Colors.white,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(byKey('address-card-a-1'), findsOneWidget);
    final Size button = tester.getSize(byKey('address-new'));
    expect(button.height, 54);
    expect(button.width, 360, reason: 'the screen width less 20 each side');
    expect(find.text('Добавить адрес'), findsOneWidget);
  });

  testWidgets('loading shows three skeleton cards and the add button works', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await openFailed(tester);
    await retryHeld(tester);

    expect(byKey('address-skeleton'), findsNWidgets(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Загружаем адреса'), findsOneWidget);
    semantics.dispose();

    await tester.tap(byKey('address-new'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(byKey('address-point-confirm'), findsOneWidget);
  });

  testWidgets('opened while the list loads shows skeletons, not a spinner', (
    WidgetTester tester,
  ) async {
    addresses.loadHold = Completer<void>();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        device: const Locale('ru'),
        addresses: addresses,
        preferences: preferences,
        overrides: [profileRepositoryProvider.overrideWithValue(profile)],
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).last))
          .push<void>(AppPaths.customerAddresses),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(byKey('address-skeleton'), findsNWidgets(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the cards fade in where the skeleton stood', (
    WidgetTester tester,
  ) async {
    await openFailed(tester);
    await retryHeld(tester);
    await release(tester);
    await tester.pump();

    expect(byKey('address-skeleton'), findsNothing);
    expect(byKey('address-card-a-1'), findsOneWidget);
    expect(fadeOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 130));
    expect(fadeOpacity(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pump(const Duration(milliseconds: 130));
    expect(fadeOpacity(tester), 1);
  });

  testWidgets('with reduced motion the cards are there at once', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openFailed(tester);
    await retryHeld(tester);
    await release(tester);

    expect(byKey('address-card-a-1'), findsOneWidget);
    expect(fadeOpacity(tester), 1);
  });

  testWidgets('a failed load shows the kit block with a green retry', (
    WidgetTester tester,
  ) async {
    await openFailed(tester);

    expect(byKey('address-new'), findsOneWidget, reason: 'the footer');
    expect(find.text('Не удалось загрузить адреса'), findsOneWidget);
    expect(
      find.text('Проверьте интернет и нажмите «Повторить».'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final Finder retry = byKey('addresses-retry');
    final FilledButton button = tester.widget<FilledButton>(retry);
    expect(
      button.style!.backgroundColor!.resolve(<WidgetState>{}),
      KitColors.primary,
    );
    expect(
      find.descendant(of: retry, matching: find.byIcon(Icons.refresh)),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsOneWidget);

    addresses.loadFailure = const UnexpectedFailure();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(
      find.text('Попробуйте ещё раз: нажмите «Повторить».'),
      findsOneWidget,
    );

    await retryHeld(tester);
    expect(byKey('address-skeleton'), findsNWidgets(3));
    await release(tester);
    await tester.pumpAndSettle();
    expect(byKey('address-card-a-1'), findsOneWidget);
    expect(find.text('Не удалось загрузить адреса'), findsNothing);
  });

  testWidgets('a reload that fails keeps the cards', (
    WidgetTester tester,
  ) async {
    await openList(tester);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).last),
    );

    addresses.loadFailure = const NetworkFailure();
    container.invalidate(addressesProvider);
    await tester.pumpAndSettle();

    expect(byKey('address-card-a-1'), findsOneWidget);
    expect(find.text('Не удалось загрузить адреса'), findsNothing);
  });

  testWidgets('no addresses: a pin, why, one add button', (
    WidgetTester tester,
  ) async {
    addresses.rows = <Address>[];
    await openList(tester);

    expect(find.text('Адресов пока нет'), findsOneWidget);
    expect(
      find.text(
        'Добавьте адрес — курьер привезёт заказ туда. Точку отметите на '
        'карте.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(byKey('address-new'), findsOneWidget);
    expect(byKey('addresses-footer'), findsNothing);
    expect(find.text('Добавить адрес'), findsOneWidget);
  });

  testWidgets('opened from the profile the list shows at once', (
    WidgetTester tester,
  ) async {
    await openProfile(tester);
    await tester.tap(byKey('profile-addresses'));
    // The route is resolved a frame or two after the tap; the screen's first
    // frame already has its cards.
    for (int i = 0; i < 5 && byKey('addresses-fade').evaluate().isEmpty; i++) {
      expect(byKey('address-skeleton'), findsNothing);
      await tester.pump();
    }

    expect(byKey('addresses-fade'), findsOneWidget);
    expect(byKey('address-card-a-1'), findsOneWidget);
    expect(byKey('address-skeleton'), findsNothing);
  });

  testWidgets('Доставлять сюда moves the mark with a light tap', (
    WidgetTester tester,
  ) async {
    addresses.rows = <Address>[
      address(),
      address(id: 'a-2', label: 'Мама', street: 'Bobur', house: '7'),
    ];
    await openList(tester);
    final List<String> haptics = hapticsOf(tester);
    tester.takeAnnouncements();

    expect(
      find.descendant(
        of: byKey('address-surface-a-1'),
        matching: find.text('Доставка сюда'),
      ),
      findsOneWidget,
    );
    await tester.tap(byKey('address-menu-a-2'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('address-choose-a-2'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: byKey('address-surface-a-2'),
        matching: find.text('Доставка сюда'),
      ),
      findsOneWidget,
    );
    expect(haptics, <String>['HapticFeedbackType.lightImpact']);
    expect(
      tester.takeAnnouncements().map((a) => a.message),
      contains('Доставка: «Мама»'),
    );
    expect(preferences.values[DeliveryAddressChoice.preferenceKey('c')], 'a-2');
  });

  testWidgets('tapping a card opens its edit', (WidgetTester tester) async {
    await openList(tester);

    await tester.tap(byKey('address-card-a-1'));
    await tester.pumpAndSettle();

    expect(byKey('address-save'), findsOneWidget);
  });

  group('every face fits at large text and meets the tap target guideline', () {
    const Size phone = Size(360, 640);
    const TextScaler large = NonlinearTextScaler(2);

    Future<void> check(WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    }

    testWidgets('loaded', (WidgetTester tester) async {
      addresses.rows = <Address>[
        address(
          label: 'Ota-onamning uyi, Chilonzor tumani',
          landmark: 'Maktab',
        ),
        address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
      ];
      await openList(tester, size: phone, textScaler: large);
      expect(byKey('address-card-a-1'), findsOneWidget);
      await check(tester);
    });

    testWidgets('loading', (WidgetTester tester) async {
      await openFailed(tester, size: phone, textScaler: large);
      await retryHeld(tester);
      expect(byKey('address-skeleton'), findsWidgets);
      await check(tester);
    });

    testWidgets('failed', (WidgetTester tester) async {
      await openFailed(tester, size: phone, textScaler: large);
      expect(byKey('addresses-retry'), findsOneWidget);
      await check(tester);
    });

    testWidgets('empty', (WidgetTester tester) async {
      addresses.rows = <Address>[];
      await openList(tester, size: phone, textScaler: large);
      expect(byKey('address-new'), findsOneWidget);
      await check(tester);
    });
  });
}
