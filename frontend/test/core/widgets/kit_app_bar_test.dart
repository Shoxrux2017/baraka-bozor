import 'package:baraka_bozor/core/widgets/kit_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/nonlinear_text_scaler.dart';

void main() {
  testWidgets('a subtitle stands under the title and both are one heading', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: kitAppBar(
            title: 'Новый адрес',
            subtitle: 'Шаг 1 из 2 · точка на карте',
            spokenTitle: 'Новый адрес, шаг 1 из 2: точка на карте',
            toolbarHeight: 60,
          ),
        ),
      ),
    );

    final Offset title = tester.getCenter(find.text('Новый адрес'));
    final Offset subtitle = tester.getCenter(
      find.text('Шаг 1 из 2 · точка на карте'),
    );
    expect(subtitle.dy, greaterThan(title.dy));
    expect(subtitle.dx, closeTo(title.dx, 0.5), reason: 'centred together');
    expect(tester.getSize(find.byType(AppBar)).height, 60);
    final Finder heading = find.bySemanticsLabel(
      'Новый адрес, шаг 1 из 2: точка на карте',
    );
    expect(heading, findsOneWidget);
    expect(
      tester.getSemantics(heading),
      matchesSemantics(
        label: 'Новый адрес, шаг 1 из 2: точка на карте',
        isHeader: true,
      ),
    );
    expect(find.bySemanticsLabel('Новый адрес'), findsNothing);
    handle.dispose();
  });

  testWidgets('without a spoken title the heading reads title, subtitle', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: kitAppBar(title: 'A', subtitle: 'B'),
        ),
      ),
    );

    expect(find.bySemanticsLabel('A, B'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('at large text both lines stay whole in a narrow bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const NonlinearTextScaler scaler = NonlinearTextScaler(2);
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        ),
        home: Scaffold(
          appBar: kitAppBar(
            title: 'Новый адрес',
            subtitle: 'Шаг 1 из 2 · точка на карте',
            toolbarHeight: kitSubtitleBarHeight(scaler),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Новый адрес'), findsOneWidget);
    expect(find.text('Шаг 1 из 2 · точка на карте'), findsOneWidget);
    final Rect bar = tester.getRect(find.byType(AppBar));
    expect(
      bar.contains(
        tester.getRect(find.text('Шаг 1 из 2 · точка на карте')).bottomRight,
      ),
      isTrue,
    );
  });
}
