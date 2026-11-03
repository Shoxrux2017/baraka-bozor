import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/widgets/stale_data_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

// 12:46 in Tashkent (UTC+5).
final DateTime _shownAt = DateTime.utc(2026, 11, 2, 7, 46);

Future<void> _open(
  WidgetTester tester, {
  required ApiFailure failure,
  DateTime? shownAt,
  VoidCallback? onRetry,
  double textScale = 1,
  bool busy = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StaleDataLine(
              failure: failure,
              shownAt: shownAt,
              onRetry: onRetry ?? () {},
              busy: busy,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('offline with data it says when the data is from and refreshes', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int retries = 0;
    await _open(
      tester,
      failure: const NetworkFailure(),
      shownAt: _shownAt,
      onRetry: () => retries++,
    );

    expect(find.text('Нет связи · данные на 12:46'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel('Нет связи. Показаны данные на 12:46'),
    );
    // ignore: deprecated_member_use
    expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('stale-retry')));
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('a cold failure offers Повторить', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _open(tester, failure: const NetworkFailure());

    expect(find.text('Нет связи'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.bySemanticsLabel('Нет связи'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('another failure says Не удалось обновить', (
    WidgetTester tester,
  ) async {
    await _open(tester, failure: const UnexpectedFailure(), shownAt: _shownAt);

    expect(find.text('Не удалось обновить · данные на 12:46'), findsOneWidget);
  });

  testWidgets('a busy button reads Обновляем…', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _open(
      tester,
      failure: const NetworkFailure(),
      shownAt: _shownAt,
      busy: true,
    );

    expect(find.bySemanticsLabel('Обновляем…'), findsOneWidget);
    semantics.dispose();
  });

  for (final double scale in <double>[1, 2]) {
    testWidgets('meets iOSTapTargetGuideline at 320 and text x$scale', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(
        tester,
        failure: const NetworkFailure(),
        shownAt: _shownAt,
        textScale: scale,
      );

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
