import 'dart:ui' show Tristate;

import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/submit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _key = ValueKey<String>('go');

Widget _app(
  SubmitFace face, {
  VoidCallback? onPressed,
  String? offHint,
  bool reduced = false,
}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: Center(
            child: SubmitButton(
              face: face,
              label: 'Сохранить',
              onPressed: onPressed,
              offHint: offHint,
              buttonKey: _key,
            ),
          ),
        ),
      ),
    ),
  );
}

ButtonStyle _style(WidgetTester t) =>
    t.widget<FilledButton>(find.byKey(_key)).style!;

Color? _fill(WidgetTester t, WidgetState s) =>
    _style(t).backgroundColor!.resolve(<WidgetState>{s});

Color? _words(WidgetTester t, WidgetState s) =>
    _style(t).foregroundColor!.resolve(<WidgetState>{s});

void main() {
  testWidgets('each face draws and taps as it should', (tester) async {
    int taps = 0;
    await tester.pumpWidget(_app(SubmitFace.ready, onPressed: () => taps++));
    expect(_fill(tester, WidgetState.focused), KitColors.primary);
    expect(_words(tester, WidgetState.focused), Colors.white);
    await tester.tap(find.byKey(_key));
    expect(taps, 1);

    await tester.pumpWidget(_app(SubmitFace.off, onPressed: () => taps++));
    expect(_fill(tester, WidgetState.disabled), KitColors.buttonOff);
    expect(_words(tester, WidgetState.disabled), KitColors.muted);
    await tester.tap(find.byKey(_key), warnIfMissed: false);
    expect(taps, 1);

    await tester.pumpWidget(_app(SubmitFace.busy, onPressed: () => taps++));
    expect(_fill(tester, WidgetState.disabled), KitColors.primary);
    expect(_words(tester, WidgetState.disabled), Colors.white);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(_key), warnIfMissed: false);
    expect(taps, 1);

    await tester.pumpWidget(_app(SubmitFace.done, onPressed: () => taps++));
    expect(_fill(tester, WidgetState.disabled), KitColors.primary);
    expect(_words(tester, WidgetState.disabled), Colors.white);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(_key), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('off reads its hint', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(SubmitFace.off, onPressed: () {}, offHint: 'имя не изменилось'),
    );
    final SemanticsData data = tester
        .getSemantics(find.byKey(_key))
        .getSemanticsData();
    expect(data.label, 'Сохранить');
    expect(data.hint, 'имя не изменилось');
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('the check pops and stands still with reduced motion', (
    tester,
  ) async {
    Finder transforms() =>
        find.descendant(of: find.byKey(_key), matching: find.byType(Transform));

    await tester.pumpWidget(_app(SubmitFace.done));
    await tester.pump(const Duration(milliseconds: 133));
    final Transform pop = tester.widget<Transform>(transforms().first);
    expect(pop.transform.getMaxScaleOnAxis(), greaterThan(1.1));

    await tester.pumpWidget(_app(SubmitFace.done, reduced: true));
    await tester.pump(const Duration(milliseconds: 133));
    expect(transforms(), findsNothing);
  });

  testWidgets('a held ready button shrinks', (tester) async {
    await tester.pumpWidget(_app(SubmitFace.ready, onPressed: () {}));
    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1);
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.byKey(_key)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(), 0.98);
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(), 1);
  });
}
