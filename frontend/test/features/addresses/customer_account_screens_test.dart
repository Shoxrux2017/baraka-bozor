import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:baraka_bozor/core/widgets/shake.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';

import '../../support/app_harness.dart';
import '../../support/fake_address_map.dart';
import '../../support/fake_address_search.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/fake_device_location.dart';
import '../../support/in_memory_stores.dart';
import '../../support/nonlinear_text_scaler.dart';

/// The Customer's profile and addresses (W1-13) through the real router,
/// session and screens.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeAddressesRepository addresses;
  late InMemoryPreferenceStore preferences;
  late FakeAddressSearch search;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  /// The screen's own title: the tab label of the bar says the same word.
  Finder profileTitle(String text) => find.descendant(
    of: find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.header == true,
    ),
    matching: find.text(text),
  );

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    addresses = FakeAddressesRepository();
    preferences = InMemoryPreferenceStore();
    search = FakeAddressSearch();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> openProfile(
    WidgetTester tester, {
    bool fakeMap = true,
    Size size = const Size(800, 2000),
    Locale device = const Locale('uz'),
    FakeDeviceLocation? location,
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
        addresses: addresses,
        preferences: preferences,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profile),
          addressSearchRepositoryProvider.overrideWithValue(search),
          if (fakeMap) addressMapProvider.overrideWithValue(FakeAddressMap()),
          if (location != null)
            deviceLocationProvider.overrideWithValue(location),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
  }

  Future<void> openAddresses(
    WidgetTester tester, {
    bool fakeMap = true,
    Size size = const Size(800, 2000),
  }) async {
    await openProfile(tester, fakeMap: fakeMap, size: size);
    await tester.tap(byKey('profile-addresses'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The name editor, opened from the profile's header.
  Future<void> openEditor(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('profile-identity'));
    expect(byKey('edit-profile'), findsOneWidget);
  }

  /// The map step of a new address: the pin moved when asked or when it is
  /// not yet placed (confirm waits for that), then confirmed.
  Future<void> confirmPoint(WidgetTester tester, {bool move = false}) async {
    final Finder confirm = byKey('address-point-confirm');
    final bool waiting =
        tester.widgetList<FilledButton>(confirm).isNotEmpty &&
        tester.widget<FilledButton>(confirm).onPressed == null;
    if (move || waiting) {
      await tapAndSettle(tester, byKey('fake-map-move'));
    }
    await tapAndSettle(tester, byKey('address-point-confirm'));
  }

  /// A notice left over covers the button of the list.
  Future<void> closeSnackBars(WidgetTester tester) async {
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pumpAndSettle();
  }

  /// The map step: the address typed in words and searched.
  Future<void> searchWords(WidgetTester tester, String words) async {
    await tester.enterText(byKey('address-search-field'), words);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  String streetText(WidgetTester tester) =>
      tester.widget<TextFormField>(byKey('field-street')).controller!.text;

  Future<void> fillNewAddress(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('address-new'));
    await confirmPoint(tester);
    await tester.enterText(byKey('field-street'), 'Navoiy');
    await tester.enterText(byKey('field-house'), '5A');
  }

  Finder inForm(Finder finder) =>
      find.descendant(of: find.byType(Form), matching: finder);

  group('profile', () {
    testWidgets(
      'the profile carries the tab bar with the profile tab current',
      (WidgetTester tester) async {
        await openProfile(tester);

        expect(find.byType(CustomerTabBar), findsOneWidget);
        expect(
          tester.widget<CustomerTabBar>(find.byType(CustomerTabBar)).current,
          CustomerTab.profile,
        );
      },
    );

    testWidgets('the profile logs the Customer out', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);
      await tester.tap(byKey('logout-button'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('logout-confirm'));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('logout:customer'));
      expect(byKey('profile-list'), findsNothing);
    });

    testWidgets('the phone is shown and a name is saved', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);

      expect(find.text(formatPhone('+998901234567')), findsOneWidget);
      expect(find.text(l10n(tester).profileNoName), findsOneWidget);
      expect(find.text(l10n(tester).profileSetName), findsOneWidget);

      await openEditor(tester);
      await tester.enterText(byKey('profile-name-field'), '  Aziza Karimova ');
      await tapAndSettle(tester, byKey('profile-save'));

      expect(profile.renames, <String>['Aziza Karimova']);
      expect(byKey('edit-profile'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(l10n(tester).profileNoName), findsNothing);
      expect(find.text('Aziza Karimova'), findsOneWidget);
    });

    testWidgets('an empty name is refused before sending', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);

      await openEditor(tester);
      await tester.enterText(byKey('profile-name-field'), '   ');
      await tester.pumpAndSettle();
      await tester.tap(byKey('profile-save'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).profileNameEnter), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('profile-save')).onPressed,
        isNull,
      );
      expect(profile.renames, isEmpty);
    });

    testWidgets('the language chosen here is the interface language', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);

      await tapAndSettle(tester, byKey('profile-language'));
      await tapAndSettle(tester, byKey('language-ru'));

      expect(byKey('language-sheet'), findsNothing);
      expect(profileTitle('Профиль'), findsOneWidget);
      expect(auth.calls, contains('language:customer:ru'));
    });
  });

  group('profile that does not load', () {
    testWidgets('the language can still be chosen while the profile fails', (
      WidgetTester tester,
    ) async {
      profile.loadFailure = const NetworkFailure();
      await openProfile(tester);
      expect(find.text(l10n(tester).profileLoadFailedOffline), findsOneWidget);
      expect(byKey('profile-language'), findsOneWidget);

      await tapAndSettle(tester, byKey('profile-language'));
      await tapAndSettle(tester, byKey('language-ru'));

      expect(profileTitle('Профиль'), findsOneWidget);
      expect(auth.calls, contains('language:customer:ru'));
    });
  });

  group('addresses', () {
    testWidgets('a new address takes the point where the pin was left', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      expect(find.text('Uy'), findsOneWidget);

      await tapAndSettle(tester, byKey('address-new'));
      expect(
        find.text('41.311081,69.240562'),
        findsOneWidget,
        reason: 'the pin starts in Tashkent',
      );
      await confirmPoint(tester, move: true);
      expect(
        tester.widget<Text>(byKey('fake-map-preview')).data,
        '${fakeDoor.latitude},${fakeDoor.longitude}',
        reason: 'the form shows the point the map step confirmed',
      );
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      await tester.enterText(byKey('field-delivery_note'), 'Domofon 12');
      await tapAndSettle(tester, byKey('address-save'));

      final (String? id, AddressDraft draft) = addresses.saved.single;
      expect(id, isNull);
      expect(draft.point, fakeDoor);
      expect(draft.street, 'Navoiy');
      expect(draft.label, isNull);
      expect(draft.deliveryNote, 'Domofon 12');
      expect(
        find.text(l10n(tester).addressAdded('Navoiy, 5A')),
        findsOneWidget,
      );
      expect(
        find.text('Navoiy, 5A'),
        findsOneWidget,
        reason: 'back on the list',
      );
    });

    testWidgets('a new address says its step in the bar and the panel has no '
        'heading', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));

      final AppLocalizations strings = l10n(tester);
      expect(find.text(strings.addressNew), findsOneWidget);
      expect(find.text(strings.addressStepPoint), findsOneWidget);
      expect(
        find.bySemanticsLabel(strings.addressStepPointSpoken),
        findsOneWidget,
      );
      expect(
        find.text(strings.addressPointTitle),
        findsNothing,
        reason: 'neither the bar nor the panel carries the old heading',
      );
      expect(
        tester.widget<Text>(byKey('fake-map-initial')).data,
        '41.311081,69.240562',
        reason: 'the delivery address Uy is where the map opens',
      );

      await confirmPoint(tester, move: true);
      expect(find.text(strings.addressStepDetails), findsOneWidget);
      expect(find.text(strings.addressStepPoint), findsNothing);
      handle.dispose();
    });

    testWidgets('the street and the house are required', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));
      await confirmPoint(tester);

      await tapAndSettle(tester, byKey('address-save'));

      expect(find.text(l10n(tester).fieldRequired), findsNWidgets(2));
      expect(addresses.saved, isEmpty);
    });

    testWidgets('a point outside the area is refused with both distances', (
      WidgetTester tester,
    ) async {
      addresses.saveFailure = const ApiRefusal(
        ApiError(
          status: 422,
          code: 'address_outside_service_area',
          details: <String, Object?>{
            'max_distance_km': '5.00',
            'distance_km': '7.25',
          },
        ),
      );
      await openAddresses(tester);
      await fillNewAddress(tester);
      await tapAndSettle(tester, byKey('address-save'));

      expect(
        find.text(l10n(tester).addressOutsideArea('7,25', '5,00')),
        findsOneWidget,
        reason: 'with the decimal comma',
      );
      expect(byKey('address-save'), findsOneWidget, reason: 'the form stays');

      await tapAndSettle(tester, byKey('address-change-point'));
      await tapAndSettle(tester, byKey('fake-map-far'));
      await confirmPoint(tester);
      expect(
        byKey('address-outside-area'),
        findsNothing,
        reason: 'the refusal was about the point before',
      );
    });

    testWidgets('an area not configured yet is explained', (
      WidgetTester tester,
    ) async {
      addresses.saveFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_configuration_incomplete'),
      );
      await openAddresses(tester);
      await fillNewAddress(tester);
      await tapAndSettle(tester, byKey('address-save'));

      expect(
        find.text(l10n(tester).errorConfigurationIncomplete),
        findsOneWidget,
      );
    });

    testWidgets('an edit starts from the address and keeps its point', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);

      await tapAndSettle(tester, find.text('Uy'));
      expect(
        tester.widget<Text>(byKey('fake-map-preview')).data,
        '41.311081,69.240562',
        reason: 'an edit opens on the form with the stored point',
      );
      expect(byKey('address-point-confirm'), findsNothing);
      await tester.enterText(byKey('field-house'), '14');
      await tapAndSettle(tester, byKey('address-save'));

      final (String? id, AddressDraft draft) = addresses.saved.single;
      expect(id, 'a-1');
      expect(
        draft.point,
        const GeoPoint(latitude: '41.311081', longitude: '69.240562'),
      );
      expect(draft.house, '14');
      expect(draft.label, 'Uy');
    });

    testWidgets('editing an address does not change the delivery address', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[
        address(),
        address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
      ];
      preferences.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-2';
      await openAddresses(tester);

      await tapAndSettle(tester, find.text('Uy'));
      await tester.enterText(byKey('field-house'), '14');
      await tapAndSettle(tester, byKey('address-save'));

      expect(addresses.saved.single.$1, 'a-1');
      expect(
        preferences.values[DeliveryAddressChoice.preferenceKey('c')],
        'a-2',
      );
    });

    testWidgets('typed words fill an empty street', (
      WidgetTester tester,
    ) async {
      search.answers['квартал Ц-5, дом 12'] = fakeDoor;
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));
      await tester.enterText(
        byKey('address-search-field'),
        'квартал Ц-5, дом 12',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await confirmPoint(tester);

      expect(
        tester.widget<TextFormField>(byKey('field-street')).controller!.text,
        'квартал Ц-5, дом 12',
      );
    });

    testWidgets('an edit never takes the words and does not promise them', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, find.text('Uy'));
      await tapAndSettle(tester, byKey('address-change-point'));
      await searchWords(tester, 'квартал Ц-5, дом 12');
      expect(byKey('address-words-kept'), findsNothing);
      await confirmPoint(tester);

      expect(streetText(tester), 'Amir Temur');
    });

    testWidgets('the latest words fill a street they filled before', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));
      await searchWords(tester, 'Navoiy 5');
      expect(byKey('address-words-kept'), findsOneWidget);
      await confirmPoint(tester);
      expect(streetText(tester), 'Navoiy 5');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await searchWords(tester, 'Bobur 7');
      expect(byKey('address-words-kept'), findsOneWidget);
      await confirmPoint(tester);

      expect(streetText(tester), 'Bobur 7');
    });

    testWidgets('words do not overwrite a street the Customer edited', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));
      await searchWords(tester, 'Navoiy 5');
      await confirmPoint(tester);
      await tester.enterText(byKey('field-street'), 'Navoiy ko`chasi');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await searchWords(tester, 'Bobur 7');
      expect(byKey('address-words-kept'), findsNothing);
      await confirmPoint(tester);

      expect(streetText(tester), 'Navoiy ko`chasi');
    });

    testWidgets('an edit keeps its street when the point changes', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, find.text('Uy'));

      await tapAndSettle(tester, byKey('address-change-point'));
      await confirmPoint(tester, move: true);
      expect(
        tester.widget<TextFormField>(byKey('field-street')).controller!.text,
        'Amir Temur',
      );
      await tapAndSettle(tester, byKey('address-save'));

      final (String? id, AddressDraft draft) = addresses.saved.single;
      expect(id, 'a-1');
      expect(draft.point, fakeDoor);
      expect(draft.street, 'Amir Temur');
    });

    testWidgets('the form and the map step use the kit app bar on white', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));
      for (int step = 0; step < 2; step++) {
        final AppBar bar = tester.widget<AppBar>(find.byType(AppBar).last);
        expect(bar.centerTitle, isTrue);
        expect(bar.backgroundColor, Colors.white);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
          Colors.white,
        );
        if (step == 0) {
          await confirmPoint(tester);
        }
      }
    });

    testWidgets('back walks the steps', (WidgetTester tester) async {
      await openAddresses(tester);

      // A new address: form, back, the map with the same point, back, list.
      await tapAndSettle(tester, byKey('address-new'));
      await confirmPoint(tester, move: true);
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(byKey('address-point-confirm'), findsOneWidget);
      expect(
        tester.widget<Text>(byKey('fake-map-initial')).data,
        '${fakeDoor.latitude},${fakeDoor.longitude}',
        reason: 'the point is kept',
      );
      await confirmPoint(tester);
      expect(
        tester.widget<TextFormField>(byKey('field-street')).controller!.text,
        'Navoiy',
        reason: 'what was typed is kept',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('address-point-confirm'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        byKey('address-leave-sheet'),
        findsOneWidget,
        reason: 'a filled form asks before it is left (DL-138)',
      );
      await tester.tap(byKey('address-leave-go'));
      await tester.pumpAndSettle();
      expect(byKey('address-new'), findsOneWidget, reason: 'the list');

      // A new address changing its point from the form: back returns to the
      // form with everything as it was.
      await tapAndSettle(tester, byKey('address-new'));
      await confirmPoint(tester, move: true);
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      await tapAndSettle(tester, byKey('address-change-point'));
      expect(byKey('address-point-confirm'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(byKey('address-save'), findsOneWidget);
      expect(streetText(tester), 'Navoiy');
      expect(
        tester.widget<Text>(byKey('fake-map-preview')).data,
        '${fakeDoor.latitude},${fakeDoor.longitude}',
        reason: 'the point is unchanged',
      );
      await tapAndSettle(tester, byKey('address-change-point'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('address-save'), findsOneWidget);
      expect(streetText(tester), 'Navoiy');
      expect(
        tester.widget<TextFormField>(byKey('field-house')).controller!.text,
        '5A',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('address-point-confirm'), findsOneWidget, reason: 'step 1');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(byKey('address-leave-go'));
      await tester.pumpAndSettle();
      expect(byKey('address-new'), findsOneWidget, reason: 'the list');

      // An edit: the map step goes back to the form unchanged.
      await tapAndSettle(tester, find.text('Uy'));
      await tapAndSettle(tester, byKey('address-change-point'));
      await tapAndSettle(tester, byKey('fake-map-move'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(byKey('fake-map-preview')).data,
        '41.311081,69.240562',
        reason: 'the old point, nothing changed',
      );
      await tapAndSettle(tester, byKey('address-change-point'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('address-save'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(byKey('address-new'), findsOneWidget, reason: 'the list');
    });

    testWidgets('back does not leave while a save is pending', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await fillNewAddress(tester);
      addresses.hold = Completer<void>();
      await tester.tap(byKey('address-save'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(byKey('address-save'), findsOneWidget);
      expect(byKey('address-point-confirm'), findsNothing);
      expect(
        tester.widget<InkWell>(byKey('address-preview')).onTap,
        isNull,
        reason: 'the point cannot be changed mid-save',
      );

      addresses.hold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the label chips', (WidgetTester tester) async {
      await openAddresses(tester);
      await fillNewAddress(tester);

      await tapAndSettle(tester, byKey('label-home'));
      await tapAndSettle(tester, byKey('address-save'));
      expect(addresses.saved.last.$2.label, 'Uy');

      await closeSnackBars(tester);
      await fillNewAddress(tester);
      await tapAndSettle(tester, byKey('label-home'));
      await tapAndSettle(tester, byKey('label-home'));
      await tapAndSettle(tester, byKey('address-save'));
      expect(addresses.saved.last.$2.label, isNull);

      await closeSnackBars(tester);
      await fillNewAddress(tester);
      expect(byKey('field-label'), findsNothing);
      await tapAndSettle(tester, byKey('label-custom'));
      await tester.enterText(byKey('field-label'), 'Dacha');
      await tapAndSettle(tester, byKey('address-save'));
      expect(addresses.saved.last.$2.label, 'Dacha');
    });

    testWidgets('an existing label picks its chip', (
      WidgetTester tester,
    ) async {
      addresses.rows = <Address>[
        address(label: 'Ofis'),
        address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7'),
        address(id: 'a-3', label: null, street: 'Chilonzor', house: '1'),
      ];
      await openAddresses(tester);

      await tapAndSettle(tester, find.text('Ofis'));
      expect(
        tester.widget<TextFormField>(byKey('field-label')).controller!.text,
        'Ofis',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text('Ish'));
      expect(byKey('field-label'), findsNothing, reason: 'Ish is a chip');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text('Chilonzor, 1'));
      expect(byKey('field-label'), findsNothing, reason: 'no label, no chip');
    });

    testWidgets('a point outside the area is refused on the form', (
      WidgetTester tester,
    ) async {
      addresses.saveFailure = const ApiRefusal(
        ApiError(
          status: 422,
          code: 'address_outside_service_area',
          details: <String, Object?>{
            'max_distance_km': '5.00',
            'distance_km': '7.25',
          },
        ),
      );
      await openAddresses(tester);
      await fillNewAddress(tester);
      await tapAndSettle(tester, byKey('address-save'));

      final Finder refusal = byKey('address-outside-area');
      expect(refusal, findsOneWidget);
      expect(
        tester.getBottomLeft(refusal).dy,
        lessThanOrEqualTo(tester.getTopLeft(byKey('address-save')).dy),
        reason: 'above the button',
      );
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets('the form holds at 320x640 with text x2 '
          '(${device.languageCode})', (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addresses.rows = <Address>[address(label: 'L' * 60, street: 'S' * 160)];
        await tester.pumpWidget(
          appUnderTest(
            tokens: tokens,
            repository: auth,
            device: device,
            addresses: addresses,
            overrides: [
              profileRepositoryProvider.overrideWithValue(profile),
              addressMapProvider.overrideWithValue(FakeAddressMap()),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tapAndSettle(tester, byKey('open-profile'));
        await tester.scrollUntilVisible(
          byKey('profile-addresses'),
          200,
          scrollable: find
              .descendant(
                of: byKey('profile-list'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tapAndSettle(tester, byKey('profile-addresses'));
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .push(AppPaths.customerAddress('a-1'));
        await tester.pumpAndSettle();
        expect(byKey('address-save'), findsOneWidget);
        await tester.drag(byKey('address-form'), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(byKey('field-label'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets('the change-point pill leaves the map logo free at 320x640 '
          'with text x2 (${device.languageCode})', (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openProfile(tester, size: const Size(320, 640), device: device);
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .push(AppPaths.customerAddress('a-1'));
        await tester.pumpAndSettle();

        final Rect preview = tester.getRect(byKey('address-preview'));
        final Rect pill = tester.getRect(byKey('address-change-point'));
        expect(pill.height, greaterThanOrEqualTo(44));
        // The lite map's Google logo sits at the preview's bottom left and is
        // never covered (`DL-86` (2)).
        expect(pill.left, greaterThanOrEqualTo(preview.left + 90));
        expect(pill.top, greaterThanOrEqualTo(preview.top + 10));
        expect(pill.bottom, closeTo(preview.bottom - 10, 0.5));
        expect(pill.right, closeTo(preview.right - 10, 0.5));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the change-point pill leaves the map logo free at 320x640 '
          'at 100 % (${device.languageCode})', (WidgetTester tester) async {
        await openProfile(tester, size: const Size(320, 640), device: device);
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .push(AppPaths.customerAddress('a-1'));
        await tester.pumpAndSettle();

        final Rect preview = tester.getRect(byKey('address-preview'));
        final Rect pill = tester.getRect(byKey('address-change-point'));
        expect(pill.left, greaterThanOrEqualTo(preview.left + 90));
        expect(preview.height, closeTo(118, 0.5));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the outside-area refusal fits above the button at 320x640 '
          'with text x2 (${device.languageCode})', (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addresses.saveFailure = const ApiRefusal(
          ApiError(
            status: 422,
            code: 'address_outside_service_area',
            details: <String, Object?>{
              'max_distance_km': '5.00',
              'distance_km': '7.25',
            },
          ),
        );
        await openProfile(tester, size: const Size(320, 640), device: device);
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .push(AppPaths.customerNewAddress);
        await tester.pumpAndSettle();
        await confirmPoint(tester);
        await tester.enterText(byKey('field-street'), 'Navoiy');
        await tester.enterText(byKey('field-house'), '5A');
        await tapAndSettle(tester, byKey('address-save'));

        final Finder refusal = byKey('address-outside-area');
        expect(refusal, findsOneWidget);
        final double buttonTop = tester.getTopLeft(byKey('address-save')).dy;
        expect(tester.getTopLeft(refusal).dy, lessThan(buttonTop));
        expect(
          tester
              .getBottomLeft(
                find.ancestor(
                  of: refusal,
                  matching: find.byType(SingleChildScrollView),
                ),
              )
              .dy,
          lessThanOrEqualTo(buttonTop),
          reason: 'the refusal scrolls in its own box above the button',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('removing an address folds it and tells the server when the '
        'bar ends', (WidgetTester tester) async {
      await openAddresses(tester);

      await tester.tap(byKey('address-menu-a-1'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('address-delete-a-1'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(addresses.removed, isEmpty, reason: 'the bar is still up');
      expect(find.text(l10n(tester).addressRemovedBar('Uy')), findsOneWidget);
      expect(find.text(l10n(tester).addressNone), findsOneWidget);

      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(addresses.removed, <String>['a-1']);
      expect(find.text(l10n(tester).addressNone), findsOneWidget);
    });

    testWidgets('without a map key the point is typed', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester, fakeMap: false);
      await tapAndSettle(tester, byKey('address-new'));

      expect(find.text(l10n(tester).addressMapUnavailable), findsOneWidget);
      expect(
        find.text(l10n(tester).addressMapHint),
        findsNothing,
        reason: 'no map to move in a build without a key',
      );
      await tester.enterText(byKey('point-latitude'), '41.33');
      await tester.enterText(byKey('point-longitude'), '69.28');
      await tapAndSettle(tester, byKey('address-point-confirm'));
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      await tapAndSettle(tester, byKey('address-save'));

      expect(
        addresses.saved.single.$2.point,
        const GeoPoint(latitude: '41.330000', longitude: '69.280000'),
      );
    });

    testWidgets('going back while a save runs keeps the Customer there', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await fillNewAddress(tester);
      addresses.hold = Completer<void>();
      await tester.tap(byKey('address-save'));
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      // The button's spinner never settles while the save is held.
      await tester.pump(const Duration(milliseconds: 500));
      expect(byKey('address-save'), findsOneWidget, reason: 'nothing moves');
      expect(byKey('address-new'), findsNothing);

      addresses.hold!.complete();
      await tester.pumpAndSettle();
      expect(addresses.saved, hasLength(1));
      expect(byKey('address-new'), findsOneWidget, reason: 'the list');
      expect(
        find.text(l10n(tester).addressAdded('Navoiy, 5A')),
        findsOneWidget,
      );
      expect(
        find.text('Navoiy, 5A'),
        findsOneWidget,
        reason: 'the list shows the address the save made',
      );
    });

    testWidgets('a failure shows where it happened and nowhere else', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await fillNewAddress(tester);
      addresses.saveFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('address-save'));
      expect(inForm(find.text(l10n(tester).errorNetwork)), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(byKey('address-point-confirm'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(byKey('address-leave-go'));
      await tester.pumpAndSettle();
      expect(find.text(l10n(tester).errorNetwork), findsNothing);

      addresses.removeFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('address-menu-a-1'));
      await tester.tap(byKey('address-delete-a-1'));
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        find.text(l10n(tester).addressNotRemovedOffline),
        findsOneWidget,
        reason: 'the red line of the card that was not removed',
      );

      await tapAndSettle(tester, byKey('address-new'));
      await confirmPoint(tester);
      expect(byKey('address-save'), findsOneWidget);
      expect(inForm(find.text(l10n(tester).errorNetwork)), findsNothing);
      expect(
        inForm(find.text(l10n(tester).addressNotRemovedOffline)),
        findsNothing,
      );
    });

    testWidgets('signing out while an address saves leaves nothing behind', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await fillNewAddress(tester);
      addresses.hold = Completer<void>();
      await tester.tap(byKey('address-save'));
      await tester.pump();

      await ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      ).read(sessionControllerProvider.notifier).logout(SessionMode.customer);
      await tester.pumpAndSettle();
      addresses.hold!.complete();
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).addressAdded('Navoiy, 5A')), findsNothing);
      expect(byKey('address-new'), findsNothing);
    });

    testWidgets('a phone-size window with large text fits', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addresses.rows = <Address>[
        address(
          label: 'Ota-onamning uyi, Chilonzor tumani',
          street: 'Bunyodkor shoh ko\'chasi',
        ),
      ];

      // The search field grows with the text and covers the fake map's
      // buttons, so the pin is placed by the silent fix instead.
      await openProfile(
        tester,
        size: const Size(320, 568),
        location: FakeDeviceLocation()..silent = fakeDoor,
      );
      await tester.scrollUntilVisible(
        byKey('profile-addresses'),
        200,
        scrollable: find
            .descendant(
              of: byKey('profile-list'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapAndSettle(tester, byKey('profile-addresses'));
      await tapAndSettle(tester, byKey('address-new'));
      await confirmPoint(tester);
      await tester.scrollUntilVisible(
        byKey('field-delivery_note'),
        200,
        scrollable: find
            .descendant(
              of: byKey('address-form'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    });
  });

  group('address details', () {
    const Size phone = Size(360, 640);

    /// The details of a new address in Russian, the pin placed by the silent
    /// fix so a large search field cannot cover the fake map's buttons.
    Future<void> openDetails(
      WidgetTester tester, {
      TextScaler? textScaler,
    }) async {
      await openProfile(
        tester,
        size: phone,
        device: const Locale('ru'),
        textScaler: textScaler,
        location: FakeDeviceLocation()..silent = fakeDoor,
      );
      await tester.scrollUntilVisible(
        byKey('profile-addresses'),
        200,
        scrollable: find
            .descendant(
              of: byKey('profile-list'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapAndSettle(tester, byKey('profile-addresses'));
      await tapAndSettle(tester, byKey('address-new'));
      await confirmPoint(tester);
      expect(byKey('address-save'), findsOneWidget);
    }

    List<String> haptics(WidgetTester tester) {
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

    Finder editable(String key) => find.descendant(
      of: byKey('field-$key'),
      matching: find.byType(EditableText),
    );

    FocusNode focusOf(WidgetTester tester, String key) =>
        tester.widget<EditableText>(editable(key)).focusNode;

    testWidgets('optional fields say so and required ones carry no star', (
      WidgetTester tester,
    ) async {
      await openDetails(tester);
      final AppLocalizations strings = l10n(tester);

      expect(
        find.descendant(
          of: byKey('label-of-house'),
          matching: find.text(strings.addressHouse),
        ),
        findsOneWidget,
      );
      expect(find.text(strings.addressFieldStreet), findsOneWidget);
      expect(
        find.text(strings.addressOptional(strings.addressFieldApartment)),
        findsOneWidget,
      );
      expect(
        find.text(strings.addressOptional(strings.addressLandmark)),
        findsOneWidget,
      );
      expect(
        find.text(strings.addressOptional(strings.addressFieldNote)),
        findsOneWidget,
      );
      expect(find.textContaining('*'), findsNothing);
      await tester.scrollUntilVisible(
        byKey('label-custom'),
        200,
        scrollable: find
            .descendant(
              of: byKey('address-form'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapAndSettle(tester, byKey('label-custom'));
      expect(
        find.text(strings.addressOptional(strings.addressLabelName)),
        findsOneWidget,
      );
    });

    testWidgets('a reader hears required and optional', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openDetails(tester);
      final AppLocalizations strings = l10n(tester);

      final SemanticsNode house = tester.getSemantics(editable('house'));
      expect(house.label, strings.fieldRequiredSpoken(strings.addressHouse));
      expect(house.flagsCollection.isTextField, isTrue);
      expect(
        tester.getSemantics(editable('apartment')).label,
        strings.fieldOptionalSpoken(strings.addressFieldApartment),
      );
      expect(
        find.bySemanticsLabel(strings.addressHouse),
        findsNothing,
        reason: 'the visible label is not read apart from its field',
      );
      handle.dispose();
    });

    testWidgets('Далее walks the fields', (WidgetTester tester) async {
      await openDetails(tester);
      await tester.tap(byKey('field-street'));
      await tester.pump();

      for (final String next in <String>[
        'house',
        'apartment',
        'landmark',
        'delivery_note',
      ]) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        expect(focusOf(tester, next).hasFocus, isTrue, reason: next);
      }
    });

    testWidgets('leaving an empty required field says so at once', (
      WidgetTester tester,
    ) async {
      await openDetails(tester);
      final String required = l10n(tester).fieldRequired;
      expect(find.text(required), findsNothing);

      await tester.tap(byKey('field-house'));
      await tester.pump();
      await tester.tap(byKey('field-street'));
      await tester.pump();
      expect(find.text(required), findsOneWidget);

      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.pump();
      expect(find.text(required), findsOneWidget, reason: 'the house still');
      await tester.enterText(byKey('field-house'), '5');
      await tester.pump();
      expect(find.text(required), findsNothing, reason: 'typing clears it');
    });

    testWidgets(
      'saving with a gap brings it into view, focuses and shakes it',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await openDetails(tester);
        final AppLocalizations strings = l10n(tester);
        final List<String> taps = haptics(tester);
        await tester.enterText(byKey('field-street'), 'Navoiy');
        await tester.enterText(byKey('field-apartment'), '12');
        await tester.enterText(byKey('field-landmark'), 'Apteka');
        await tester.enterText(byKey('field-delivery_note'), 'Domofon');
        await tester.drag(byKey('address-form'), const Offset(0, -2000));
        await tester.pumpAndSettle();
        final Finder label = byKey('label-of-house');
        final double rest = tester.getTopLeft(label).dx;
        final double listTop = tester.getTopLeft(byKey('address-form')).dy;
        expect(
          tester.getTopLeft(label).dy - listTop,
          isNot(closeTo(12, 0.5)),
          reason: 'the label is not yet where the scroll will put it',
        );
        tester.takeAnnouncements();

        await tester.tap(byKey('address-save'));
        // One frame lays the error lines out, the next starts the scroll.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.getTopLeft(label).dy - listTop,
          closeTo(12, 0.5),
          reason: 'the label stands 12 below the top of the list',
        );
        // Focus and the shake follow the scroll by about 20 ms.
        bool shook = false;
        for (int step = 0; step < 6; step++) {
          await tester.pump(const Duration(milliseconds: 20));
          shook = shook || (tester.getTopLeft(label).dx - rest).abs() > 0.01;
        }
        expect(focusOf(tester, 'house').hasFocus, isTrue);
        expect(shook, isTrue, reason: 'the field is shaking');
        expect(taps, <String>['HapticFeedbackType.warningNotification']);
        expect(
          tester
              .takeAnnouncements()
              .map((CapturedAccessibilityAnnouncement a) => a.message)
              .toList(),
          <String>[strings.addressFieldMissingSpoken(strings.addressHouse)],
        );
        expect(addresses.saved, isEmpty);
        await tester.pumpAndSettle();
        handle.dispose();
      },
    );

    testWidgets(
      'a gap whose row is not built is still brought into view, with the '
      'keyboard up and text x2',
      (WidgetTester tester) async {
        await openDetails(tester, textScaler: const NonlinearTextScaler(2));
        final List<String> taps = haptics(tester);
        await tester.scrollUntilVisible(
          byKey('label-custom'),
          200,
          scrollable: find
              .descendant(
                of: byKey('address-form'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tapAndSettle(tester, byKey('label-custom'));
        await tester.enterText(byKey('field-label'), 'Dacha');
        await tester.drag(byKey('address-form'), const Offset(0, -4000));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(byKey('label-of-street'), findsNothing, reason: 'not built');

        await tester.tap(byKey('address-save'));
        await tester.pumpAndSettle();

        final double listTop = tester.getTopLeft(byKey('address-form')).dy;
        expect(
          tester.getTopLeft(byKey('label-of-street')).dy - listTop,
          closeTo(12, 0.5),
        );
        expect(focusOf(tester, 'street').hasFocus, isTrue);
        expect(
          tester
              .widget<Shake>(
                find.ancestor(
                  of: byKey('label-of-street'),
                  matching: find.byType(Shake),
                ),
              )
              .trigger,
          1,
          reason: 'the field shook',
        );
        expect(taps, <String>['HapticFeedbackType.warningNotification']);
        expect(addresses.saved, isEmpty);
      },
    );

    testWidgets('saving stays green and ends with a check', (
      WidgetTester tester,
    ) async {
      await openDetails(tester);
      final AppLocalizations strings = l10n(tester);
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      addresses.hold = Completer<void>();

      await tester.tap(byKey('address-save'));
      await tester.pump();
      final Finder button = byKey('address-save');
      expect(
        find.descendant(of: button, matching: find.text(strings.addressSaving)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final Material face = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      expect(face.color, KitColors.primary);
      for (final String key in <String>['street', 'house']) {
        final TextField field = tester.widget<TextField>(
          find.descendant(
            of: byKey('field-$key'),
            matching: find.byType(TextField),
          ),
        );
        expect(field.enabled, isTrue, reason: key);
        expect(field.readOnly, isTrue, reason: key);
      }

      addresses.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(
          of: button,
          matching: find.text(strings.addressSavedButton),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(byKey('address-save'), findsOneWidget, reason: 'still the form');
      expect(find.text(strings.addressAdded('Navoiy, 5A')), findsNothing);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text(strings.addressAdded('Navoiy, 5A')), findsOneWidget);
      expect(byKey('address-save'), findsNothing, reason: 'back on the list');
    });

    testWidgets('a failed save gives the button back', (
      WidgetTester tester,
    ) async {
      await openDetails(tester);
      final AppLocalizations strings = l10n(tester);
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      addresses.saveFailure = const NetworkFailure();

      await tapAndSettle(tester, byKey('address-save'));

      expect(
        find.descendant(
          of: byKey('address-save'),
          matching: find.text(strings.addressSaveButton),
        ),
        findsOneWidget,
      );
      expect(inForm(find.text(strings.errorNetwork)), findsOneWidget);
    });

    testWidgets('house and apartment inputs stand level at normal text', (
      WidgetTester tester,
    ) async {
      await openDetails(tester);

      final double level = tester.getRect(byKey('field-house')).top;
      expect(tester.getRect(byKey('field-apartment')).top, level);

      await tapAndSettle(tester, byKey('address-save'));
      expect(find.text('Заполните поле'), findsWidgets);
      expect(
        tester.getRect(byKey('field-apartment')).top,
        tester.getRect(byKey('field-house')).top,
        reason: 'the house error line does not move the apartment input',
      );
    });

    testWidgets('large text stacks house and apartment', (
      WidgetTester tester,
    ) async {
      await openDetails(tester, textScaler: const NonlinearTextScaler(2));

      final Offset house = tester.getTopLeft(byKey('field-house'));
      final Offset apartment = tester.getTopLeft(byKey('field-apartment'));
      expect(house.dy, lessThan(apartment.dy), reason: 'house above');
      expect(house.dx, apartment.dx);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });
  });

  testWidgets('with two sessions the mode shows on every account screen', (
    WidgetTester tester,
  ) async {
    tokens.tokens[SessionSlot.staff] = 's';
    auth.identities[SessionSlot.staff] = user(id: 's', role: UserRole.courier);
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        addresses: addresses,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profile),
          addressMapProvider.overrideWithValue(FakeAddressMap()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, byKey('staff-menu'));
    await tapAndSettle(tester, byKey('switch-to-customer-button'));

    final Finder mode = byKey('active-mode');
    await tapAndSettle(tester, byKey('open-profile'));
    expect(mode, findsOneWidget, reason: 'on the profile');
    await tapAndSettle(tester, byKey('profile-addresses'));
    expect(mode, findsOneWidget, reason: 'on the addresses');
    await tapAndSettle(tester, byKey('address-new'));
    expect(mode, findsOneWidget, reason: 'on a new address');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Uy'));
    expect(mode, findsOneWidget, reason: 'on an edit');
  });

  group('coordinates typed without a map', () {
    Future<void> typePoint(
      WidgetTester tester,
      String latitude,
      String longitude,
    ) async {
      await openAddresses(tester, fakeMap: false);
      await tapAndSettle(tester, byKey('address-new'));
      await tester.enterText(byKey('point-latitude'), latitude);
      await tester.enterText(byKey('point-longitude'), longitude);
      await tapAndSettle(tester, byKey('address-point-confirm'));
      if (byKey('field-street').evaluate().isEmpty) {
        return;
      }
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      await tapAndSettle(tester, byKey('address-save'));
    }

    testWidgets('a decimal comma is read as the point it shows', (
      WidgetTester tester,
    ) async {
      await typePoint(tester, '41,33', '69,28');

      expect(
        addresses.saved.single.$2.point,
        const GeoPoint(latitude: '41.330000', longitude: '69.280000'),
      );
    });

    testWidgets('more than six decimals are rounded, not dropped', (
      WidgetTester tester,
    ) async {
      await typePoint(tester, '41.3456789', '69.2405617');

      expect(
        addresses.saved.single.$2.point,
        const GeoPoint(latitude: '41.345679', longitude: '69.240562'),
      );
    });

    testWidgets('an empty or impossible coordinate stops the save', (
      WidgetTester tester,
    ) async {
      await typePoint(tester, '95.5', '');

      expect(addresses.saved, isEmpty);
      expect(byKey('field-street'), findsNothing, reason: 'still the point');
      expect(find.text(l10n(tester).addressLatitudeInvalid), findsOneWidget);
      expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets('the fields fit a phone-size window with large text '
          '(${device.languageCode})', (WidgetTester tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          appUnderTest(
            tokens: tokens,
            repository: auth,
            device: device,
            addresses: addresses,
            overrides: [profileRepositoryProvider.overrideWithValue(profile)],
          ),
        );
        await tester.pumpAndSettle();
        await tapAndSettle(tester, byKey('open-profile'));
        await tester.scrollUntilVisible(
          byKey('profile-addresses'),
          200,
          scrollable: find
              .descendant(
                of: byKey('profile-list'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tapAndSettle(tester, byKey('profile-addresses'));
        await tapAndSettle(tester, byKey('address-new'));
        expect(byKey('point-longitude'), findsOneWidget);
      });
    }
  });

  group('failures and answers', () {
    testWidgets('a profile that failed to load shows progress on its retry', (
      WidgetTester tester,
    ) async {
      profile.loadFailure = const NetworkFailure();
      await openProfile(tester);
      expect(find.text(l10n(tester).profileLoadFailedOffline), findsOneWidget);

      profile.hold = Completer<void>();
      await tester.tap(byKey('profile-header-retry'));
      await tester.pump();
      expect(byKey('profile-header-skeleton'), findsOneWidget);

      profile.hold!.complete();
      await tester.pumpAndSettle();
      expect(byKey('profile-name'), findsOneWidget);
    });

    testWidgets("another Customer's profile is not shown", (
      WidgetTester tester,
    ) async {
      profile.current = const CustomerProfile(
        id: 'someone-else',
        phone: '+998909999999',
        fullName: 'Begona',
      );
      await openProfile(tester);

      expect(find.text(l10n(tester).profileLoadFailed), findsOneWidget);
      expect(find.text(l10n(tester).profileLoadFailedOther), findsOneWidget);
      expect(find.text('Begona'), findsNothing);
    });

    testWidgets('a refused rename explains itself and keeps the name typed', (
      WidgetTester tester,
    ) async {
      profile.renameFailure = const NetworkFailure();
      await openProfile(tester);

      await openEditor(tester);
      await tester.enterText(byKey('profile-name-field'), 'Aziza Karimova');
      await tapAndSettle(tester, byKey('profile-save'));

      expect(find.text(l10n(tester).profileNameNotSaved), findsOneWidget);
      expect(
        tester.widget<TextField>(byKey('profile-name-field')).controller!.text,
        'Aziza Karimova',
      );
    });

    testWidgets('an unchanged name is not sent and says so', (
      WidgetTester tester,
    ) async {
      profile.current = const CustomerProfile(
        id: 'c',
        phone: '+998901234567',
        fullName: 'Aziza',
      );
      await openProfile(tester);

      await openEditor(tester);
      await tester.tap(byKey('profile-save'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(profile.renames, isEmpty);
      expect(byKey('edit-profile'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(byKey('profile-save')).onPressed,
        isNull,
      );
      expect(find.text(l10n(tester).profileSaved), findsNothing);
    });

    testWidgets('the Customer cannot move on while the rename is on its way', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);
      await openEditor(tester);
      await tester.enterText(byKey('profile-name-field'), 'Aziza Karimova');
      profile.hold = Completer<void>();
      await tester.pump();
      await tester.tap(byKey('profile-save'));
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(byKey('edit-profile'), findsOneWidget);
      expect(byKey('name-leave-sheet'), findsNothing);

      profile.hold!.complete();
      await tester.pumpAndSettle();

      expect(profile.renames, <String>['Aziza Karimova']);
      expect(byKey('edit-profile'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an unchanged address is not sent and says so', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, find.text('Uy'));

      await tapAndSettle(tester, byKey('address-save'));

      expect(addresses.saved, isEmpty);
      expect(find.text(l10n(tester).noChanges), findsOneWidget);
      expect(byKey('address-save'), findsOneWidget, reason: 'the form stays');
    });

    testWidgets('an address that no longer exists says so', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push(AppPaths.customerAddress('a-gone'));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).errorNotFound), findsOneWidget);
      expect(byKey('address-save'), findsNothing);
    });

    testWidgets('a refusal of the area without its numbers still explains', (
      WidgetTester tester,
    ) async {
      addresses.saveFailure = const ApiRefusal(
        ApiError(status: 422, code: 'address_outside_service_area'),
      );
      await openAddresses(tester);
      await fillNewAddress(tester);
      await tapAndSettle(tester, byKey('address-save'));

      expect(find.text(l10n(tester).addressOutsideAreaPlain), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('an address already gone when removed leaves the list', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      addresses.rows = <Address>[];
      addresses.removeFailure = const ApiRefusal(
        ApiError(status: 404, code: 'resource_not_found'),
      );

      await tapAndSettle(tester, byKey('address-menu-a-1'));
      await tester.tap(byKey('address-delete-a-1'));
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(addresses.removed, <String>['a-1']);
      expect(find.text(l10n(tester).addressNone), findsOneWidget);
      expect(find.text(l10n(tester).addressNotRemovedOffline), findsNothing);
      expect(find.text(l10n(tester).addressNotRemovedOther), findsNothing);
    });
  });
}
