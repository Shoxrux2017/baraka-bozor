import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tab bar's look on a stand-in screen. How a tab is reached is tested on
/// the real app in `features/shells/presentation/customer_tabs_test.dart`.
void main() {
  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('uz'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Text('stand-in home'),
          bottomNavigationBar: CustomerTabBar(current: CustomerTab.home),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the bar is 99 high, white, with the icons at 26 and labels', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);

    expect(tester.getSize(find.byType(CustomerTabBar)).height, 99);
    final Icon home = tester.widget<Icon>(
      find.descendant(of: byKey('open-home'), matching: find.byType(Icon)),
    );
    final Icon orders = tester.widget<Icon>(
      find.descendant(of: byKey('open-orders'), matching: find.byType(Icon)),
    );
    expect(home.size, 26);
    expect(home.icon, Icons.home);
    expect(home.color, KitColors.primary);
    expect(orders.icon, isNot(Icons.receipt_long));
    expect(orders.color, isNot(KitColors.primary));
    expect(find.bySemanticsLabel('Bosh sahifa'), findsOneWidget);
    expect(find.bySemanticsLabel('Sevimlilar'), findsOneWidget);
    expect(find.bySemanticsLabel('Buyurtmalar'), findsOneWidget);
    expect(find.bySemanticsLabel('Profil'), findsOneWidget);
    semantics.dispose();
  });

  Text label(WidgetTester tester, String key, String text) => tester
      .widget<Text>(find.descendant(of: byKey(key), matching: find.text(text)));

  testWidgets(
    'labels under the icons, the current one bold in the text green',
    (WidgetTester tester) async {
      await open(tester);

      final Text home = label(tester, 'open-home', 'Bosh sahifa');
      expect(home.style?.fontWeight, FontWeight.w700);
      expect(home.style?.color, KitColors.primaryDark);
      for (final (String key, String text) in <(String, String)>[
        ('open-favorites', 'Sevimlilar'),
        ('open-orders', 'Buyurtmalar'),
        ('open-profile', 'Profil'),
      ]) {
        final Text other = label(tester, key, text);
        expect(other.style?.fontWeight, FontWeight.w500);
        expect(other.style?.color, KitColors.muted);
      }
      expect(
        tester.getTopLeft(find.text('Bosh sahifa')).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.descendant(
                  of: byKey('open-home'),
                  matching: find.byType(Icon),
                ),
              )
              .dy,
        ),
      );
    },
  );

  testWidgets('labels stop growing at 15 px', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          bottomNavigationBar: CustomerTabBar(current: CustomerTab.home),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.text('Profil'),
    );
    expect(paragraph.textScaler.scale(11), closeTo(15, 1e-9));
  });

  testWidgets('labels fit a 320 px phone in Uzbek with text x 2', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          bottomNavigationBar: CustomerTabBar(current: CustomerTab.orders),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('every target meets iOSTapTargetGuideline', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await open(tester);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('with reduced motion the current tab jumps its list to the top', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            primary: true,
            children: <Widget>[
              for (int i = 0; i < 40; i++)
                SizedBox(height: 80, child: Text('$i')),
            ],
          ),
          bottomNavigationBar: const CustomerTabBar(current: CustomerTab.home),
        ),
      ),
    );
    final ScrollableState list = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    list.position.jumpTo(300);
    await tester.pump();
    expect(list.position.pixels, 300);

    await tester.tap(byKey('open-home'));
    await tester.pump();

    expect(list.position.pixels, 0);
  });
}
