import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../domain/board.dart';

/// A person's name, or a word saying there is none.
String nameOf(AppLocalizations l10n, PersonRef person) =>
    person.fullName ?? l10n.personWithoutName;

/// An order's status in words, framed, so it reads the same without colour.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool ended =
        status == OrderStatus.completed || status == OrderStatus.cancelled;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: ended ? colors.outline : colors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(OrderLabels.status(AppLocalizations.of(context), status)),
      ),
    );
  }
}

/// The mark of a self-order (`BR-ASSIGN-005`): an icon and a word, with the
/// meaning spelled out for a pointer and for assistive technology.
class SelfOrderMark extends StatelessWidget {
  const SelfOrderMark({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Tooltip(
      message: l10n.selfOrderExplained,
      child: Semantics(
        label: l10n.selfOrderExplained,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.person_pin_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(width: 4),
            Text(l10n.selfOrderMark),
          ],
        ),
      ),
    );
  }
}

/// An order's total with its kind (`DL-37` (10)): the amount and whether
/// it is an estimate or final, or that nothing is due.
String totalText(
  BuildContext context,
  AppLocalizations l10n,
  int? totalUzs,
  TotalKind kind,
) => switch (kind) {
  TotalKind.none => l10n.totalNothingDue,
  TotalKind.estimate =>
    '${MoneyFormat.uzs(totalUzs ?? 0, interfaceLanguage(context))} · '
        '${l10n.totalKindEstimate}',
  TotalKind.finalTotal =>
    '${MoneyFormat.uzs(totalUzs ?? 0, interfaceLanguage(context))} · '
        '${l10n.totalKindFinal}',
};
