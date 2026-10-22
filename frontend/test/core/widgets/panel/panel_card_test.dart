import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_card.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_note.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 400, child: card)),
      ),
    ),
  );

  testWidgets('a panel card shows its title, count and trailing in its tone', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const PanelCard(
        title: 'Orders',
        count: '12',
        trailing: Icon(Icons.refresh),
        tone: KitTone.amber,
        children: <Widget>[Text('body')],
      ),
    );

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Orders')).style!.fontSize, 15);
    expect(
      tester.getTopRight(find.byIcon(Icons.refresh)).dx,
      tester.getTopRight(find.byType(KitCard)).dx - 20,
      reason: 'the trailing widget ends the header inside the padding',
    );
    KitCard card = tester.widget<KitCard>(find.byType(KitCard));
    expect(card.color, KitColors.warningWash);
    expect(card.outline, KitColors.warning);
    expect(
      card.padding,
      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );

    await pump(
      tester,
      const PanelCard(
        title: 'Orders',
        tone: KitTone.red,
        flush: true,
        children: <Widget>[Text('body')],
      ),
    );
    card = tester.widget<KitCard>(find.byType(KitCard));
    expect(card.color, Colors.white);
    expect(card.outline, KitColors.danger);
    expect(card.padding, const EdgeInsets.only(top: 18));
    expect(
      tester.getTopLeft(find.text('Orders')).dx -
          tester.getTopLeft(find.byType(KitCard)).dx,
      20,
      reason: 'a flush card keeps the header\'s side padding',
    );
    expect(
      tester.getTopLeft(find.text('body')).dx,
      tester.getTopLeft(find.byType(KitCard)).dx,
    );

    await pump(tester, const PanelCard(children: <Widget>[Text('body')]));
    expect(tester.widget<KitCard>(find.byType(KitCard)).outline, isNull);
    expect(find.byType(Row), findsNothing, reason: 'no header without parts');
  });
}
