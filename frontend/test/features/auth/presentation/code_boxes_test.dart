import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/auth/presentation/code_boxes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController controller;
  late List<bool> completed;

  setUp(() {
    controller = TextEditingController();
    completed = <bool>[];
  });

  tearDown(() => controller.dispose());

  Widget app({
    CodeBoxesLook look = CodeBoxesLook.entry,
    int misses = 0,
    bool reduced = false,
  }) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CodeBoxes(
              controller: controller,
              invalidMessage: 'invalid',
              look: look,
              misses: misses,
              onCompleted: completed.add,
            ),
          ),
        ),
      ),
    );
  }

  Finder box(int i) => find.byKey(ValueKey<String>('code-box-$i'));
  Finder field() => find.byKey(const ValueKey<String>('code-field'));

  BoxDecoration decorationOf(WidgetTester tester, int i) =>
      (tester.widget<Container>(
            find.descendant(of: box(i), matching: find.byType(Container)).first,
          )).decoration!
          as BoxDecoration;

  Future<void> typeDigit(WidgetTester tester, String all) async {
    await tester.enterText(field(), all);
    await tester.pump();
  }

  testWidgets('the code is read digit by digit with the count', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(app());
    const Key key = ValueKey<String>('code-semantics');
    expect(tester.getSemantics(find.byKey(key)).value, 'пусто');
    await typeDigit(tester, '4815');
    final SemanticsNode node = tester.getSemantics(find.byKey(key));
    expect(node.value, 'введено 4 из 6: 4 8 1 5');
    expect(node.label, 'Код для входа');
    handle.dispose();
  });

  testWidgets('the sixth digit completes once', (WidgetTester tester) async {
    await tester.pumpWidget(app());
    await typeDigit(tester, '4');
    await typeDigit(tester, '48');
    await typeDigit(tester, '481');
    await typeDigit(tester, '4815');
    await typeDigit(tester, '48152');
    expect(completed, isEmpty);
    await typeDigit(tester, '481526');
    expect(completed, <bool>[false]);
    await typeDigit(tester, '48152');
    await typeDigit(tester, '481527');
    expect(completed, <bool>[false, false]);
  });

  testWidgets('a pasted code completes as pasted', (WidgetTester tester) async {
    await tester.pumpWidget(app());
    await typeDigit(tester, '481526');
    expect(completed, <bool>[true]);
  });

  testWidgets('only the new digit pops', (WidgetTester tester) async {
    await tester.pumpWidget(app());
    await typeDigit(tester, '4');
    await typeDigit(tester, '48');
    await typeDigit(tester, '481');
    await tester.pump(const Duration(milliseconds: 400));
    await typeDigit(tester, '4815');
    await tester.pump(const Duration(milliseconds: 16));
    final Finder popped = find.descendant(
      of: box(3),
      matching: find.byType(Transform),
    );
    expect(popped, findsOneWidget);
    expect(tester.widget<Transform>(popped).transform.storage[0], lessThan(1));
    expect(
      find.descendant(of: box(0), matching: find.byType(Transform)),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(of: box(3), matching: find.byType(Transform)),
      findsNothing,
    );
  });

  testWidgets('nothing pops or pulses with reduced motion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(reduced: true));
    await typeDigit(tester, '4');
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.descendant(of: box(0), matching: find.byType(Transform)),
      findsNothing,
    );
    await tester.pumpWidget(app(look: CodeBoxesLook.checking, reduced: true));
    final Color before = decorationOf(tester, 5).color!;
    await tester.pump(const Duration(milliseconds: 500));
    expect(decorationOf(tester, 5).color, before);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the caret blinks while focused', (WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    const Key caret = ValueKey<String>('code-caret');
    expect(find.byKey(caret), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 530));
    expect(find.byKey(caret), findsNothing);
    await tester.pump(const Duration(milliseconds: 530));
    expect(find.byKey(caret), findsOneWidget);
  });

  testWidgets('the caret is steady with reduced motion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(reduced: true));
    await tester.pump();
    const Key caret = ValueKey<String>('code-caret');
    for (int i = 0; i < 3; i++) {
      expect(find.byKey(caret), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 530));
    }
  });

  testWidgets('checking pulses the boxes', (WidgetTester tester) async {
    await tester.pumpWidget(app(look: CodeBoxesLook.checking));
    await typeDigit(tester, '481526');
    final Color start = decorationOf(tester, 0).color!;
    expect(start, KitColors.field);
    await tester.pump(const Duration(seconds: 1));
    final BoxDecoration peak = decorationOf(tester, 0);
    expect(peak.color, KitColors.primaryWash);
    expect((peak.border! as Border).top.color, KitColors.pulseEdge);
  });

  testWidgets('wrong boxes are red, shake and refuse input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app());
    await typeDigit(tester, '481526');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(app(look: CodeBoxesLook.wrong, misses: 1));
    final BoxDecoration d = decorationOf(tester, 2);
    expect(d.color, KitColors.dangerWash);
    expect((d.border! as Border).top.color, KitColors.danger);
    await tester.pump(const Duration(milliseconds: 72));
    final Finder shifted = find.descendant(
      of: find.byKey(const ValueKey<String>('code-semantics')),
      matching: find.byType(Transform),
    );
    expect(
      tester.widget<Transform>(shifted.first).transform.storage[12],
      isNot(0),
    );

    await tester.enterText(field(), '48152');
    await tester.pump();
    expect(controller.text, '481526');
    expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isTrue);
  });

  testWidgets('right boxes are green with green digits', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app());
    await typeDigit(tester, '481526');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(app(look: CodeBoxesLook.right));
    final BoxDecoration d = decorationOf(tester, 4);
    expect(d.color, KitColors.primaryWash);
    expect((d.border! as Border).top.color, KitColors.primary);
    final Text digit = tester.widget<Text>(
      find.descendant(of: box(4), matching: find.byType(Text)),
    );
    expect(digit.style!.color, KitColors.primaryDark);
  });
}
