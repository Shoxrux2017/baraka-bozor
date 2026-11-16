import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/addresses/application/address_removals.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/presentation/addresses_screens.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  group('removal', () {
    Address home() => address(id: 'a-home', label: 'Дом');
    Address mama() => address(id: 'a-mama', label: 'Мама', street: 'Bobur');
    Address work() => address(id: 'a-work', label: 'Работа', street: 'Navoiy');

    /// The menu's «Удалить» of [id], tapped; the first frame of its effect is
    /// pumped.
    Future<void> removeVia(WidgetTester tester, String id) async {
      await tester.tap(byKey('address-menu-$id'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('address-delete-$id'));
      await tester.pump();
    }

    /// Past the fold (its clock starts at the first frame after the tap) and
    /// the bar's coming in.
    Future<void> folded(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> drag(WidgetTester tester, String id, double dx) async {
      await tester.drag(byKey('address-card-$id'), Offset(dx, 0));
      await tester.pumpAndSettle();
    }

    double surfaceLeft(WidgetTester tester, String id) =>
        tester.getTopLeft(byKey('address-surface-$id')).dx;

    /// Frames of 200 ms, so that animations that start on a frame run through.
    Future<void> frames(WidgetTester tester, int count) async {
      for (int i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    List<String> spoken(WidgetTester tester) =>
        tester.takeAnnouncements().map((a) => a.message).toList();

    testWidgets('removing folds the card and offers Вернуть for 5 s', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[home(), work()];
      await openList(tester);

      await removeVia(tester, 'a-work');
      expect(addresses.removed, isEmpty);
      await folded(tester);

      expect(byKey('address-card-a-work'), findsNothing);
      expect(find.text('Удалили «Работа».'), findsOneWidget);
      expect(find.text('Вернуть'), findsOneWidget);
      expect(find.text('Удалить этот адрес?'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(addresses.removed, isEmpty, reason: 'the bar is still up');

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(addresses.removed, <String>['a-work']);
    });

    testWidgets('removing the last address folds it, then shows the empty '
        'state', (WidgetTester tester) async {
      addresses.rows = <Address>[work()];
      await openList(tester);

      await removeVia(tester, 'a-work');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Адресов пока нет'), findsNothing, reason: 'folding');
      expect(byKey('address-card-a-work'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(byKey('address-card-a-work'), findsNothing);
      expect(find.text('Адресов пока нет'), findsOneWidget);
      expect(find.text('Удалили «Работа».'), findsOneWidget);
    });

    testWidgets('Вернуть brings the card back, glowing, and sends nothing', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[home(), work()];
      await openList(tester);
      await removeVia(tester, 'a-work');
      await folded(tester);
      tester.takeAnnouncements();

      await tester.tap(find.text('Вернуть'));
      await tester.pump();
      expect(spoken(tester), contains('Адрес «Работа» возвращён'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(byKey('address-card-a-work'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.widget<Opacity>(byKey('address-glow-a-work')).opacity,
        greaterThan(0),
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(addresses.removed, isEmpty);
    });

    testWidgets('removing the delivery address says where delivery goes now', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[home(), mama()];
      await openList(tester);
      tester.takeAnnouncements();

      await removeVia(tester, 'a-home');
      await folded(tester);

      expect(
        find.text('Удалили «Дом». Доставка теперь: «Мама».'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('address-surface-a-mama'),
          matching: find.text('Доставка сюда'),
        ),
        findsOneWidget,
      );
      expect(
        spoken(tester),
        contains(
          'Адрес «Дом» удалён. Доставка теперь: «Мама». '
          'Вернуть — кнопка внизу.',
        ),
      );
    });

    testWidgets('the delivery address removed while the list reloads still '
        'says where delivery goes', (WidgetTester tester) async {
      addresses.rows = <Address>[home(), mama(), work()];
      await openList(tester);
      await removeVia(tester, 'a-work');
      await folded(tester);
      addresses.loadHold = Completer<void>();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      expect(addresses.removed, <String>['a-work']);

      await removeVia(tester, 'a-home');
      await folded(tester);

      expect(
        find.text('Удалили «Дом». Доставка теперь: «Мама».'),
        findsOneWidget,
      );
      addresses.loadHold!.complete();
      addresses.loadHold = null;
      await tester.pump();
    });

    testWidgets('the bar stands above the add button, which still opens the '
        'form', (WidgetTester tester) async {
      addresses.rows = <Address>[home(), work()];
      await openList(tester, size: const Size(360, 640));
      await removeVia(tester, 'a-work');
      await folded(tester);

      final Rect bar = tester.getRect(find.byType(SnackBar));
      final Rect footer = tester.getRect(byKey('addresses-footer'));
      expect(bar.bottom, lessThanOrEqualTo(footer.top));

      await tester.tap(byKey('address-new'));
      await tester.pumpAndSettle();
      expect(find.byType(AddressFormScreen), findsOneWidget);
    });

    testWidgets('a card that glowed once does not glow again when the cards '
        'are rebuilt', (WidgetTester tester) async {
      addresses.rows = <Address>[home()];
      await openList(tester);
      await removeVia(tester, 'a-home');
      await folded(tester);
      await tester.tap(find.text('Вернуть'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester.widget<Opacity>(byKey('address-glow-a-home')).opacity,
        greaterThan(0),
      );
      await tester.pump(const Duration(seconds: 3));

      addresses.removeFailure = const NetworkFailure();
      await removeVia(tester, 'a-home');
      await folded(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(byKey('address-card-a-home'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.widget<Opacity>(byKey('address-glow-a-home')).opacity, 0);
    });

    testWidgets('offline the card returns and says it was not removed', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[home(), work()];
      addresses.removeFailure = const NetworkFailure();
      await openList(tester);
      await removeVia(tester, 'a-work');
      await folded(tester);
      tester.takeAnnouncements();

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(addresses.removed, <String>['a-work']);
      expect(byKey('address-card-a-work'), findsOneWidget);
      expect(find.text('Нет связи — адрес не удалён'), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('address-card-a-work')).dy,
        greaterThan(tester.getTopLeft(byKey('address-card-a-home')).dy),
        reason: 'at its place',
      );
      expect(spoken(tester), contains('Нет связи, адрес «Работа» не удалён'));
    });

    testWidgets('a reload that fails after an earlier removal keeps the cards '
        'and the returning one says why', (WidgetTester tester) async {
      addresses.rows = <Address>[home(), mama(), work()];
      await openList(tester);
      await removeVia(tester, 'a-work');
      await folded(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      expect(addresses.removed, <String>['a-work']);

      await removeVia(tester, 'a-mama');
      await folded(tester);
      addresses.removeFailure = const NetworkFailure();
      addresses.loadFailure = const NetworkFailure();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Не удалось загрузить адреса'), findsNothing);
      expect(byKey('address-card-a-home'), findsOneWidget);
      expect(byKey('address-card-a-mama'), findsOneWidget);
      expect(find.text('Нет связи — адрес не удалён'), findsOneWidget);
    });

    testWidgets('a long swipe removes, a medium one reveals Удалить', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[home(), mama(), work()];
      await openList(tester);

      await drag(tester, 'a-work', -150);
      expect(surfaceLeft(tester, 'a-work'), closeTo(20 - 88, 1));
      expect(byKey('address-reveal-a-work'), findsOneWidget);
      expect(addresses.removed, isEmpty);

      await tester.tap(byKey('address-reveal-a-work'));
      await tester.pump();
      await folded(tester);
      expect(byKey('address-card-a-work'), findsNothing);
      expect(find.text('Удалили «Работа».'), findsOneWidget);

      await tester.drag(byKey('address-card-a-mama'), const Offset(-300, 0));
      await frames(tester, 8);
      expect(byKey('address-card-a-mama'), findsNothing);
      expect(find.text('Удалили «Мама».'), findsOneWidget);
      expect(addresses.removed, <String>['a-work'], reason: 'sent at once');

      await frames(tester, 40);
      expect(addresses.removed, <String>['a-work', 'a-mama']);
    });

    testWidgets('revealing a card closes the one open', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[home(), mama(), work()];
      await openList(tester);

      await drag(tester, 'a-home', -150);
      expect(surfaceLeft(tester, 'a-home'), closeTo(20 - 88, 1));
      await drag(tester, 'a-mama', -150);
      expect(surfaceLeft(tester, 'a-home'), closeTo(20, 1));
      expect(surfaceLeft(tester, 'a-mama'), closeTo(20 - 88, 1));

      await tester.tap(byKey('address-menu-a-work'));
      await tester.pumpAndSettle();
      expect(surfaceLeft(tester, 'a-mama'), closeTo(20, 1), reason: 'menu');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await drag(tester, 'a-work', -150);
      expect(surfaceLeft(tester, 'a-work'), closeTo(20 - 88, 1));
      await tester.tapAt(const Offset(200, 700));
      await tester.pumpAndSettle();
      expect(surfaceLeft(tester, 'a-work'), closeTo(20, 1), reason: 'tap');
    });

    testWidgets('scrolling closes the open card', (WidgetTester tester) async {
      addresses.rows = <Address>[home(), mama(), work()];
      await openList(tester, size: const Size(400, 360));

      await drag(tester, 'a-home', -150);
      expect(surfaceLeft(tester, 'a-home'), closeTo(20 - 88, 1));
      await tester.drag(byKey('address-card-a-mama'), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(surfaceLeft(tester, 'a-home'), closeTo(20, 1));
    });

    testWidgets('a second removal sends the first at once', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[home(), mama(), work()];
      await openList(tester);

      await removeVia(tester, 'a-home');
      await folded(tester);
      await removeVia(tester, 'a-mama');
      await frames(tester, 6);

      expect(addresses.removed, <String>['a-home']);
      expect(
        find.text('Удалили «Мама». Доставка теперь: «Работа».'),
        findsOneWidget,
      );
      await tester.tap(find.text('Вернуть'));
      await tester.pump();
      await frames(tester, 40);

      expect(addresses.removed, <String>['a-home']);
      expect(byKey('address-card-a-mama'), findsOneWidget);
      expect(byKey('address-card-a-home'), findsNothing);
    });

    /// The card's custom «Удалить» action, as a screen reader performs it.
    void readerRemove(WidgetTester tester, String id) {
      final SemanticsNode node = tester.getSemantics(byKey('address-card-$id'));
      final SemanticsData data = node.getSemanticsData();
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        data.customSemanticsActionIds!.firstWhere(
          (int id) => CustomSemanticsAction.getAction(id)!.label == 'Удалить',
        ),
      );
    }

    testWidgets('three removals close together hold each and send each once', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      addresses.rows = <Address>[
        home(),
        mama(),
        work(),
        address(id: 'a-dacha', label: 'Дача', street: 'Olmazor'),
      ];
      await openList(tester);

      readerRemove(tester, 'a-home');
      await tester.pump();
      await folded(tester);
      readerRemove(tester, 'a-mama');
      await tester.pump(const Duration(milliseconds: 100));
      readerRemove(tester, 'a-work');
      await frames(tester, 40);

      expect(tester.takeException(), isNull);
      expect(addresses.removed, <String>['a-home', 'a-mama', 'a-work']);
      expect(byKey('address-card-a-dacha'), findsOneWidget);
      expect(byKey('address-card-a-work'), findsNothing);
      semantics.dispose();
    });

    testWidgets('an account change before the next bar is in leaves nothing '
        'of the previous Customer', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      addresses.rows = <Address>[home(), mama(), work()];
      await openList(tester);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).last),
      );

      readerRemove(tester, 'a-home');
      await tester.pump();
      await folded(tester);
      readerRemove(tester, 'a-mama');
      await tester.pump(const Duration(milliseconds: 100));
      container.invalidate(addressRemovalsProvider);
      await frames(tester, 40);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Удалили'), findsNothing);
      expect(addresses.removed, <String>['a-home']);
      semantics.dispose();
    });

    testWidgets("the reader's Удалить removes and is announced", (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      addresses.rows = <Address>[home(), work()];
      await openList(tester);
      tester.takeAnnouncements();

      expect(find.bySemanticsLabel(RegExp(r'^Удалить$')), findsNothing);
      expect(find.byTooltip('Удалить'), findsNothing);
      final SemanticsNode node = tester.getSemantics(
        byKey('address-card-a-work'),
      );
      final SemanticsData data = node.getSemanticsData();
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        data.customSemanticsActionIds!.firstWhere(
          (int id) => CustomSemanticsAction.getAction(id)!.label == 'Удалить',
        ),
      );
      await tester.pump();
      await folded(tester);

      expect(
        spoken(tester),
        contains('Адрес «Работа» удалён. Вернуть — кнопка внизу.'),
      );
      expect(byKey('address-card-a-work'), findsNothing);
      semantics.dispose();
    });

    testWidgets('leaving the screen keeps the bar and the removal', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[work(), mama()];
      await openList(tester);
      Finder profileValue(String text) => find.descendant(
        of: byKey('profile-addresses'),
        matching: find.text(text),
      );
      await removeVia(tester, 'a-work');
      await folded(tester);

      GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Удалили «Работа». Доставка теперь: «Мама».'), findsOne);
      expect(profileValue('Мама'), findsOneWidget);
      expect(profileValue('Работа'), findsNothing);
      expect(addresses.removed, isEmpty);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(addresses.removed, <String>['a-work']);
      expect(profileValue('Работа'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('a saved address', () {
    List<Address> ten() => <Address>[
      for (int i = 0; i < 10; i++)
        address(id: 'a-$i', label: 'Метка $i', street: 'Ул $i', house: '$i'),
    ];

    ScrollPosition position(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: byKey('addresses-list'),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    /// Frames of 50 ms until the form is gone.
    Future<void> leaveForm(WidgetTester tester) async {
      for (
        int i = 0;
        i < 60 && byKey('address-save').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(byKey('address-save'), findsNothing);
    }

    Future<void> saveForm(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        byKey('address-save'),
        200,
        scrollable: find
            .descendant(
              of: byKey('address-form'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      await tester.tap(byKey('address-save'));
      await tester.pump();
    }

    /// A new address «Сестра» typed and sent; the form is left.
    Future<void> addSister(WidgetTester tester) async {
      await tester.tap(byKey('address-new'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('address-point-confirm'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('field-street'), 'Bobur');
      await tester.enterText(byKey('field-house'), '3');
      await tester.ensureVisible(byKey('label-custom'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('label-custom'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(byKey('field-label'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('field-label'), 'Сестра');
      await saveForm(tester);
      await leaveForm(tester);
    }

    /// The last card, cut by the bottom of the list, opened and its house
    /// changed.
    Future<void> editLastCut(WidgetTester tester) async {
      await tester.drag(byKey('addresses-list'), const Offset(0, -5000));
      await tester.pumpAndSettle();
      await tester.drag(byKey('addresses-list'), const Offset(0, 90));
      await tester.pumpAndSettle();
      final Offset top = tester.getTopLeft(byKey('address-card-a-9'));
      await tester.tapAt(top + const Offset(60, 20));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('field-house'), '99');
      await saveForm(tester);
      await leaveForm(tester);
    }

    double glowOf(WidgetTester tester, String id) =>
        tester.widget<Opacity>(byKey('address-glow-$id')).opacity;

    testWidgets(
      'a new address unfolds at the top and glows; the bar names it',
      (WidgetTester tester) async {
        addresses.rows = ten();
        await openList(tester);
        await tester.drag(byKey('addresses-list'), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(position(tester).pixels, greaterThan(100));

        await addSister(tester);
        await tester.pump(const Duration(milliseconds: 350));
        expect(position(tester).pixels, 0);
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Сестра'), findsOneWidget);
        expect(
          tester.getTopLeft(byKey('address-card-a-new-1')).dy,
          lessThan(tester.getTopLeft(byKey('address-card-a-0')).dy),
          reason: 'the new card is the first',
        );
        expect(glowOf(tester, 'a-new-1'), greaterThan(0));
        expect(find.text('Адрес «Сестра» добавлен'), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('an edited address glows and the bar names it', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[
        ...ten().take(9),
        address(id: 'a-9', label: 'Работа', street: 'Ул 9', house: '9'),
      ];
      await openList(tester);
      await editLastCut(tester);
      await tester.pump(const Duration(milliseconds: 350));

      final double bottom = tester.getBottomLeft(byKey('address-card-a-9')).dy;
      expect(
        bottom,
        lessThanOrEqualTo(tester.getBottomLeft(byKey('addresses-list')).dy),
        reason: 'brought into view',
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(glowOf(tester, 'a-9'), greaterThan(0));
      expect(find.text('Адрес «Работа» сохранён'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the glow waits for a list that reloads late', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[
        ...ten().take(9),
        address(id: 'a-9', label: 'Работа', street: 'Ул 9', house: '9'),
      ];
      await openList(tester);
      addresses.loadHold = Completer<void>();
      await editLastCut(tester);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(glowOf(tester, 'a-9'), 0, reason: 'the list has not answered');

      await release(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(glowOf(tester, 'a-9'), greaterThan(0));
      await tester.pumpAndSettle();
    });
  });

  group('every face fits and meets the tap target guideline', () {
    const Size phone = Size(360, 640);

    Future<void> check(WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    }

    // At 100 % and at the largest text the batch tests (`DL-126`).
    for (final (String scale, TextScaler scaler) in <(String, TextScaler)>[
      ('100 %', TextScaler.noScaling),
      ('x2', const NonlinearTextScaler(2)),
    ]) {
      group(scale, () {
        testWidgets('loaded', (WidgetTester tester) async {
          addresses.rows = <Address>[
            address(
              label: 'Ota-onamning uyi, Chilonzor tumani',
              landmark: 'Maktab',
            ),
            address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
          ];
          await openList(tester, size: phone, textScaler: scaler);
          expect(byKey('address-card-a-1'), findsOneWidget);
          await check(tester);
        });

        testWidgets('loaded, with a revealed card', (
          WidgetTester tester,
        ) async {
          addresses.rows = <Address>[
            address(label: 'Ota-onamning uyi, Chilonzor tumani'),
            address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
          ];
          await openList(tester, size: phone, textScaler: scaler);
          await tester.drag(byKey('address-card-a-1'), const Offset(-150, 0));
          await tester.pumpAndSettle();
          expect(byKey('address-reveal-a-1'), findsOneWidget);
          await check(tester);
        });

        testWidgets('loaded, with the menu open', (WidgetTester tester) async {
          addresses.rows = <Address>[
            address(label: 'Ota-onamning uyi, Chilonzor tumani'),
            address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
          ];
          await openList(tester, size: phone, textScaler: scaler);
          await tester.tap(byKey('address-menu-a-1'));
          await tester.pumpAndSettle();
          expect(byKey('address-delete-a-1'), findsOneWidget);
          await check(tester);
        });

        testWidgets('loading', (WidgetTester tester) async {
          await openFailed(tester, size: phone, textScaler: scaler);
          await retryHeld(tester);
          expect(byKey('address-skeleton'), findsWidgets);
          await check(tester);
        });

        testWidgets('failed', (WidgetTester tester) async {
          await openFailed(tester, size: phone, textScaler: scaler);
          expect(byKey('addresses-retry'), findsOneWidget);
          await check(tester);
        });

        testWidgets('empty', (WidgetTester tester) async {
          addresses.rows = <Address>[];
          await openList(tester, size: phone, textScaler: scaler);
          expect(byKey('address-new'), findsOneWidget);
          await check(tester);
        });
      });
    }
  });
}
