import 'package:baraka_bozor/features/addresses/presentation/map/map_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required bool lifted,
    required int drops,
    bool reduced = false,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 200,
        height: 200,
        child: MapPin(lifted: lifted, drops: drops),
      ),
    ),
  );

  Transform icon(WidgetTester tester) => tester.widget<Transform>(
    find.byKey(const ValueKey<String>('map-pin-icon')),
  );

  testWidgets('the pin lifts while lifted and drops with a squash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(lifted: false, drops: 0));
    expect(icon(tester).transform.getTranslation().y, 0);

    await tester.pumpWidget(host(lifted: true, drops: 0));
    await tester.pump(const Duration(milliseconds: 160));
    expect(icon(tester).transform.getTranslation().y, closeTo(-14, 0.01));

    await tester.pumpWidget(host(lifted: false, drops: 1));
    await tester.pump(const Duration(milliseconds: 196));
    expect(icon(tester).transform.entry(1, 1), closeTo(0.88, 0.01));
    expect(icon(tester).transform.entry(0, 0), closeTo(1.07, 0.01));

    await tester.pump(const Duration(milliseconds: 84));
    expect(icon(tester).transform.entry(1, 1), closeTo(1, 0.001));
    expect(icon(tester).transform.getTranslation().y, closeTo(0, 0.001));
  });

  testWidgets('reduced motion keeps the pin still', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(lifted: false, drops: 0, reduced: true));
    await tester.pumpWidget(host(lifted: true, drops: 0, reduced: true));
    await tester.pump(const Duration(milliseconds: 160));
    expect(icon(tester).transform.getTranslation().y, 0);

    await tester.pumpWidget(host(lifted: false, drops: 1, reduced: true));
    await tester.pump(const Duration(milliseconds: 196));
    expect(icon(tester).transform.entry(1, 1), 1);
  });
}
