import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's own font so that widths in a test are the widths on a
/// phone; the test font is wider and would hide or invent overflow.
Future<void> loadMontserrat() async {
  final FontLoader loader = FontLoader('Montserrat')
    ..addFont(rootBundle.load('assets/fonts/Montserrat-Variable.ttf'));
  await loader.load();
}

/// The paragraphs drawn under [within].
List<RenderParagraph> paragraphsIn(WidgetTester tester, Finder within) {
  final Finder found = find.descendant(
    of: within,
    matching: find.byType(RichText),
  );
  return <RenderParagraph>[
    for (int i = 0; i < found.evaluate().length; i++)
      tester.renderObject<RenderParagraph>(found.at(i)),
  ];
}

/// The text of every paragraph under [within] that is cut by its line limit.
List<String> cutParagraphs(WidgetTester tester, Finder within) => <String>[
  for (final RenderParagraph paragraph in paragraphsIn(tester, within))
    if (paragraph.didExceedMaxLines) paragraph.text.toPlainText(),
];

/// How many lines the paragraph is set on.
int linesOf(RenderParagraph paragraph) => paragraph
    .getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: paragraph.text.toPlainText().length,
      ),
    )
    .length;
