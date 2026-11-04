import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../domain/customer_orders.dart';
import 'order_cards.dart';

/// What a screen reader says for a current order's card (`DL-131`): the
/// order, its status with the stage, the question waiting and the minutes
/// left when they are known, the sum, then when it was placed and how many
/// goods it holds. [questions] is what the card shows, the summary's count
/// when it is `null`.
String currentOrderSpoken(
  AppLocalizations l10n,
  AppLanguage language,
  OrderSummary order,
  DateTime now, {
  int? minutesLeft,
  int? questions,
}) {
  final int asked = questions ?? order.pendingApprovalCount;
  final int? total = order.totalUzs;
  final String amount = total == null
      ? l10n.totalNothingDue
      : order.totalKind == TotalKind.estimate
      ? l10n.orderCardEstimateSpoken(MoneyFormat.uzs(total, language))
      : MoneyFormat.uzs(total, language);
  final String placed = orderAt(l10n, order.createdAt, now);

  return <String>[
    l10n.customerOrderTitle(order.orderNumber),
    l10n.orderCardStageSpoken(
      OrderLabels.customerStatus(l10n, order.status),
      orderStage(order.status),
    ),
    if (asked > 0)
      minutesLeft == null
          ? l10n.orderCardQuestion(asked)
          : '${l10n.orderCardQuestion(asked)}, '
                '${l10n.deadlineLeftSpoken(minutesLeft)}',
    amount,
    order.itemCount > 0
        ? '$placed, ${l10n.orderItemCount(order.itemCount)}'
        : placed,
  ].join('. ');
}
