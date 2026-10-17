import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/map/address_map.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const GeoPoint point = GeoPoint(
    latitude: '41.311081',
    longitude: '69.240562',
  );

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  test('without the Google key the provider is the fields map', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(addressMapProvider).movable, isFalse);
  });

  testWidgets('the fields map keeps the coordinate fields', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AddressMap map = container.read(addressMapProvider);

    await tester.pumpWidget(
      host(
        map.picker(
          initial: point,
          mover: PointMapMover(),
          enabled: true,
          onMoved: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('point-latitude')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('point-longitude')),
      findsOneWidget,
    );
  });

  testWidgets('the fields map previews the point as text', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      host(container.read(addressMapProvider).preview(point: point)),
    );

    expect(find.text('41.311081, 69.240562'), findsOneWidget);
  });

  test('the mover remembers its target and notifies', () {
    final PointMapMover mover = PointMapMover();
    int calls = 0;
    mover.addListener(() => calls++);

    mover.moveTo(point);

    expect(mover.target, point);
    expect(calls, 1);
  });
}
