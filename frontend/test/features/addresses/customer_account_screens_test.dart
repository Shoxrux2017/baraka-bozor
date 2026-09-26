import 'dart:async';

import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/map_picker.dart';
import 'package:baraka_bozor/features/profile/application/profile_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_customer_repositories.dart';
import '../../support/in_memory_stores.dart';

const GeoPoint _door = GeoPoint(latitude: '41.320000', longitude: '69.250000');

/// A map whose pin moves to [_door] when its button is tapped.
Widget _fakeMap({
  required GeoPoint initial,
  required ValueChanged<GeoPoint> onMoved,
}) => Column(
  children: <Widget>[
    Text(
      '${initial.latitude},${initial.longitude}',
      key: const ValueKey<String>('fake-map-initial'),
    ),
    TextButton(
      key: const ValueKey<String>('fake-map-move'),
      onPressed: () => onMoved(_door),
      child: const Text('move'),
    ),
  ],
);

/// The Customer's profile and addresses (W1-13) through the real router,
/// session and screens.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeAddressesRepository addresses;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore();
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    addresses = FakeAddressesRepository();
    tokens.tokens[SessionSlot.customer] = 'c';
    auth.identities[SessionSlot.customer] = user(id: 'c');
  });

  Future<void> openProfile(
    WidgetTester tester, {
    bool fakeMap = true,
    Size size = const Size(800, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profile),
          addressesRepositoryProvider.overrideWithValue(addresses),
          if (fakeMap) mapPickerProvider.overrideWithValue(_fakeMap),
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

  Future<void> fillNewAddress(WidgetTester tester) async {
    await tapAndSettle(tester, byKey('address-new'));
    await tester.enterText(byKey('field-street'), 'Navoiy');
    await tester.enterText(byKey('field-house'), '5A');
  }

  Finder inForm(Finder finder) =>
      find.descendant(of: find.byType(Form), matching: finder);

  group('profile', () {
    testWidgets('the phone is shown and a name is saved', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);

      expect(find.text(formatPhone('+998901234567')), findsOneWidget);
      expect(find.text(l10n(tester).profileNameNeeded), findsOneWidget);

      await tester.enterText(byKey('profile-name'), '  Aziza Karimova ');
      await tapAndSettle(tester, byKey('profile-save'));

      expect(profile.renames, <String>['Aziza Karimova']);
      expect(find.text(l10n(tester).profileSaved), findsOneWidget);
      expect(find.text(l10n(tester).profileNameNeeded), findsNothing);
    });

    testWidgets('an empty name is refused before sending', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);

      await tapAndSettle(tester, byKey('profile-save'));

      expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
      expect(profile.renames, isEmpty);
    });

    testWidgets('the language chosen here is the interface language', (
      WidgetTester tester,
    ) async {
      await openProfile(tester);

      await tapAndSettle(tester, find.text('Русский'));

      expect(find.text('Профиль'), findsOneWidget);
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
      await tapAndSettle(tester, byKey('fake-map-move'));
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      await tester.enterText(byKey('field-delivery_note'), 'Domofon 12');
      await tapAndSettle(tester, byKey('address-save'));

      final (String? id, AddressDraft draft) = addresses.saved.single;
      expect(id, isNull);
      expect(draft.point, _door);
      expect(draft.street, 'Navoiy');
      expect(draft.label, isNull);
      expect(draft.deliveryNote, 'Domofon 12');
      expect(find.text(l10n(tester).addressSaved), findsOneWidget);
      expect(
        find.text('Navoiy, 5A'),
        findsOneWidget,
        reason: 'back on the list',
      );
    });

    testWidgets('the street and the house are required', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));

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
      await tapAndSettle(tester, byKey('address-new'));
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
      await tapAndSettle(tester, byKey('address-save'));

      expect(
        find.text(l10n(tester).addressOutsideArea('7.25', '5.00')),
        findsOneWidget,
      );
      expect(byKey('address-save'), findsOneWidget, reason: 'the form stays');
    });

    testWidgets('an area not configured yet is explained', (
      WidgetTester tester,
    ) async {
      addresses.saveFailure = const ApiRefusal(
        ApiError(status: 409, code: 'checkout_configuration_incomplete'),
      );
      await openAddresses(tester);
      await tapAndSettle(tester, byKey('address-new'));
      await tester.enterText(byKey('field-street'), 'Navoiy');
      await tester.enterText(byKey('field-house'), '5A');
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
      expect(find.text('41.311081,69.240562'), findsOneWidget);
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

    testWidgets('removing an address asks first', (WidgetTester tester) async {
      await openAddresses(tester);

      await tapAndSettle(tester, byKey('address-remove-a-1'));
      await tapAndSettle(tester, find.text(l10n(tester).cancelButton));
      expect(addresses.removed, isEmpty);

      await tapAndSettle(tester, byKey('address-remove-a-1'));
      await tapAndSettle(tester, byKey('address-remove-confirm'));
      expect(addresses.removed, <String>['a-1']);
      expect(find.text(l10n(tester).addressNone), findsOneWidget);
    });

    testWidgets('without a map key the point is typed', (
      WidgetTester tester,
    ) async {
      await openAddresses(tester, fakeMap: false);
      await tapAndSettle(tester, byKey('address-new'));

      expect(find.text(l10n(tester).addressMapUnavailable), findsOneWidget);
      await tester.enterText(byKey('point-latitude'), '41.33');
      await tester.enterText(byKey('point-longitude'), '69.28');
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
      await tester.pumpAndSettle();
      expect(byKey('address-new'), findsOneWidget);

      addresses.hold!.complete();
      await tester.pumpAndSettle();
      expect(addresses.saved, hasLength(1));
      expect(byKey('address-new'), findsOneWidget, reason: 'still the list');
      expect(find.text(l10n(tester).addressSaved), findsNothing);
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
      expect(find.text(l10n(tester).errorNetwork), findsNothing);

      addresses.removeFailure = const NetworkFailure();
      await tapAndSettle(tester, byKey('address-remove-a-1'));
      await tapAndSettle(tester, byKey('address-remove-confirm'));
      expect(find.text(l10n(tester).errorNetwork), findsOneWidget);

      await tapAndSettle(tester, byKey('address-new'));
      expect(inForm(find.text(l10n(tester).errorNetwork)), findsNothing);
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

      expect(find.text(l10n(tester).addressSaved), findsNothing);
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

      await openProfile(tester, size: const Size(320, 568));
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
      await tester.pumpAndSettle();
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
        overrides: [
          profileRepositoryProvider.overrideWithValue(profile),
          addressesRepositoryProvider.overrideWithValue(addresses),
          mapPickerProvider.overrideWithValue(_fakeMap),
        ],
      ),
    );
    await tester.pumpAndSettle();
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
}
