import 'dart:async';

import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/formatting/money_format.dart';
import 'package:baraka_bozor/core/formatting/tashkent_time.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/catalog_labels.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/localization/order_labels.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/core/orders/quantity_rules.dart';
import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/features/orders/domain/customer_orders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_cart_repository.dart';
import '../../../support/fake_customer_orders_repository.dart';
import '../../../support/in_memory_stores.dart';

const String lineApple = '0192f0a0-0000-7000-8000-00000000c014';
const String orderTwo = '0192f0a0-0000-7000-8000-00000000c002';
const String approvalTwo = '0192f0a0-0000-7000-8000-00000000c032';

/// [line] with its question renamed [id], as a question asked later.
Map<String, Object?> askedAgain(Map<String, Object?> line, String id) =>
    <String, Object?>{
      ...line,
      'pending_approval': <String, Object?>{
        ...line['pending_approval']! as Map<String, Object?>,
        'id': id,
      },
    };

/// The tomato line with the cherry replacement authorized.
Map<String, Object?> replaced(Map<String, Object?> line) => <String, Object?>{
  ...line,
  'replacement': const <String, Object?>{
    'name_uz': 'Olcha pomidor',
    'name_ru': 'Помидоры черри',
  },
};

/// The tomato line's question of [type], the price one about the
/// replacement the Customer authorized when [aboutReplacement].
Map<String, Object?> asked(String type, {bool aboutReplacement = false}) {
  final Map<String, Object?> line = questionLineJson(type);
  if (!aboutReplacement) {
    return line;
  }
  const Map<String, Object?> cherry = <String, Object?>{
    'name_uz': 'Olcha pomidor',
    'name_ru': 'Помидоры черри',
  };
  return <String, Object?>{
    ...line,
    'replacement': cherry,
    'pending_approval': <String, Object?>{
      ...line['pending_approval']! as Map<String, Object?>,
      'replacement': <String, Object?>{
        ...cherry,
        'customer_unit_price_uzs': 21850,
      },
    },
  };
}

/// An order being shopped, holding [lines].
Map<String, Object?> shopping(
  List<Object?> lines, {
  String id = orderOne,
  String status = 'shopping',
  bool canRequestCancellation = true,
  String? request,
  Map<String, Object?>? payment,
}) => customerOrderJson(
  id: id,
  status: status,
  changeable: false,
  lines: lines,
  canRequestCancellation: canRequestCancellation,
  cancellationRequest: request,
  payment: payment,
);

