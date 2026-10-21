import 'package:baraka_bozor/core/widgets/kit/kit_empty_state.dart';
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
