import 'package:baraka_bozor/core/widgets/skeleton_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool pulsing = true, bool reduced = false}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(body: SkeletonBar(width: 80, pulsing: pulsing)),
      ),
    ),
  );
}

double _opacity(WidgetTester t) => t
    .widget<Opacity>(
      find
          .descendant(
            of: find.byType(SkeletonBar),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void main() {
  testWidgets('a bar pulses to 0.45 and back in 1.2 s', (tester) async {
    await tester.pumpWidget(_app());
    expect(_opacity(tester), closeTo(1, 0.001));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacity(tester), closeTo(0.45, 0.001));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacity(tester), closeTo(1, 0.001));
  });

  testWidgets('a still bar does not pulse', (tester) async {
    await tester.pumpWidget(_app(pulsing: false));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_opacity(tester), 1);
  });

  testWidgets('with reduced motion it does not pulse', (tester) async {
    await tester.pumpWidget(_app(reduced: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_opacity(tester), 1);
  });

  testWidgets('a bar says nothing to a screen reader', (tester) async {
    await tester.pumpWidget(_app(pulsing: false));
    expect(
      find.descendant(
        of: find.byType(SkeletonBar),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .descendant(
                  of: find.byType(SkeletonBar),
                  matching: find.byType(ExcludeSemantics),
                )
                .first,
          )
          .excluding,
      isTrue,
    );
  });
}