/// The Customer's order while it is shopped and delivered (`docs/09`
/// sections 20, 22 and 23, `DL-71`) through the real router and screens,
/// with the repositories faked.
void main() {
  late InMemoryTokenStore tokens;
  late FakeAuthRepository auth;
  late FakeCustomerOrdersRepository orders;
  late FakeCartRepository cart;

  Finder byKey(String key) => find.byKey(ValueKey<String>(key));

  BuildContext anywhere(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last);

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(anywhere(tester));

  setUp(() {
    tokens = InMemoryTokenStore()..tokens[SessionSlot.customer] = 'c';
    auth = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user(id: 'c');
    orders = FakeCustomerOrdersRepository();
    cart = FakeCartRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    String? at,
    Size size = const Size(800, 2400),
    double textScale = 1,
    Locale device = const Locale('uz'),
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
        orders: orders,
        cart: cart,
        device: device,
      ),
    );
    await tester.pumpAndSettle();
    if (at != null) {
      GoRouter.of(anywhere(tester)).push(at);
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  VoidCallback? pressed(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(byKey(key)).onPressed;

  group('the questions', () {
    test('each type reads its own way, in both languages', () {
      for (final Locale locale in const <Locale>[Locale('uz'), Locale('ru')]) {
        final AppLocalizations words = lookupAppLocalizations(locale);
        final Set<String> read = <String>{
          words.questionPrice('A', 'B', 'C'),
          words.questionReplacementPrice('A', 'B'),
          words.questionSubstitution('A', 'D', 'B'),
          words.questionQuantity('A', 'B', 'C'),
        };
        expect(read, hasLength(4), reason: locale.languageCode);
      }
      final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));
      final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
      expect(
        uz.questionPrice('A', 'B', 'C'),
        isNot(ru.questionPrice('A', 'B', 'C')),
      );
      expect(
        OrderLabels.customerRemovedReason(
          ru,
          ItemRemovedReason.customerRejected,
        ),
        isNot(
          OrderLabels.removedReason(ru, ItemRemovedReason.customerRejected),
        ),
        reason: 'the Customer reads about their own refusal',
      );
    });

    for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
      testWidgets(
        'each question shows its proposal in the Customer\'s words (${device.languageCode})',
        (WidgetTester tester) async {
          final AppLanguage language = device.languageCode == 'ru'
              ? AppLanguage.ru
              : AppLanguage.uz;
          orders.rows = <Map<String, Object?>>[
            shopping(<Object?>[asked('price_over_tolerance')]),
            shopping(<Object?>[
              asked('price_over_tolerance', aboutReplacement: true),
            ], id: orderTwo),
          ];
          await open(tester, device: device);
          final AppLocalizations words = l10n(tester);
          final String kg = CatalogLabels.unit(words, UnitCode.kg);
          String perKg(int uzs) =>
              words.catalogPricePerUnit(MoneyFormat.uzs(uzs, language), kg);
          final String tomato = language == AppLanguage.ru
              ? 'Помидоры'
              : 'Pomidor';
          final String cherry = language == AppLanguage.ru
              ? 'Помидоры черри'
              : 'Olcha pomidor';

          Future<void> show(String orderId) async {
            GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderId));
            await tester.pumpAndSettle();
          }

          await show(orderOne);
          expect(
            find.text(words.questionPrice(tomato, perKg(21850), perKg(18400))),
            findsOneWidget,
          );
          expect(
            find.text(words.questionNote('Qizili qolmadi')),
            findsOneWidget,
          );
          expect(
            find.text(words.questionExpires('28.09.2026 13:00')),
            findsOneWidget,
          );
          expect(find.text(words.questionRejectRemoves), findsOneWidget);
          expect(byKey('approve-$approvalOne'), findsOneWidget);
          expect(byKey('reject-$approvalOne'), findsOneWidget);

          await show(orderTwo);
          expect(
            find.text(words.questionReplacementPrice(cherry, perKg(21850))),
            findsOneWidget,
          );
          // The line shows the replacement the Customer authorized.
          expect(find.text(words.itemReplacedWith(cherry)), findsOneWidget);

          orders.rows = <Map<String, Object?>>[
            shopping(<Object?>[asked('substitution')]),
            shopping(<Object?>[asked('reduced_quantity')], id: orderTwo),
          ];
          await tester.pumpWidget(const SizedBox.shrink());
          await open(tester, device: device);
          await show(orderOne);
          expect(
            find.text(words.questionSubstitution(tomato, cherry, perKg(21850))),
            findsOneWidget,
          );
          await show(orderTwo);
          expect(
            find.text(
              words.questionQuantity(
                tomato,
                '${QuantityRules.display('1.000')} $kg',
                '${QuantityRules.display('1.500')} $kg',
              ),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'a price question about the product ordered says it drops the replacement',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[replaced(asked('price_over_tolerance'))]),
          shopping(<Object?>[
            asked('price_over_tolerance', aboutReplacement: true),
          ], id: orderTwo),
        ];
        await open(tester, at: AppPaths.customerOrder(orderOne));
        expect(
          byKey('question-drops-replacement-$approvalOne'),
          findsOneWidget,
        );
        expect(
          find.text(l10n(tester).questionDropsReplacement),
          findsOneWidget,
        );

        // About the replacement itself, or with none on the line, nothing
        // is dropped.
        GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderTwo));
        await tester.pumpAndSettle();
        expect(byKey('question-drops-replacement-$approvalOne'), findsNothing);
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[asked('price_over_tolerance')]),
          // Nor does a smaller quantity, whatever replaced the line.
          shopping(<Object?>[
            replaced(asked('reduced_quantity')),
          ], id: orderTwo),
        ];
        await tester.pumpWidget(const SizedBox.shrink());
        await open(tester, at: AppPaths.customerOrder(orderOne));
        expect(byKey('question-drops-replacement-$approvalOne'), findsNothing);
        GoRouter.of(anywhere(tester)).push(AppPaths.customerOrder(orderTwo));
        await tester.pumpAndSettle();
        expect(byKey('question-$approvalOne'), findsOneWidget);
        expect(byKey('question-drops-replacement-$approvalOne'), findsNothing);
      },
    );

    testWidgets('an approval is sent with its key, and the order reloaded', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[asked('price_over_tolerance')]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      orders.afterDecision = shopping(<Object?>[orderLineJson()]);
      final int loads = orders.loads.length;

      await tapAndSettle(tester, byKey('approve-$approvalOne'));

      final (String approval, ApprovalDecision decision, String key) =
          orders.decisions.single;
      expect(approval, approvalOne);
      expect(decision, ApprovalDecision.approve);
      expect(key, isNotEmpty);
      expect(orders.loads.skip(loads), contains('order:$orderOne'));
      expect(byKey('question-$approvalOne'), findsNothing);
      expect(byKey('failure-message'), findsNothing);
    });

    testWidgets(
      'a refusal to answer removes the line, said as the Customer\'s',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[asked('substitution')]),
        ];
        await open(tester, at: AppPaths.customerOrder(orderOne));
        orders.afterDecision = shopping(<Object?>[
          orderLineJson(status: 'removed', removedReason: 'customer_rejected'),
        ]);

        await tapAndSettle(tester, byKey('reject-$approvalOne'));

        expect(orders.decisions.single.$2, ApprovalDecision.reject);
        final AppLocalizations words = l10n(tester);
        expect(
          find.text(words.orderLineRemoved(words.removedYouRejected)),
          findsOneWidget,
        );
        expect(byKey('question-$approvalOne'), findsNothing);
      },
    );

    testWidgets('one answer at a time', (WidgetTester tester) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[asked('price_over_tolerance')]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      final Completer<void> hold = Completer<void>();
      orders.hold = hold;

      await tester.tap(byKey('approve-$approvalOne'));
      await tester.pump();
      expect(pressed(tester, 'approve-$approvalOne'), isNull);
      expect(pressed(tester, 'reject-$approvalOne'), isNull);
      // The answer on its way says so, on its own button.
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.descendant(
                of: byKey('approve-$approvalOne'),
                matching: find.byType(CircularProgressIndicator),
              ),
            )
            .semanticsLabel,
        l10n(tester).decisionSending,
      );
      expect(
        find.descendant(
          of: byKey('reject-$approvalOne'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      orders.hold = null;
      hold.complete();
      await tester.pumpAndSettle();
      expect(orders.decisions, hasLength(1));
    });

    testWidgets(
      'after a lost answer only the same decision goes again, under its key',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[asked('reduced_quantity')]),
        ];
        await open(tester, at: AppPaths.customerOrder(orderOne));
        orders.decisionFailure = const NetworkFailure();

        await tapAndSettle(tester, byKey('reject-$approvalOne'));

        final AppLocalizations words = l10n(tester);
        expect(find.text(words.errorNetwork), findsOneWidget);
        expect(
          find.text(words.decisionUnanswered(words.questionReject)),
          findsOneWidget,
        );
        expect(byKey('approve-$approvalOne'), findsNothing);
        expect(byKey('reject-$approvalOne'), findsNothing);

        orders
          ..decisionFailure = null
          ..afterDecision = shopping(<Object?>[
            orderLineJson(
              status: 'removed',
              removedReason: 'customer_rejected',
            ),
          ]);
        await tapAndSettle(tester, byKey('decide-again-$approvalOne'));

        expect(orders.decisions, hasLength(2));
        expect(orders.decisions[1].$1, approvalOne);
        expect(orders.decisions[1].$2, ApprovalDecision.reject);
        expect(orders.decisions[1].$3, orders.decisions[0].$3, reason: 'key');
        expect(byKey('question-$approvalOne'), findsNothing);
        expect(find.text(words.errorNetwork), findsNothing);
      },
    );

    testWidgets('an unanswered decision outlasts a reload that failed', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[asked('price_over_tolerance')]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      orders
        ..decisionFailure = const NetworkFailure()
        ..loadFailure = const NetworkFailure();

      await tapAndSettle(tester, byKey('approve-$approvalOne'));
      expect(byKey('question-$approvalOne'), findsNothing);
      await tapAndSettle(tester, byKey('retry-load'));

      expect(byKey('decide-again-$approvalOne'), findsOneWidget);
      expect(byKey('approve-$approvalOne'), findsNothing);
    });

    testWidgets('a key whose answer came is not sent again', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[asked('price_over_tolerance')]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      orders.decisionFailure = const ApiRefusal(
        ApiError(status: 409, code: 'order_state_conflict'),
      );
      await tapAndSettle(tester, byKey('approve-$approvalOne'));
      expect(byKey('decide-again-$approvalOne'), findsNothing);

      orders.decisionFailure = null;
      await tapAndSettle(tester, byKey('reject-$approvalOne'));
      expect(orders.decisions, hasLength(2));
      expect(orders.decisions[1].$3, isNot(orders.decisions[0].$3));
      expect(orders.decisions[1].$2, ApprovalDecision.reject);
    });

    testWidgets(
      'an expired question is refused, said so, and the line says its time ran out',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[asked('price_over_tolerance')]),
        ];
        await open(tester, at: AppPaths.customerOrder(orderOne));
        // The expiry stands although the decision is refused.
        orders
          ..decisionFailure = const ApiRefusal(
            ApiError(status: 409, code: 'approval_expired'),
          )
          ..afterDecision = shopping(<Object?>[
            orderLineJson(status: 'awaiting_customer'),
          ]);

        await tapAndSettle(tester, byKey('approve-$approvalOne'));

        final AppLocalizations words = l10n(tester);
        expect(find.text(words.errorApprovalExpired), findsOneWidget);
        expect(byKey('question-$approvalOne'), findsNothing);
        expect(byKey('question-expired-$lineTomato'), findsOneWidget);
        expect(find.text(words.questionExpired), findsOneWidget);
        expect(byKey('decide-again-$approvalOne'), findsNothing);
      },
    );

    testWidgets('a question answered elsewhere is refused and said so', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[asked('price_over_tolerance')]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      orders
        ..decisionFailure = const ApiRefusal(
          ApiError(status: 409, code: 'approval_already_resolved'),
        )
        ..afterDecision = shopping(<Object?>[orderLineJson()]);

      await tapAndSettle(tester, byKey('reject-$approvalOne'));

      expect(
        find.text(l10n(tester).errorApprovalAlreadyResolved),
        findsOneWidget,
      );
      expect(byKey('question-$approvalOne'), findsNothing);
      expect(byKey('question-expired-$lineTomato'), findsNothing);
    });

    testWidgets('a refusal is not said under a question asked since', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[asked('price_over_tolerance')]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      // Answered on another device, and the Shopper asked again since.
      orders
        ..decisionFailure = const ApiRefusal(
          ApiError(status: 409, code: 'approval_already_resolved'),
        )
        ..afterDecision = shopping(<Object?>[
          askedAgain(asked('reduced_quantity'), approvalTwo),
        ]);

      await tapAndSettle(tester, byKey('approve-$approvalOne'));

      expect(byKey('question-$approvalTwo'), findsOneWidget);
      expect(
        find.text(l10n(tester).errorApprovalAlreadyResolved),
        findsNothing,
      );
      expect(byKey('failure-message'), findsNothing);
    });

    testWidgets('a line waiting past its question offers no answer', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[orderLineJson(status: 'awaiting_customer')]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));

      expect(byKey('question-expired-$lineTomato'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });
  });

  group('the order as it is shopped and delivered', () {
    testWidgets('a bought line shows what is billed, and what replaced it', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[
          orderLineJson(
            status: 'purchased',
            patch: <String, Object?>{
              'replacement': <String, Object?>{
                'name_uz': 'Olcha pomidor',
                'name_ru': 'Помидоры черри',
              },
            },
          ),
          orderLineJson(
            id: lineBread,
            productId: productBread,
            unit: 'piece',
            quantity: '2',
          ),
        ]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      final AppLocalizations words = l10n(tester);
      final String kg = CatalogLabels.unit(words, UnitCode.kg);

      expect(
        find.text(
          words.orderLineBought(
            '${QuantityRules.display('1.500')} $kg',
            words.catalogPricePerUnit(
              MoneyFormat.uzs(18975, AppLanguage.uz),
              kg,
            ),
            MoneyFormat.uzs(28463, AppLanguage.uz),
          ),
        ),
        findsOneWidget,
      );
      expect(byKey('order-line-replacement-$lineTomato'), findsOneWidget);
      expect(
        find.text(words.itemReplacedWith('Olcha pomidor')),
        findsOneWidget,
      );
      // The ordered price is not what the bought line is billed at.
      expect(
        find.textContaining(MoneyFormat.uzs(18400, AppLanguage.uz)),
        findsNothing,
      );
      expect(byKey('order-line-replacement-$lineBread'), findsNothing);
    });

    testWidgets('the payment taken at the door, with the final total', (
      WidgetTester tester,
    ) async {
      final Map<String, Object?> done = shopping(
        <Object?>[orderLineJson(status: 'purchased')],
        status: 'completed',
        canRequestCancellation: false,
        payment: <String, Object?>{
          'method': 'cash',
          'status': 'paid',
          'amount_uzs': 48463,
          'paid_at': '2026-09-28T09:00:00Z',
        },
      );
      orders.rows = <Map<String, Object?>>[
        <String, Object?>{
          ...done,
          'totals': <String, Object?>{
            'merchandise_subtotal_uzs': 28463,
            'service_fee_uzs': 5000,
            'delivery_fee_uzs': 15000,
            'total_uzs': 48463,
            'total_kind': 'final',
          },
        },
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      final AppLocalizations words = l10n(tester);

      expect(
        find.text(
          words.orderPaid(
            MoneyFormat.uzs(48463, AppLanguage.uz),
            TashkentTime.format(DateTime.utc(2026, 9, 28, 9)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${MoneyFormat.uzs(48463, AppLanguage.uz)} · ${words.totalKindFinal}',
        ),
        findsOneWidget,
      );
      expect(byKey('order-request-cancel'), findsNothing);
    });

    testWidgets('no payment shows until one is made', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[orderLineJson()]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      expect(byKey('order-payment'), findsNothing);
    });
  });

  group('the cancellation request', () {
    final Map<String, String Function(AppLocalizations)> states =
        <String, String Function(AppLocalizations)>{
          'pending': (AppLocalizations l) => l.orderCancellationRequested,
          'approved': (AppLocalizations l) => l.requestStateApproved,
          'rejected': (AppLocalizations l) => l.requestStateRejected,
          'closed': (AppLocalizations l) => l.requestStateClosed,
        };
    states.forEach((String status, String Function(AppLocalizations) word) {
      testWidgets('shows its reason and that it is $status', (
        WidgetTester tester,
      ) async {
        orders.rows = <Map<String, Object?>>[
          shopping(
            <Object?>[orderLineJson()],
            status: status == 'approved' ? 'cancelled' : 'shopping',
            canRequestCancellation: status != 'pending',
            request: status,
          ),
        ];
        await open(tester, at: AppPaths.customerOrder(orderOne));
        final AppLocalizations words = l10n(tester);

        expect(find.text(words.requestYours('Kerak emas')), findsOneWidget);
        expect(find.text(word(words)), findsOneWidget);
        for (final MapEntry<String, String Function(AppLocalizations)> other
            in states.entries) {
          if (other.key != status) {
            expect(find.text(other.value(words)), findsNothing);
          }
        }
      });
    });

    testWidgets('asking needs a reason, and files the request', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[orderLineJson()]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      final AppLocalizations words = l10n(tester);
      expect(byKey('order-cancel'), findsNothing);

      await tapAndSettle(tester, byKey('order-request-cancel'));
      expect(find.text(words.orderRequestCancelTitle), findsOneWidget);
      expect(find.text(words.orderRequestCancelExplained), findsOneWidget);
      await tester.enterText(byKey('cancel-reason'), '   ');
      await tapAndSettle(tester, byKey('cancel-confirm'));
      expect(find.text(words.fieldRequired), findsOneWidget);
      expect(orders.cancels, isEmpty);

      await tester.enterText(byKey('cancel-reason'), 'a' * 301);
      await tapAndSettle(tester, byKey('cancel-confirm'));
      expect(find.text(words.fieldTooLong(300)), findsOneWidget);
      expect(orders.cancels, isEmpty);

      orders.answer = shopping(
        <Object?>[orderLineJson()],
        canRequestCancellation: false,
        request: 'pending',
      );
      await tester.enterText(byKey('cancel-reason'), '  Kech qoldi ');
      await tapAndSettle(tester, byKey('cancel-confirm'));

      expect(orders.cancels.single.$2, 'Kech qoldi');
      expect(byKey('order-cancellation-requested'), findsOneWidget);
      expect(byKey('order-request-cancel'), findsNothing);
    });

    testWidgets(
      'a cancel lost before shopping began goes again as it was, without a reason',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[customerOrderJson()];
        await open(tester, at: AppPaths.customerOrder(orderOne));
        orders
          ..failure = const NetworkFailure()
          ..rows = <Map<String, Object?>>[
            shopping(<Object?>[orderLineJson()]),
          ];
        await tapAndSettle(tester, byKey('order-cancel'));
        await tapAndSettle(tester, byKey('cancel-confirm'));
        expect(orders.cancels.single.$2, isNull);

        await tapAndSettle(tester, byKey('order-request-cancel'));
        expect(find.text(l10n(tester).orderCancelRepeating), findsOneWidget);
        orders.answer = customerOrderJson(
          status: 'cancelled',
          changeable: false,
        );
        await tapAndSettle(tester, byKey('cancel-confirm'));

        expect(find.text(l10n(tester).fieldRequired), findsNothing);
        expect(orders.cancels, hasLength(2));
        expect(orders.cancels[1].$2, isNull);
        expect(orders.cancels[1].$3, orders.cancels[0].$3);
      },
    );

    testWidgets('a request filed meanwhile elsewhere is shown, not an error', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[orderLineJson()]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      orders
        ..failure = const ApiRefusal(
          ApiError(status: 409, code: 'cancellation_already_pending'),
        )
        ..rows = <Map<String, Object?>>[
          shopping(
            <Object?>[orderLineJson()],
            canRequestCancellation: false,
            request: 'pending',
          ),
        ];
      await tapAndSettle(tester, byKey('order-request-cancel'));
      await tester.enterText(byKey('cancel-reason'), 'Kech qoldi');
      await tapAndSettle(tester, byKey('cancel-confirm'));

      expect(byKey('failure-message'), findsNothing);
      expect(byKey('order-cancellation-requested'), findsOneWidget);
    });
  });

  group('staying current', () {
    testWidgets(
      'an open order loads again every fifteen seconds, and the list with it',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[asked('price_over_tolerance')]),
        ];
        await open(tester, at: AppPaths.customerOrders);
        expect(byKey('order-waiting-$orderOne'), findsOneWidget);
        await tapAndSettle(tester, byKey('order-$orderOne'));
        expect(byKey('question-$approvalOne'), findsOneWidget);

        // Answered on another device meanwhile.
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[orderLineJson()]),
        ];
        final int loads = orders.loads.length;
        await tester.pump(const Duration(seconds: 14));
        await tester.pumpAndSettle();
        expect(orders.loads.length, loads);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(orders.loads.skip(loads), contains('order:$orderOne'));
        expect(byKey('question-$approvalOne'), findsNothing);

        await tapAndSettle(tester, find.byType(BackButton));
        expect(byKey('order-$orderOne'), findsOneWidget);
        expect(byKey('order-waiting-$orderOne'), findsNothing);
      },
    );

    testWidgets('an ended order is not loaded again', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        customerOrderJson(status: 'cancelled', changeable: false),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      final int loads = orders.loads.length;
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(orders.loads.length, loads);
    });

    testWidgets('a refresh that failed stops, and says so with a retry', (
      WidgetTester tester,
    ) async {
      orders.rows = <Map<String, Object?>>[
        shopping(<Object?>[orderLineJson()]),
      ];
      await open(tester, at: AppPaths.customerOrder(orderOne));
      orders.loadFailure = const NetworkFailure();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(byKey('retry-load'), findsOneWidget);

      final int loads = orders.loads.length;
      await tester.pump(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(orders.loads.length, loads, reason: 'a refresh is not a retry');

      await tapAndSettle(tester, byKey('retry-load'));
      expect(byKey('order-status'), findsOneWidget);
    });
  });

  testWidgets('My orders marks the orders waiting for the Customer', (
    WidgetTester tester,
  ) async {
    orders.rows = <Map<String, Object?>>[
      shopping(<Object?>[asked('substitution')]),
      shopping(<Object?>[orderLineJson()], id: orderTwo),
    ];
    await open(tester, at: AppPaths.customerOrders);

    expect(byKey('order-waiting-$orderOne'), findsOneWidget);
    expect(byKey('order-waiting-$orderTwo'), findsNothing);
    expect(find.text(l10n(tester).ordersNeedAnswer), findsOneWidget);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets(
      'questions, a bought line, the request and its dialog fit a phone with large text (${device.languageCode})',
      (WidgetTester tester) async {
        orders.rows = <Map<String, Object?>>[
          shopping(<Object?>[
            asked('substitution'),
            orderLineJson(
              id: lineApple,
              status: 'purchased',
              patch: <String, Object?>{
                'replacement': <String, Object?>{
                  'name_uz': 'Olcha pomidor',
                  'name_ru': 'Помидоры черри',
                },
              },
            ),
            orderLineJson(id: lineMilk, status: 'awaiting_customer'),
          ], request: 'rejected'),
        ];
        await open(
          tester,
          at: AppPaths.customerOrders,
          size: const Size(360, 800),
          textScale: 2,
          device: device,
        );
        expect(tester.takeException(), isNull);
        await tapAndSettle(tester, byKey('order-$orderOne'));
        expect(tester.takeException(), isNull);

        orders.decisionFailure = const NetworkFailure();
        await tapAndSettle(tester, byKey('approve-$approvalOne'));
        expect(byKey('decide-again-$approvalOne'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tapAndSettle(tester, byKey('order-request-cancel'));
        await tapAndSettle(tester, byKey('cancel-confirm'));
        expect(find.text(l10n(tester).fieldRequired), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
