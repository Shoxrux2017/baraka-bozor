import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/shopper_orders.dart';
import 'shopper_line_actions.dart';

/// The words of one line in the interface language, with its amounts
/// formatted: what every part of a line's card reads from.
class _LineWords {
  _LineWords(BuildContext context)
    : l10n = AppLocalizations.of(context),
      language = interfaceLanguage(context);

  final AppLocalizations l10n;
  final AppLanguage language;

  String name(String uz, String ru) => language == AppLanguage.ru ? ru : uz;

  String unit(ShopperLine line) => CatalogLabels.unit(l10n, line.unit);

  String money(int amount) => MoneyFormat.uzs(amount, language);

  String amount(ShopperLine line, String quantity) =>
      '${QuantityRules.display(quantity)} ${unit(line)}';
}

/// Whether the text is large enough that the quantity goes under the name
/// instead of beside it.
bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(15) > 15 * 1.3;

const ColorFilter _grey = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// A product's picture in a square of the kit's card colour; [greyed] for a
/// line that went.
class _Picture extends StatelessWidget {
  const _Picture({required this.url, required this.size, this.greyed = false});

  final String? url;
  final double size;
  final bool greyed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KitColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: greyed
          ? Opacity(
              opacity: 0.4,
              child: ColorFiltered(
                colorFilter: _grey,
                child: ProductImage(url: url, size: size),
              ),
            )
          : ProductImage(url: url, size: size),
    );
  }
}

/// The tag with the Customer's rule for a replacement.
class _PolicyTag extends StatelessWidget {
  const _PolicyTag({required this.policy});

  final SubstitutionPolicy policy;

  @override
  Widget build(BuildContext context) {
    return KitTag(
      text: OrderLabels.substitution(AppLocalizations.of(context), policy),
      icon: switch (policy) {
        SubstitutionPolicy.allowSimilar => Icons.swap_horiz,
        SubstitutionPolicy.contactBefore => Icons.call,
        SubstitutionPolicy.removeIfUnavailable => Icons.block,
      },
    );
  }
}

/// The quantity to buy as a chip: green to buy, amber while waiting.
class _QuantityChip extends StatelessWidget {
  const _QuantityChip({required this.text, required this.tone});

  final String text;
  final KitTone tone;

  @override
  Widget build(BuildContext context) {
    final bool amber = tone == KitTone.amber;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: amber ? KitColors.warningWash : KitColors.primaryWash,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: amber ? KitColors.warningDark : KitColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

/// The picture, the name over the market price, and the quantity chip: the
/// top of a card for a line still to buy or waiting.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.line, required this.tone});

  final ShopperLine line;
  final KitTone tone;

  @override
  Widget build(BuildContext context) {
    final _LineWords words = _LineWords(context);
    final bool large = _largeText(context);
    final Widget chip = _QuantityChip(
      text: words.amount(line, line.approvedQuantityCap ?? line.quantity),
      tone: tone,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Picture(url: line.imageUrl, size: 60),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                words.name(line.nameUz, line.nameRu),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                words.l10n.shopperMarketPer(
                  words.money(line.marketPriceUzs),
                  words.unit(line),
                ),
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
              if (large) ...<Widget>[const SizedBox(height: 8), chip],
            ],
          ),
        ),
        if (!large) ...<Widget>[const SizedBox(width: 8), chip],
      ],
    );
  }
}

/// The Customer's note on a line, in a grey note.
class _CustomerNote extends StatelessWidget {
  const _CustomerNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return KitNote(
      icon: Icons.chat_outlined,
      tone: KitTone.grey,
      text: Text(AppLocalizations.of(context).shopperClientNote(note)),
    );
  }
}

/// How far the original's price may go without asking the Customer.
class _BoundRow extends StatelessWidget {
  const _BoundRow({required this.line, required this.bound, super.key});

  final ShopperLine line;
  final PriceBound bound;

