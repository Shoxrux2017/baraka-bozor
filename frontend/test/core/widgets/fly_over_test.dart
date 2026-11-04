import 'package:baraka_bozor/core/widgets/fly_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Key target = ValueKey<String>('target');
  const Key ghost = ValueKey<String>('ghost');
  const Rect from = Rect.fromLTWH(10, 20, 50, 40);

  late BuildContext context;

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext c) {
            context = c;
            return Stack(
              children: const <Widget>[
                Positioned(
                  left: 200,
                  top: 400,
                  width: 100,
                  height: 80,
                  child: SizedBox(key: target),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  testWidgets('flyOver flies from one rect to the other and removes itself', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);
    bool landed = false;
    final Rect place = tester.getRect(find.byKey(target));
    flyOver(
      context,
      from: from,
      to: () => tester.getRect(find.byKey(target)),
      child: const ColoredBox(key: ghost, color: Colors.red),
    ).then((_) => landed = true);

    await tester.pump();
    await tester.pump();
    final Rect start = tester.getRect(find.byKey(ghost));
    expect(start.topLeft, from.topLeft);
    expect(start.width, closeTo(from.width, 0.5));

    await tester.pump(const Duration(milliseconds: 220));
    final Rect middle = tester.getRect(find.byKey(ghost));
    expect(middle.left, inExclusiveRange(from.left, place.left));
    expect(middle.top, inExclusiveRange(from.top, place.top));
    expect(middle.width, inExclusiveRange(from.width, place.width));
    expect(landed, isFalse);

    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump();
    expect(find.byKey(ghost), findsNothing);
    expect(landed, isTrue);
  });

  testWidgets('flyOver ends when its target is gone', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);
    bool gone = false;
    bool landed = false;
    flyOver(
      context,
      from: from,
      to: () => gone ? null : tester.getRect(find.byKey(target)),
      child: const ColoredBox(key: ghost, color: Colors.red),
    ).then((_) => landed = true);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(ghost), findsOneWidget);

    gone = true;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(find.byKey(ghost), findsNothing);
    expect(landed, isTrue);
  });
}
