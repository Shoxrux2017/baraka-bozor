import 'package:flutter/material.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../cart/domain/cart.dart';
import '../domain/checkout.dart';
import 'checkout_sections.dart';

/// One product of the checkout: what the Customer ordered, and the server's
/// sum for it once a preview has answered (`DL-121`). [id] is the cart item
/// id, the same in the cart and in the preview.
final class CheckoutItem {
  const CheckoutItem({
    required this.id,
    required this.nameUz,
    required this.nameRu,
    required this.unit,
    required this.quantity,
    required this.priceMode,
    required this.imageUrl,
    required this.lineTotalUzs,
  });

  final String id;
  final String nameUz;
  final String nameRu;
  final UnitCode unit;

  /// A decimal string, as the API gives it.
  final String quantity;
  final PriceMode priceMode;
  final String? imageUrl;

  /// The preview's sum; `null` while no preview stands, never the cart's own
  /// estimate.
  final int? lineTotalUzs;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;
}

/// The products to show: the preview's lines with the cart's pictures by cart
/// item id and their sums; without a preview the cart's lines with no sums
/// (`DL-121`).
List<CheckoutItem> checkoutItemsOf({CheckoutPreview? preview, Cart? cart}) {
  final List<CartLine> cartLines = cart?.lines ?? const <CartLine>[];
  if (preview != null) {
    final Map<String, String?> images = <String, String?>{
      for (final CartLine line in cartLines) line.id: line.imageUrl,
    };
    return <CheckoutItem>[
      for (final PreviewLine line in preview.lines)
        CheckoutItem(
          id: line.cartItemId,
          nameUz: line.nameUz,
          nameRu: line.nameRu,
          unit: line.unit,
          quantity: line.quantity,
          priceMode: line.priceMode,
          imageUrl: images[line.cartItemId],
          lineTotalUzs: line.lineTotalUzs,
        ),
    ];
  }
  return <CheckoutItem>[
    for (final CartLine line in cartLines)
      CheckoutItem(
        id: line.id,
        nameUz: line.nameUz,
        nameRu: line.nameRu,
        unit: line.unit,
        quantity: line.quantity,
        priceMode: line.priceMode,
        imageUrl: line.imageUrl,
        lineTotalUzs: null,
      ),
  ];
}

/// "Товары · N": the pictures of the first four products, and under
/// «Показать состав» every product with its quantity and the server's sum.
/// While a sum is not known it is a grey bar, which pulses while [pending]
/// (`DL-121`).
class CheckoutItems extends StatefulWidget {
  const CheckoutItems({
    required this.items,
    required this.pending,
    required this.onChange,
    super.key,
  });

  /// The most pictures the strip shows.
  static const int shown = 4;

  final List<CheckoutItem> items;
  final bool pending;
  final VoidCallback onChange;

  @override
  State<CheckoutItems> createState() => _CheckoutItemsState();
}

class _CheckoutItemsState extends State<CheckoutItems> {
  bool _open = false;

  /// The list is built while it is open and while it folds away.
  bool _listBuilt = false;

  static const TextStyle _heading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: KitColors.ink,
  );

  static String _quantity(AppLocalizations l10n, CheckoutItem item) =>
      '${QuantityRules.display(item.quantity)} '
      '${CatalogLabels.unit(l10n, item.unit)}';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final List<CheckoutItem> items = widget.items;
    final bool still = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.checkoutItems(items.length),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _heading,
              ),
            ),
            const SizedBox(width: 8),
            CheckoutEditButton(
              buttonKey: 'checkout-items-change',
              label: l10n.editButton,
              onPressed: widget.onChange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final CheckoutItem item in items.take(CheckoutItems.shown))
              Semantics(
                image: true,
                label: '${item.name(language)}, ${_quantity(l10n, item)}',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: <Widget>[
                        _tile(ProductImage(url: item.imageUrl, size: 48)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _quantity(l10n, item),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: KitColors.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (items.length > CheckoutItems.shown)
              SizedBox(
                width: 64,
                child: _tile(
                  Text(
                    '+${items.length - CheckoutItems.shown}',
                    key: const ValueKey<String>('checkout-items-more'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey<String>('checkout-items-toggle'),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() {
              _open = !_open;
              _listBuilt = _listBuilt || _open;
            }),
            child: Semantics(
              expanded: _open,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      _open ? l10n.checkoutItemsHide : l10n.checkoutItemsShow,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: KitColors.primaryDark,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.ease,
                    child: const Icon(
                      Icons.expand_more,
                      size: 20,
                      color: KitColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Fold(
          shown: _open,
          onFolded: () => setState(() => _listBuilt = false),
          child: _listBuilt
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final CheckoutItem item in items)
                      _row(l10n, language, item),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _row(AppLocalizations l10n, AppLanguage language, CheckoutItem item) {
    final int? total = item.lineTotalUzs;
    final String? sum = total == null
        ? null
        : item.priceMode == PriceMode.estimate
        ? l10n.cartLineEstimate(MoneyFormat.uzs(total, language))
        : MoneyFormat.uzs(total, language);
    return DecoratedBox(
      key: ValueKey<String>('checkout-item-${item.id}'),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: ProductImage(url: item.imageUrl, size: 32),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name(language),
                    style: const TextStyle(fontSize: 14, color: KitColors.ink),
                  ),
                  Text(
                    _quantity(l10n, item),
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (sum != null)
              Text(
                sum,
                key: ValueKey<String>('checkout-item-${item.id}-sum'),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KitColors.ink,
                ),
              )
            else
              SkeletonBar(
                key: ValueKey<String>('checkout-item-${item.id}-pending'),
                width: 64,
                pulsing: widget.pending,
              ),
          ],
        ),
      ),
    );
  }

  static Widget _tile(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: KitColors.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: SizedBox.square(dimension: 64, child: Center(child: child)),
  );
}
