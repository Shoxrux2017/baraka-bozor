import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/failure_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../../catalog/presentation/catalog_paths.dart';
import '../../catalog/presentation/quantity_sheet.dart';
import '../application/card_quantity.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_line_stepper.dart';
import 'remove_line_sheet.dart';

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
  // The remove sheet is open: a second minus does not stack another.
  bool _asking = false;

  CartLine get _line => widget.line;

  /// Runs one change of this line; a failure is said in a snackbar, and the
  /// controller has already asked for the cart again when it may be stale.
  Future<void> _run(Future<Cart?> Function() change) async {
    if (ref.read(cartLineProvider(_line.id)).isBusy) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String id = _line.id;
    final Cart? answer = await change();
    if (answer != null || !mounted) {
      return;
    }
    final ApiFailure? failure = ref.read(cartLineProvider(id)).failure;
    if (failure == null) {
      return;
    }
    final String? text = failureText(l10n, failure);
    if (text != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _remove() =>
      _run(() => ref.read(cartLineProvider(_line.id).notifier).remove());

  Future<void> _change(String quantity) {
    final CartLinePatch patch = CartLinePatch.between(
      _line,
      quantity: quantity,
      customerNote: _line.customerNote,
      substitutionPolicy: _line.substitutionPolicy,
    );
    if (patch.isEmpty) {
      return Future<void>.value();
    }
    return _run(
      () => ref.read(cartLineProvider(_line.id).notifier).change(patch),
    );
  }

  Future<void> _plus() {
    final String? quantity = CardQuantity.next(_line.unit, _line.quantity);
    return quantity == null ? Future<void>.value() : _change(quantity);
  }

  Future<void> _minus() async {
    if (_asking || ref.read(cartLineProvider(_line.id)).isBusy) {
      return;
    }
    final String? quantity = CardQuantity.previous(_line.unit, _line.quantity);
    if (quantity != null) {
      return _change(quantity);
    }
    _asking = true;
    final bool confirmed = await confirmRemoveLine(context, _line);
    _asking = false;
    if (confirmed && mounted) {
      await _remove();
    }
  }

  Future<void> _exactQuantity() async {
    final String? quantity = await showQuantitySheet(
      context,
      unit: _line.unit,
      current: _line.quantity,
    );
    if (quantity != null && mounted) {
      await _change(quantity);
    }
  }

  void _openProduct() => context.push(CatalogPaths.product(_line.productId));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CartLine line = _line;
    final bool busy = ref.watch(cartLineProvider(line.id)).isBusy;
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final String quantity = '${QuantityRules.display(line.quantity)} $unit';
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
          _InfoRow(
            key: ValueKey<String>('line-rule-${line.id}'),
            icon: line.substitutionPolicy == SubstitutionPolicy.contactBefore
                ? Icons.call_outlined
                : Icons.block,
            text: OrderLabels.substitution(l10n, line.substitutionPolicy),
            maxLines: 1,
          ),
        if (available && note != null)
          _InfoRow(
            key: ValueKey<String>('line-note-${line.id}'),
            icon: Icons.chat_bubble_outline,
            text: note,
            maxLines: 2,
          ),
      ],
    );

    final Widget bottom = available && total != null
        ? Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      estimate
                          ? l10n.cartLineEstimate(
                              MoneyFormat.uzs(total, language),
                            )
                          : MoneyFormat.uzs(total, language),
                      key: ValueKey<String>('line-sum-${line.id}'),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CartLineStepper(
                id: line.id,
                quantityText: quantity,
                busy: busy,
                canStep:
                    QuantityRules.normalize(line.unit, line.quantity) != null,
                onMinus: _minus,
                onPlus: _plus,
                onQuantity: _exactQuantity,
              ),
            ],
          )
        : Row(
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
                  onPressed: busy ? null : _remove,
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
    // picture's bottom when the text is short, in the column beside it.
    final Widget row = IntrinsicHeight(
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
                const SizedBox(height: 8),
                bottom,
              ],
            ),
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: available
            ? InkWell(
                key: ValueKey<String>('cart-line-${line.id}'),
                onTap: _openProduct,
                child: row,
              )
            : row,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
