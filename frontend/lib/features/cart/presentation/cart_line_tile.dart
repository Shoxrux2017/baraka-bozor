import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/soft_change.dart';
import '../../../core/widgets/product_image.dart';
import '../../catalog/presentation/catalog_paths.dart';
import '../../catalog/presentation/quantity_sheet.dart';
import '../application/card_quantity.dart';
import '../application/cart_quantity_queue.dart';
import '../domain/cart.dart';
import 'cart_line_stepper.dart';
import 'cart_feedback.dart';
import 'swipe_to_remove.dart';

/// One line of the cart (drawings 19 and 19б): picture, name, the unit price,
/// the rule and the note when set, and a bottom row with the line's estimate
/// and a stepper. A line no longer sold is greyed and only removed. Every
/// change goes through the line's own controller, which answers the whole
/// cart and reloads it when the line is gone or changed elsewhere.
class CartLineTile extends ConsumerStatefulWidget {
  const CartLineTile({required this.line, super.key});

  final CartLine line;

  @override
  ConsumerState<CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends ConsumerState<CartLineTile> {
  CartLine get _line => widget.line;

  /// What the Customer sees: the wish the server has not answered yet, else
  /// the line's own quantity (`DL-119`).
  String _shown(Map<String, String> wishes) =>
      shownCartQuantity(wishes, _line.productId, _line) ?? _line.quantity;

  /// Wishes [quantity] through the queue; a failure is said in a snackbar.
  Future<void> _want(String quantity, {bool now = false}) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ApiFailure? failure = await ref
        .read(cartQuantityQueueProvider.notifier)
        .want(_line.productId, quantity, now: now);
    showCartFailure(messenger, l10n, failure);
  }

  /// Takes the line out at once and offers it back.
  Future<void> _remove() => removeCartLine(
    context,
    ref,
    line: _line,
    quantity: _shown(ref.read(cartQuantityQueueProvider)),
    name: _line.name(interfaceLanguage(context)),
  );

  void _plus() {
    final String? quantity = CardQuantity.next(
      _line.unit,
      _shown(ref.read(cartQuantityQueueProvider)),
    );
    if (quantity != null) {
      _want(quantity);
    }
  }

  void _minus() {
    final String shown = _shown(ref.read(cartQuantityQueueProvider));
    final String? quantity = CardQuantity.previous(_line.unit, shown);
    if (quantity == null) {
      _remove();
    } else {
      _want(quantity);
    }
  }

  Future<void> _exactQuantity() async {
    final String? quantity = await showQuantitySheet(
      context,
      unit: _line.unit,
      current: _shown(ref.read(cartQuantityQueueProvider)),
    );
    if (quantity != null && mounted) {
      await _want(quantity, now: true);
    }
  }

  void _openProduct() => context.push(CatalogPaths.product(_line.productId));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CartLine line = _line;
    final Map<String, String> wishes = ref.watch(cartQuantityQueueProvider);
    final String shown = _shown(wishes);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final String quantity = '${QuantityRules.display(shown)} $unit';
    final bool canStep =
        QuantityRules.normalize(line.unit, line.quantity) != null;
    final bool available = line.isAvailable;
    final int? price = line.customerUnitPriceUzs;
    final int? total = line.estimatedLineTotalUzs;
    final bool estimate = line.priceMode == PriceMode.estimate;
    final String? note = line.customerNote;

