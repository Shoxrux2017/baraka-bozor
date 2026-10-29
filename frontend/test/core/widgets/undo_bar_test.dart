import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/undo_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(
  WidgetTester tester,
  VoidCallback onUndo, {
  bool screenReader = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(accessibleNavigation: screenReader),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showUndoBar(
              ScaffoldMessenger.of(context),
              text: 'Olma removed',
              actionLabel: 'Undo',
              onUndo: onUndo,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('shows the text and the action for 4 s', (tester) async {
    await _open(tester, () {});
    expect(find.text('Olma removed'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(undoBarDuration - const Duration(milliseconds: 600));
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('with a screen reader the bar stays until its action', (
    tester,
  ) async {
    int undone = 0;
    await _open(tester, () => undone++, screenReader: true);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Undo'), findsNothing);
  });
  testWidgets('a tap runs onUndo once and closes the bar', (tester) async {
    int undone = 0;
    await _open(tester, () => undone++);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('the action is at least 44 high and in its colours', (
    tester,
  ) async {
    await _open(tester, () {});
    final Finder button = find.ancestor(
      of: find.text('Undo'),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    final Text label = tester.widget<Text>(find.text('Undo'));
    expect(label.style!.color, KitColors.undoAction);
    expect(label.style!.fontWeight, FontWeight.w700);
    expect(label.style!.fontSize, 14);
    final SnackBar bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, KitColors.undoBar);
  });
}
