import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/addresses/presentation/address_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/nonlinear_text_scaler.dart';

void main() {
  const GeoPoint point = GeoPoint(
    latitude: '41.311081',
    longitude: '69.240562',
  );
  const Address home = Address(
    id: 'a1',
    label: 'Дом',
    point: point,
    street: "Navoiy ko'chasi",
    house: '12',
    apartment: '5',
    landmark: 'Напротив школы № 64',
    deliveryNote: null,
  );
  const Address bare = Address(
    id: 'a2',
    label: null,
    point: point,
    street: "Bobur ko'chasi",
    house: '7',
    apartment: '3',
    landmark: null,
    deliveryNote: null,
  );

  final Finder face = find.byKey(const ValueKey<String>('address-card-a1'));

  Future<void> show(
    WidgetTester tester, {
    Address address = home,
    bool delivery = false,
    VoidCallback? onEdit,
    VoidCallback? onChoose,
    VoidCallback? onDelete,
    ApiFailure? notRemoved,
    int glow = 0,
    Locale locale = const Locale('ru'),
    TextScaler textScaler = TextScaler.noScaling,
    bool reduced = false,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: textScaler, disableAnimations: reduced),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: AddressListCard(
                address: address,
                delivery: delivery,
                onEdit: onEdit ?? () {},
                onChoose: onChoose,
                onDelete: onDelete ?? () {},
                notRemoved: notRemoved,
                glow: glow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a labelled card shows the line with the flat and the landmark', (
    WidgetTester tester,
  ) async {
    await show(tester);

    TextStyle style(String text) => tester
        .widget<Text>(find.descendant(of: face, matching: find.text(text)))
        .style!;
    final TextStyle title = style('Дом');
    expect(title.fontSize, 15);
    expect(title.fontWeight, FontWeight.w700);
    expect(title.color, KitColors.ink);
    final TextStyle line = style("Navoiy ko'chasi, 12, кв. 5");
    expect(line.fontSize, 13);
    expect(line.color, KitColors.ink2);
    final TextStyle landmark = style('Ориентир: Напротив школы № 64');
    expect(landmark.fontSize, 12);
    expect(landmark.color, KitColors.muted);
  });

  testWidgets('an unlabelled card is named by its street and shows the flat '
      'under it', (WidgetTester tester) async {
    await show(tester, address: bare);
    final Finder bareFace = find.byKey(
      const ValueKey<String>('address-card-a2'),
    );

    expect(
      find.descendant(of: bareFace, matching: find.text("Bobur ko'chasi, 7")),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bareFace, matching: find.text('кв. 3')),
      findsOneWidget,
    );

    await show(
      tester,
      address: const Address(
        id: 'a2',
        label: null,
        point: point,
        street: "Bobur ko'chasi",
        house: '7',
        apartment: null,
        landmark: null,
        deliveryNote: null,
      ),
    );
    expect(
      find.descendant(of: bareFace, matching: find.byType(Text)),
      findsOneWidget,
    );
  });

  testWidgets('the icon follows the label', (WidgetTester tester) async {
    Address labelled(String? label) => Address(
      id: 'a1',
      label: label,
      point: point,
      street: 'Street',
      house: '1',
      apartment: null,
      landmark: null,
      deliveryNote: null,
    );
    IconData? icon() => tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('address-lead-a1')),
            matching: find.byType(Icon),
          ),
        )
        .icon;

    await show(tester, address: labelled('Дом'));
    expect(icon(), Icons.home_outlined);
    await show(tester, address: labelled('Работа'));
    expect(icon(), Icons.work_outline);
    await show(tester, address: labelled('Мама'));
    expect(icon(), Icons.location_on_outlined);
    await show(tester, address: labelled(null));
    expect(icon(), Icons.location_on_outlined);

    await show(tester, address: labelled('Uy'), locale: const Locale('uz'));
    expect(icon(), Icons.home_outlined);
    await show(tester, address: labelled('Ish'), locale: const Locale('uz'));
    expect(icon(), Icons.work_outline);

    final Finder lead = find.byKey(const ValueKey<String>('address-lead-a1'));
    expect(tester.getSize(lead), const Size(44, 44));
    final BoxDecoration decoration =
        tester.widget<Container>(lead).decoration! as BoxDecoration;
    expect(decoration.color, KitColors.primaryWash);
  });

  testWidgets('the delivery card has a green ring and Доставка сюда', (
    WidgetTester tester,
  ) async {
    BoxDecoration surface() =>
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey<String>('address-surface-a1')),
                )
                .decoration
            as BoxDecoration;

    await show(tester, delivery: true);
    final Border ring = surface().border! as Border;
    expect(ring.top.width, 1.5);
    expect(ring.top.color, KitColors.primary);
    expect(find.text('Доставка сюда'), findsOneWidget);

    await show(tester);
    expect(surface().border, isNull);
    expect(find.text('Доставка сюда'), findsNothing);
  });

  group('the chip pop', () {
    double scale(WidgetTester tester) => tester
        .widget<Transform>(
          find.byKey(const ValueKey<String>('address-chip-a1')),
        )
        .transform
        .entry(0, 0);

    testWidgets('the chip pops when the card becomes the delivery address', (
      WidgetTester tester,
    ) async {
      await show(tester);
      await show(tester, delivery: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(tester), greaterThan(1.05));
      await tester.pump(const Duration(milliseconds: 220));
      expect(scale(tester), 1);
    });

    testWidgets('there is no pop on a first build', (
      WidgetTester tester,
    ) async {
      await show(tester, delivery: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(tester), 1);
    });

    testWidgets('there is no pop with reduced motion', (
      WidgetTester tester,
    ) async {
      await show(tester, reduced: true);
      await show(tester, delivery: true, reduced: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(tester), 1);
    });
  });

  testWidgets('a card is one stop with its actions', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int edited = 0;
    int deleted = 0;
    int chosen = 0;
    await show(
      tester,
      delivery: true,
      onEdit: () => edited++,
      onDelete: () => deleted++,
      onChoose: () => chosen++,
    );

    SemanticsNode node = tester.getSemantics(face);
    SemanticsData data = node.getSemanticsData();
    expect(
      data.label,
      "Дом, доставка сюда, Navoiy ko'chasi, 12, кв. 5, "
      'Ориентир: Напротив школы № 64',
    );
    expect(data.flagsCollection.isButton, isTrue);
    expect(node.hintOverrides?.onTapHint, 'изменить');
    expect(node.childrenCount, 0);
    List<String> actions() => data.customSemanticsActionIds!
        .map(CustomSemanticsAction.getAction)
        .whereType<CustomSemanticsAction>()
        .where((CustomSemanticsAction a) => a.label != null)
        .map((CustomSemanticsAction a) => a.label!)
        .toList();
    expect(actions(), <String>['Удалить']);

    await show(tester, onChoose: () => chosen++, onDelete: () => deleted++);
    node = tester.getSemantics(face);
    data = node.getSemanticsData();
    expect(data.label, startsWith('Дом, Navoiy'));
    expect(actions(), <String>['Удалить', 'Доставлять сюда']);
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      data.customSemanticsActionIds!.firstWhere(
        (int id) =>
            CustomSemanticsAction.getAction(id)!.label == 'Доставлять сюда',
      ),
    );
    expect(chosen, 1);

    expect(find.byTooltip('Действия: Дом'), findsOneWidget);
    expect(edited, 0);
    expect(deleted, 0);
    handle.dispose();
  });

  group('the menu', () {
    Finder item(String name) =>
        find.byKey(ValueKey<String>('address-$name-a1'));

    testWidgets('the menu offers edit, deliver here and a red delete', (
      WidgetTester tester,
    ) async {
      int edited = 0;
      int chosen = 0;
      int deleted = 0;
      await show(
        tester,
        onEdit: () => edited++,
        onChoose: () => chosen++,
        onDelete: () => deleted++,
      );
      await tester.tap(item('menu'));
      await tester.pumpAndSettle();

      expect(find.text('Изменить'), findsOneWidget);
      final double edit = tester.getTopLeft(item('edit')).dy;
      final double choose = tester.getTopLeft(item('choose')).dy;
      final double delete = tester.getTopLeft(item('delete')).dy;
      expect(edit, lessThan(choose));
      expect(choose, lessThan(delete));
      for (final String name in <String>['edit', 'choose', 'delete']) {
        expect(tester.getSize(item(name)).height, 44);
      }
      final Text deleteText = tester.widget<Text>(find.text('Удалить'));
      expect(deleteText.style!.color, KitColors.danger);
      final Icon deleteIcon = tester.widget<Icon>(
        find.descendant(of: item('delete'), matching: find.byType(Icon)),
      );
      expect(deleteIcon.color, KitColors.danger);
      expect(deleteIcon.icon, Icons.delete_outline);

      await tester.tap(item('choose'));
      await tester.pumpAndSettle();
      expect(chosen, 1);
      await tester.tap(item('menu'));
      await tester.pumpAndSettle();
      await tester.tap(item('edit'));
      await tester.pumpAndSettle();
      expect(edited, 1);
      await tester.tap(item('menu'));
      await tester.pumpAndSettle();
      await tester.tap(item('delete'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
    });

    testWidgets('there is no deliver-here item on the delivery card or '
        'without onChoose', (WidgetTester tester) async {
      await show(tester, delivery: true, onChoose: () {});
      await tester.tap(item('menu'));
      await tester.pumpAndSettle();
      expect(item('choose'), findsNothing);
      expect(item('edit'), findsOneWidget);
      await tester.tapAt(const Offset(5, 600));
      await tester.pumpAndSettle();

      await show(tester);
      await tester.tap(item('menu'));
      await tester.pumpAndSettle();
      expect(item('choose'), findsNothing);
      expect(find.text('Доставлять сюда'), findsNothing);
    });
  });

  testWidgets('the menu button sits 10 down and 4 in, the text ends 12 '
      'before it', (WidgetTester tester) async {
    await show(tester);

    final Rect card = tester.getRect(
      find.byKey(const ValueKey<String>('address-surface-a1')),
    );
    final Rect menu = tester.getRect(
      find.byKey(const ValueKey<String>('address-menu-a1')),
    );
    expect(menu.top - card.top, 10);
    expect(card.right - menu.right, 4);
    final Rect title = tester.getRect(find.text('Дом'));
    final Rect line = tester.getRect(find.textContaining('Navoiy'));
    expect(card.right - line.right, greaterThanOrEqualTo(60));
    expect(title.right, lessThanOrEqualTo(line.right));
  });

  testWidgets('a failed removal says why on the card', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await show(tester, notRemoved: const NetworkFailure());
    final Text line = tester.widget<Text>(
      find.descendant(
        of: face,
        matching: find.text('Нет связи — адрес не удалён'),
      ),
    );
    expect(line.style!.fontSize, 13);
    expect(line.style!.fontWeight, FontWeight.w600);
    expect(line.style!.color, KitColors.danger);
    expect(
      tester.getSemantics(face).getSemanticsData().label,
      endsWith(', Нет связи — адрес не удалён'),
    );

    await show(tester, notRemoved: const UnexpectedFailure());
    expect(find.text('Не удалось удалить адрес'), findsOneWidget);
    expect(find.text('Нет связи — адрес не удалён'), findsNothing);
    handle.dispose();
  });

  group('the glow', () {
    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(find.byKey(const ValueKey<String>('address-glow-a1')))
        .opacity;

    testWidgets('the glow plays once when asked', (WidgetTester tester) async {
      await show(tester);
      expect(opacity(tester), 0);
      await show(tester, glow: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 450));
      expect(opacity(tester), closeTo(1, 0.01));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(opacity(tester), 0);
    });

    testWidgets('it plays on a first build when asked, and not again for '
        'the same count', (WidgetTester tester) async {
      await show(tester, glow: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacity(tester), closeTo(1, 0.01));
      await tester.pump(const Duration(milliseconds: 1500));
      await show(tester, glow: 1);
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacity(tester), 0);
    });

    testWidgets('with reduced motion it starts at once', (
      WidgetTester tester,
    ) async {
      await show(tester, reduced: true);
      await show(tester, glow: 1, reduced: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(tester), greaterThan(0.3));
    });
  });

  testWidgets('large text keeps the card whole', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await show(
      tester,
      delivery: true,
      notRemoved: const NetworkFailure(),
      textScaler: const NonlinearTextScaler(2),
    );
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

    await tester.tap(find.byKey(const ValueKey<String>('address-menu-a1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  });
}
