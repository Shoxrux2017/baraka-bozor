import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/address_point_step.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/point_fields_address_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_address_map.dart';
import '../../support/fake_address_search.dart';
import '../../support/fake_device_location.dart';

void main() {
  const GeoPoint start = GeoPoint(
    latitude: '41.311081',
    longitude: '69.240562',
  );
  const GeoPoint found = GeoPoint(
    latitude: '41.299512',
    longitude: '69.240146',
  );
  const GeoPoint other = GeoPoint(
    latitude: '41.280000',
    longitude: '69.200000',
  );

  late FakeAddressSearch search;
  late FakeDeviceLocation location;
  late List<AddressPointResult> confirmed;

  setUp(() {
    search = FakeAddressSearch();
    location = FakeDeviceLocation();
    confirmed = <AddressPointResult>[];
  });

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AddressPointStep)));

  Future<void> open(
    WidgetTester tester, {
    AddressMap? map,
    Locale locale = const Locale('uz'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressMapProvider.overrideWithValue(map ?? FakeAddressMap()),
          addressSearchRepositoryProvider.overrideWithValue(search),
          deviceLocationProvider.overrideWithValue(location),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddressPointStep(initial: start, onConfirmed: confirmed.add),
          ),
        ),
      ),
    );
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(byKey('address-search-field'), text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(byKey('address-point-confirm'));
    await tester.pump();
  }

  String target(WidgetTester tester) =>
      tester.widget<Text>(byKey('fake-map-target')).data!;

  testWidgets('the pin starts where it was given and confirms where it was '
      'left', (WidgetTester tester) async {
    await open(tester);
    expect(
      tester.widget<Text>(byKey('fake-map-initial')).data,
      '41.311081,69.240562',
    );
    expect(find.text(l10n(tester).addressMapHint), findsOneWidget);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    await confirm(tester);

    expect(confirmed.single.point, fakeDoor);
    expect(confirmed.single.words, isNull);
  });

  testWidgets('a typed address moves the map and is kept', (
    WidgetTester tester,
  ) async {
    search.answers['Navoiy 5'] = found;
    await open(tester);
    await type(tester, 'Navoiy 5');
    await tester.pump();

    expect(target(tester), '41.299512,69.240146');
    expect(find.text(l10n(tester).addressSearchFound), findsOneWidget);
    expect(byKey('address-words-kept'), findsOneWidget);

    await confirm(tester);
    expect(confirmed.single.point, found);
    expect(confirmed.single.words, 'Navoiy 5');
  });

  testWidgets('nothing found asks for the pin and keeps the words', (
    WidgetTester tester,
  ) async {
    search.answers['Navoiy 5'] = null;
    await open(tester);
    await type(tester, 'Navoiy 5');
    await tester.pump();

    expect(byKey('address-search-not-found'), findsOneWidget);
    expect(find.text(l10n(tester).addressSearchNotFound), findsOneWidget);
    expect(byKey('address-words-kept'), findsOneWidget);

    await confirm(tester);
    expect(confirmed.single.point, start);
    expect(confirmed.single.words, 'Navoiy 5');
  });

  testWidgets('an unavailable search says so', (WidgetTester tester) async {
    search.failures['Navoiy 5'] = const NetworkFailure();
    search.failures['Navoiy 7'] = const ApiRefusal(
      ApiError(status: 503, code: 'provider_unavailable'),
    );
    await open(tester);

    await type(tester, 'Navoiy 5');
    await tester.pump();
    expect(byKey('address-search-unavailable'), findsOneWidget);
    expect(byKey('address-words-kept'), findsOneWidget);

    await type(tester, 'Navoiy 7');
    await tester.pump();
    expect(byKey('address-search-unavailable'), findsOneWidget);
    await confirm(tester);
    expect(confirmed.single.words, 'Navoiy 7');
  });

  testWidgets('two characters search nothing', (WidgetTester tester) async {
    await open(tester);
    await type(tester, ' Na ');

    expect(search.queries, isEmpty);
  });

  testWidgets('clearing forgets the words', (WidgetTester tester) async {
    search.answers['Navoiy 5'] = null;
    await open(tester);
    await type(tester, 'Navoiy 5');
    await tester.pump();
    expect(byKey('address-search-not-found'), findsOneWidget);

    await tester.tap(byKey('address-search-clear'));
    await tester.pump();

    expect(byKey('address-search-not-found'), findsNothing);
    expect(byKey('address-words-kept'), findsNothing);
    expect(find.text(l10n(tester).addressPointText), findsOneWidget);
    await confirm(tester);
    expect(confirmed.single.words, isNull);
  });

  testWidgets('a late answer does not move a map the Customer moved', (
    WidgetTester tester,
  ) async {
    search.held.add('Navoiy 5');
    await open(tester);
    await type(tester, 'Navoiy 5');
    expect(byKey('address-search-busy'), findsOneWidget);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    search.release('Navoiy 5', found);
    await tester.pump();

    expect(target(tester), '');
    expect(byKey('address-search-busy'), findsNothing);
    await confirm(tester);
    expect(confirmed.single.point, fakeDoor);
    expect(confirmed.single.words, 'Navoiy 5');
  });

  testWidgets('an older answer after a newer search is ignored', (
    WidgetTester tester,
  ) async {
    search.held.add('Navoiy 5');
    search.answers['Navoiy 7'] = other;
    await open(tester);
    await type(tester, 'Navoiy 5');
    await type(tester, 'Navoiy 7');
    await tester.pump();
    search.release('Navoiy 5', found);
    await tester.pump();

    expect(target(tester), '41.280000,69.200000');
    await confirm(tester);
    expect(confirmed.single.point, other);
    expect(confirmed.single.words, 'Navoiy 7');
  });

  testWidgets('where am I moves the map', (WidgetTester tester) async {
    location.point = found;
    await open(tester);
    await tester.tap(byKey('address-my-location'));
    await tester.pump();

    expect(target(tester), '41.299512,69.240146');
    await confirm(tester);
    expect(confirmed.single.point, found);
  });

  testWidgets('where am I is off while it runs and drops a late answer', (
    WidgetTester tester,
  ) async {
    location.hold = true;
    await open(tester);
    await tester.tap(byKey('address-my-location'));
    await tester.pump();
    await tester.tap(byKey('address-my-location'), warnIfMissed: false);
    await tester.pump();
    expect(location.calls, 1);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    location.release(found);
    await tester.pump();

    expect(target(tester), '');
    await confirm(tester);
    expect(confirmed.single.point, fakeDoor);
  });

  testWidgets('a refused location says so and leaves the map', (
    WidgetTester tester,
  ) async {
    location.hold = true;
    await open(tester);
    await tester.tap(byKey('address-my-location'));
    await tester.pump();
    location.release(null);
    await tester.pump();

    expect(find.text(l10n(tester).addressLocationFailed), findsOneWidget);
    expect(target(tester), '');
    location.hold = false;
    location.point = found;
    await tester.tap(byKey('address-my-location'));
    await tester.pump();
    expect(location.calls, 2);
    await confirm(tester);
    expect(confirmed.single.point, found);
  });

  testWidgets('without a map the point is typed', (WidgetTester tester) async {
    // The fake map has no fields; the real fields map is the one that is
    // not movable.
    await open(tester, map: const PointFieldsAddressMap());

    expect(byKey('address-search-field'), findsNothing);
    expect(byKey('address-my-location'), findsNothing);
    expect(byKey('point-latitude'), findsOneWidget);

    await tester.enterText(byKey('point-latitude'), '');
    await confirm(tester);
    expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
    expect(confirmed, isEmpty);

    await tester.enterText(byKey('point-latitude'), '41.3');
    await confirm(tester);
    expect(confirmed, hasLength(1));
    expect(confirmed.single.words, isNull);
  });

  for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('the step holds at 320x640 with text x2 '
        '(${locale.languageCode})', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      search.answers['Navoiy 5'] = null;
      search.failures['Navoiy 7'] = const NetworkFailure();

      await open(tester, locale: locale);
      expect(tester.takeException(), isNull);

      await type(tester, 'Navoiy 5');
      await tester.pump();
      expect(byKey('address-search-not-found'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await type(tester, 'Navoiy 7');
      await tester.pump();
      expect(byKey('address-search-unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
