import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/panel/panel_card.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:baraka_bozor/features/operations/presentation/order_side.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_operations_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/operations_json.dart';

/// The order page after the final review and the real-stack walk
/// (`DL-100` (8)): the laptop widths, dates on the path and in the history,
/// the prices of bought and fixed lines, and the header of a card.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String money(int amount) => MoneyFormat.uzs(amount, AppLanguage.uz);

  Finder inStep(int step, Finder matching) =>
      find.descendant(of: byKey('order-path-$step'), matching: matching);

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository();
  });

  Future<void> openOrder(
    WidgetTester tester, {
    Size size = const Size(1440, 1600),
    Locale device = const Locale('uz'),
    DateTime Function()? clock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        operations: operations,
        device: device,
        clock: clock ?? () => DateTime.utc(2026, 9, 27, 10),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/operations/orders/$orderA');
    await tester.pumpAndSettle();
  }

  BoardOrder order({
    String status = 'shopping',
    List<Object?>? items,
    List<Object?>? history,
  }) => OperationsApi.parseOrder(
    orderJson(status: status, items: items, history: history),
  );

  Finder itemsCard() => find.ancestor(
    of: byKey('order-item-$itemId'),
    matching: find.byType(PanelCard),
  );

  testWidgets('a 1366 laptop window has two columns on the order page', (
    WidgetTester tester,
  ) async {
    await openOrder(tester, size: const Size(1366, 768));

    expect(
      tester.getTopRight(itemsCard()).dx,
      lessThan(tester.getTopLeft(find.byType(ClientCard)).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the path and the history of another day carry the date', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order(
      status: 'new',
      history: <Object?>[historyJson()],
    );

    await openOrder(tester, clock: () => DateTime.utc(2026, 9, 28, 10));
    AppLocalizations words = l10n(tester);
    expect(
      inStep(0, find.text(words.orderPathWaiting('27.09 12:00'))),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('history-$historyId'),
        matching: find.text('27.09 12:05'),
      ),
      findsOneWidget,
    );

    await openOrder(tester);
    words = l10n(tester);
    expect(
      inStep(0, find.text(words.orderPathWaiting('12:00'))),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('history-$historyId'),
        matching: find.text('12:05'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the red end of a cancelled path carries the date too', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order(status: 'cancelled');

    await openOrder(tester, clock: () => DateTime.utc(2026, 9, 28, 10));
    expect(inStep(1, find.text('27.09 13:00')), findsOneWidget);

    await openOrder(tester);
    expect(inStep(1, find.text('13:00')), findsOneWidget);
  });

  testWidgets(
    'a bought estimate line keeps the estimate under the price paid',
    (WidgetTester tester) async {
      operations.details[orderA] = order(
        status: 'ready_for_delivery',
        items: <Object?>[itemJson(status: 'purchased')],
      );
      await openOrder(tester);
      final AppLocalizations words = l10n(tester);

      expect(
        tester.widget<Text>(byKey('order-item-was-$itemId')).data,
        words.itemWasEstimate('${money(18400)}/${words.unitKg}'),
      );
      expect(
        tester.getTopLeft(byKey('order-item-was-$itemId')).dy,
        greaterThan(
          tester.getBottomLeft(byKey('order-item-paid-$itemId')).dy - 1,
        ),
      );
    },
  );

  testWidgets('a fixed line shows its price plain, an estimate line with ≈', (
    WidgetTester tester,
  ) async {
    const String estimateId = '0192f0a0-0000-7000-8000-500000000008';
    operations.details[orderA] = order(
      items: <Object?>[
        itemJson(priceMode: 'fixed'),
        itemJson(id: estimateId),
      ],
    );
    await openOrder(tester);
    final AppLocalizations words = l10n(tester);
    final String unitPrice = '${money(18400)}/${words.unitKg}';

    Finder inLine(String id, Finder matching) =>
        find.descendant(of: byKey('order-line-$id'), matching: matching);
    expect(inLine(itemId, find.text(unitPrice)), findsOneWidget);
    expect(inLine(itemId, find.text(money(55200))), findsOneWidget);
    expect(inLine(estimateId, find.text('≈ $unitPrice')), findsOneWidget);
    expect(inLine(estimateId, find.text('≈ ${money(55200)}')), findsOneWidget);
  });

  testWidgets('the markup stands at the right end of the items header', (
    WidgetTester tester,
  ) async {
    operations.details[orderA] = order(items: <Object?>[itemJson()]);
    await openOrder(tester);

    final Finder markup = find.descendant(
      of: itemsCard(),
      matching: find.text(l10n(tester).itemMarkup('15')),
    );
    expect(markup, findsOneWidget);
    expect(
      tester.getTopRight(itemsCard()).dx - tester.getTopRight(markup).dx,
      lessThan(24),
    );
  });
}