  @override
  Widget build(BuildContext context) {
    final _LineWords words = _LineWords(context);
    final String price = words.money(bound.marketPriceUzs);
    final String sentence = words.l10n.shopperBoundPer(price, words.unit(line));
    final int at = sentence.indexOf(price);
    const TextStyle plain = TextStyle(fontSize: 13, color: KitColors.ink2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.verified_outlined, size: 17, color: KitColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            at < 0
                ? TextSpan(text: sentence, style: plain)
                : TextSpan(
                    style: plain,
                    children: <InlineSpan>[
                      TextSpan(text: sentence.substring(0, at)),
                      TextSpan(
                        text: price,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: sentence.substring(at + price.length)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// The replacement authorized on a line, with its own bound.
class _ReplacementBox extends StatelessWidget {
  const _ReplacementBox({required this.replacement, super.key});

  final ShopperReplacement replacement;

  @override
  Widget build(BuildContext context) {
    final _LineWords words = _LineWords(context);
    final AppLocalizations l10n = words.l10n;
    const TextStyle small = TextStyle(fontSize: 11, color: KitColors.ink2);

    return KitNote(
      icon: Icons.swap_horiz,
      text: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.itemReplacedWith(
              words.name(replacement.nameUz, replacement.nameRu),
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            replacement.resolution == SubstitutionResolution.automatic
                ? l10n.shopperReplacementAutomatic
                : l10n.shopperReplacementApproved,
            style: small,
          ),
          Text(
            l10n.shopperReplacementPrices(
              words.money(replacement.marketPriceUzs),
              words.money(replacement.bound.marketPriceUzs),
            ),
            style: small,
          ),
        ],
      ),
    );
  }
}

/// A plain row for a line: before the shopping starts, and in the done
/// group where it says what was bought or why the line went.
class ShopperLineRow extends StatelessWidget {
  const ShopperLineRow({required this.line, super.key});

  final ShopperLine line;

  @override
  Widget build(BuildContext context) {
    final _LineWords words = _LineWords(context);
    final AppLocalizations l10n = words.l10n;
    final ShopperPurchase? purchase = line.purchase;
    final ShopperReplacement? replacement = line.replacement;
    // The replacement itself, when that is what was bought.
    final ShopperReplacement? instead =
        purchase != null &&
            replacement != null &&
            purchase.productId == replacement.productId
        ? replacement
        : null;
    final bool removed = line.status == OrderItemStatus.removed;
    final String name = instead != null
        ? words.name(instead.nameUz, instead.nameRu)
        : words.name(line.nameUz, line.nameRu);
    const TextStyle small = TextStyle(fontSize: 12, color: KitColors.ink2);
    final int? paid = purchase?.actualMarketPriceUzs;
    final ItemRemovedReason? reason = line.removedReason;
    final String? note = line.customerNote;

    final List<Widget> details = <Widget>[];
    if (purchase != null) {
      final String quantity = words.amount(line, purchase.purchasedQuantity);
      final String bought = paid == null
          ? l10n.itemBought(quantity)
          : instead != null
          ? l10n.shopperBoughtInstead(
              words.name(line.nameUz, line.nameRu),
              quantity,
              words.money(paid),
            )
          : l10n.shopperBoughtAt(quantity, words.money(paid));
      details.add(
        Text(
          bought,
          key: ValueKey<String>('shopper-line-bought-${line.id}'),
          style: small,
        ),
      );
      details.add(const SizedBox(height: 6));
      details.add(
        KitTag(
          text: instead != null ? l10n.shopperTagReplaced : l10n.lineTagBought,
          icon: instead != null ? Icons.swap_horiz : Icons.check,
          tone: KitTone.green,
        ),
      );
    } else if (removed) {
      details.add(
        Text(
          words.amount(line, line.quantity),
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
      );
      if (reason != null) {
        details.add(const SizedBox(height: 6));
        details.add(
          KitTag(
            key: ValueKey<String>('shopper-line-status-${line.id}'),
            text: l10n.shopperTagRemoved(
              OrderLabels.removedReason(l10n, reason),
            ),
            tone: KitTone.grey,
          ),
        );
      }
    } else {
      details.add(
        Text(
          l10n.shopperMarketPer(
            words.money(line.marketPriceUzs),
            words.unit(line),
          ),
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
      );
      if (note != null) {
        details.add(const SizedBox(height: 2));
        details.add(Text(l10n.shopperClientNote(note), style: small));
      }
      details.add(const SizedBox(height: 6));
      details.add(_PolicyTag(policy: line.substitutionPolicy));
    }

    final bool large = _largeText(context);
    final Widget quantity = Text(
      removed
          ? '—'
          : words.amount(line, purchase?.purchasedQuantity ?? line.quantity),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: removed ? KitColors.muted : KitColors.ink,
      ),
    );

    return KitCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Picture(
            url: instead != null ? instead.imageUrl : line.imageUrl,
            size: 56,
            greyed: removed,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: removed ? KitColors.muted : KitColors.ink,
                    decoration: removed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                ...details,
                if (large) ...<Widget>[const SizedBox(height: 6), quantity],
              ],
            ),
          ),
          if (!large) ...<Widget>[const SizedBox(width: 8), quantity],
        ],
      ),
    );
  }
}

