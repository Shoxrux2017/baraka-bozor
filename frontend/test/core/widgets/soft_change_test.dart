import 'package:baraka_bozor/core/widgets/soft_change.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(int value, {bool waiting = false, bool reduced = false}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: SoftChange(
            value: value,
            waiting: waiting,
            child: Text('v$value', key: const Key('t')),
          ),
        ),
      ),
    ),
  );
}

double _opacity(WidgetTester t) => t
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('t')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

double _dy(WidgetTester t) => t
    .widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const Key('t')),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .y;

void main() {
  testWidgets('a new value rises softly', (tester) async {
    await tester.pumpWidget(_app(1));
    await tester.pumpWidget(_app(2));
    await tester.pump();
    expect(_opacity(tester), closeTo(0.2, 0.001));
    expect(_dy(tester), closeTo(4, 0.001));
    await tester.pump(const Duration(milliseconds: 240));
    expect(_opacity(tester), 1);
    expect(_dy(tester), 0);
  });

  testWidgets('waiting dims to 0.45', (tester) async {
    await tester.pumpWidget(_app(1));
    await tester.pumpWidget(_app(1, waiting: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final AnimatedOpacity dim = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(const Key('t')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(dim.opacity, 0.45);
    final FadeTransition fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const Key('t')),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, closeTo(0.45, 0.001));
  });

  testWidgets('the same value does not move', (tester) async {
    await tester.pumpWidget(_app(1));
    await tester.pumpWidget(_app(1));
    await tester.pump();
    expect(_opacity(tester), 1);
    expect(_dy(tester), 0);
  });

  testWidgets('reduced motion shows the new value at once', (tester) async {
    await tester.pumpWidget(_app(1, reduced: true));
    await tester.pumpWidget(_app(2, reduced: true));
    await tester.pump();
    expect(find.text('v2'), findsOneWidget);
    expect(_opacity(tester), 1);
    expect(_dy(tester), 0);
  });
}
