import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/address_point_step.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/map_pin.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/point_fields_address_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_address_map.dart';
import '../../support/fake_address_search.dart';
import '../../support/fake_device_location.dart';
import '../../support/nonlinear_text_scaler.dart';

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
    bool keepsWords = true,
    bool placed = true,
    Address? openedAt,
    GeoPoint? initial,
    TextScaler? scaler,
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
          builder: scaler == null
              ? null
              : (BuildContext context, Widget? child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: scaler),
                  child: child!,
                ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddressPointStep(
              key: UniqueKey(),
              initial: initial ?? start,
              placed: placed,
              openedAt: openedAt,
              keepsWords: keepsWords,
              onConfirmed: confirmed.add,
            ),
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

  testWidgets('the step draws the pin over a movable map and none over the '
      'fields', (WidgetTester tester) async {
    await open(tester);

    expect(find.byType(MapPin), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);

    await open(tester, map: const PointFieldsAddressMap());

    expect(find.byType(MapPin), findsNothing);
    expect(find.byIcon(Icons.location_on), findsNothing);
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

  testWidgets('the words are not promised where the street will not take '
      'them', (WidgetTester tester) async {
    search.answers['Navoiy 5'] = found;
    await open(tester, keepsWords: false);
    await type(tester, 'Navoiy 5');
    await tester.pump();

    expect(find.text(l10n(tester).addressSearchFound), findsOneWidget);
    expect(byKey('address-words-kept'), findsNothing);
    await confirm(tester);
    expect(confirmed.single.words, 'Navoiy 5');
  });

  testWidgets('the search field takes 200 characters', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.enterText(byKey('address-search-field'), 'a' * 250);
    await tester.pump();

    expect(
      tester.widget<TextField>(byKey('address-search-field')).controller!.text,
      'a' * 200,
    );
    expect(find.text('200/200'), findsNothing, reason: 'no counter');
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
    location.outcome = LocationFound(found);
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
    location.release(LocationFound(found));
    await tester.pump();

    expect(target(tester), '');
    await confirm(tester);
    expect(confirmed.single.point, fakeDoor);
  });

  testWidgets('a camera report while the location is read still moves the '
      'map', (WidgetTester tester) async {
    final FakeAddressMap map = FakeAddressMap();
    location.hold = true;
    await open(tester, map: map);
    await tester.tap(byKey('address-my-location'));
    await tester.pump();

    map.emitMove(fakeDoor);
    await tester.pump();
    location.release(LocationFound(found));
    await tester.pump();

    expect(target(tester), '41.299512,69.240146');
    await confirm(tester);
    expect(confirmed.single.point, found);
  });

  testWidgets('a camera report while a search runs still moves the map', (
    WidgetTester tester,
  ) async {
    final FakeAddressMap map = FakeAddressMap();
    search.held.add('Navoiy 5');
    await open(tester, map: map);
    await type(tester, 'Navoiy 5');

    map.emitMove(fakeDoor);
    await tester.pump();
    search.release('Navoiy 5', found);
    await tester.pump();

    expect(target(tester), '41.299512,69.240146');
    await confirm(tester);
    expect(confirmed.single.point, found);
    expect(confirmed.single.words, 'Navoiy 5');
  });

  testWidgets('a refused location says so and leaves the map', (
    WidgetTester tester,
  ) async {
    location.hold = true;
    await open(tester);
    await tester.tap(byKey('address-my-location'));
    await tester.pump();
    location.release(const LocationFailed(LocationFailure.failed));
    await tester.pump();

    expect(find.text(l10n(tester).addressLocationFailed), findsOneWidget);
    expect(target(tester), '');
    location.hold = false;
    location.outcome = LocationFound(found);
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

  MapPin pin(WidgetTester tester) => tester.widget<MapPin>(find.byType(MapPin));

  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(byKey('address-point-confirm'));

  const Address home = Address(
    id: 'a-1',
    label: 'Дом',
    point: GeoPoint(latitude: '41.320000', longitude: '69.260000'),
    street: 'Navoiy',
    house: '5',
    apartment: null,
    landmark: null,
    deliveryNote: null,
  );

  testWidgets('the pin lifts while the Customer moves the map and drops with '
      'a light tap', (WidgetTester tester) async {
    final List<String> taps = haptics(tester);
    await open(tester);
    expect(pin(tester).lifted, isFalse);

    await tester.tap(byKey('fake-map-start'));
    await tester.pump();
    expect(pin(tester).lifted, isTrue);
    expect(taps, isEmpty);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    expect(pin(tester).lifted, isFalse);
    expect(pin(tester).drops, 1);
    expect(taps, <String>['HapticFeedbackType.lightImpact']);
    await tester.pumpAndSettle();
  });

  testWidgets('a search moves the pin without lifting it or tapping', (
    WidgetTester tester,
  ) async {
    final List<String> taps = haptics(tester);
    final FakeAddressMap map = FakeAddressMap();
    search.answers['Navoiy 5'] = found;
    await open(tester, map: map);
    await type(tester, 'Navoiy 5');
    await tester.pump();
    map.emitMove(found);
    await tester.pump();

    expect(pin(tester).lifted, isFalse);
    expect(pin(tester).drops, 0);
    expect(taps, isEmpty);
  });

  testWidgets('the hint fades after the first move', (
    WidgetTester tester,
  ) async {
    await open(tester);
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: byKey('address-point-hint'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(opacity(), 1);

    await tester.tap(byKey('fake-map-start'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(byKey('fake-map-far'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0);
  });

  testWidgets('opened without a fix the map starts at the delivery address '
      'and confirm waits', (WidgetTester tester) async {
    await open(
      tester,
      locale: const Locale('ru'),
      placed: false,
      openedAt: home,
      initial: home.point,
    );

    expect(
      tester.widget<Text>(byKey('fake-map-initial')).data,
      '41.320000,69.260000',
    );
    expect(confirmButton(tester).onPressed, isNull);
    expect(find.text('Сначала передвиньте карту к дому'), findsOneWidget);
    expect(
      find.text(
        'Карта открыта у вашего адреса «Дом». Передвиньте её так, чтобы метка '
        'встала на вход нового дома.',
      ),
      findsOneWidget,
    );
    await tester.tap(byKey('address-point-confirm'), warnIfMissed: false);
    await tester.pump();
    expect(confirmed, isEmpty);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
    expect(find.text('Сначала передвиньте карту к дому'), findsNothing);
    await confirm(tester);
    expect(confirmed.single.point, fakeDoor);
  });

  testWidgets('a search or Где я places the pin too', (
    WidgetTester tester,
  ) async {
    search.answers['Navoiy 5'] = found;
    await open(tester, placed: false);
    expect(confirmButton(tester).onPressed, isNull);
    await type(tester, 'Navoiy 5');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
    await confirm(tester);
    expect(confirmed.single.point, found);

    location.outcome = LocationFound(other);
    await open(tester, placed: false);
    expect(confirmButton(tester).onPressed, isNull);
    await tester.tap(byKey('address-my-location'));
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
    await confirm(tester);
    expect(confirmed.last.point, other);
  });

  testWidgets('opened with the location already allowed the map starts '
      'there', (WidgetTester tester) async {
    location.silent = found;
    await open(tester, placed: false, openedAt: home);
    await tester.pump();

    expect(target(tester), '41.299512,69.240146');
    expect(confirmButton(tester).onPressed, isNotNull);
    expect(location.calls, 0, reason: 'nothing was asked');
    expect(location.silentCalls, 1);
    await confirm(tester);
    expect(confirmed.single.point, found);
  });

  testWidgets('a silent fix after a touch does not move the map', (
    WidgetTester tester,
  ) async {
    location.holdSilent = true;
    await open(tester, placed: false);
    await tester.tap(byKey('fake-map-start'));
    await tester.pump();
    location.releaseSilent(found);
    await tester.pump();

    expect(target(tester), '');
    expect(confirmButton(tester).onPressed, isNull);

    search.answers['Navoiy 5'] = other;
    location.holdSilent = true;
    await open(tester, placed: false);
    await type(tester, 'Navoiy 5');
    await tester.pump();
    expect(target(tester), '41.280000,69.200000');
    location.releaseSilent(found);
    await tester.pump();
    expect(target(tester), '41.280000,69.200000');
  });

  testWidgets('with no address the map starts at the city centre', (
    WidgetTester tester,
  ) async {
    await open(tester, placed: false, initial: defaultMapCentre);

    expect(
      tester.widget<Text>(byKey('fake-map-initial')).data,
      '${defaultMapCentre.latitude},${defaultMapCentre.longitude}',
    );
    expect(confirmButton(tester).onPressed, isNull);
    expect(find.text(l10n(tester).addressPointText), findsOneWidget);
  });

  testWidgets('an edit map and the way back from the details start placed', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(confirmButton(tester).onPressed, isNotNull);
    expect(find.text(l10n(tester).addressMoveFirst), findsNothing);
    await confirm(tester);
    expect(confirmed.single.point, start);
  });

  testWidgets('the confirm result carries the map height', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await confirm(tester);

    expect(confirmed.single.mapHeight, greaterThan(100));
    expect(confirmed.single.place, isNull);
  });

  testWidgets('large text drops the hint and the panel says it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(
      tester,
      locale: const Locale('ru'),
      placed: false,
      scaler: const NonlinearTextScaler(2),
    );

    expect(byKey('address-point-hint'), findsNothing);
    expect(
      find.text(
        'Передвиньте карту, чтобы метка встала на вход в дом. Квартиру и '
        'подъезд укажете на следующем шаге.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
      search.answers['Navoiy 9'] = found;
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

      await type(tester, 'Navoiy 9');
      await tester.pump();
      expect(
        find.text(l10n(tester).addressSearchFound),
        findsNothing,
        reason: 'large text has no hint',
      );
      expect(byKey('address-words-kept'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