    final Widget picture = SizedBox.square(
      dimension: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: available
              ? ProductImage(url: line.imageUrl, size: 64)
              : Opacity(
                  opacity: 0.4,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0, 0, 0, 1, 0, //
                    ]),
                    child: ProductImage(url: line.imageUrl, size: 64),
                  ),
                ),
        ),
      ),
    );

    final Widget info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          line.name(language),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: available ? KitColors.ink : KitColors.muted,
          ),
        ),
        if (!available)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.field,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  l10n.cartLineUnavailable,
                  key: ValueKey<String>('cart-line-unavailable-${line.id}'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: KitColors.danger,
                  ),
                ),
              ),
            ),
          )
        else if (price != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            estimate
                ? l10n.cartUnitPrice(unit, MoneyFormat.uzs(price, language))
                : l10n.cartUnitPriceExact(
                    unit,
                    MoneyFormat.uzs(price, language),
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
        ],
        if (available &&
            line.substitutionPolicy != SubstitutionPolicy.allowSimilar)
          CartInfoRow(
            key: ValueKey<String>('line-rule-${line.id}'),
            icon: line.substitutionPolicy == SubstitutionPolicy.contactBefore
                ? Icons.call_outlined
                : Icons.block,
            text: OrderLabels.substitution(l10n, line.substitutionPolicy),
            maxLines: 1,
          ),
        if (available && note != null)
          CartInfoRow(
            key: ValueKey<String>('line-note-${line.id}'),
            icon: Icons.chat_bubble_outline,
            text: note,
            maxLines: 2,
          ),
      ],
    );

    final String? sumText = available && total != null
        ? (estimate
              ? l10n.cartLineEstimate(MoneyFormat.uzs(total, language))
              : MoneyFormat.uzs(total, language))
        : null;
    const TextStyle sumStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: KitColors.ink,
    );

    /// The bottom row of a sold line: the sum, dimmed while the change
    /// waits, beside the stepper or, when they do not fit, over it.
    Widget bottom(double columnWidth) {
      final Widget sum = SoftChange(
        value: total ?? 0,
        waiting: wishes.containsKey(line.productId),
        child: Text(
          sumText!,
          key: ValueKey<String>('line-sum-${line.id}'),
          style: sumStyle,
        ),
      );
      Widget stepper(double width) => CartLineStepper(
        id: line.id,
        quantityText: quantity,
        busy: false,
        canStep: canStep,
        atMinimum: canStep && CardQuantity.previous(line.unit, shown) == null,
        binLabel: l10n.cartRemoveLine,
        width: width,
        onMinus: _minus,
        onPlus: _plus,
        onQuantity: _exactQuantity,
      );
      final double sumWidth = textWidth(context, sumText, sumStyle);
      if (sumWidth + 8 + CartLineStepper.defaultWidth <= columnWidth) {
        return Row(
          children: <Widget>[
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: sum),
            ),
            const SizedBox(width: 8),
            stepper(CartLineStepper.defaultWidth),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          sum,
          const SizedBox(height: 6),
          stepper(math.min(180, columnWidth)),
        ],
      );
    }

    final Widget unavailableBottom = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              quantity,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KitColors.muted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: OutlinedButton(
            key: ValueKey<String>('remove-line-${line.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KitColors.danger,
              side: const BorderSide(color: KitColors.danger),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _remove,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l10n.cartRemoveConfirm,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // The picture on the left; the text, then the bottom row level with the
    // picture's bottom when the text is short, in the column beside it. The
    // LayoutBuilder sits above the IntrinsicHeight, which cannot hold one.
    final Widget row = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double columnWidth = constraints.maxWidth - 84 - 12;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(alignment: Alignment.topLeft, child: picture),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    info,
                    const Spacer(),
                    // The 44 stepper under the text still ends level with
                    // the 84 picture, so the gap is small (`DL-117`).
                    const SizedBox(height: 2),
                    sumText != null ? bottom(columnWidth) : unavailableBottom,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    final Widget content = available
        ? InkWell(
            key: ValueKey<String>('cart-line-${line.id}'),
            onTap: _openProduct,
            child: row,
          )
        : row;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: SwipeToRemove(
          label: l10n.cartRemoveConfirm,
          removing: wishes[line.productId] == CartQuantityQueue.out,
          onRemove: _remove,
          child: content,
        ),
      ),
    );
  }
}

/// A muted line of a row's details: a small icon and a text, as the rule
/// and the note of a line are shown.
class CartInfoRow extends StatelessWidget {
  const CartInfoRow({
    required this.icon,
    required this.text,
    required this.maxLines,
    super.key,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: KitColors.muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: KitColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