/// A line the Shopper still has to deal with while shopping: a card to buy,
/// with what applies to it and the buttons, or a card waiting for the
/// Customer's answer. A line already bought or removed is a plain row.
class ShopperLineCard extends StatelessWidget {
  const ShopperLineCard({required this.order, required this.line, super.key});

  final ShopperOrder order;
  final ShopperLine line;

  @override
  Widget build(BuildContext context) {
    return switch (line.status) {
      OrderItemStatus.pending => _ToBuyCard(order: order, line: line),
      OrderItemStatus.awaitingCustomer => _WaitingCard(line: line),
      _ => ShopperLineRow(line: line),
    };
  }
}

class _ToBuyCard extends StatelessWidget {
  const _ToBuyCard({required this.order, required this.line});

  final ShopperOrder order;
  final ShopperLine line;

  @override
  Widget build(BuildContext context) {
    final _LineWords words = _LineWords(context);
    final AppLocalizations l10n = words.l10n;
    final String? cap = line.approvedQuantityCap;
    final PriceBound? bound = line.bound;
    final ShopperReplacement? replacement = line.replacement;
    final String? note = line.customerNote;

    return KitCard(
      key: ValueKey<String>('shopper-line-${line.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(line: line, tone: KitTone.green),
          if (bound != null && replacement == null) ...<Widget>[
            const SizedBox(height: 12),
            _BoundRow(
              key: ValueKey<String>('shopper-line-limit-${line.id}'),
              line: line,
              bound: bound,
            ),
          ],
          if (cap != null) ...<Widget>[
            const SizedBox(height: 10),
            KitNote(
              icon: Icons.check_circle_outline,
              text: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.shopperCapAgreed(
                      words.amount(line, cap),
                      words.amount(line, line.quantity),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(l10n.shopperCapBuy(words.amount(line, cap))),
                ],
              ),
            ),
          ],
          if (replacement != null) ...<Widget>[
            const SizedBox(height: 10),
            _ReplacementBox(
              key: ValueKey<String>('shopper-line-replacement-${line.id}'),
              replacement: replacement,
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _PolicyTag(policy: line.substitutionPolicy),
          ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 10),
            _CustomerNote(note: note),
          ],
          // At the market an open line can be bought, replaced or said not
          // to be found; a line waiting for the Customer cannot.
          if (order.status == OrderStatus.shopping)
            ShopperLineActions(order: order, line: line),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.line});

  final ShopperLine line;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OpenQuestion? question = line.openQuestion;
    final Key questionKey = ValueKey<String>(
      'shopper-line-question-${line.id}',
    );

    // A question that is no longer open was not answered in time; only an
    // Operator or Admin may remove the line (`docs/03`).
    return KitCard(
      key: ValueKey<String>('shopper-line-${line.id}'),
      padding: const EdgeInsets.all(14),
      outline: question == null ? KitColors.line : KitColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(line: line, tone: KitTone.amber),
          const SizedBox(height: 12),
          if (question == null)
            KitNote(
              key: questionKey,
              icon: Icons.timer_off_outlined,
              tone: KitTone.red,
              text: Text(l10n.shopperQuestionExpired),
            )
          else ...<Widget>[
            KitNote(
              key: questionKey,
              icon: Icons.hourglass_top,
              tone: KitTone.amber,
              text: Text(_asked(l10n, question)),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.shopperWaitBuyOthers,
              style: const TextStyle(fontSize: 11, color: KitColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  String _asked(AppLocalizations l10n, OpenQuestion question) {
    final String time = TashkentTime.time(question.expiresAt);
    return switch (question.type) {
      ApprovalType.priceOverTolerance => l10n.shopperAskedPrice(time),
      ApprovalType.substitution => l10n.shopperAskedSubstitution(time),
      ApprovalType.reducedQuantity => l10n.shopperAskedQuantity(time),
    };
  }
}
