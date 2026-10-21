import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The card on top of a staff order, and the steps under it.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('a status card shows its title, hint and progress in its tone', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const KitStatusCard(
        key: ValueKey<String>('card'),
        icon: Icons.shopping_basket_outlined,
        title: 'On the way',
        hint: 'Leave at 14:00',
        hintKey: ValueKey<String>('hint'),
        tone: KitTone.amber,
        progress: Text('progress'),
        below: <Widget>[Text('below')],
      ),
    );

    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('card')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, KitColors.warningWash);
    expect(find.text('On the way'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey<String>('hint'))).data,
      'Leave at 14:00',
    );
    expect(find.text('progress'), findsOneWidget);
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('steps name each stage and the times known', (
    WidgetTester tester,
  ) async {
    final DateTime assigned = DateTime.utc(2026, 10, 21, 9, 2);
    await pump(
      tester,
      KitSteps(
        reached: 2,
        steps: <KitStep>[
          (label: 'Assigned', at: assigned),
          (label: 'Accepted', at: null),
          (label: 'On the way', at: null),
        ],
      ),
    );

    final List<Color> segments = tester
        .widget<SegmentBar>(find.byType(SegmentBar))
        .segments;
    expect(segments, <Color>[
      KitColors.primary,
      KitColors.primary,
      KitColors.primarySoft,
    ]);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text(TashkentTime.time(assigned)), findsOneWidget);
    // Only the step with an instant shows a time.
    expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);
  });
}
