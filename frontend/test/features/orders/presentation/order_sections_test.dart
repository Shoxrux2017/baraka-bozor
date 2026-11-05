import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/formatting/phone_format.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/theme/kit_colors.dart';
import 'package:baraka_bozor/features/orders/application/customer_orders_controllers.dart';
import 'package:baraka_bozor/features/orders/presentation/order_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/fake_shopper_orders_repository.dart';
import '../../../support/in_memory_stores.dart';
import '../../../support/nonlinear_text_scaler.dart';
import '../../../support/paragraphs.dart';

const String _phone = '+998901112233';

/// The Customer's order page in the kit look (drawings 29 to 29з) through
/// the real router and screens, with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late FakePhoneCalls phone;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations ru() => lookupAppLocalizations(const Locale('ru'));

  String m(int amount) => MoneyFormat.uzs(amount, AppLanguage.ru);

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(byKey(key)).data!;

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
    phone = FakePhoneCalls();
  });

  /// Opens the order [json] answers, today being 28 September 2026 at 14:00
  /// in Tashkent unless [now] says otherwise.
  Future<void> show(
    WidgetTester tester,
    Map<String, Object?> json, {
    DateTime? now,
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('ru'),
    TextScaler? scaler,
  }) async {
    // A fresh app each time, so a test may show several orders.
    await tester.pumpWidget(const SizedBox());
    orders.rows = <Map<String, Object?>>[json];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      appUnderTest(
        tokens: tokens,
        repository: auth,
        orders: orders,
        cart: FakeCartRepository(),
        phoneCalls: phone,
        device: device,
        textScaler: scaler,
        clock: () => now ?? DateTime.utc(2026, 9, 28, 9),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderOne));
    await tester.pumpAndSettle();
  }

  group('the status card', () {
    final List<(OrderStatus, String, String?, Map<String, Object?>)> cases =
        <(OrderStatus, String, String?, Map<String, Object?>)>[
          (
            OrderStatus.newOrder,
            'Заказ принят',
            'Скоро сборщик начнёт покупать на базаре',
            <String, Object?>{},
          ),
          (
            OrderStatus.shoppingAssigned,
            'Заказ принят',
            'Скоро сборщик начнёт покупать на базаре',
            <String, Object?>{},
          ),
          (
            OrderStatus.shopping,
            'Покупаем на базаре',
            'Сборщик выбирает ваши продукты',
            <String, Object?>{},
          ),
          (
            OrderStatus.readyForDelivery,
            'Заказ собран',
            'Скоро курьер заберёт его',
            <String, Object?>{},
          ),
          (
            OrderStatus.deliveryAssigned,
            'Заказ собран',
            'Скоро курьер заберёт его',
            <String, Object?>{},
          ),
          (
            OrderStatus.finalPaymentPending,
            'Ждёт оплаты',
            null,
            <String, Object?>{},
          ),
          (
            OrderStatus.onTheWay,
            'Курьер везёт заказ',
            'Выехал в 12:52',
            <String, Object?>{'on_the_way_at': '2026-09-28T07:52:00Z'},
          ),
          (
            OrderStatus.completed,
            'Доставлен',
            'Сегодня в 13:30',
            <String, Object?>{'completed_at': '2026-09-28T08:30:00Z'},
          ),
        ];
    for (final (
          OrderStatus status,
          String title,
          String? hint,
          Map<String, Object?> stamps,
        )
        in cases) {
      testWidgets('reads ${status.code} as "$title"', (
        WidgetTester tester,
      ) async {
        await show(
          tester,
          customerOrderJson(
            status: status.code,
            changeable: false,
            timestamps: stamps,
          ),
        );

        expect(textOf(tester, 'order-status-title'), title);
        if (hint == null) {
          expect(byKey('order-status-hint'), findsNothing);
        } else {
          expect(textOf(tester, 'order-status-hint'), hint);
        }
      });
    }

    testWidgets('says who cancelled, and when, not the words typed', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(status: 'cancelled', changeable: false),
      );

      expect(textOf(tester, 'order-status-title'), 'Заказ отменён');
      expect(
        textOf(tester, 'order-status-hint'),
        'Вы отменили сегодня в 13:00',
      );
      expect(byKey('order-status-reason'), findsNothing);
      expect(byKey('order-stage-0'), findsNothing, reason: 'no bar');
    });

    testWidgets(
      'a cancelled order shows the reason the Customer gave (DL-133)',
      (WidgetTester tester) async {
        await show(
          tester,
          customerOrderJson(
            status: 'cancelled',
            changeable: false,
            cancellationNote: 'Передумал',
          ),
        );
        expect(
          textOf(tester, 'order-status-reason'),
          ru().orderCancelReasonQuoted('Передумал'),
        );

        await show(
          tester,
          customerOrderJson(status: 'cancelled', changeable: false),
        );
        expect(byKey('order-status-reason'), findsNothing);

        await show(
          tester,
          customerOrderJson(
            status: 'cancelled',
            changeable: false,
            cancellationReason: 'cancellation_request_approved',
            cancellationRequest: 'approved',
            requestReason: 'Срочно уезжаю',
          ),
        );
        expect(
          textOf(tester, 'order-status-reason'),
          'Причина: «Срочно уезжаю»',
        );
      },
    );

    testWidgets('quotes the reason of an approved request', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'cancelled',
          changeable: false,
          cancellationReason: 'cancellation_request_approved',
          cancellationRequest: 'approved',
          requestReason: 'Срочно уезжаю',
        ),
      );

      expect(textOf(tester, 'order-status-hint'), 'Отменён сегодня в 13:00');
      expect(textOf(tester, 'order-status-reason'), 'Причина: «Срочно уезжаю»');
    });

    testWidgets('names a cancellation by the business', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'cancelled',
          changeable: false,
          cancellationReason: 'delivery_failed',
        ),
      );

      expect(
        textOf(tester, 'order-status-reason'),
        ru().requestReason(ru().cancelDeliveryFailed),
      );
    });

    testWidgets('the bar shows the times reached', (WidgetTester tester) async {
      await show(
        tester,
        customerOrderJson(
          status: 'on_the_way',
          changeable: false,
          timestamps: <String, Object?>{
            'created_at': '2026-09-28T07:10:00Z',
            'shopping_started_at': '2026-09-28T07:25:00Z',
            'on_the_way_at': '2026-09-28T07:52:00Z',
          },
        ),
      );

      expect(textOf(tester, 'order-stage-time-0'), '12:10');
      expect(textOf(tester, 'order-stage-time-1'), '12:25');
      expect(textOf(tester, 'order-stage-time-2'), '12:52');
      expect(byKey('order-stage-time-3'), findsNothing);
      for (final String label in <String>[
        'Принят',
        'Покупаем',
        'Везём',
        'Доставлен',
      ]) {
        expect(
          find.descendant(
            of: byKey('order-status'),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'past stages carry a check, the current is bold, the track shows what is ahead',
      (WidgetTester tester) async {
        await show(
          tester,
          customerOrderJson(status: 'shopping', changeable: false),
        );

        final Finder checks = find.descendant(
          of: byKey('order-status'),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Icon && w.icon == Icons.check && w.size == 13,
          ),
        );
        expect(checks, findsOneWidget);
        expect(tester.widget<Icon>(checks).color, KitColors.primary);
        // The check leads the first stage, 2 px before its word.
        expect(
          tester.getTopLeft(byKey('order-stage-label-0')).dx -
              tester.getTopRight(checks).dx,
          2,
        );

        TextStyle label(int i) =>
            tester.widget<Text>(byKey('order-stage-label-$i')).style!;
        expect(textOf(tester, 'order-stage-label-1'), 'Покупаем');
        expect(label(1).fontWeight, FontWeight.w700);
        expect(label(0).fontWeight, FontWeight.w500);
        for (int i = 0; i < 4; i++) {
          expect(label(i).fontSize, 12);
          expect(label(i).height, 1.3);
        }
        expect(label(0).color, KitColors.ink);
        expect(label(2).color, KitColors.muted);

        Color? segment(int i) =>
            ((tester.widget<DecoratedBox>(byKey('order-stage-$i'))).decoration
                    as BoxDecoration)
                .color;
        expect(segment(0), KitColors.primary);
        expect(segment(1), KitColors.primary);
        expect(segment(2), KitColors.primary.withValues(alpha: 0.22));
        expect(
          find.descendant(
            of: byKey('order-status'),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('a delivered order checks every stage', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'completed',
          changeable: false,
          timestamps: <String, Object?>{'completed_at': '2026-09-28T08:30:00Z'},
        ),
      );

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Icon && w.icon == Icons.check && w.size == 13,
        ),
        findsNWidgets(4),
      );
    });

    testWidgets('the stages say «Этап 2 из 4» and the heading', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await show(
        tester,
        customerOrderJson(status: 'shopping', changeable: false),
      );

      expect(
        find.bySemanticsLabel(ru().orderStageOf(2, 'Покупаем на базаре')),
        findsOneWidget,
      );
      expect(
        ru().orderStageOf(2, 'Покупаем на базаре'),
        'Этап 2 из 4: Покупаем на базаре',
      );
      handle.dispose();
    });

    testWidgets('at large text the stages stand as a list', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          timestamps: <String, Object?>{
            'created_at': '2026-09-28T07:10:00Z',
            'shopping_started_at': '2026-09-28T07:25:00Z',
          },
        ),
        size: const Size(360, 2400),
        scaler: const NonlinearTextScaler(2),
      );

      expect(byKey('order-stages-list'), findsOneWidget);
      expect(byKey('order-stage-0'), findsNothing, reason: 'no segments');
      IconData icon(int i) =>
          tester.widget<Icon>(byKey('order-stage-icon-$i')).icon!;
      expect(icon(0), Icons.check_circle);
      expect(icon(1), Icons.radio_button_checked);
      expect(icon(2), Icons.radio_button_unchecked);
      expect(icon(3), Icons.radio_button_unchecked);
      expect(textOf(tester, 'order-stage-label-1'), 'Покупаем на базаре');
      expect(
        tester.widget<Text>(byKey('order-stage-label-1')).style!.fontWeight,
        FontWeight.w700,
      );
      expect(textOf(tester, 'order-stage-time-1'), '12:25');
      expect(
        tester.getTopRight(byKey('order-stage-time-1')).dx,
        greaterThan(tester.getTopRight(byKey('order-stage-label-1')).dx),
      );
      expect(
        find.bySemanticsLabel(ru().orderStageOf(2, 'Покупаем на базаре')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('an order that may still change says so', (
      WidgetTester tester,
    ) async {
      await show(tester, customerOrderJson());
      expect(find.text(ru().orderCanStillChange), findsOneWidget);

      await show(
        tester,
        customerOrderJson(status: 'shopping', changeable: false),
      );
      expect(find.text(ru().orderCanStillChange), findsNothing);
    });
  });

  group('lines', () {
    testWidgets('read as they stand', (WidgetTester tester) async {
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          lines: <Object?>[
            orderLineJson(
              quantity: '2.000',
              patch: <String, Object?>{
                'customer_unit_price_uzs': 14000,
                'line_total_uzs': 28000,
              },
            ),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '3',
              status: 'purchased',
              patch: <String, Object?>{
                'billable_unit_price_uzs': 3000,
                'line_total_uzs': 9000,
              },
            ),
            orderLineJson(
              id: lineMilk,
              productId: productMilk,
              unit: 'piece',
              quantity: '1',
              status: 'removed',
              removedReason: 'unavailable',
            ),
            orderLineJson(
              id: '0192f0a0-0000-7000-8000-00000000c014',
              unit: 'piece',
              status: 'removed',
              removedReason: 'customer_removed',
            ),
          ],
        ),
      );

      expect(find.text('Товары · 2'), findsOneWidget);
      expect(
        find.text('2 кг · ${ru().cartLineEstimate('${m(14000)} / кг')}'),
        findsOneWidget,
      );
      expect(find.text(ru().cartLineEstimate(m(28000))), findsOneWidget);
      expect(find.text('3 шт. × ${m(3000)}'), findsOneWidget);
      expect(find.text('Куплено'), findsOneWidget);
      expect(find.text(m(9000)), findsOneWidget);
      expect(find.text('Не было на базаре — убрали'), findsOneWidget);
      expect(find.text(m(0)), findsNothing);
      expect(
        byKey('order-line-0192f0a0-0000-7000-8000-00000000c014'),
        findsNothing,
      );
    });

    testWidgets(
      'removed lines stand under «Убрали из заказа · 2» without a sum',
      (WidgetTester tester) async {
        await show(
          tester,
          customerOrderJson(
            status: 'shopping',
            changeable: false,
            lines: <Object?>[
              orderLineJson(),
              orderLineJson(
                id: lineBread,
                productId: productBread,
                status: 'removed',
                removedReason: 'unavailable',
              ),
              orderLineJson(
                id: lineMilk,
                productId: productMilk,
                status: 'removed',
                removedReason: 'customer_rejected',
              ),
            ],
          ),
        );

        final Finder header = find.text('Убрали из заказа · 2');
        expect(header, findsOneWidget);
        final TextStyle style = tester.widget<Text>(header).style!;
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, KitColors.ink2);
        final Finder group = byKey('order-removed-group');
        for (final String id in <String>[lineBread, lineMilk]) {
          final Finder row = find.descendant(
            of: group,
            matching: byKey('order-line-$id'),
          );
          expect(row, findsOneWidget, reason: id);
          expect(
            find.descendant(of: row, matching: find.textContaining('сум')),
            findsNothing,
            reason: id,
          );
        }
        expect(
          find.descendant(of: group, matching: byKey('order-line-$lineTomato')),
          findsNothing,
        );
        expect(find.text('Товары · 1'), findsOneWidget);
      },
    );

    testWidgets('no removed lines, no group', (WidgetTester tester) async {
      await show(tester, customerOrderJson());

      expect(byKey('order-removed-group'), findsNothing);
      expect(find.textContaining('Убрали из заказа'), findsNothing);
    });

    testWidgets('the header and the amounts count the same lines', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
            ),
            orderLineJson(
              id: lineMilk,
              productId: productMilk,
              unit: 'piece',
              status: 'removed',
              removedReason: 'unavailable',
            ),
            orderLineJson(id: '0192f0a0-0000-7000-8000-00000000c015'),
          ],
        ),
      );

      expect(find.text('Товары · 3'), findsOneWidget);
      expect(find.text('Товары (3)'), findsOneWidget);
    });

    testWidgets('a cancelled order keeps its lines in the list', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'cancelled',
          changeable: false,
          lines: <Object?>[
            orderLineJson(status: 'removed', removedReason: 'order_cancelled'),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              status: 'removed',
              removedReason: 'order_cancelled',
            ),
          ],
        ),
      );

      expect(byKey('order-removed-group'), findsNothing);
      expect(find.text('Товары · 2'), findsOneWidget);
      expect(byKey('order-line-$lineTomato'), findsOneWidget);
      expect(byKey('order-line-$lineBread'), findsOneWidget);
    });

    testWidgets(
      'a line removed meanwhile folds out of the lines and into the group',
      (WidgetTester tester) async {
        Map<String, Object?> json({required bool removed}) => customerOrderJson(
          status: 'shopping',
          changeable: false,
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              status: removed ? 'removed' : 'pending',
              removedReason: removed ? 'unavailable' : null,
            ),
          ],
        );
        await show(tester, json(removed: false));
        expect(byKey('order-removed-group'), findsNothing);
        expect(find.text('Товары · 2'), findsOneWidget);

        orders.rows = <Map<String, Object?>>[json(removed: true)];
        ProviderScope.containerOf(anywhere(tester))
            .invalidate(customerOrderProvider(orderOne));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        // Mid-way the line still folds in the lines and already stands in the
        // group.
        expect(byKey('order-line-$lineBread'), findsNWidgets(2));
        await tester.pumpAndSettle();

        expect(byKey('order-line-$lineBread'), findsOneWidget);
        expect(
          find.descendant(
            of: byKey('order-removed-group'),
            matching: byKey('order-line-$lineBread'),
          ),
          findsOneWidget,
        );
        expect(find.text('Убрали из заказа · 1'), findsOneWidget);
        expect(find.text('Товары · 1'), findsOneWidget);
      },
    );

    testWidgets('at 100 % the sum stands beside the name', (
      WidgetTester tester,
    ) async {
      await show(tester, customerOrderJson());

      final Finder row = byKey('order-line-$lineTomato');
      final Rect name = tester.getRect(
        find.descendant(of: row, matching: find.textContaining('Помидоры')),
      );
      final Rect amount = tester.getRect(
        find.descendant(
          of: row,
          matching: find.text(ru().cartLineEstimate(m(27600))),
        ),
      );
      expect(amount.left, greaterThan(name.right));
      expect(amount.top, lessThan(name.bottom));
    });

    testWidgets('at large text the sum stands under the name', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(),
        size: const Size(360, 3000),
        scaler: const NonlinearTextScaler(2),
      );

      final Finder row = byKey('order-line-$lineTomato');
      final Finder sum = find.descendant(
        of: row,
        matching: find.text(ru().cartLineEstimate(m(27600))),
      );
      final Rect name = tester.getRect(
        find.descendant(of: row, matching: find.textContaining('Помидоры')),
      );
      final Rect amount = tester.getRect(sum);
      expect(amount.top, greaterThanOrEqualTo(name.bottom));
      expect(amount.left, tester.getRect(row).left + 60);
      final TextStyle style = tester.widget<Text>(sum).style!;
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w700);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a six-digit sum on a 320 dp phone stands whole', (
      WidgetTester tester,
    ) async {
      await loadMontserrat();
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          lines: <Object?>[
            orderLineJson(
              id: lineBread,
              productId: productBread,
              quantity: '1.500',
              status: 'purchased',
              patch: <String, Object?>{
                'billable_unit_price_uzs': 188975,
                'line_total_uzs': 283463,
              },
            ),
          ],
        ),
        size: const Size(320, 3000),
      );

      final Finder row = byKey('order-line-$lineBread');
      final Finder sum = find.descendant(
        of: row,
        matching: find.text(m(283463)),
      );
      expect(sum, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byType(FittedBox)),
        findsNothing,
      );
      expect(cutParagraphs(tester, sum), isEmpty);
      expect(linesOf(paragraphsIn(tester, sum).single), 1);
      expect(
        tester.getRect(sum).right,
        lessThanOrEqualTo(tester.getRect(row).right),
      );
      expect(tester.takeException(), isNull);
    });

    for (final (String, TextScaler) scale in const <(String, TextScaler)>[
      ('100 %', TextScaler.noScaling),
      ('200 %', NonlinearTextScaler(2)),
    ]) {
      testWidgets(
        'the lines and the removed group meet the guideline at ${scale.$1}',
        (WidgetTester tester) async {
          await show(
            tester,
            customerOrderJson(
              status: 'shopping',
              changeable: false,
              lines: <Object?>[
                orderLineJson(),
                orderLineJson(
                  id: lineBread,
                  productId: productBread,
                  status: 'removed',
                  removedReason: 'unavailable',
                ),
              ],
            ),
            size: const Size(360, 800),
            scaler: scale.$2,
          );

          expect(byKey('order-removed-group'), findsOneWidget);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        },
      );
    }

    testWidgets('only an estimate price carries "≈"', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              unit: 'piece',
              quantity: '2',
            ),
          ],
        ),
      );

      expect(find.text(ru().cartLineEstimate(m(27600))), findsOneWidget);
      expect(find.text(m(8000)), findsOneWidget);
      expect(
        find.text('2 шт. · ${m(4000)} / шт.'),
        findsOneWidget,
        reason: 'a fixed price per unit has no "≈"',
      );
    });

    testWidgets('a bought line reads on once shopping is over', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'ready_for_delivery',
          changeable: false,
          lines: <Object?>[
            orderLineJson(
              unit: 'piece',
              quantity: '3',
              status: 'purchased',
              patch: <String, Object?>{
                'billable_unit_price_uzs': 3000,
                'line_total_uzs': 9000,
              },
            ),
          ],
        ),
      );

      expect(find.text('Куплено 3 шт. × ${m(3000)}'), findsOneWidget);
      expect(find.text('Куплено'), findsNothing);
    });

    testWidgets('a line with a question says it waits', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          lines: <Object?>[questionLineJson('price_over_tolerance')],
        ),
        // Before the question's 13:00, or the phone's clock calls it over.
        now: DateTime.utc(2026, 9, 28, 7, 30),
      );

      expect(find.text('Ждёт вашего ответа'), findsOneWidget);
      expect(byKey('question-$approvalOne'), findsOneWidget);
    });

    testWidgets('the tags of a removed line follow the reason', (
      WidgetTester tester,
    ) async {
      final Map<String, String?> tags = <String, String?>{
        'unavailable': 'Не было на базаре — убрали',
        'customer_rejected': 'Вы отказались — убрали',
        'approval_expired': 'Не ответили вовремя — убрали',
        'operator_removed': 'Убрал оператор',
        'order_cancelled': null,
      };
      for (final MapEntry<String, String?> entry in tags.entries) {
        await show(
          tester,
          customerOrderJson(
            status: 'shopping',
            changeable: false,
            lines: <Object?>[
              orderLineJson(
                status: 'removed',
                removedReason: entry.key,
                patch: <String, Object?>{
                  'substitution_policy': 'contact_before_substitution',
                },
              ),
            ],
          ),
        );
        for (final String? other in tags.values) {
          if (other != null) {
            expect(
              find.text(other),
              other == entry.value ? findsOneWidget : findsNothing,
              reason: entry.key,
            );
          }
        }
      }
    });
  });

  group('amounts', () {
    testWidgets('an estimate reads with its note', (WidgetTester tester) async {
      await show(tester, customerOrderJson());

      expect(find.text('Товары (2)'), findsOneWidget);
      expect(find.text(ru().cartLineEstimate(m(35600))), findsOneWidget);
      expect(find.text(m(15000)), findsOneWidget);
      expect(find.text(ru().cartLineEstimate(m(55600))), findsOneWidget);
      expect(find.text(ru().cartEstimateNote), findsOneWidget);
    });

    testWidgets('a final total has no "≈"', (WidgetTester tester) async {
      await show(
        tester,
        customerOrderJson(
          status: 'ready_for_delivery',
          changeable: false,
          totals: <String, Object?>{
            'merchandise_subtotal_uzs': 28463,
            'service_fee_uzs': 5000,
            'delivery_fee_uzs': 15000,
            'total_uzs': 48463,
            'total_kind': 'final',
          },
        ),
      );

      expect(find.text(m(48463)), findsOneWidget);
      expect(find.text(ru().cartEstimateNote), findsNothing);
    });

    testWidgets('nothing due reads "К оплате нет"', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(status: 'cancelled', changeable: false),
      );

      expect(find.text('К оплате'), findsOneWidget);
      expect(find.text('нет'), findsOneWidget);
      expect(find.text(ru().cartEstimateNote), findsNothing);
    });
  });

  group('information', () {
    testWidgets('the payment reads as it stands', (WidgetTester tester) async {
      await show(tester, customerOrderJson());
      expect(
        find.descendant(
          of: byKey('order-payment'),
          matching: find.text(ru().paymentCashTitle),
        ),
        findsOneWidget,
      );
      expect(find.text(ru().paymentCashHint), findsOneWidget);

      await show(
        tester,
        customerOrderJson(
          status: 'on_the_way',
          changeable: false,
          totals: <String, Object?>{
            'merchandise_subtotal_uzs': 28463,
            'service_fee_uzs': 5000,
            'delivery_fee_uzs': 15000,
            'total_uzs': 48463,
            'total_kind': 'final',
          },
        ),
      );
      expect(find.text('К оплате ${m(48463)}'), findsOneWidget);
      expect(find.text('Наличными курьеру при получении'), findsOneWidget);

      await show(
        tester,
        customerOrderJson(
          status: 'completed',
          changeable: false,
          payment: <String, Object?>{
            'method': 'cash',
            'status': 'paid',
            'amount_uzs': 48463,
            'paid_at': '2026-09-28T08:30:00Z',
          },
        ),
      );
      expect(find.text('Оплачено наличными'), findsOneWidget);
      expect(find.text('${m(48463)}, сегодня в 13:30'), findsOneWidget);

      await show(
        tester,
        customerOrderJson(
          status: 'completed',
          changeable: false,
          payment: <String, Object?>{
            'method': 'online',
            'status': 'paid',
            'amount_uzs': 48463,
            'paid_at': '2026-09-28T08:30:00Z',
          },
        ),
      );
      expect(find.text(ru().orderPaidOnline), findsOneWidget);
      expect(find.text(ru().orderPaidCash), findsNothing);
      expect(
        lookupAppLocalizations(const Locale('uz')).orderPaidOnline,
        isNot(lookupAppLocalizations(const Locale('uz')).orderPaidCash),
      );

      await show(
        tester,
        customerOrderJson(status: 'cancelled', changeable: false),
      );
      expect(byKey('order-payment'), findsNothing);
      expect(find.text(ru().paymentCashTitle), findsNothing);
      expect(find.text(ru().paymentCashHint), findsNothing);
      expect(find.text(ru().orderNothingDue), findsOneWidget);
    });

    testWidgets('the address, its landmark and the wish', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          note: 'Вечером',
          address: <String, Object?>{'landmark': 'Возле аптеки'},
        ),
      );

      expect(find.text('Адрес доставки'), findsOneWidget);
      expect(find.text('Amir Temur, 12, кв. 34'), findsOneWidget);
      expect(find.text('Возле аптеки'), findsOneWidget);
      expect(find.text('Вечером'), findsOneWidget);

      await show(tester, customerOrderJson(note: null));
      expect(find.text(ru().checkoutWishLabel), findsNothing);
    });

    testWidgets(
      'support shows on a current order with a phone, never on a finished one',
      (WidgetTester tester) async {
        await show(tester, customerOrderJson(supportPhone: _phone));
        expect(byKey('order-support'), findsOneWidget);
        await tester.tap(byKey('order-call-support'));
        await tester.pumpAndSettle();
        expect(phone.calls, <String>[_phone]);

        await show(tester, customerOrderJson());
        expect(byKey('order-support'), findsNothing, reason: 'no phone');

        for (final String ended in <String>['completed', 'cancelled']) {
          await show(
            tester,
            customerOrderJson(
              status: ended,
              changeable: false,
              supportPhone: _phone,
            ),
          );
          expect(byKey('order-support'), findsNothing, reason: ended);
        }
      },
    );
  });

  group('the Courier', () {
    Map<String, Object?> onTheWay(Map<String, Object?> courier) =>
        customerOrderJson(
          status: 'on_the_way',
          changeable: false,
          courier: courier,
        );

    testWidgets('the courier card calls the courier', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        onTheWay(<String, Object?>{'first_name': 'Rustam', 'phone': _phone}),
      );

      expect(find.text('Rustam'), findsOneWidget);
      expect(find.text('Ваш курьер'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      await tester.tap(byKey('order-call-courier'));
      await tester.pumpAndSettle();
      expect(phone.calls, <String>[_phone]);
    });

    testWidgets('a courier without a name is shown by phone', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        onTheWay(<String, Object?>{'first_name': null, 'phone': _phone}),
      );

      expect(
        find.descendant(
          of: byKey('order-courier'),
          matching: find.text(formatPhone(_phone)),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('a failed dial shows the number', (WidgetTester tester) async {
      phone.opens = false;
      await show(
        tester,
        onTheWay(<String, Object?>{'first_name': 'Rustam', 'phone': _phone}),
      );

      await tester.tap(byKey('order-call-courier'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('+998 90 111 22 33'), findsOneWidget);
    });

    testWidgets('no courier card without a courier', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(status: 'on_the_way', changeable: false),
      );
      expect(byKey('order-courier'), findsNothing);
    });

    testWidgets('on the way, payment and address come before the lines', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(status: 'on_the_way', changeable: false),
      );
      expect(
        tester.getTopLeft(byKey('order-payment')).dy,
        lessThan(tester.getTopLeft(byKey('order-line-$lineTomato')).dy),
      );

      await show(tester, customerOrderJson());
      expect(
        tester.getTopLeft(byKey('order-payment')).dy,
        greaterThan(tester.getTopLeft(byKey('order-line-$lineTomato')).dy),
      );
    });
  });

  group('the footer', () {
    testWidgets('a finished order offers "Повторить заказ"', (
      WidgetTester tester,
    ) async {
      for (final String ended in <String>['completed', 'cancelled']) {
        await show(tester, customerOrderJson(status: ended, changeable: false));
        expect(byKey('order-repeat'), findsOneWidget, reason: ended);
        expect(find.text('Повторить заказ'), findsOneWidget, reason: ended);
        expect(byKey('order-edit'), findsNothing);
        expect(byKey('order-cancel'), findsNothing);
      }
    });

    testWidgets('a current order offers to cancel and to edit side by side', (
      WidgetTester tester,
    ) async {
      await show(tester, customerOrderJson());

      expect(find.text('Отменить'), findsOneWidget);
      expect(find.text('Изменить'), findsOneWidget);
      expect(
        tester.getTopLeft(byKey('order-cancel')).dy,
        tester.getTopLeft(byKey('order-edit')).dy,
      );
    });

    testWidgets('a shopping order offers to ask for the cancellation', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          canRequestCancellation: true,
        ),
      );

      expect(byKey('order-request-cancel'), findsOneWidget);
      expect(find.text('Попросить отменить'), findsOneWidget);
      expect(byKey('order-edit'), findsNothing);
    });

    testWidgets('a pending request shows its reason and no button', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          cancellationRequest: 'pending',
          requestReason: 'Kech qoldi',
        ),
      );

      expect(byKey('order-cancellation-request'), findsOneWidget);
      expect(find.text('Вы попросили отменить'), findsOneWidget);
      expect(find.text('«Kech qoldi»'), findsOneWidget);
      expect(find.text('Ждёт решения'), findsOneWidget);
      expect(find.text(ru().requestPendingHint), findsOneWidget);
      expect(find.byType(OrderFooter), findsNothing);
    });
  });

  group('the cancel sheet', () {
    testWidgets('names the order and opens a field for the reason', (
      WidgetTester tester,
    ) async {
      await show(tester, customerOrderJson());
      await tester.tap(byKey('order-cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Отменить заказ № 1001?'), findsOneWidget);
      await tester.tap(byKey('cancel-more'));
      await tester.pumpAndSettle();
      expect(find.text(ru().cancelFieldOwn), findsOneWidget);
      await tester.enterText(byKey('cancel-reason'), '  не то  ');
      await tester.pump();
      expect(find.text('  не то  '), findsOneWidget);
    });

    testWidgets('the close button keeps the order', (
      WidgetTester tester,
    ) async {
      await show(tester, customerOrderJson());
      await tester.tap(byKey('order-cancel'));
      await tester.pumpAndSettle();

      await tester.tap(byKey('cancel-sheet-close'));
      await tester.pumpAndSettle();

      expect(byKey('cancel-reason'), findsNothing);
      expect(orders.cancels, isEmpty);
    });

    testWidgets('a request asks in its own words', (WidgetTester tester) async {
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          canRequestCancellation: true,
        ),
      );
      await tester.tap(byKey('order-request-cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Попросить отменить заказ № 1001?'), findsOneWidget);
      expect(find.text(ru().requestSheetHint), findsOneWidget);
      await tester.tap(byKey('cancel-chip-changedMind'));
      await tester.pumpAndSettle();
      expect(find.text(ru().cancelSheetSendRequest), findsOneWidget);
      expect(find.text('Оставить заказ'), findsOneWidget);
    });
  });

  testWidgets('only an open line shows its substitution rule and note', (
    WidgetTester tester,
  ) async {
    const Map<String, Object?> rule = <String, Object?>{
      'substitution_policy': 'contact_before_substitution',
    };
    await show(
      tester,
      customerOrderJson(
        status: 'shopping',
        changeable: false,
        lines: <Object?>[
          orderLineJson(note: 'Спелые', patch: rule),
          orderLineJson(
            id: lineBread,
            productId: productBread,
            status: 'purchased',
            note: 'Свежий',
            patch: rule,
          ),
          orderLineJson(
            id: lineMilk,
            productId: productMilk,
            status: 'removed',
            removedReason: 'approval_expired',
            note: 'Тёплое',
            patch: rule,
          ),
        ],
      ),
    );
    Finder inLine(String id, String text) =>
        find.descendant(of: byKey('order-line-$id'), matching: find.text(text));
    final String ask = OrderLabels.substitution(
      ru(),
      SubstitutionPolicy.contactBefore,
    );

    expect(inLine(lineTomato, ask), findsOneWidget);
    expect(inLine(lineTomato, '«Спелые»'), findsOneWidget);
    for (final (String id, String note) in <(String, String)>[
      (lineBread, '«Свежий»'),
      (lineMilk, '«Тёплое»'),
    ]) {
      expect(inLine(id, ask), findsNothing, reason: id);
      expect(inLine(id, note), findsNothing, reason: id);
    }
  });

  for (final (Size size, double scale) in <(Size, double)>[
    (const Size(320, 640), 2),
    (const Size(360, 800), 1.3),
  ]) {
    testWidgets('a line amount stays one whole line at $size x$scale', (
      WidgetTester tester,
    ) async {
      await loadMontserrat();
      await show(
        tester,
        customerOrderJson(
          status: 'shopping',
          changeable: false,
          lines: <Object?>[
            orderLineJson(),
            orderLineJson(
              id: lineBread,
              productId: productBread,
              quantity: '1.500',
              status: 'purchased',
              patch: <String, Object?>{
                'billable_unit_price_uzs': 18975,
                'line_total_uzs': 28463,
              },
            ),
          ],
        ),
        size: Size(size.width, 3000),
        textScale: scale,
      );

      for (final (String id, String text) in <(String, String)>[
        (lineTomato, ru().cartLineEstimate(m(27600))),
        (lineBread, m(28463)),
      ]) {
        final Finder row = byKey('order-line-$id');
        final Finder amount = find.descendant(
          of: row,
          matching: find.text(text),
        );
        expect(amount, findsOneWidget, reason: text);
        expect(cutParagraphs(tester, amount), isEmpty);
        expect(linesOf(paragraphsIn(tester, amount).single), 1, reason: text);
        final Rect inside = tester.getRect(row);
        final Rect rect = tester.getRect(amount);
        expect(rect.left, greaterThanOrEqualTo(inside.left), reason: text);
        expect(rect.right, lessThanOrEqualTo(inside.right), reason: text);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'the order page holds at the extremes (${device.languageCode})',
      (WidgetTester tester) async {
        String id(int n) =>
            '0192f0a0-0000-7000-8000-0000000002${n.toString().padLeft(2, '0')}';
        final List<Object?> lines = <Object?>[
          for (int i = 0; i < 12; i++)
            i < 3
                ? orderLineJson(
                    id: id(i),
                    status: 'awaiting_customer',
                    patch: <String, Object?>{
                      'pending_approval': <String, Object?>{
                        'id': id(50 + i),
                        'type': 'price_over_tolerance',
                        'proposed_customer_unit_price_uzs': 21850,
                        'proposed_quantity': null,
                        'replacement': null,
                        'request_note': 'Qizili qolmadi',
                        'expires_at': '2026-09-28T09:30:00Z',
                        'estimate_if_approved_uzs': 99999999,
                        'change_if_approved_uzs': 99999999,
                        'change_if_rejected_uzs': -99999999,
                      },
                      'customer_note': 'n' * 160,
                      'line_total_uzs': 99999999,
                    },
                  )
                : orderLineJson(
                    id: id(i),
                    unit: i.isEven ? 'kg' : 'piece',
                    status: i == 5 ? 'removed' : 'purchased',
                    removedReason: i == 5 ? 'approval_expired' : null,
                    patch: <String, Object?>{
                      if (i != 5)
                        'replacement': <String, Object?>{
                          'name_uz': 'Olcha pomidor ' * 4,
                          'name_ru': 'Помидоры черри ' * 4,
                        },
                      'substitution_policy': 'contact_before_substitution',
                    },
                  ),
        ];
        await show(
          tester,
          customerOrderJson(
            status: 'on_the_way',
            changeable: false,
            canRequestCancellation: true,
            lines: lines,
            note: 'w' * 160,
            supportPhone: _phone,
            courier: <String, Object?>{
              'first_name': 'Abdurahmonjon',
              'phone': _phone,
            },
            address: <String, Object?>{
              'street': 'S' * 60,
              'landmark': 'L' * 60,
            },
            totals: <String, Object?>{
              'merchandise_subtotal_uzs': 99999999,
              'service_fee_uzs': 99999999,
              'delivery_fee_uzs': 99999999,
              'total_uzs': 99999999,
              'total_kind': 'estimate',
            },
            timestamps: <String, Object?>{
              'shopping_started_at': '2026-09-28T07:25:00Z',
              'on_the_way_at': '2026-09-28T07:52:00Z',
            },
          ),
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );

        expect(tester.takeException(), isNull);
        for (int i = 0; i < 14; i++) {
          await tester.drag(byKey('order'), const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'after scroll $i');
        }
      },
    );

    testWidgets(
      'the footer and the cancel sheet hold at the extremes (${device.languageCode})',
      (WidgetTester tester) async {
        await show(
          tester,
          customerOrderJson(),
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(byKey('order-cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(byKey('cancel-more'));
        await tester.tap(byKey('cancel-more'));
        await tester.pumpAndSettle();
        await tester.enterText(byKey('cancel-reason'), 'x' * 301);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(byKey('cancel-keep'));
        await tester.tap(byKey('cancel-keep'));
        await tester.pumpAndSettle();

        await show(
          tester,
          customerOrderJson(
            status: 'shopping',
            changeable: false,
            canRequestCancellation: true,
          ),
          size: const Size(320, 640),
          textScale: 2,
          device: device,
        );
        await tester.tap(byKey('order-request-cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(byKey('cancel-chip-changedMind'));
        await tester.tap(byKey('cancel-chip-changedMind'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(byKey('cancel-confirm'));
        await tester.tap(byKey('cancel-confirm'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
