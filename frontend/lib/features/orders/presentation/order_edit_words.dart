import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../application/order_draft.dart';

/// What a substitution rule says in the options row: «замена похожим»,
/// «позвонить перед заменой», «нет — убрать» (`DL-132`).
String ruleShort(AppLocalizations l10n, SubstitutionPolicy rule) =>
    switch (rule) {
      SubstitutionPolicy.allowSimilar => l10n.substitutionShortSimilar,
      SubstitutionPolicy.contactBefore => l10n.substitutionShortContact,
      SubstitutionPolicy.removeIfUnavailable => l10n.substitutionShortRemove,
    };

/// A quantity with its unit, as the stepper shows it, or «—» while the
/// quantity is one its unit does not take.
String quantityWords(AppLocalizations l10n, UnitCode unit, String quantity) =>
    QuantityRules.normalize(unit, quantity) == null
    ? '—'
    : '${QuantityRules.display(quantity)} ${CatalogLabels.unit(l10n, unit)}';

/// [amount] with "≈" when the line's price is an estimate, as it stands when
/// the price is fixed (`DL-52` (2)).
String estimatedAmount(
  AppLocalizations l10n,
  DraftLine line,
  AppLanguage language,
  int amountUzs,
) {
  final String amount = MoneyFormat.uzs(amountUzs, language);
  return line.priceMode == PriceMode.estimate
      ? l10n.cartLineEstimate(amount)
      : amount;
}

/// The line's price per unit, with "≈" only for an estimate price.
String perUnitWords(
  AppLocalizations l10n,
  DraftLine line,
  AppLanguage language,
  String unit,
) {
  final String price = l10n.catalogPricePerUnit(
    MoneyFormat.uzs(line.unitPriceUzs, language),
    unit,
  );
  return line.priceMode == PriceMode.estimate
      ? l10n.cartLineEstimate(price)
      : price;
}

/// The words of the options row: the note in quotes, or «Комментарий», then
/// the rule said short.
String optionsWords(AppLocalizations l10n, DraftLine line) {
  final String? note = line.note;
  return l10n.orderEditOptions(
    note == null || note.isEmpty ? l10n.orderEditComment : '«$note»',
    ruleShort(l10n, line.policy),
  );
}

/// What a screen reader says of a kept line: its name, quantity and sum; an
/// added line says it is new, at the price now.
String lineSpoken(
  AppLocalizations l10n,
  AppLanguage language,
  DraftLine line, {
  required bool adds,
}) {
  final int? preview = line.previewUzs;
  final String name = line.name(language);
  final String quantity = quantityWords(l10n, line.unit, line.quantity);
  final String sum = preview == null
      ? '—'
      : estimatedAmount(l10n, line, language, preview);
  return adds
      ? l10n.orderEditLineNewSpoken(name, quantity, sum)
      : l10n.orderEditLineSpoken(name, quantity, sum);
}

/// One change an edit makes, as a line of the exit sheet and the lock view.
String changeText(
  AppLocalizations l10n,
  AppLanguage language,
  DraftChange change,
) {
  final String name = language == AppLanguage.uz
      ? change.nameUz
      : change.nameRu;
  String quantity(String? value) => change.unit == null || value == null
      ? '—'
      : quantityWords(l10n, change.unit!, value);
  return switch (change.kind) {
    DraftChangeKind.added => l10n.orderChangeAdded(name, quantity(change.to)),
    DraftChangeKind.removed => l10n.orderChangeRemoved(name),
    DraftChangeKind.quantity => l10n.orderChangeQuantity(
      name,
      quantity(change.from),
      quantity(change.to),
    ),
    DraftChangeKind.note =>
      change.to == null
          ? l10n.orderChangeNoNote(name)
          : l10n.orderChangeNote(name, change.to!),
    DraftChangeKind.rule => l10n.orderChangeRule(
      name,
      _lowerFirst(OrderLabels.substitution(l10n, change.rule!)),
    ),
    DraftChangeKind.wish =>
      change.to == null
          ? l10n.orderChangeNoWish
          : l10n.orderChangeWish(change.to!),
  };
}

String _lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
