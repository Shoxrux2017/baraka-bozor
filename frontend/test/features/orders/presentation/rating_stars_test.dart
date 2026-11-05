import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/features/orders/presentation/rating_stars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Choice = (int, RatingInput);

class _Host extends StatefulWidget {
  const _Host({
    required this.log,
    this.start,
    this.adjustable = true,
    super.key,
  });

  final List<_Choice> log;
  final int? start;
  final bool adjustable;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int? value = widget.start;

  void set(int? next) => setState(() => value = next);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: RatingStars(
      value: value,
      adjustable: widget.adjustable,
      onChanged: (int stars, RatingInput how) {
        widget.log.add((stars, how));
        setState(() => value = stars);
      },
    ),
  );
}

void main() {
  late List<MethodCall> platformCalls;
  late List<_Choice> log;
  final GlobalKey<_HostState> hostKey = GlobalKey<_HostState>();

  setUp(() {
    log = <_Choice>[];
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          platformCalls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  int buzzes(String type) => platformCalls
      .where(
        (MethodCall c) =>
            c.method == 'HapticFeedback.vibrate' && c.arguments == type,
      )
      .length;

  int anyBuzz() => platformCalls
      .where((MethodCall c) => c.method == 'HapticFeedback.vibrate')
      .length;

  Future<void> pump(
    WidgetTester tester, {
    int? start,
    bool adjustable = true,
    bool reduced = false,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: _Host(
            key: hostKey,
            log: log,
            start: start,
            adjustable: adjustable,
          ),
        ),
      ),
    ),
  );

  Finder star(int i) => find.byKey(ValueKey<String>('rate-star-$i'));

  double scaleOf(WidgetTester tester, int i) => tester
      .widget<Transform>(
        find.descendant(of: star(i), matching: find.byType(Transform)).first,
      )
      .transform
      .entry(0, 0);

  testWidgets('a tap chooses on release and buzzes', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(star(3)),
    );
    await tester.pump();
    expect(log, isEmpty);
    expect(buzzes('HapticFeedbackType.lightImpact'), 0);
    await finger.up();
    await tester.pump();
    expect(log, <_Choice>[(3, RatingInput.tap)]);
    expect(buzzes('HapticFeedbackType.lightImpact'), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('a slide changes under the finger and clicks', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(star(1)),
    );
    for (final double x in <double>[30, 30, 52, 52]) {
      await finger.moveBy(Offset(x, 0));
      await tester.pump();
    }
    expect(log.map((_Choice c) => c.$1), <int>[1, 2, 3, 4]);
    expect(log.every((_Choice c) => c.$2 == RatingInput.slide), isTrue);
    expect(buzzes('HapticFeedbackType.selectionClick'), 4);
    // Past the fifth star it stays at 5.
    await finger.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(log.last, (5, RatingInput.slide));
    await finger.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(log.length, 5);
    // Left of the first star it stays at 1.
    await finger.moveTo(tester.getTopLeft(star(1)) - const Offset(80, 0));
    await tester.pump();
    expect(log.last, (1, RatingInput.slide));
    await finger.up();
    await tester.pumpAndSettle();
    expect(buzzes('HapticFeedbackType.lightImpact'), 0);
  });

  testWidgets('a vertical drag chooses nothing', (WidgetTester tester) async {
    await pump(tester);
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(star(2)),
    );
    for (int i = 0; i < 4; i++) {
      await finger.moveBy(const Offset(0, 30));
      await tester.pump();
    }
    await finger.up();
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(anyBuzz(), 0);
  });

  testWidgets('the cascade lights one by one and the chosen pops', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    hostKey.currentState!.set(4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(scaleOf(tester, 1), lessThan(1));
    expect(scaleOf(tester, 4), 1);
    await tester.pump(const Duration(milliseconds: 120));
    expect(scaleOf(tester, 4), isNot(1));
    await tester.pump(const Duration(milliseconds: 560));
    for (int i = 1; i <= 5; i++) {
      expect(scaleOf(tester, i), 1, reason: 'star $i');
    }
    await tester.pumpAndSettle();
  });

  testWidgets('the chosen star pops again when it is tapped again', (
    WidgetTester tester,
  ) async {
    await pump(tester, start: 3);
    await tester.tap(star(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester, 3), greaterThan(1));
    expect(log, <_Choice>[(3, RatingInput.tap)]);
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion no star is scaled', (
    WidgetTester tester,
  ) async {
    await pump(tester, reduced: true);
    hostKey.currentState!.set(4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    for (int i = 1; i <= 5; i++) {
      expect(scaleOf(tester, i), 1, reason: 'star $i');
    }
    await tester.pumpAndSettle();
  });

  testWidgets('a reader meets one adjustable rating', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, start: 2);
    final Finder node = find.bySemanticsLabel('Оценка');
    expect(node, findsOneWidget);
    final semantics = tester.getSemantics(node);
    expect(semantics.value, '2 из 5, Плохо');
    expect(semantics.increasedValue, '3 из 5, Нормально');
    expect(semantics.decreasedValue, '1 из 5, Очень плохо');
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.increase),
      isTrue,
    );
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.decrease),
      isTrue,
    );
    expect(find.bySemanticsLabel(RegExp('Оценить на')), findsNothing);

    tester.semantics.performAction(
      find.semantics.byLabel('Оценка'),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(log, <_Choice>[(3, RatingInput.reader)]);
    expect(anyBuzz(), 0);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('a reader hears that nothing is chosen and starts at one', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester);
    final Finder node = find.bySemanticsLabel('Оценка');
    expect(tester.getSemantics(node).value, 'не выбрана');
    tester.semantics.performAction(
      find.semantics.byLabel('Оценка'),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(log, <_Choice>[(1, RatingInput.reader)]);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('the card mode is five buttons', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, adjustable: false);
    for (int i = 1; i <= 5; i++) {
      expect(find.bySemanticsLabel('Оценить на $i из 5'), findsOneWidget);
    }
    await tester.tap(star(5));
    await tester.pump();
    expect(log, <_Choice>[(5, RatingInput.tap)]);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('a disabled rating ignores input', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RatingStars(
            value: 2,
            enabled: false,
            adjustable: true,
            onChanged: (int stars, RatingInput how) => log.add((stars, how)),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('rate-star-4')));
    await tester.drag(
      find.byKey(const ValueKey<String>('rate-star-1')),
      const Offset(150, 0),
    );
    await tester.pump();
    expect(log, isEmpty);
    expect(anyBuzz(), 0);
  });
}
