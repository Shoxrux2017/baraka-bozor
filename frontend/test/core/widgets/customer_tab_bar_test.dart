import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/customer_tab_bar.dart';
import 'package:flutter/material.dart';
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

  testWidgets('the bar is 99 high, white, with the icons at 28 and labels', (
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
    expect(home.size, 28);
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
}
