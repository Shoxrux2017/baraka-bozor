import 'package:baraka_bozor/core/widgets/entrance_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ProviderContainer container, {bool reduced = false, Key? key}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: EntranceFade(key: key, child: const Text('внутри')),
        ),
      ),
    ),
  );
}

Finder _fade() => find.descendant(
  of: find.byType(EntranceFade),
  matching: find.byType(FadeTransition),
);

Finder _white() => find.descendant(
  of: find.byType(EntranceFade),
  matching: find.byWidgetPredicate(
    (Widget w) => w is ColoredBox && w.color == Colors.white,
  ),
);

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  testWidgets('a requested fade runs once over white', (tester) async {
    container.read(entranceFadeProvider).request();
    await tester.pumpWidget(_app(container));
    expect(tester.widget<FadeTransition>(_fade()).opacity.value, 0);
    expect(_white(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 320));
    expect(tester.widget<FadeTransition>(_fade()).opacity.value, 1);
    expect(find.text('внутри'), findsOneWidget);

    await tester.pumpWidget(_app(container, key: UniqueKey()));
    expect(_fade(), findsNothing);
    expect(find.text('внутри'), findsOneWidget);
  });

  testWidgets('without a request nothing fades', (tester) async {
    await tester.pumpWidget(_app(container));
    expect(_fade(), findsNothing);
    expect(_white(), findsNothing);
    expect(find.text('внутри'), findsOneWidget);
  });

  testWidgets('reduced motion shows the child at once', (tester) async {
    container.read(entranceFadeProvider).request();
    await tester.pumpWidget(_app(container, reduced: true));
    expect(_fade(), findsNothing);
    expect(find.text('внутри'), findsOneWidget);
    expect(container.read(entranceFadeProvider).pending, isFalse);
  });
}
