import 'package:baraka_bozor/core/widgets/kit/kit_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pair of buttons a staff sheet ends with.
void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KitActionPair(
            secondary: OutlinedButton(
              key: const ValueKey<String>('secondary'),
              onPressed: () {},
              child: const Text('Cancel'),
            ),
            primary: FilledButton(
              key: const ValueKey<String>('primary'),
              onPressed: () {},
              child: const Text('Confirm'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a pair stands side by side at normal text', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    expect(
      tester.getTopLeft(byKey('secondary')).dy,
      tester.getTopLeft(byKey('primary')).dy,
    );
    expect(
      tester.getTopLeft(byKey('secondary')).dx,
      lessThan(tester.getTopLeft(byKey('primary')).dx),
    );
    expect(
      tester.getSize(byKey('secondary')).width,
      tester.getSize(byKey('primary')).width,
    );
  });

  testWidgets('a pair stacks, primary first, at large text', (
    WidgetTester tester,
  ) async {
    await pump(tester, textScale: 2);

    expect(
      tester.getTopLeft(byKey('primary')).dy,
      lessThan(tester.getTopLeft(byKey('secondary')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
