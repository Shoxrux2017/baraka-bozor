import 'package:baraka_bozor/core/catalog/catalog_values.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/generated/app_localizations.dart';
import 'package:baraka_bozor/core/orders/order_values.dart';
import 'package:baraka_bozor/features/orders/application/order_draft.dart';
import 'package:baraka_bozor/features/orders/presentation/order_edit_words.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The words the editor says of its lines and of what an edit changes
/// (`DL-132`).
void main() {
  final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
  final AppLocalizations uz = lookupAppLocalizations(const Locale('uz'));

  DraftChange change(
    DraftChangeKind kind, {
    UnitCode? unit,
    String? from,
    String? to,
    SubstitutionPolicy? rule,
  }) => (
    kind: kind,
    nameUz: kind == DraftChangeKind.wish ? '' : 'Sut',
    nameRu: kind == DraftChangeKind.wish ? '' : 'Молоко',
    unit: unit,
    from: from,
    to: to,
    rule: rule,
  );

  test('the rule is said short, in both languages', () {
    expect(ruleShort(ru, SubstitutionPolicy.allowSimilar), 'замена похожим');
    expect(
      ruleShort(ru, SubstitutionPolicy.contactBefore),
      'позвонить перед заменой',
    );
    expect(
      ruleShort(ru, SubstitutionPolicy.removeIfUnavailable),
      'нет — убрать',
    );
    expect(
      ruleShort(uz, SubstitutionPolicy.allowSimilar),
      "o'xshashiga almashtirish",
    );
    expect(
      ruleShort(uz, SubstitutionPolicy.removeIfUnavailable),
      "yo'q bo'lsa — olib tashlash",
    );
  });

  test('a change reads as a line, in the interface language', () {
    String say(DraftChange c, [AppLanguage l = AppLanguage.ru]) =>
        changeText(l == AppLanguage.ru ? ru : uz, l, c);

    expect(
      say(change(DraftChangeKind.added, unit: UnitCode.piece, to: '2')),
      '+ Молоко, 2 шт.',
    );
    expect(say(change(DraftChangeKind.removed)), '− Молоко');
    expect(
      say(
        change(
          DraftChangeKind.quantity,
          unit: UnitCode.kg,
          from: '1.500',
          to: '2',
        ),
      ),
      'Молоко: 1,5 кг → 2 кг',
    );
    expect(
      say(change(DraftChangeKind.note, to: 'Свежее')),
      'Молоко: комментарий «Свежее»',
    );
    expect(say(change(DraftChangeKind.note)), 'Молоко: без комментария');
    expect(
      say(
        change(
          DraftChangeKind.rule,
          rule: SubstitutionPolicy.removeIfUnavailable,
        ),
      ),
      'Молоко: если нет — убрать',
    );
    expect(
      say(change(DraftChangeKind.wish, to: 'Ertalab')),
      'Пожелание к доставке: «Ertalab»',
    );
    expect(say(change(DraftChangeKind.wish)), 'Пожелание к доставке убрано');
    expect(say(change(DraftChangeKind.removed), AppLanguage.uz), '− Sut');
    expect(
      say(change(DraftChangeKind.note, to: 'Yangi'), AppLanguage.uz),
      'Sut: izoh «Yangi»',
    );
  });
}
