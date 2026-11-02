import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/platform/clock.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/deadline_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _start = DateTime.utc(2026, 11, 2, 7);

Future<void> _open(
  WidgetTester tester, {
  required Duration left,
  required DateTime Function() clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [clockProvider.overrideWithValue(clock)],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DeadlineChip(
            key: const ValueKey<String>('deadline-chip'),
            deadline: _start.add(left),
          ),
        ),
      ),
    ),
  );
}

Color _color(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.timer)).color!;

void main() {
  test('minutesLeft rounds up and is 0 at the deadline', () {
    final DateTime deadline = _start.add(const Duration(minutes: 5));
    expect(minutesLeft(deadline, _start), 5);
    expect(minutesLeft(deadline, _start.add(const Duration(seconds: 1))), 5);
    expect(minutesLeft(deadline, _start.add(const Duration(minutes: 4))), 1);
    expect(minutesLeft(deadline, deadline), 0);
    expect(minutesLeft(deadline, deadline.add(const Duration(hours: 1))), 0);
  });

  testWidgets('shows the minutes left rounded up and turns red at 3', (
    WidgetTester tester,
  ) async {
    DateTime now = _start;
    await _open(
      tester,
      left: const Duration(minutes: 9, seconds: 10),
      clock: () => now,
    );
    expect(find.text('Осталось 10 мин'), findsOneWidget);
    expect(_color(tester), KitColors.warningDark);

    now = _start.add(const Duration(minutes: 6, seconds: 10));
    await tester.pump(const Duration(minutes: 6, seconds: 10));
    expect(find.text('Осталось 3 мин'), findsOneWidget);
    expect(_color(tester), KitColors.danger);
    expect(
      tester.widget<Text>(find.text('Осталось 3 мин')).style!.color,
      KitColors.danger,
    );
  });

  testWidgets('counts down each minute and hides at the deadline', (
    WidgetTester tester,
  ) async {
    DateTime now = _start;
    await _open(
      tester,
      left: const Duration(minutes: 2, seconds: 30),
      clock: () => now,
    );
    expect(find.text('Осталось 3 мин'), findsOneWidget);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Осталось 2 мин'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Осталось 1 мин'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.byIcon(Icons.timer), findsNothing);
    expect(find.textContaining('Осталось'), findsNothing);
  });
}
