import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/widgets/skeleton_bar.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/data/device_location.dart';
import 'package:baraka_bozor/features/addresses/domain/address_search.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/address_point_step.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/map_pin.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/point_fields_address_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
        retry: (int count, Object error) => null,
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
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == Icons.location_on && w.size == 48,
      ),
      findsOneWidget,
    );

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
    expect(byKey('address-search-result'), findsOneWidget);
    expect(
      byKey('address-words-kept'),
      findsNothing,
      reason: 'a found address needs no promise; the street is filled',
    );

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

    expect(byKey('address-search-result'), findsOneWidget);
    expect(
      find.text(l10n(tester).addressSearchNotFoundAt('Navoiy 5')),
      findsOneWidget,
    );
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
    expect(find.text(l10n(tester).addressSearchDown), findsOneWidget);
    expect(byKey('address-words-kept'), findsOneWidget);

    await type(tester, 'Navoiy 7');
    await tester.pump();
    expect(find.text(l10n(tester).addressSearchDown), findsOneWidget);
    await confirm(tester);
    expect(confirmed.single.words, 'Navoiy 7');
  });

  testWidgets('the words are not promised where the street will not take '
      'them', (WidgetTester tester) async {
    search.answers['Navoiy 5'] = found;
    await open(tester, keepsWords: false);
    await type(tester, 'Navoiy 5');
    await tester.pump();

    expect(byKey('address-search-result'), findsOneWidget);
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
    expect(byKey('address-search-result'), findsOneWidget);

    await tester.tap(byKey('address-search-clear'));
    await tester.pump();

    expect(byKey('address-search-result'), findsNothing);
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

  testWidgets('a camera report with no finger on the map is not the '
      "Customer's move", (WidgetTester tester) async {
    final List<String> taps = haptics(tester);
    final FakeAddressMap map = FakeAddressMap();
    search.places[fakeDoor] = const PointAddress(
      line: 'Navoiy 12',
      houseKnown: true,
    );
    await open(tester, map: map, placed: false);

    map.emitSystemCamera(fakeDoor);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(pin(tester).lifted, isFalse);
    expect(pin(tester).drops, 0);
    expect(taps, isEmpty);
    expect(search.lookups, isEmpty);
    expect(confirmButton(tester).onPressed, isNull);
    expect(byKey('address-point-place'), findsNothing);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: byKey('address-point-hint'),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity,
      1,
    );
  });

  testWidgets('a held silent fix still lands after a camera report with no '
      'finger', (WidgetTester tester) async {
    final FakeAddressMap map = FakeAddressMap();
    location.holdSilent = true;
    await open(tester, map: map, placed: false);

    map.emitSystemCamera(fakeDoor);
    await tester.pump();
    location.releaseSilent(found);
    await tester.pump();
    await tester.pump();

    expect(target(tester), '41.299512,69.240146');
    await confirm(tester);
    expect(confirmed.single.point, found);
  });

  testWidgets('a finger that lifted without moving the map does not make a '
      "later camera report the Customer's", (WidgetTester tester) async {
    final FakeAddressMap map = FakeAddressMap();
    await open(tester, map: map, placed: false);

    await tester.tapAt(const Offset(10, 300));
    await tester.pump(const Duration(seconds: 1));
    map.emitSystemCamera(fakeDoor);
    await tester.pump();

    expect(pin(tester).lifted, isFalse);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('the hint goes once a search has answered, and stays gone', (
    WidgetTester tester,
  ) async {
    search.answers['Navoiy 5'] = null;
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

    await type(tester, 'Navoiy 5');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0);

    await tester.tap(byKey('address-search-clear'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0, reason: 'the hint never returns');
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

  testWidgets('Где я drops a silent fix still on its way', (
    WidgetTester tester,
  ) async {
    location.holdSilent = true;
    location.outcome = LocationFound(other);
    await open(tester, placed: false);
    await tester.tap(byKey('address-my-location'));
    await tester.pump();
    await tester.pump();
    expect(target(tester), '41.280000,69.200000');

    location.releaseSilent(found);
    await tester.pump();
    await tester.pump();

    expect(target(tester), '41.280000,69.200000');
    await confirm(tester);
    expect(confirmed.single.point, other);
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

  testWidgets('the map height the morph starts from ignores the keyboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    await confirm(tester);
    final double closed = confirmed.single.mapHeight;

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await confirm(tester);

    expect(confirmed.last.mapHeight, closeTo(closed, 0.5));
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

  const PointAddress door = PointAddress(
    line: "Navoiy ko'chasi, 12",
    houseKnown: true,
  );
  const ServiceArea zone = ServiceArea(centre: start, radiusKm: '10.00');
  const Duration rest = Duration(milliseconds: 400);

  Future<void> moveAndRest(WidgetTester tester, String move) async {
    await tester.tap(byKey(move));
    await tester.pump();
    await tester.pump(rest);
    await tester.pump();
  }

  Finder lookingRow() => find.byType(SkeletonBar);

  List<String> spoken(WidgetTester tester) => tester
      .takeAnnouncements()
      .map((CapturedAccessibilityAnnouncement a) => a.message)
      .toList();

  testWidgets('the panel names the address under the pin once the map rests', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    search.places[fakeDoor] = door;
    await open(tester, locale: const Locale('ru'));

    await tester.tap(byKey('fake-map-start'));
    await tester.pump();
    expect(lookingRow(), findsOneWidget);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    expect(lookingRow(), findsOneWidget);
    expect(search.lookups, isEmpty, reason: 'waits 400 ms after the rest');
    await tester.pump(rest);
    await tester.pump();

    expect(search.lookups, <(GeoPoint, String)>[(fakeDoor, 'ru')]);
    expect(lookingRow(), findsNothing);
    expect(find.text("Navoiy ko'chasi, 12"), findsOneWidget);
    expect(
      tester
          .getSemantics(byKey('address-point-place'))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    await confirm(tester);
    expect(confirmed.single.place?.line, "Navoiy ko'chasi, 12");
    semantics.dispose();
  });

  testWidgets('the place row reads Ищем адрес while it looks', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester, locale: const Locale('ru'));
    await tester.tap(byKey('fake-map-start'));
    await tester.pump();

    expect(
      tester.getSemantics(byKey('address-point-place')).label,
      'Ищем адрес',
    );
    semantics.dispose();
  });

  testWidgets('a point without a house says to put the pin on a building', (
    WidgetTester tester,
  ) async {
    search.places[fakeDoor] = const PointAddress(
      line: "Navoiy ko'chasi",
      houseKnown: false,
    );
    await open(tester, locale: const Locale('ru'));
    await moveAndRest(tester, 'fake-map-move');

    expect(find.text("Navoiy ko'chasi"), findsOneWidget);
    expect(
      find.text('Дом не определили — поставьте метку на здание'),
      findsOneWidget,
    );
    await confirm(tester);
    expect(confirmed.single.place?.houseKnown, isFalse);
  });

  testWidgets('nothing known says so', (WidgetTester tester) async {
    await open(tester, locale: const Locale('ru'));
    await moveAndRest(tester, 'fake-map-move');

    expect(find.text('Адрес не определили'), findsOneWidget);
    expect(find.text('Поставьте метку на здание'), findsOneWidget);
    await confirm(tester);
    expect(confirmed.single.place, isNull);
  });

  testWidgets('a failed lookup shows no row and confirm still works', (
    WidgetTester tester,
  ) async {
    for (final ApiFailure failure in const <ApiFailure>[
      NetworkFailure(),
      ApiRefusal(ApiError(status: 429, code: 'rate_limited')),
      ApiRefusal(ApiError(status: 503, code: 'provider_unavailable')),
    ]) {
      search.placeFailure = failure;
      await open(tester, locale: const Locale('ru'));
      await moveAndRest(tester, 'fake-map-move');

      expect(byKey('address-point-place'), findsNothing);
      expect(lookingRow(), findsNothing);
      expect(confirmButton(tester).onPressed, isNotNull);
      await confirm(tester);
      expect(confirmed.last.point, fakeDoor);
      expect(confirmed.last.place, isNull);
    }
  });

  for (final (String, int?, int) pause in <(String, int?, int)>[
    ('the Retry-After it carried', 30, 30),
    ('60 s when it carried none', null, 60),
  ]) {
    testWidgets('after a 429 no lookup goes out for ${pause.$1}', (
      WidgetTester tester,
    ) async {
      search.placeFailure = ApiRefusal(
        const ApiError(status: 429, code: 'rate_limited'),
        retryAfterSeconds: pause.$2,
      );
      await open(tester, locale: const Locale('ru'));
      await moveAndRest(tester, 'fake-map-move');
      expect(search.lookups, hasLength(1));

      search.placeFailure = null;
      search.places[fakeDoor] = door;
      await moveAndRest(tester, 'fake-map-far');
      expect(search.lookups, hasLength(1), reason: 'paused');
      expect(byKey('address-point-place'), findsNothing);
      expect(confirmButton(tester).onPressed, isNotNull);

      await tester.pump(Duration(seconds: pause.$3 - 1));
      await moveAndRest(tester, 'fake-map-move');
      expect(search.lookups, hasLength(1), reason: 'still paused');

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(rest);
      await tester.pump();
      expect(search.lookups, hasLength(2), reason: 'the pause is over');
      expect(find.text("Navoiy ko'chasi, 12"), findsOneWidget);
    });
  }

  testWidgets('a map reopened with the place it knows asks nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressMapProvider.overrideWithValue(FakeAddressMap()),
          addressSearchRepositoryProvider.overrideWithValue(search),
          deviceLocationProvider.overrideWithValue(location),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddressPointStep(
              initial: fakeDoor,
              placed: true,
              place: door,
              keepsWords: true,
              onConfirmed: confirmed.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump(rest);
    await tester.pump();

    expect(search.lookups, isEmpty);
    expect(find.text("Navoiy ko'chasi, 12"), findsOneWidget);
    await confirm(tester);
    expect(confirmed.single.place?.line, "Navoiy ko'chasi, 12");

    await tester.tap(byKey('fake-map-far'));
    await tester.pump();
    await tester.pump(rest);
    expect(search.lookups, hasLength(1), reason: 'a new place is asked for');
  });

  testWidgets('a late answer for an older point is not shown', (
    WidgetTester tester,
  ) async {
    search.heldPlaces.add(fakeDoor);
    search.places[fakeFar] = const PointAddress(
      line: 'Chilonzor 9, 14',
      houseKnown: true,
    );
    await open(tester, locale: const Locale('ru'));
    await moveAndRest(tester, 'fake-map-move');
    expect(search.lookups, hasLength(1));

    await tester.tap(byKey('fake-map-far'));
    await tester.pump();
    search.releasePlace(fakeDoor, door);
    await tester.pump();
    expect(find.text("Navoiy ko'chasi, 12"), findsNothing);
    expect(lookingRow(), findsOneWidget);

    await tester.pump(rest);
    await tester.pump();
    expect(find.text("Navoiy ko'chasi, 12"), findsNothing);
    expect(find.text('Chilonzor 9, 14'), findsOneWidget);
    await confirm(tester);
    expect(confirmed.single.place?.line, 'Chilonzor 9, 14');
  });

  testWidgets('a rest within 15 m asks nothing again', (
    WidgetTester tester,
  ) async {
    search.places[fakeDoor] = door;
    await open(tester, locale: const Locale('ru'));
    await moveAndRest(tester, 'fake-map-move');
    expect(search.lookups, hasLength(1));

    await tester.tap(byKey('fake-map-start'));
    await tester.pump();
    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    expect(lookingRow(), findsNothing, reason: 'the answer is reused');
    await tester.pump(rest);
    await tester.pump();
    expect(search.lookups, hasLength(1));
    expect(find.text("Navoiy ko'chasi, 12"), findsOneWidget);

    await moveAndRest(tester, 'fake-map-far');
    expect(search.lookups, hasLength(2));
  });

  testWidgets('the fields map looks nothing up', (WidgetTester tester) async {
    await open(tester, map: FakeAddressMap(movable: false));
    await tester.pump(rest);
    await tester.pump();

    expect(search.lookups, isEmpty);
    expect(byKey('address-point-place'), findsNothing);
  });

  testWidgets('an unplaced pin is not looked up', (WidgetTester tester) async {
    await open(tester, placed: false);
    await tester.pump(rest);
    await tester.pump();

    expect(search.lookups, isEmpty);
    expect(byKey('address-point-place'), findsNothing);
    await tester.tap(byKey('fake-map-start'));
    await tester.pump();
    await tester.pump(rest);
    expect(search.lookups, isEmpty, reason: 'still moving');
  });

  testWidgets('outside the zone the map says how far and confirm waits', (
    WidgetTester tester,
  ) async {
    final FakeAddressMap map = FakeAddressMap();
    search.area = zone;
    await open(tester, map: map, locale: const Locale('ru'));
    await tester.pump();
    expect(map.zone, isNotNull);
    tester.takeAnnouncements();

    await tester.tap(byKey('fake-map-far'));
    await tester.pump();

    expect(
      find.text(
        'Сюда пока не возим: до метки 11,7 км, а возим в радиусе 10 км. '
        'Передвиньте метку ближе к городу.',
      ),
      findsOneWidget,
    );
    expect(byKey('address-outside-zone'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
    expect(find.text(l10n(tester).addressConfirmWhyZone), findsNothing);
    expect(
      spoken(tester),
      contains('Сюда пока не возим: 11,7 километра, возим в радиусе 10'),
    );
    await tester.tap(byKey('address-point-confirm'), warnIfMissed: false);
    await tester.pump();
    expect(confirmed, isEmpty);

    await tester.tap(byKey('fake-map-move'));
    await tester.pump();
    expect(byKey('address-outside-zone'), findsNothing);
    expect(confirmButton(tester).onPressed, isNotNull);
    await confirm(tester);
    expect(confirmed.single.point, fakeDoor);
  });

  testWidgets('while the zone is still loading nothing is outside', (
    WidgetTester tester,
  ) async {
    search.holdArea = true;
    search.area = zone;
    await open(tester, locale: const Locale('ru'));
    await tester.pump();

    await tester.tap(byKey('fake-map-far'));
    await tester.pump();
    expect(byKey('address-outside-zone'), findsNothing);
    expect(confirmButton(tester).onPressed, isNotNull);

    search.releaseArea(zone);
    await tester.pump();
    await tester.pump();
    expect(byKey('address-outside-zone'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('without a zone nothing is outside', (WidgetTester tester) async {
    search.areaFailure = const NetworkFailure();
    await open(tester);
    await tester.pump();
    await tester.tap(byKey('fake-map-far'));
    await tester.pump();

    expect(byKey('address-outside-zone'), findsNothing);
    expect(confirmButton(tester).onPressed, isNotNull);
    await confirm(tester);
    expect(confirmed.single.point, fakeFar);

    search.areaFailure = null;
    search.area = null;
    await open(tester);
    await tester.pump();
    await tester.tap(byKey('fake-map-far'));
    await tester.pump();
    expect(byKey('address-outside-zone'), findsNothing);
    await confirm(tester);
    expect(confirmed.last.point, fakeFar);
  });

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(byKey('address-search-field'), text);
    await tester.pump();
  }

  testWidgets(
    'the green arrow searches and the answer stands under the field',
    (WidgetTester tester) async {
      search.answers['Chilonzor 9-kvartal, 14'] = found;
      await open(tester, locale: const Locale('ru'));
      tester.takeAnnouncements();

      await enter(tester, 'Ch');
      expect(byKey('address-search-go'), findsNothing);
      await enter(tester, 'Chilonzor 9-kvartal, 14');
      expect(byKey('address-search-go'), findsOneWidget);
      expect(search.queries, isEmpty);

      await tester.tap(byKey('address-search-go'));
      await tester.pump();
      await tester.pump();

      expect(search.queries, <String>['Chilonzor 9-kvartal, 14']);
      expect(
        find.text(
          'Нашли: «Chilonzor 9-kvartal, 14». Проверьте, что метка на вашем '
          'доме.',
        ),
        findsOneWidget,
      );
      final Text result = tester.widget<Text>(
        find
            .descendant(
              of: byKey('address-search-result'),
              matching: find.byType(Text),
            )
            .first,
      );
      final List<TextSpan> bold = <TextSpan>[];
      result.textSpan!.visitChildren((InlineSpan span) {
        if (span is TextSpan && span.style?.fontWeight == FontWeight.w700) {
          bold.add(span);
        }
        return true;
      });
      expect(bold.single.text, 'Chilonzor 9-kvartal, 14');
      expect(spoken(tester), contains('Нашли адрес. Метка передвинута'));
      expect(byKey('address-search-clear'), findsOneWidget);
    },
  );

  testWidgets('not found and unavailable are said under the field with the '
      'kept words', (WidgetTester tester) async {
    search.answers['Navoiy 5'] = null;
    search.failures['Navoiy 7'] = const NetworkFailure();
    await open(tester, locale: const Locale('ru'));

    await enter(tester, 'Navoiy 5');
    await tester.tap(byKey('address-search-go'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Не нашли «Navoiy 5». Передвиньте карту к дому сами.'),
      findsOneWidget,
    );
    expect(find.text(l10n(tester).addressWordsKept), findsOneWidget);

    await enter(tester, 'Navoiy 7');
    await tester.tap(byKey('address-search-go'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Поиск сейчас не работает. Передвиньте карту сами.'),
      findsOneWidget,
    );
    expect(find.text(l10n(tester).addressWordsKept), findsOneWidget);
  });

  group('Где я says why it failed and offers the way out', () {
    Future<void> fail(WidgetTester tester, LocationFailure why) async {
      location.outcome = LocationFailed(why);
      await open(tester, locale: const Locale('ru'));
      await tester.tap(byKey('address-my-location'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('forever denied opens the settings', (
      WidgetTester tester,
    ) async {
      await fail(tester, LocationFailure.deniedForever);
      expect(
        find.text(
          'Доступ к геолокации запрещён. Разрешите в настройках или '
          'передвиньте карту сами.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.widgetWithText(SnackBarAction, 'Настройки'));
      await tester.pump();
      expect(location.settingsOpened, 1);
    });

    testWidgets('service off opens the location settings', (
      WidgetTester tester,
    ) async {
      await fail(tester, LocationFailure.serviceOff);
      expect(find.text('Геолокация на телефоне выключена.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.widgetWithText(SnackBarAction, 'Включить'));
      await tester.pump();
      expect(location.locationSettingsOpened, 1);
    });

    testWidgets('a time out reads again', (WidgetTester tester) async {
      await fail(tester, LocationFailure.timedOut);
      expect(
        find.text('Не нашли вас за 10 секунд. Передвиньте карту сами.'),
        findsOneWidget,
      );
      expect(location.calls, 1);
      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.widgetWithText(SnackBarAction, 'Ещё раз'));
      await tester.pump();
      expect(location.calls, 2);
    });

    testWidgets('denied and failed have no action', (
      WidgetTester tester,
    ) async {
      for (final LocationFailure why in const <LocationFailure>[
        LocationFailure.denied,
        LocationFailure.failed,
      ]) {
        await fail(tester, why);
        expect(find.text(l10n(tester).addressLocationFailed), findsOneWidget);
        expect(find.byType(SnackBarAction), findsNothing);
      }
    });

    testWidgets('a found place is announced', (WidgetTester tester) async {
      location.outcome = LocationFound(found);
      await open(tester, locale: const Locale('ru'));
      tester.takeAnnouncements();
      await tester.tap(byKey('address-my-location'));
      await tester.pump();
      await tester.pump();
      expect(spoken(tester), contains('Метка там, где вы'));
    });
  });

  testWidgets('the map is one reader stop that names the pin', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    search.places[fakeDoor] = door;
    await open(tester, locale: const Locale('ru'), placed: false);

    expect(
      tester.getSemantics(byKey('address-point-map')).label,
      'Карта, метка в центре. Без карты метку ставят поиском или кнопкой '
      '«Где я»',
    );
    expect(
      tester.getSemantics(byKey('address-point-confirm')).hint,
      'недоступна: сначала передвиньте карту',
    );
    expect(
      tester.getSemantics(byKey('address-search-field')).label,
      contains('Адрес словами. Найдём и передвинем метку'),
    );
    expect(
      tester.getSemantics(byKey('address-my-location')).label,
      'Где я: поставить метку туда, где вы',
    );

    await moveAndRest(tester, 'fake-map-move');
    expect(
      tester.getSemantics(byKey('address-point-map')).label,
      "Карта, метка в центре. Метка: Navoiy ko'chasi, 12. Без карты метку "
      'ставят поиском или кнопкой «Где я»',
    );
    semantics.dispose();
  });

  testWidgets('the off button says why when the pin is outside', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    search.area = zone;
    await open(tester, locale: const Locale('ru'));
    await tester.pump();
    await tester.tap(byKey('fake-map-far'));
    await tester.pump();

    expect(
      tester.getSemantics(byKey('address-point-confirm')).hint,
      'недоступна: сюда не возим',
    );
    semantics.dispose();
  });

  testWidgets('an app move landing during a Customer glide ends the '
      'lift', (WidgetTester tester) async {
    search.answers['Navoiy 5'] = found;
    await open(tester, placed: false);
    await tester.tap(byKey('fake-map-start'));
    await tester.pump();
    expect(pin(tester).lifted, isTrue);

    await type(tester, 'Navoiy 5');
    await tester.pump();

    expect(pin(tester).lifted, isFalse);
    expect(target(tester), '41.299512,69.240146');
    expect(confirmButton(tester).onPressed, isNotNull);
    await confirm(tester);
    expect(confirmed.single.point, found);
  });

  testWidgets('Ещё раз pressed after the step is gone does nothing', (
    WidgetTester tester,
  ) async {
    location.outcome = const LocationFailed(LocationFailure.timedOut);
    final ValueNotifier<bool> shown = ValueNotifier<bool>(true);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressMapProvider.overrideWithValue(FakeAddressMap()),
          addressSearchRepositoryProvider.overrideWithValue(search),
          deviceLocationProvider.overrideWithValue(location),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: shown,
              builder: (BuildContext context, bool on, Widget? _) => on
                  ? AddressPointStep(
                      initial: start,
                      placed: true,
                      keepsWords: true,
                      onConfirmed: confirmed.add,
                    )
                  : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(byKey('address-my-location'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(location.calls, 1);

    shown.value = false;
    await tester.pump();
    await tester.tap(find.widgetWithText(SnackBarAction, 'Ещё раз'));
    await tester.pump();

    expect(location.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Где я and the field buttons keep their tap action for a '
      'reader', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester, locale: const Locale('ru'));
    await enter(tester, 'Navoiy 5');

    for (final String key in <String>[
      'address-my-location',
      'address-search-go',
      'address-search-clear',
    ]) {
      expect(
        tester
            .getSemantics(byKey(key))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
        reason: key,
      );
    }
    semantics.dispose();
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
      search.answers['Navoiy 9'] = fakeFar;
      search.failures['Navoiy 7'] = const NetworkFailure();
      search.area = zone;

      await open(tester, locale: locale);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await enter(tester, 'Navoiy 5');
      await tester.tap(byKey('address-search-go'));
      await tester.pump();
      await tester.pump();
      expect(byKey('address-search-result'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await enter(tester, 'Navoiy 7');
      await tester.tap(byKey('address-search-go'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n(tester).addressSearchDown), findsOneWidget);
      expect(tester.takeException(), isNull);

      await enter(tester, 'Navoiy 9');
      await tester.tap(byKey('address-search-go'));
      await tester.pump();
      await tester.pump();
      expect(byKey('address-point-hint'), findsNothing);
      expect(byKey('address-words-kept'), findsNothing);
      expect(byKey('address-outside-zone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (String, TextScaler?) face in <(String, TextScaler?)>[
    ('at 100 %', null),
    ('at x2', const NonlinearTextScaler(2)),
  ]) {
    testWidgets('every face of the map step meets the tap target guideline '
        '${face.$1}', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      search.area = zone;
      search.places[fakeDoor] = door;
      search.answers['Navoiy 9'] = fakeFar;
      await open(tester, locale: const Locale('ru'), scaler: face.$2);
      await tester.pump();
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await moveAndRest(tester, 'fake-map-move');
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await tester.tap(byKey('fake-map-far'));
      await tester.pump();
      expect(byKey('address-outside-zone'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

      await enter(tester, 'Navoiy 9');
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await tester.tap(byKey('address-search-go'));
      await tester.pump();
      await tester.pump();
      expect(byKey('address-search-result'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });
  }
}
