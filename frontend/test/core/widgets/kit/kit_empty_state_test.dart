import 'package:baraka_bozor/core/widgets/kit/kit_empty_state.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an empty state inside a list of unbounded height lays out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(height: 600, child: _InList())),
      ),
    );

    expect(find.text('Nothing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty state in a bounded box is centred and fills it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KitEmptyState(
            icon: Icons.search_off,
            title: 'Nothing',
            text: 'Try again',
          ),
        ),
      ),
    );

    expect(tester.getCenter(find.text('Nothing')).dx, 400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the quiet face is grey and the button can carry an icon', (
    WidgetTester tester,
  ) async {
    Color? circleColor() {
      final Container circle = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.cloud_off),
              matching: find.byType(Container),
            )
            .first,
      );
      return (circle.decoration! as BoxDecoration).color;
    }

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KitEmptyState(
            quiet: true,
            icon: Icons.cloud_off,
            title: 'Nothing',
            text: 'Try again',
            actionLabel: 'Retry',
            actionIcon: Icons.refresh,
            actionKey: ValueKey<String>('act'),
          ),
        ),
      ),
    );

    expect(circleColor(), KitColors.chip);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cloud_off)).color,
      KitColors.muted,
    );
    final Finder button = find.byKey(const ValueKey<String>('act'));
    final Finder icon = find.descendant(
      of: button,
      matching: find.byIcon(Icons.refresh),
    );
    expect(tester.widget<Icon>(icon).size, 22);
    expect(
      tester.getTopRight(icon).dx + 10,
      tester
          .getTopLeft(find.descendant(of: button, matching: find.text('Retry')))
          .dx,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KitEmptyState(
            icon: Icons.cloud_off,
            title: 'Nothing',
            text: 'Try again',
            actionLabel: 'Retry',
          ),
        ),
      ),
    );

    expect(circleColor(), KitColors.primaryWash);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cloud_off)).color,
      KitColors.primaryDark,
    );
    expect(find.byIcon(Icons.refresh), findsNothing);
  });
}

class _InList extends StatelessWidget {
  const _InList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const <Widget>[
        KitEmptyState(
          icon: Icons.search_off,
          title: 'Nothing',
          text: 'Try again',
        ),
      ],
    );
  }
}
