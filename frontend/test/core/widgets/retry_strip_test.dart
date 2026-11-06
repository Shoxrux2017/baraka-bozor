import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/widgets/retry_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/nonlinear_text_scaler.dart';

const Key _retry = ValueKey<String>('again');

Widget _app({VoidCallback? onRetry, TextScaler scaler = TextScaler.noScaling}) {
  return MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: scaler),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: RetryStrip(
            message: 'Нет связи — имя не сохранено',
            onRetry: onRetry ?? () {},
            retryKey: _retry,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the strip says its words and retries', (tester) async {
    int taps = 0;
    await tester.pumpWidget(_app(onRetry: () => taps++));
    await tester.pumpAndSettle();
    expect(find.text('Нет связи — имя не сохранено'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(tester.getSize(find.byKey(_retry)).height, greaterThanOrEqualTo(44));
    await tester.tap(find.byKey(_retry));
    expect(taps, 1);
  });

  testWidgets('at large text Повторить goes under the words', (tester) async {
    await tester.pumpWidget(_app(scaler: const NonlinearTextScaler(2)));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(_retry)).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.text('Нет связи — имя не сохранено')).dy,
      ),
    );
  });

  testWidgets('it is one live region', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(RetryStrip),
        matching: find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
  });
}
