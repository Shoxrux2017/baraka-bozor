import 'package:baraka_bozor/core/widgets/kit/kit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kit sheet every staff sheet is built on: a title row with a ×, a body
/// that scrolls above the keyboard, and no drag to close.
void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pumpHost(
    WidgetTester tester, {
    required WidgetBuilder builder,
    Size size = const Size(400, 800),
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey<String>('open'),
                onPressed: () => showKitSheet<void>(
                  context,
                  title: 'Sheet title',
                  sheetKey: 'test-sheet',
                  builder: builder,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(byKey('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the × closes the sheet', (WidgetTester tester) async {
    await pumpHost(
      tester,
      builder: (BuildContext context) => const Text('body'),
    );
    expect(byKey('test-sheet'), findsOneWidget);
    expect(find.text('Sheet title'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);

    await tester.tap(byKey('test-sheet-close'));
    await tester.pumpAndSettle();

    expect(byKey('test-sheet'), findsNothing);
  });

  testWidgets('a body that refuses to pop keeps the sheet on the ×, back and '
      'the scrim', (WidgetTester tester) async {
    await pumpHost(
      tester,
      builder: (BuildContext context) =>
          const PopScope(canPop: false, child: Text('busy')),
    );

    await tester.tap(byKey('test-sheet-close'));
    await tester.pumpAndSettle();
    expect(byKey('test-sheet'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(byKey('test-sheet'), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(byKey('test-sheet'), findsOneWidget);
  });

  testWidgets('a tall body scrolls above the keyboard', (
    WidgetTester tester,
  ) async {
    await pumpHost(
      tester,
      size: const Size(320, 640),
      keyboard: 300,
      builder: (BuildContext context) => Column(
        children: <Widget>[
          const SizedBox(height: 1000),
          Text('last', key: const ValueKey<String>('last')),
        ],
      ),
    );

    await tester.scrollUntilVisible(
      byKey('last'),
      200,
      scrollable: find.descendant(
        of: byKey('test-sheet'),
        matching: find.byType(Scrollable),
      ),
    );

    expect(byKey('last'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
