import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/paged.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Paged<int> pageOf(int page, {int total = 41}) => Paged<int>(
    items: const <int>[],
    page: page,
    perPage: 12,
    total: total,
    lastPage: (total / 12).ceil(),
  );

  Future<void> pump(
    WidgetTester tester,
    Paged<int> page,
    ValueChanged<int> onPage,
  ) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: PanelPager(page: page, onPage: onPage),
          ),
        ),
      ),
    ),
  );

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  testWidgets('the pager says the range and goes to a page', (
    WidgetTester tester,
  ) async {
    final List<int> asked = <int>[];
    await pump(tester, pageOf(1), asked.add);

    expect(find.text('1–12 из 41'), findsOneWidget);
    expect(byKey('page-1'), findsOneWidget);
    expect(byKey('page-4'), findsOneWidget);
    expect(byKey('page-5'), findsNothing);
    expect(tester.widget<IconButton>(byKey('previous-page')).onPressed, isNull);

    await tester.tap(byKey('page-2'));
    expect(asked, <int>[2]);
    await tester.tap(byKey('next-page'));
    expect(asked, <int>[2, 2]);

    await pump(tester, pageOf(4), asked.add);
    expect(find.text('37–41 из 41'), findsOneWidget);
    expect(tester.widget<IconButton>(byKey('next-page')).onPressed, isNull);
  });

  testWidgets('the pager numbers up to five pages around the current one', (
    WidgetTester tester,
  ) async {
    await pump(tester, pageOf(7, total: 120), (int _) {});

    expect(find.text('73–84 из 120'), findsOneWidget);
    for (final int number in const <int>[5, 6, 7, 8, 9]) {
      expect(byKey('page-$number'), findsOneWidget);
    }
    expect(byKey('page-4'), findsNothing);
    expect(byKey('page-10'), findsNothing);
    expect(tester.getSize(byKey('page-7')), const Size(32, 32));
  });

  testWidgets('one page shows no pager', (WidgetTester tester) async {
    await pump(tester, pageOf(1, total: 9), (int _) {});

    expect(find.byType(Text), findsNothing);
    expect(byKey('next-page'), findsNothing);
  });
}
