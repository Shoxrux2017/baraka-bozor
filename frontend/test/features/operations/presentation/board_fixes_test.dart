import 'dart:ui' show PointerDeviceKind;

import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_operations_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/operations_json.dart';

/// The board after the final review and the real-stack walk (`DL-100` (8)):
/// the laptop widths, the summary on return, the dates, the status pills by
/// mouse and while the summary fails, and the total of a row.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  const String orderC = '0192f0a0-0000-7000-8000-00000000000c';

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
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
  }

  for (final Size size in const <Size>[Size(1366, 768), Size(1424, 900)]) {
    testWidgets('a laptop window keeps the attention list beside a table '
        '(${size.width.toInt()}x${size.height.toInt()})', (
      WidgetTester tester,
    ) async {
      await open(tester, size: size);

      expect(find.byType(Table), findsWidgets);
      expect(
        tester.getTopLeft(byKey('board-attention')).dx,
        greaterThan(tester.getTopRight(byKey('board-row-$orderA')).dx),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the board and back loads the summary again and says when', (
    WidgetTester tester,
  ) async {
    DateTime now = DateTime.utc(2026, 9, 27, 10);
    await open(tester, clock: () => now);
    expect(find.text(l10n(tester).boardUpdatedAt('15:00')), findsOneWidget);
    expect(operations.loads.where((String l) => l == 'summary'), hasLength(1));

    await tester.tap(byKey('board-row-$orderA'));
    await tester.pumpAndSettle();
    now = DateTime.utc(2026, 9, 27, 10, 30);
    await tester.tap(byKey('order-back'));
    await tester.pumpAndSettle();

    expect(operations.loads.where((String l) => l == 'summary'), hasLength(2));
    expect(find.text(l10n(tester).boardUpdatedAt('15:30')), findsOneWidget);
    expect(find.text(l10n(tester).boardUpdatedAt('15:00')), findsNothing);
  });

  testWidgets('a row and an attention item of another day carry the date', (
    WidgetTester tester,
  ) async {
    operations.rows = <BoardRow>[
      OperationsApi.parseRow(rowJson(createdAt: '2026-09-27T13:00:00Z')),
    ];
    operations.attentionAnswer = <AttentionItem>[
      OperationsApi.parseAttention(<String, Object?>{
        ...attentionJson(),
        'since': '2026-09-27T13:00:00Z',
      }),
    ];

    // The next day: the date stands before the time.
    await open(tester, clock: () => DateTime.utc(2026, 9, 28, 10));
    expect(
      find.descendant(
        of: byKey('board-row-$orderA'),
        matching: find.text('27.09 18:00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('board-attention'),
        matching: find.textContaining(
          l10n(tester).attentionSince('27.09 18:00'),
        ),
      ),
      findsOneWidget,
    );

    // The same day: the time alone.
    await open(tester, clock: () => DateTime.utc(2026, 9, 27, 15));
    expect(
      find.descendant(
        of: byKey('board-row-$orderA'),
        matching: find.text('18:00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('board-attention'),
        matching: find.textContaining(l10n(tester).attentionSince('18:00')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a mouse drags the narrow status row to its last pill', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(940, 900));
    final Finder last = byKey('summary-on_the_way');
    final double before = tester.getTopLeft(last).dx;
    expect(before, greaterThan(940));

    final TestGesture mouse = await tester.startGesture(
      tester.getCenter(byKey('summary-all')),
      kind: PointerDeviceKind.mouse,
    );
    for (int i = 0; i < 6; i++) {
      await mouse.moveBy(const Offset(-300, 0));
    }
    await mouse.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(last).dx, lessThan(940));
    expect(find.byType(Scrollbar), findsWidgets);
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(operations.queries.last.status, OrderStatus.onTheWay);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the status pills filter while the summary fails', (
    WidgetTester tester,
  ) async {
    operations.summaryFailure = const NetworkFailure();
    await open(tester);

    expect(byKey('summary-all'), findsOneWidget);
    for (final OrderStatus status in OrderStatus.open) {
      expect(byKey('summary-${status.code}'), findsOneWidget);
    }
    expect(
      find.descendant(of: byKey('summary-new'), matching: find.text('2')),
      findsNothing,
      reason: 'the counts wait for the summary',
    );

    await tester.tap(byKey('summary-new'));
    await tester.pumpAndSettle();
    expect(operations.queries.last.status, OrderStatus.newOrder);
  });

  for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
    testWidgets(
      'a row and a card show the estimate with a sign, the final total '
      'plain (${size.width.toInt()})',
      (WidgetTester tester) async {
        operations.rows = <BoardRow>[
          OperationsApi.parseRow(rowJson()),
          OperationsApi.parseRow(
            rowJson(
              id: orderB,
              number: 1002,
              totalUzs: 31000,
              totalKind: 'final',
            ),
          ),
          OperationsApi.parseRow(
            rowJson(
              id: orderC,
              number: 1003,
              totalUzs: null,
              totalKind: 'none',
              status: 'cancelled',
            ),
          ),
        ];
        await open(tester, size: size);
        final AppLocalizations words = l10n(tester);
        String money(int amount) => MoneyFormat.uzs(amount, AppLanguage.uz);

        Finder inRow(String id, Finder matching) =>
            find.descendant(of: byKey('board-row-$id'), matching: matching);
        expect(inRow(orderA, find.text('≈ ${money(75200)}')), findsOneWidget);
        expect(inRow(orderB, find.text(money(31000))), findsOneWidget);
        expect(inRow(orderC, find.text(words.totalNothingDue)), findsOneWidget);
        expect(find.textContaining(words.totalKindEstimate), findsNothing);
        expect(find.textContaining(words.totalKindFinal), findsNothing);
      },
    );
  }

  testWidgets('a card puts its total at the right end of its row', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(820, 1180));

    final Rect card = tester.getRect(byKey('board-row-$orderA'));
    final Finder total = find.descendant(
      of: byKey('board-row-$orderA'),
      matching: find.text('≈ ${MoneyFormat.uzs(75200, AppLanguage.uz)}'),
    );
    expect(tester.getTopRight(total).dx, closeTo(card.right - 16, 0.5));
  });
}
