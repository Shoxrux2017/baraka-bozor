import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/board.dart';

/// A person's name, or a word saying there is none.
String nameOf(AppLocalizations l10n, PersonRef person) =>
    person.fullName ?? l10n.personWithoutName;

/// An order's status in words, framed, so it reads the same without colour:
/// a new order solid green, an ended one grey or red, a final payment amber,
/// the rest a green wash.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color ground, Color text) = switch (status) {
      OrderStatus.newOrder => (KitColors.primary, Colors.white),
      OrderStatus.completed => (KitColors.field, KitColors.ink2),
      OrderStatus.cancelled => (KitColors.dangerWash, KitColors.danger),
      OrderStatus.finalPaymentPending => (
        KitColors.warningWash,
        KitColors.warningDark,
      ),
      _ => (KitColors.primaryWash, KitColors.primaryDark),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            OrderLabels.status(AppLocalizations.of(context), status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark of a self-order (`BR-ASSIGN-005`): an amber tag with a word,
/// with the meaning spelled out for a pointer and for assistive technology.
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.warningWash,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                l10n.selfOrderMark,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: KitColors.warningDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An order's total (`DL-37` (10)): "≈ amount" for an estimate, the amount
/// for a final total, or that nothing is due.
String totalText(
  BuildContext context,
  AppLocalizations l10n,
  int? totalUzs,
  TotalKind kind,
) {
  final String money = MoneyFormat.uzs(
    totalUzs ?? 0,
    interfaceLanguage(context),
  );
  return switch (kind) {
    TotalKind.none => l10n.totalNothingDue,
    TotalKind.estimate => '≈ $money',
    TotalKind.finalTotal => money,
  };
}
