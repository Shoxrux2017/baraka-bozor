import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/widgets/keyboard_done_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Готово calls back and meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    int done = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: KeyboardDoneBar(onDone: () => done++),
          ),
        ),
      ),
    );

    expect(find.text('Готово'), findsOneWidget);
    expect(tester.getSize(find.byType(KeyboardDoneBar)).height, 44);
    final Size button = tester.getSize(
      find.byKey(const ValueKey<String>('keyboard-done')),
    );
    expect(button.width, greaterThanOrEqualTo(44));
    expect(button.height, greaterThanOrEqualTo(44));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

    await tester.tap(find.byKey(const ValueKey<String>('keyboard-done')));
    expect(done, 1);
  });
}
