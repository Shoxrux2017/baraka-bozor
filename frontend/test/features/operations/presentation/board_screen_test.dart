import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/core/widgets/kit/kit_card.dart';
import 'package:baraka_bozor/features/operations/presentation/board_filters.dart';
import 'package:baraka_bozor/features/operations/presentation/board_orders.dart';
import 'package:baraka_bozor/features/operations/presentation/board_screen.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/operations/data/operations_api.dart';
import 'package:baraka_bozor/features/operations/domain/board.dart';
import 'package:baraka_bozor/features/operations/presentation/board_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_operations_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/operations_json.dart';

/// The board of `docs/09` section 38 through the real router, shell and
/// controllers, with the operations repository faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeOperationsRepository operations;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  String location(WidgetTester tester) =>
      GoRouter.of(anywhere(tester)).routeInformationProvider.value.uri
          .toString();

  BoardQuery lastQuery() => operations.queries.last;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.staff] = 's';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.staff] = user(role: UserRole.operator);
    operations = FakeOperationsRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1400, 1200),
    double textScale = 1,
    Locale device = const Locale('uz'),
    DateTime Function()? clock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        surface: Surface.web,
        operations: operations,
        device: device,
        clock: clock,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Whether the text [finder] shows is cut: laid out shorter than it needs.
  bool cut(WidgetTester tester, Finder finder) {
    final RenderParagraph paragraph = tester.renderObject(finder);
    return paragraph.size.height <
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The attention items on the board, not the fold button.
  Finder attentionItems() => find.descendant(
    of: byKey('board-attention'),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          RegExp(r'^attention-[a-z_]+-[0-9a-f-]{36}$')
              .hasMatch((widget.key! as ValueKey<String>).value) &&
          widget is InkWell,
    ),
  );

  List<AttentionItem> waiting(int count, {String type = 'courier_delayed'}) =>
      <AttentionItem>[
        for (int i = 1; i <= count; i++)
          OperationsApi.parseAttention(<String, Object?>{
            ...attentionJson(order: '0192f0a0-0000-7000-8000-0000000001a$i'),
            'type': type,
            'shopper': null,
          }),
      ];

  Color? washOf(WidgetTester tester, String key) =>
      (tester.widget<Container>(byKey(key)).decoration! as BoxDecoration).color;

  BoardSummary summaryOf({int attention = 1}) =>
      OperationsApi.parseSummary(<String, Object?>{
        ...summaryJson(attention: attention),
        'open_by_status': <String, int>{
          'new': 2,
          'shopping_assigned': 1,
          'shopping': 4,
          'final_payment_pending': 0,
          'ready_for_delivery': 1,
          'delivery_assigned': 1,
          'on_the_way': 2,
        },
        'completed_today': 24,
        'cancelled_today': 2,
        'sales_today_uzs': 3862400,
      });

  /// Opens the menu button [button] and takes the item with [item].
  Future<void> choose(WidgetTester tester, String button, String item) async {
    await tapAndSettle(tester, byKey(button));
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text(item),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect ordersCard(WidgetTester tester) =>
      tester.getRect(find.byType(BoardOrders));

  testWidgets('the board shows the day, the orders and what needs attention', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(1440, 900));

    expect(byKey('summary-open'), findsOneWidget);
    expect(find.byType(Table), findsWidgets);
    expect(byKey('board-row-$orderA'), findsOneWidget);
    expect(byKey('board-row-$orderB'), findsOneWidget);
    expect(find.text(l10n(tester).boardNoShopper), findsOneWidget);
    expect(byKey('attention-self_order-$orderA'), findsOneWidget);
    expect(lastQuery(), const BoardQuery());
  });

  testWidgets('the tiles count the open orders and today\'s ends', (
    WidgetTester tester,
  ) async {
    operations.summaryAnswer = summaryOf();
    await open(tester);

    Finder inTile(String key, Finder text) =>
        find.descendant(of: byKey(key), matching: text);
    expect(inTile('summary-open', find.text('11')), findsOneWidget);
    expect(inTile('summary-completed', find.text('24')), findsOneWidget);
    expect(inTile('summary-cancelled', find.text('2')), findsOneWidget);
    expect(
      inTile(
        'summary-sales',
        find.text(MoneyFormat.uzs(3862400, AppLanguage.uz)),
      ),
      findsOneWidget,
    );
    for (final String key in const <String>['summary-open', 'summary-sales']) {
      expect(
        inTile(key, find.byType(InkWell)),
        findsNothing,
        reason: '$key does nothing',
      );
    }
  });

  testWidgets('today\'s completed and cancelled tiles filter the board', (
    WidgetTester tester,
  ) async {
    await open(tester);
    KitCard card(String key) => tester.widget<KitCard>(
      find.descendant(of: byKey(key), matching: find.byType(KitCard)),
    );

    expect(card('summary-completed').outline, isNull);
    await tapAndSettle(tester, byKey('summary-completed'));
    expect(lastQuery().status, OrderStatus.completed);
    expect(card('summary-completed').color, KitColors.primaryWash);
    expect(card('summary-completed').outline, KitColors.primary);
    expect(card('summary-cancelled').outline, isNull);

    await tapAndSettle(tester, byKey('summary-completed'));
    expect(lastQuery().status, isNull);
    expect(card('summary-completed').outline, isNull);

    await tapAndSettle(tester, byKey('summary-cancelled'));
    expect(lastQuery().status, OrderStatus.cancelled);
    await tapAndSettle(tester, byKey('summary-cancelled'));
    expect(lastQuery().status, isNull);
  });

  testWidgets('a status pill filters the board and "Все заказы" clears it', (
    WidgetTester tester,
  ) async {
    operations.summaryAnswer = summaryOf();
    await open(tester);
    final AppLocalizations words = l10n(tester);
    Color? ground(String key) => tester
        .widget<Material>(
          find
              .descendant(of: byKey(key), matching: find.byType(Material))
              .first,
        )
        .color;
    Color? textOf(String key, String text) => tester
        .widget<Text>(
          find.descendant(of: byKey(key), matching: find.text(text)),
        )
        .style!
        .color;

    expect(
      tester.getTopLeft(byKey('summary-all')).dx,
      lessThan(tester.getTopLeft(byKey('summary-new')).dx),
    );
    expect(
      find.descendant(of: byKey('summary-shopping'), matching: find.text('4')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('summary-all'),
        matching: find.text(words.boardAllOrders),
      ),
      findsOneWidget,
    );
    expect(ground('summary-all'), KitColors.primary);
    expect(
      textOf('summary-final_payment_pending', '0'),
      KitColors.muted,
      reason: 'a zero count reads muted',
    );

    await tapAndSettle(tester, byKey('summary-new'));
    expect(lastQuery().status, OrderStatus.newOrder);
    expect(ground('summary-new'), KitColors.primary);
    expect(
      textOf('summary-new', OrderLabels.status(words, OrderStatus.newOrder)),
      Colors.white,
    );
    expect(ground('summary-all'), Colors.white);

    await tapAndSettle(tester, byKey('summary-all'));
    expect(lastQuery().status, isNull);
    expect(ground('summary-all'), KitColors.primary);
  });

  testWidgets(
    'the refresh button is labelled on a wide board, an icon on a narrow one',
    (WidgetTester tester) async {
      await open(tester, size: const Size(1440, 900));
      expect(
        find.descendant(
          of: byKey('board-refresh'),
          matching: find.text(l10n(tester).boardRefresh),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('board-refresh'),
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );

      await open(tester, size: const Size(820, 1180), textScale: 2);
      expect(
        find.descendant(
          of: byKey('board-refresh'),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: byKey('board-refresh'),
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the header says when the board was loaded', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      device: const Locale('ru'),
      clock: () => DateTime.utc(2026, 10, 22, 9, 34),
    );

    expect(find.text(l10n(tester).boardUpdatedAt('14:34')), findsOneWidget);
    expect(find.text('Обновлено в 14:34'), findsOneWidget);
  });

  testWidgets('an attention item says how long it has waited, in its tone', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 10, 22, 9, 34);
    String since(int minutes) =>
        now.subtract(Duration(minutes: minutes)).toIso8601String();
    const List<String> orders = <String>[
      '0192f0a0-0000-7000-8000-0000000001a1',
      '0192f0a0-0000-7000-8000-0000000001a2',
      '0192f0a0-0000-7000-8000-0000000001a3',
      '0192f0a0-0000-7000-8000-0000000001a4',
    ];
    operations.attentionAnswer = <AttentionItem>[
      OperationsApi.parseAttention(<String, Object?>{
        ...attentionJson(order: orders[0]),
        'type': 'approval_expired',
        'since': since(114),
        'courier': <String, Object?>{
          'id': courierId,
          'full_name': 'Kamol Karimov',
        },
      }),
      OperationsApi.parseAttention(<String, Object?>{
        ...attentionJson(order: orders[1]),
        'type': 'approval_pending',
        'since': since(36),
        'shopper': null,
      }),
      OperationsApi.parseAttention(<String, Object?>{
        ...attentionJson(order: orders[2]),
        'type': 'low_rating',
        'since': since(36),
        'shopper': null,
      }),
      OperationsApi.parseAttention(<String, Object?>{
        ...attentionJson(order: orders[3]),
        'type': 'self_order',
        'since': since(61),
        'shopper': null,
      }),
    ];
    await open(tester, size: const Size(1800, 1600), clock: () => now);
    final AppLocalizations words = l10n(tester);
    Color? iconColor(String code, String order) => tester
        .widget<Icon>(
          find.descendant(
            of: byKey('attention-icon-$code-$order'),
            matching: find.byType(Icon),
          ),
        )
        .color;
    Color? waitingColor(String code, String order) => tester
        .widget<Text>(byKey('attention-waiting-$code-$order'))
        .style!
        .color;

    expect(
      find.descendant(
        of: byKey('attention-approval_expired-${orders[0]}'),
        matching: find.text(words.attentionWaitingHours(1, 54)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('attention-approval_pending-${orders[1]}'),
        matching: find.text(words.attentionWaitingMinutes(36)),
      ),
      findsOneWidget,
    );
    expect(find.text(words.attentionWaitingHours(1, 1)), findsOneWidget);

    expect(
      washOf(tester, 'attention-icon-approval_expired-${orders[0]}'),
      KitColors.dangerWash,
    );
    expect(iconColor('approval_expired', orders[0]), KitColors.danger);
    expect(waitingColor('approval_expired', orders[0]), KitColors.danger);

    expect(
      washOf(tester, 'attention-icon-approval_pending-${orders[1]}'),
      KitColors.warningWash,
    );
    expect(iconColor('approval_pending', orders[1]), KitColors.warning);
    expect(waitingColor('approval_pending', orders[1]), KitColors.warningDark);

    for (final (String, String) grey in <(String, String)>[
      ('low_rating', orders[2]),
      ('self_order', orders[3]),
    ]) {
      expect(
        washOf(tester, 'attention-icon-${grey.$1}-${grey.$2}'),
        KitColors.field,
      );
      expect(iconColor(grey.$1, grey.$2), KitColors.ink2);
      expect(waitingColor(grey.$1, grey.$2), KitColors.warningDark);
    }

    final String time = TashkentTime.time(
      now.subtract(const Duration(minutes: 114)),
    );
    expect(
      find.text(
        '${words.historyAssignedTo('Sardor Yusupov')} · '
        '${words.historyCourierAssignedTo('Kamol Karimov')} · '
        '${words.attentionSince(time)}',
      ),
      findsOneWidget,
    );
    expect(byKey('summary-attention'), findsOneWidget);
  });

  for (final Size size in const <Size>[
    Size(1440, 900),
    Size(1280, 800),
    Size(1188, 800),
  ]) {
    testWidgets('a wide board keeps the attention list beside the orders '
        '(${size.width.toInt()}x${size.height.toInt()})', (
      WidgetTester tester,
    ) async {
      operations.attentionAnswer = waiting(7);
      await open(tester, size: size);

      final Rect list = tester.getRect(byKey('board-attention'));
      expect(list.width, BoardScreen.attentionWidth);
      expect(
        list.left,
        greaterThan(tester.getTopRight(byKey('board-row-$orderA')).dx),
      );
      expect(attentionItems(), findsNWidgets(5));
      expect(find.text(l10n(tester).attentionShowAll(7)), findsOneWidget);
      expect(
        list.right,
        lessThanOrEqualTo(tester.getRect(byKey('operations-board')).right),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final Size size in const <Size>[Size(1187, 1180), Size(820, 1180)]) {
    testWidgets('a narrower board puts the attention list above the orders, '
        'two items first (${size.width.toInt()})', (WidgetTester tester) async {
      operations.attentionAnswer = waiting(6);
      await open(tester, size: size);

      expect(
        tester.getBottomLeft(byKey('board-attention')).dy,
        lessThanOrEqualTo(tester.getTopLeft(byKey('board-row-$orderA')).dy),
      );
      expect(attentionItems(), findsNWidgets(2));
      expect(find.text(l10n(tester).attentionShowAll(6)), findsOneWidget);

      await tapAndSettle(tester, byKey('attention-fold'));
      expect(attentionItems(), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });
  }

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final (String, Size, double) setup in const <(String, Size, double)>[
      ('820x1180 with text x2', Size(820, 1180), 2),
      ('1440x900', Size(1440, 900), 1),
    ]) {
      testWidgets('the board holds at ${setup.$1} (${language.languageCode})', (
        WidgetTester tester,
      ) async {
        operations.summaryAnswer = summaryOf(attention: 6);
        operations.attentionAnswer = <AttentionItem>[
          for (final AttentionItem item in waiting(6, type: 'delivery_failed'))
            AttentionItem(
              type: item.type,
              code: item.code,
              orderId: item.orderId,
              orderNumber: item.orderNumber,
              since: item.since,
              shopper: const PersonRef(
                id: shopperId,
                fullName: 'Abdurakhmonova Shakhnoza Rustamovna',
              ),
              courier: const PersonRef(
                id: courierId,
                fullName: 'Muhammadjonov Abdulloh Karimovich',
              ),
            ),
        ];
        await open(
          tester,
          size: setup.$2,
          textScale: setup.$3,
          device: language,
        );

        expect(byKey('board-attention'), findsOneWidget);
        expect(byKey('summary-sales'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('attention-fold'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'each attention type has its words, and one order may need two things',
    (WidgetTester tester) async {
      operations.attentionAnswer = <AttentionItem>[
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(),
          'type': 'approval_pending',
        }),
        OperationsApi.parseAttention(attentionJson()),
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: orderB, number: 1002),
          'type': 'approval_expired',
          'shopper': null,
        }),
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: orderB, number: 1002),
          'type': 'a_later_type',
        }),
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: orderB, number: 1002),
          'type': 'another_later_type',
        }),
      ];

      for (final Locale language in const <Locale>[
        Locale('uz'),
        Locale('ru'),
      ]) {
        await open(tester, size: const Size(1800, 1600), device: language);
        final AppLocalizations words = l10n(tester);

        expect(byKey('attention-approval_pending-$orderA'), findsOneWidget);
        expect(byKey('attention-self_order-$orderA'), findsOneWidget);
        expect(byKey('attention-approval_expired-$orderB'), findsOneWidget);
        expect(
          find.textContaining(words.attentionApprovalPending),
          findsOneWidget,
        );
        expect(
          find.textContaining(words.attentionApprovalExpired),
          findsOneWidget,
        );
        // Two types this client does not know are two rows, each in general
        // words.
        for (final String later in const <String>[
          'a_later_type',
          'another_later_type',
        ]) {
          expect(
            find.descendant(
              of: byKey('attention-$later-$orderB'),
              matching: find.textContaining(words.attentionOther),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final (Locale, String) language in const <(Locale, String)>[
    (Locale('uz'), 'Past baho'),
    (Locale('ru'), 'Низкая оценка'),
  ]) {
    testWidgets('a low_rating attention item reads as a low rating', (
      WidgetTester tester,
    ) async {
      operations.attentionAnswer = <AttentionItem>[
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(),
          'type': 'low_rating',
          'shopper': null,
        }),
      ];

      await open(tester, device: language.$1);

      expect(l10n(tester).attentionLowRating, language.$2);
      expect(
        find.descendant(
          of: byKey('attention-low_rating-$orderA'),
          matching: find.textContaining(language.$2),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'a row names its Courier and the Customer\'s open questions, in a table and a card',
    (WidgetTester tester) async {
      operations.rows = <BoardRow>[
        OperationsApi.parseRow(
          rowJson(
            status: 'delivery_assigned',
            courier: courierId,
            pendingApprovals: 2,
          ),
        ),
      ];
      for (final Size size in const <Size>[Size(1440, 900), Size(420, 1600)]) {
        await open(tester, size: size);
        final AppLocalizations words = l10n(tester);

        expect(
          find.descendant(
            of: byKey('board-courier-$orderA'),
            matching: find.text('Kamol Karimov'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: byKey('board-courier-$orderA'),
            matching: find.byIcon(Icons.two_wheeler),
          ),
          findsOneWidget,
        );
        expect(find.text(words.boardPendingQuestions(2)), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'the questions go under the status, so the table keeps its columns',
    (WidgetTester tester) async {
      operations.rows = <BoardRow>[
        OperationsApi.parseRow(rowJson(pendingApprovals: 3)),
      ];
      await open(tester, size: const Size(1440, 900));
      final Finder chip = find.descendant(
        of: byKey('board-row-$orderA'),
        matching: find.byType(OrderStatusChip),
      );
      final Finder questions = byKey('board-questions-$orderA');
      final AppLocalizations words = l10n(tester);

      expect(
        tester.getTopLeft(questions).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(chip).dy),
      );
      expect(
        tester.getTopLeft(find.byIcon(Icons.help_outline).last).dx,
        tester.getTopLeft(chip).dx,
        reason: 'the question starts where the status does',
      );
      expect(
        tester.getTopLeft(chip).dx,
        tester.getTopLeft(find.text(words.boardColumnStatus.toUpperCase())).dx,
        reason: 'under the status header',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the Courier\'s and the cancellation\'s attention have their words',
    (WidgetTester tester) async {
      const Map<String, String Function(AppLocalizations)> types =
          <String, String Function(AppLocalizations)>{
            'courier_delayed': _courierDelayed,
            'delivery_failed': _deliveryFailed,
            'cancellation_request': _cancellationRequest,
            'staff_blocked': _staffBlocked,
          };
      operations.attentionAnswer = <AttentionItem>[
        for (final String type in types.keys)
          OperationsApi.parseAttention(<String, Object?>{
            ...attentionJson(order: orderB, number: 1002),
            'type': type,
          }),
      ];

      for (final Locale language in const <Locale>[
        Locale('uz'),
        Locale('ru'),
      ]) {
        await open(tester, size: const Size(1800, 1600), device: language);
        final AppLocalizations words = l10n(tester);

        for (final MapEntry<String, String Function(AppLocalizations)> type
            in types.entries) {
          expect(
            find.descendant(
              of: byKey('attention-${type.key}-$orderB'),
              matching: find.textContaining(type.value(words)),
            ),
            findsOneWidget,
            reason: type.key,
          );
        }
      }
    },
  );

  testWidgets('the attention list folds past five items and unfolds on a tap', (
    WidgetTester tester,
  ) async {
    const List<String> orders = <String>[
      '0192f0a0-0000-7000-8000-0000000001a1',
      '0192f0a0-0000-7000-8000-0000000001a2',
      '0192f0a0-0000-7000-8000-0000000001a3',
      '0192f0a0-0000-7000-8000-0000000001a4',
      '0192f0a0-0000-7000-8000-0000000001a5',
      '0192f0a0-0000-7000-8000-0000000001a6',
      '0192f0a0-0000-7000-8000-0000000001a7',
    ];
    operations.attentionAnswer = <AttentionItem>[
      for (final String order in orders)
        OperationsApi.parseAttention(<String, Object?>{
          ...attentionJson(order: order),
          'type': 'courier_delayed',
          'shopper': null,
        }),
    ];
    await open(tester, size: const Size(1800, 1600));
    Finder items() => attentionItems();

    expect(items(), findsNWidgets(5));
    expect(find.text(l10n(tester).attentionShowAll(7)), findsOneWidget);
    await tapAndSettle(tester, byKey('attention-fold'));
    expect(items(), findsNWidgets(7));
    await tapAndSettle(tester, byKey('attention-fold'));
    expect(items(), findsNWidgets(5));
    expect(find.text(l10n(tester).attentionShowAll(7)), findsOneWidget);
  });

  testWidgets('the filters keep every way to narrow the board', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(1440, 900));
    final AppLocalizations words = l10n(tester);
    bool active(String key) =>
        tester
            .widget<OutlinedButton>(byKey(key))
            .style!
            .backgroundColor!
            .resolve(<WidgetState>{}) ==
        KitColors.primaryWash;

    expect(byKey('board-filters'), findsNothing);
    expect(active('board-payment-filter'), isFalse);
    await choose(tester, 'board-payment-filter', words.paymentCash);
    expect(lastQuery().paymentMethod, PaymentMethod.cash);
    expect(active('board-payment-filter'), isTrue);

    await tapAndSettle(tester, byKey('board-shopper-filter'));
    expect(find.text(words.boardAllShoppers), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('Sardor Yusupov'),
      ),
    );
    await tester.pumpAndSettle();
    expect(lastQuery().shopperId, shopperId);
    expect(
      find.descendant(
        of: byKey('board-shopper-filter'),
        matching: find.text('Sardor Yusupov'),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('board-courier-filter'));
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('Kamol Karimov'),
      ),
    );
    await tester.pumpAndSettle();
    expect(lastQuery().courierId, courierId);

    await tapAndSettle(tester, byKey('board-self-orders'));
    expect(lastQuery().selfOrdersOnly, isTrue);
    await tapAndSettle(tester, byKey('board-awaiting-customer'));
    expect(lastQuery().awaitingCustomerOnly, isTrue);
    expect(tester.getSize(byKey('board-self-orders')).height, 32);
    expect(tester.getSize(byKey('board-awaiting-customer')).height, 32);

    await tester.enterText(byKey('board-search'), ' 1001 ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(lastQuery().search, '1001');
    expect(lastQuery().page, 1);
    expect(tester.getSize(byKey('board-search')).height, 40);

    await tapAndSettle(tester, byKey('board-clear-filters'));
    expect(lastQuery(), const BoardQuery());
    expect(
      tester.widget<TextField>(byKey('board-search')).controller!.text,
      isEmpty,
    );
    expect(active('board-payment-filter'), isFalse);
    expect(byKey('board-clear-filters'), findsNothing);

    // A status in the summary filters the board by it, and again clears it.
    await tapAndSettle(tester, byKey('summary-new'));
    expect(lastQuery().status, OrderStatus.newOrder);
    expect(byKey('board-row-$orderA'), findsNothing);
    await tapAndSettle(tester, byKey('summary-new'));
    expect(lastQuery().status, isNull);
  });

  testWidgets('the days are a range that one tap clears', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(1440, 900));
    final AppLocalizations words = l10n(tester);

    expect(byKey('board-clear-days'), findsNothing);
    expect(
      find.descendant(
        of: byKey('board-days'),
        matching: find.byIcon(Icons.calendar_month),
      ),
      findsOneWidget,
    );
    await tapAndSettle(tester, byKey('board-days'));
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.text('10').first);
    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(DateRangePickerDialog),
            matching: find.byType(TextButton),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(lastQuery().from, isNotNull);
    expect(lastQuery().to, isNotNull);
    expect(find.text(words.boardDays), findsNothing);
    expect(byKey('board-clear-days'), findsOneWidget);

    await tapAndSettle(tester, byKey('board-clear-days'));
    expect(lastQuery().from, isNull);
    expect(find.text(words.boardDays), findsOneWidget);
  });

  testWidgets('a narrow board gathers the filters under one button', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(820, 1180));
    final AppLocalizations words = l10n(tester);

    expect(byKey('board-payment-filter'), findsNothing);
    expect(byKey('board-self-orders'), findsNothing);
    expect(
      find.descendant(
        of: byKey('board-filters'),
        matching: find.byIcon(Icons.tune),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byKey('board-filters'),
        matching: find.text(words.boardFilters),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(byKey('board-filters')).dx,
      greaterThan(tester.getTopRight(byKey('board-search')).dx),
      reason: 'the search takes the width the button leaves',
    );
    expect(byKey('board-clear-filters'), findsNothing);

    await tapAndSettle(tester, byKey('board-filters'));
    expect(find.byType(Dialog), findsOneWidget);
    for (final String key in const <String>[
      'board-payment-filter',
      'board-shopper-filter',
      'board-courier-filter',
      'board-days',
      'board-self-orders',
      'board-awaiting-customer',
    ]) {
      expect(
        find.descendant(of: find.byType(Dialog), matching: byKey(key)),
        findsOneWidget,
        reason: key,
      );
    }
    expect(byKey('board-clear-filters'), findsNothing);

    await choose(tester, 'board-payment-filter', words.paymentCash);
    expect(lastQuery().paymentMethod, PaymentMethod.cash);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: byKey('board-clear-filters'),
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, byKey('board-clear-filters'));
    expect(lastQuery(), const BoardQuery());
    await tapAndSettle(tester, byKey('board-filters-close'));
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the filters switch to the wide row at a card of 820', (
    WidgetTester tester,
  ) async {
    // Stacked, the orders card is the board's content: window less 48.
    await open(tester, size: const Size(867, 1180));
    expect(ordersCard(tester).width, BoardFilters.wideWidth - 1);
    expect(byKey('board-filters'), findsOneWidget);

    await open(tester, size: const Size(868, 1180));
    expect(ordersCard(tester).width, BoardFilters.wideWidth);
    expect(byKey('board-filters'), findsNothing);
    expect(byKey('board-payment-filter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Shopper no longer listed stays the filter', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(1440, 900), device: const Locale('ru'));
    await choose(tester, 'board-shopper-filter', 'Sardor Yusupov');
    expect(lastQuery().shopperId, shopperId);

    operations.shopperList = <StaffChoice>[];
    await tapAndSettle(tester, byKey('board-row-$orderA'));
    await tapAndSettle(tester, byKey('order-back'));

    expect(lastQuery().shopperId, shopperId);
    expect(
      find.descendant(
        of: byKey('board-shopper-filter'),
        matching: find.text('Выбранный сборщик'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(byKey('board-shopper-filter'))
          .style!
          .backgroundColor!
          .resolve(<WidgetState>{}),
      KitColors.primaryWash,
    );
  });

  testWidgets('an erased row says so instead of a name and phone', (
    WidgetTester tester,
  ) async {
    operations.rows = <BoardRow>[OperationsApi.parseRow(rowJson(erased: true))];
    await open(tester, size: const Size(1440, 900), device: const Locale('ru'));

    final Finder erased = find.descendant(
      of: byKey('board-customer-$orderA'),
      matching: find.text('Данные покупателя удалены'),
    );
    expect(erased, findsOneWidget);
    final TextStyle style = tester.widget<Text>(erased).style!;
    expect(style.fontStyle, FontStyle.italic);
    expect(style.color, KitColors.muted);
    expect(find.textContaining('901112233'), findsNothing);
  });

  testWidgets(
    'an order opens on its page, and the board comes back as it was left',
    (WidgetTester tester) async {
      await open(tester);
      final AppLocalizations words = l10n(tester);
      await tapAndSettle(tester, byKey('board-self-orders'));
      operations.rows = <BoardRow>[
        ...operations.rows.map(
          (BoardRow row) => BoardRow(
            id: row.id,
            orderNumber: row.orderNumber,
            createdAt: row.createdAt,
            status: row.status,
            paymentMethod: row.paymentMethod,
            customerName: row.customerName,
            customerPhone: row.customerPhone,
            itemCount: row.itemCount,
            pendingApprovalCount: row.pendingApprovalCount,
            totalUzs: row.totalUzs,
            totalKind: row.totalKind,
            shopper: row.shopper,
            courier: row.courier,
            isSelfOrder: row.shopper != null,
          ),
        ),
      ];
      await tapAndSettle(tester, byKey('board-refresh'));

      await tapAndSettle(tester, byKey('board-row-$orderA'));

      expect(location(tester), '/operations/orders/$orderA');
      expect(find.text(words.orderTitle('1001')), findsOneWidget);
      expect(find.text('Pomidor · 3 ${words.unitKg}'), findsOneWidget);
      expect(find.text(words.itemMarkup('15.00')), findsOneWidget);
      expect(
        find.text(
          words.itemMarketPrice(MoneyFormat.uzs(16000, AppLanguage.uz)),
        ),
        findsOneWidget,
      );
      expect(find.text(words.assignmentCurrent), findsOneWidget);
      expect(
        find.text(
          '${words.historyEventShopperAssigned} · '
          '${words.orderStatusNew} → ${words.orderStatusShoppingAssigned}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Olim (${words.roleOperator})'),
        findsOneWidget,
      );
      expect(
        find.text(words.historyAssignedTo('Sardor Yusupov')),
        findsOneWidget,
      );
      expect(find.text('Kechqurun'), findsOneWidget);

      await tapAndSettle(tester, byKey('order-back'));
      expect(location(tester), AppPaths.operations);
      expect(lastQuery().selfOrdersOnly, isTrue, reason: 'the filters stay');
    },
  );

  testWidgets('a cancelled order shows nothing to pay and why it ended', (
    WidgetTester tester,
  ) async {
    await open(tester);
    operations.details[orderB] = OperationsApi.parseOrder(
      orderJson(
        id: orderB,
        status: 'cancelled',
        totals: <String, Object?>{
          'merchandise_subtotal_uzs': null,
          'service_fee_uzs': null,
          'delivery_fee_uzs': null,
          'total_uzs': null,
          'total_kind': 'none',
        },
        items: <Object?>[
          itemJson(status: 'removed', removedReason: 'order_cancelled'),
        ],
        assignments: <Object?>[],
        history: <Object?>[],
        cancellationReason: 'customer_cancelled',
      ),
    );
    final AppLocalizations words = l10n(tester);

    GoRouter.of(anywhere(tester)).go('/operations/orders/$orderB');
    await tester.pumpAndSettle();

    expect(find.text(words.totalNothingDue), findsOneWidget);
    expect(find.text(words.cancelCustomerCancelled), findsOneWidget);
    expect(
      find.text(words.itemRemovedBecause(words.removedOrderCancelled)),
      findsOneWidget,
    );
    expect(find.text(words.assignmentsNone), findsOneWidget);
    expect(find.text(words.historyNone), findsOneWidget);
  });

  testWidgets('an order that does not exist says so without a retry', (
    WidgetTester tester,
  ) async {
    await open(tester);

    GoRouter.of(anywhere(tester))
        .go('/operations/orders/0192f0a0-0000-7000-8000-0000000000ff');
    await tester.pumpAndSettle();

    expect(byKey('failure-message'), findsOneWidget);
    expect(byKey('retry-load'), findsNothing);
  });

  testWidgets(
    'a board that failed to load offers a retry that shows progress',
    (WidgetTester tester) async {
      operations.pageFailure = const NetworkFailure();
      await open(tester);

      expect(byKey('retry-load'), findsOneWidget);
      expect(byKey('board-row-$orderA'), findsNothing);

      operations.pageFailure = null;
      await tapAndSettle(tester, byKey('retry-load'));

      expect(byKey('board-row-$orderA'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh asks again for the page, the summary and the attention list',
    (WidgetTester tester) async {
      await open(tester);
      operations.loads.clear();

      await tapAndSettle(tester, byKey('board-refresh'));

      expect(
        operations.loads,
        containsAll(<String>['orders', 'summary', 'attention']),
      );
    },
  );

  testWidgets(
    'a phone-size window shows cards with the attention list above them',
    (WidgetTester tester) async {
      // Phone-wide, and tall enough that the list builds every row.
      await open(tester, size: const Size(400, 2400));

      expect(find.byType(Table), findsNothing);
      expect(byKey('board-row-$orderA'), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('board-attention')).dy,
        lessThan(tester.getTopLeft(byKey('board-row-$orderA')).dy),
      );
      expect(tester.takeException(), isNull);

      await tapAndSettle(tester, byKey('board-row-$orderA'));
      expect(location(tester), '/operations/orders/$orderA');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a window narrower than the whole table shows cards, not a clipped table',
    (WidgetTester tester) async {
      await open(tester, size: const Size(800, 2400));

      expect(find.byType(Table), findsNothing);
      expect(byKey('board-row-$orderA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a long name wraps in its cell rather than widening the table', (
    WidgetTester tester,
  ) async {
    operations.rows = <BoardRow>[
      for (final BoardRow row in operations.rows)
        BoardRow(
          id: row.id,
          orderNumber: row.orderNumber,
          createdAt: row.createdAt,
          status: row.status,
          paymentMethod: row.paymentMethod,
          customerName: 'Abdurakhmonova Shakhnoza Rustamovna',
          customerPhone: row.customerPhone,
          itemCount: row.itemCount,
          pendingApprovalCount: row.pendingApprovalCount,
          totalUzs: row.totalUzs,
          totalKind: row.totalKind,
          shopper: row.shopper,
          courier: row.courier,
          isSelfOrder: row.isSelfOrder,
        ),
    ];
    await open(tester, size: const Size(1440, 1600));

    final Rect card = ordersCard(tester);
    expect(card.width, greaterThanOrEqualTo(BoardOrders.tableWidth));
    expect(
      tester.getSize(byKey('board-customer-$orderA')).width,
      lessThanOrEqualTo(card.width * 2 / 8.4),
    );
    expect(
      tester.getRect(byKey('board-row-$orderA')).width,
      card.width,
      reason: 'the table keeps the card width',
    );
    expect(
      tester
          .getSize(find.text('Abdurakhmonova Shakhnoza Rustamovna').first)
          .height,
      greaterThan(20),
      reason: 'the name wraps onto a second line',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text makes a table row taller rather than cutting it', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(1440, 1600), textScale: 2);

    expect(
      ordersCard(tester).width,
      greaterThanOrEqualTo(BoardOrders.tableWidth),
    );
    final Finder name = find.descendant(
      of: find.byType(BoardOrders),
      matching: find.text('Aziza Karimova'),
    );
    final Finder phone = find.text(formatPhone('+998901112233'));
    expect(name, findsNWidgets(2));
    expect(phone, findsNWidgets(2));
    for (final Finder finder in <Finder>[name, phone]) {
      for (final Element cell in finder.evaluate()) {
        expect(
          cut(tester, find.byElementPredicate((Element e) => e == cell)),
          isFalse,
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide board lists the orders in a table', (
    WidgetTester tester,
  ) async {
    operations.rows = <BoardRow>[
      OperationsApi.parseRow(
        rowJson(
          status: 'delivery_assigned',
          courier: courierId,
          pendingApprovals: 1,
        ),
      ),
      OperationsApi.parseRow(rowJson(id: orderB, number: 1002, shopper: null)),
    ];
    await open(tester, size: const Size(1440, 900), device: const Locale('ru'));
    final AppLocalizations words = l10n(tester);
    final Rect card = ordersCard(tester);

    expect(card.width, greaterThanOrEqualTo(BoardOrders.tableWidth));
    for (final String header in <String>[
      words.boardColumnOrder,
      words.boardColumnCustomer,
      words.boardColumnStatus,
      words.boardColumnPayment,
      words.boardColumnTotal,
      words.boardColumnPeople,
    ]) {
      expect(find.text(header.toUpperCase()), findsOneWidget, reason: header);
    }

    Finder inRow(Finder matching) =>
        find.descendant(of: byKey('board-row-$orderA'), matching: matching);
    final Finder number = inRow(find.text(words.boardOrderNumber('1001')));
    final Finder time = inRow(
      find.text(TashkentTime.time(DateTime.utc(2026, 9, 27, 7))),
    );
    expect(number, findsOneWidget);
    expect(time, findsOneWidget);
    expect(
      tester.getTopLeft(time).dy,
      greaterThan(tester.getBottomLeft(number).dy - 1),
    );
    final Finder name = find.descendant(
      of: byKey('board-customer-$orderA'),
      matching: find.text('Aziza Karimova'),
    );
    final Finder phone = find.descendant(
      of: byKey('board-customer-$orderA'),
      matching: find.text(formatPhone('+998901112233')),
    );
    expect(
      tester.getTopLeft(phone).dy,
      greaterThan(tester.getBottomLeft(name).dy - 1),
    );
    expect(inRow(find.byType(OrderStatusChip)), findsOneWidget);
    expect(byKey('board-questions-$orderA'), findsOneWidget);
    expect(inRow(find.text(words.paymentCash)), findsOneWidget);
    expect(inRow(find.byIcon(Icons.shopping_basket_outlined)), findsOneWidget);
    expect(
      find.descendant(
        of: byKey('board-courier-$orderA'),
        matching: find.byIcon(Icons.two_wheeler),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopRight(inRow(find.text(words.boardItemCount(3)))).dx,
      tester.getTopRight(inRow(find.textContaining('75'))).dx,
      reason: 'the count sits under the total, both to the right',
    );

    // Nobody yet: one muted line, not two.
    final Finder none = find.descendant(
      of: byKey('board-row-$orderB'),
      matching: find.text(words.boardNoShopper),
    );
    expect(none, findsOneWidget);
    expect(tester.widget<Text>(none).style!.color, KitColors.muted);
    expect(byKey('board-courier-$orderB'), findsNothing);

    await tapAndSettle(tester, byKey('board-row-$orderA'));
    expect(location(tester), '/operations/orders/$orderA');
  });

  testWidgets('a Shopper without a Courier yet says so in muted words', (
    WidgetTester tester,
  ) async {
    await open(tester, size: const Size(1440, 900), device: const Locale('ru'));

    final Finder none = find.descendant(
      of: byKey('board-courier-$orderA'),
      matching: find.text(l10n(tester).boardNoCourier),
    );
    expect(none, findsOneWidget);
    expect(tester.widget<Text>(none).style!.color, KitColors.muted);
    expect(l10n(tester).boardNoCourier, 'Курьер не назначен');
  });

  testWidgets('a self-order carries an amber tag in its people cell', (
    WidgetTester tester,
  ) async {
    operations.rows = <BoardRow>[
      OperationsApi.parseRow(rowJson(selfOrder: true)),
    ];
    await open(tester, size: const Size(1440, 900), device: const Locale('ru'));

    final Finder mark = find.descendant(
      of: byKey('board-row-$orderA'),
      matching: find.byType(SelfOrderMark),
    );
    expect(mark, findsOneWidget);
    expect(tester.getSize(mark).height, 18);
    final Text word = tester.widget<Text>(
      find.descendant(of: mark, matching: find.text('Для себя')),
    );
    expect(word.style!.fontSize, 10);
    expect(word.style!.fontWeight, FontWeight.w700);
    expect(word.style!.color, KitColors.warningDark);
  });

  for (final (double, bool) edge in const <(double, bool)>[
    (847, false),
    (848, true),
  ]) {
    testWidgets('the orders are ${edge.$2 ? 'a table' : 'cards'} at a card of '
        '${edge.$1.toInt() - 48}', (WidgetTester tester) async {
      // Stacked, the orders card is the board's content: window less 48.
      await open(tester, size: Size(edge.$1, 2400));

      expect(ordersCard(tester).width, edge.$1 - 48);
      expect(
        find.text(l10n(tester).boardColumnOrder.toUpperCase()),
        edge.$2 ? findsOneWidget : findsNothing,
      );
      expect(byKey('board-row-$orderA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a narrow board lists the orders as cards', (
    WidgetTester tester,
  ) async {
    operations.rows = <BoardRow>[
      OperationsApi.parseRow(
        rowJson(
          status: 'delivery_assigned',
          courier: courierId,
          pendingApprovals: 2,
          selfOrder: true,
        ),
      ),
    ];
    await open(tester, size: const Size(820, 1180), device: const Locale('ru'));
    final AppLocalizations words = l10n(tester);
    Finder inCard(Finder matching) =>
        find.descendant(of: byKey('board-row-$orderA'), matching: matching);

    expect(find.byType(Table), findsNothing);
    expect(inCard(find.text(words.boardOrderNumber('1001'))), findsOneWidget);
    expect(
      inCard(find.text(TashkentTime.time(DateTime.utc(2026, 9, 27, 7)))),
      findsOneWidget,
    );
    expect(inCard(find.byType(OrderStatusChip)), findsOneWidget);
    expect(inCard(find.text('Aziza Karimova')), findsOneWidget);
    expect(inCard(find.textContaining('75')), findsOneWidget);
    expect(inCard(find.text('Sardor Yusupov')), findsOneWidget);
    expect(inCard(find.text('Kamol Karimov')), findsOneWidget);
    expect(inCard(find.byType(SelfOrderMark)), findsOneWidget);
    expect(inCard(find.text(words.boardPendingQuestions(2))), findsOneWidget);
    expect(
      inCard(find.text('${words.paymentCash} · ${words.boardItemCount(3)}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tapAndSettle(tester, byKey('board-row-$orderA'));
    expect(location(tester), '/operations/orders/$orderA');
  });

  testWidgets('a status chip takes its tone', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              for (final OrderStatus status in OrderStatus.values)
                OrderStatusChip(status, key: ValueKey<String>(status.code)),
            ],
          ),
        ),
      ),
    );
    final AppLocalizations words = AppLocalizations.of(
      tester.element(find.byType(Scaffold)),
    );
    (Color?, Color?) tone(OrderStatus status) {
      final Finder chip = byKey(status.code);
      final BoxDecoration box =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: chip,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final Text text = tester.widget<Text>(
        find.descendant(
          of: chip,
          matching: find.text(OrderLabels.status(words, status)),
        ),
      );
      return (box.color, text.style!.color);
    }

    expect(tone(OrderStatus.newOrder), (KitColors.primary, Colors.white));
    expect(tone(OrderStatus.completed), (KitColors.field, KitColors.ink2));
    expect(tone(OrderStatus.cancelled), (
      KitColors.dangerWash,
      KitColors.dangerDark,
    ));
    expect(tone(OrderStatus.finalPaymentPending), (
      KitColors.warningWash,
      KitColors.warningDark,
    ));
    expect(tone(OrderStatus.shopping), (
      KitColors.primaryWash,
      KitColors.primaryDark,
    ));
    expect(tester.getSize(byKey('new')).height, 24);
  });

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    for (final Size size in const <Size>[Size(1440, 900), Size(820, 1180)]) {
      testWidgets('the orders hold at ${size.width.toInt()} with text x2 '
          '(${language.languageCode})', (WidgetTester tester) async {
        operations.rows = <BoardRow>[
          OperationsApi.parseRow(
            rowJson(
              status: 'delivery_assigned',
              courier: courierId,
              pendingApprovals: 2,
              selfOrder: true,
            ),
          ),
        ];
        await open(tester, size: size, textScale: 2, device: language);

        expect(byKey('board-row-$orderA'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size.width < 1200) {
          await tapAndSettle(tester, byKey('board-filters'));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final Locale language in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the order page fits a phone with large text (${language.languageCode})',
      (WidgetTester tester) async {
        await open(
          tester,
          size: const Size(360, 3200),
          textScale: 2,
          device: language,
        );

        GoRouter.of(anywhere(tester)).go('/operations/orders/$orderA');
        await tester.pumpAndSettle();

        expect(byKey('totals'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'the history marks a self-order and says who a reassignment went from and to',
    (WidgetTester tester) async {
      const String secondAssignment = '0192f0a0-0000-7000-8000-0000000000a2';
      operations.details[orderA] = OperationsApi.parseOrder(
        orderJson(
          assignments: <Object?>[
            assignmentJson(
              endedAt: '2026-09-27T07:10:00Z',
              endedReason: 'reassigned',
            ),
            <String, Object?>{
              ...assignmentJson(
                id: secondAssignment,
                shopper: otherShopperId,
                selfOrder: true,
              ),
              'shopper': <String, Object?>{
                'id': otherShopperId,
                'full_name': 'Dilnoza Karimova',
                'phone': '+998901112233',
              },
            },
          ],
          history: <Object?>[
            historyJson(),
            <String, Object?>{
              ...historyJson(
                event: 'shopper_reassigned',
                details: <String, Object?>{
                  'assignment_id': secondAssignment,
                  'shopper_id': otherShopperId,
                  'is_self_order': true,
                  'previous_assignment_id': assignmentId,
                  'previous_shopper_id': shopperId,
                },
              ),
              'id': '0192f0a0-0000-7000-8000-0000000000b2',
              'from_status': null,
              'to_status': null,
            },
            <String, Object?>{
              ...historyJson(
                event: 'edited',
                details: <String, Object?>{
                  'added': <Object?>[],
                  'removed': <Object?>[],
                  'changed': <Object?>[],
                  'delivery_time_note': <String, Object?>{
                    'before': null,
                    'after': 'Kechqurun',
                  },
                },
              ),
              'id': '0192f0a0-0000-7000-8000-0000000000b3',
              'from_status': null,
              'to_status': null,
            },
          ],
        ),
      );
      await open(tester, size: const Size(1400, 2400));
      final AppLocalizations words = l10n(tester);

      GoRouter.of(anywhere(tester)).go('/operations/orders/$orderA');
      await tester.pumpAndSettle();

      expect(
        find.text(
          words.historyReassignedTo('Sardor Yusupov', 'Dilnoza Karimova'),
        ),
        findsOneWidget,
      );
      expect(
        find.byType(SelfOrderMark),
        findsNWidgets(2),
        reason: 'on the current assignment and on its history entry',
      );
      expect(find.text(words.historyDeliveryWishChanged), findsOneWidget);
      expect(find.textContaining(words.historyEditAdded(0)), findsNothing);
    },
  );

  testWidgets(
    'a Courier filter the options no longer hold still shows one is chosen',
    (WidgetTester tester) async {
      operations.rows = <BoardRow>[
        OperationsApi.parseRow(
          rowJson(status: 'delivery_assigned', courier: courierId),
        ),
      ];
      await open(tester);
      await choose(tester, 'board-courier-filter', 'Kamol Karimov');
      expect(lastQuery().courierId, courierId);

      // The Courier is blocked meanwhile, so the options come back without them.
      operations.courierList = <StaffChoice>[];
      await tapAndSettle(tester, byKey('board-row-$orderA'));
      await tapAndSettle(tester, byKey('order-back'));

      expect(lastQuery().courierId, courierId);
      expect(
        find.descendant(
          of: byKey('board-courier-filter'),
          matching: find.text(l10n(tester).boardFilteredCourier),
        ),
        findsOneWidget,
      );
    },
  );
}

String _courierDelayed(AppLocalizations l10n) => l10n.attentionCourierDelayed;

String _deliveryFailed(AppLocalizations l10n) => l10n.attentionDeliveryFailed;

String _cancellationRequest(AppLocalizations l10n) =>
    l10n.attentionCancellationRequest;

String _staffBlocked(AppLocalizations l10n) => l10n.attentionStaffBlocked;
