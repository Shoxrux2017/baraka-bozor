import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/legal/domain/legal.dart';
import 'package:baraka_bozor/features/legal/presentation/legal_blocks.dart';

import '../../../support/nonlinear_text_scaler.dart';

const LegalBlock _heading = LegalBlock(
  type: LegalBlockType.heading,
  text: 'Heading',
);
const LegalBlock _paragraph = LegalBlock(
  type: LegalBlockType.paragraph,
  text: 'Paragraph one',
);
const LegalBlock _paragraph2 = LegalBlock(
  type: LegalBlockType.paragraph,
  text: 'Paragraph two',
);
const LegalBlock _item = LegalBlock(
  type: LegalBlockType.item,
  text: 'Item one',
);
const LegalBlock _item2 = LegalBlock(
  type: LegalBlockType.item,
  text: 'Item two',
);

Future<void> _pump(
  WidgetTester tester,
  List<LegalBlock> blocks, {
  double scale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: LegalBlocks(blocks, scale: scale),
            ),
          ),
        ),
      ),
    ),
  );
}

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

double _gap(WidgetTester tester, String above, String below) =>
    tester.getRect(find.text(below)).top -
    tester.getRect(find.text(above)).bottom;

void main() {
  _largeTextCase();

  testWidgets('body is 16/26 and headings are 18 bold ink', (
    WidgetTester tester,
  ) async {
    await _pump(tester, <LegalBlock>[_heading, _paragraph]);

    final TextStyle body = _styleOf(tester, 'Paragraph one');
    expect(body.fontSize, 16);
    expect(body.height, 26 / 16);
    expect(body.color, KitColors.ink2);

    final TextStyle head = _styleOf(tester, 'Heading');
    expect(head.fontSize, 18);
    expect(head.fontWeight, FontWeight.w700);
    expect(head.color, KitColors.ink);
    expect(head.height, 24 / 18);

    final Finder headerSemantics = find.ancestor(
      of: find.text('Heading'),
      matching: find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.header == true,
      ),
    );
    expect(headerSemantics, findsOneWidget);
  });

  testWidgets('spacing follows the kind of block', (WidgetTester tester) async {
    await _pump(tester, <LegalBlock>[
      _heading,
      _item,
      _item2,
      _paragraph,
      _paragraph2,
      LegalBlock(type: LegalBlockType.heading, text: 'Second'),
      _item,
    ]);
    // A first heading sits 6 below the top.
    expect(tester.getRect(find.text('Heading')).top, 6);
    // Zero between a heading's 8 and its first item: 8 below, 0 above.
    expect(
      tester.getRect(find.text('Item one').first).top -
          tester.getRect(find.text('Heading')).bottom,
      8,
    );
    expect(
      tester.getRect(find.text('Item two')).top -
          tester.getRect(find.text('Item one').first).bottom,
      4,
    );
    expect(_gap(tester, 'Item two', 'Paragraph one'), 10);
    expect(_gap(tester, 'Paragraph one', 'Paragraph two'), 12);
    expect(_gap(tester, 'Paragraph two', 'Second'), 28);
    expect(
      tester.getRect(find.text('Item one').last).top -
          tester.getRect(find.text('Second')).bottom,
      8,
    );
  });

  testWidgets('a list item is one stop without its dot', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, <LegalBlock>[_item]);

    expect(find.bySemanticsLabel('Item one'), findsOneWidget);
    expect(find.bySemanticsLabel('•'), findsNothing);
    expect(find.text('•'), findsNothing);
    handle.dispose();
  });

  testWidgets('the dot is drawn 6 px, centred on the first line', (
    WidgetTester tester,
  ) async {
    await _pump(tester, <LegalBlock>[_item]);

    final Finder dot = find.byKey(const ValueKey<String>('legal-dot'));
    expect(dot, findsOneWidget);
    final Rect box = tester.getRect(dot);
    expect(box.size, const Size(6, 6));
    final Rect itemTop = tester.getRect(find.text('Item one'));
    expect(box.center.dy - itemTop.top, 13);
    expect(box.center.dx, 6);
    final DecoratedBox decorated = tester.widget<DecoratedBox>(dot);
    final BoxDecoration decoration = decorated.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, KitColors.ink2);
  });

  testWidgets('the preview scale shrinks everything', (
    WidgetTester tester,
  ) async {
    await _pump(tester, <LegalBlock>[
      _paragraph,
      _paragraph2,
      _heading,
    ], scale: 0.5);

    expect(_styleOf(tester, 'Paragraph one').fontSize, 8);
    expect(_styleOf(tester, 'Heading').fontSize, 9);
    expect(_gap(tester, 'Paragraph one', 'Paragraph two'), 6);
  });
}

void _largeTextCase() {
  testWidgets('at large text the dot stays on the first line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const NonlinearTextScaler(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: LegalBlocks(<LegalBlock>[_item]),
            ),
          ),
        ),
      ),
    );

    final Rect text = tester.getRect(find.text('Item one'));
    final Rect dot = tester.getRect(
      find.byKey(const ValueKey<String>('legal-dot')),
    );
    expect(dot.size, const Size(6, 6));
    expect(dot.center.dy - text.top, closeTo(text.height / 2, 0.5));
  });
}
