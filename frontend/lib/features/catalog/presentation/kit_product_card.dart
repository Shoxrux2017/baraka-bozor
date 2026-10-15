import 'dart:math' as math;

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
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/application/card_quantity.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/domain/cart.dart';
import '../../favorites/application/favorites_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';

/// The two sizes of the kit card: the rail grid's and everything else's.
enum KitCardSize { compact, regular }

/// A product in a Customer list (`DL-80`): picture, heart, name, the
/// approximate price with its unit, and either "Добавить" — one tap adds one
/// unit — or, once the product is in the cart, the quantity stepper.
class KitProductCard extends ConsumerStatefulWidget {
  const KitProductCard({
    required this.product,
    this.size = KitCardSize.regular,
    this.imageHeight,
    this.available = true,
    super.key,
  });

  final CatalogProduct product;
  final KitCardSize size;

  /// The height of the picture well; the size's own when `null`.
  final double? imageHeight;

  /// Whether the product can be bought now: a favourite that stopped being
  /// sold shows "not sold" instead of the add button.
  final bool available;

  @override
  ConsumerState<KitProductCard> createState() => _KitProductCardState();
}

class _KitProductCardState extends ConsumerState<KitProductCard> {
  // One change at a time per card: a second tap while one is on its way is
  // ignored, so a double tap never sends two requests.
  bool _heartBusy = false;
  bool _cartBusy = false;

  bool get _compact => widget.size == KitCardSize.compact;

  Future<void> _toggleHeart() async {
    if (_heartBusy) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool current = isFavorite(ref, widget.product);
    setState(() => _heartBusy = true);
    final bool saved = await ref
        .read(favoriteOverridesProvider.notifier)
        .toggle(widget.product.id, current: current);
    if (mounted) {
      setState(() => _heartBusy = false);
    }
    if (!saved) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.favoriteFailed)));
    }
  }

  /// Runs one cart change of this card; a failure other than "already in the
  /// cart" — which the refreshed cart answers by showing the stepper — is
  /// said in a snackbar.
  Future<void> _change(
    Future<Cart?> Function() change,
    MutationState Function() outcome,
  ) async {
    if (_cartBusy) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _cartBusy = true);
    final Cart? answer = await change();
    if (mounted) {
      setState(() => _cartBusy = false);
    }
    if (answer != null) {
      return;
    }
    final ApiFailure? failure = outcome().failure;
    if (failure == null ||
        (failure is ApiRefusal && failure.code == 'cart_item_already_exists')) {
      return;
    }
    final String? text = failureText(l10n, failure);
    if (text != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _add() => _change(
    () => ref
        .read(addToCartProvider(widget.product.id).notifier)
        .add(
          NewCartLine(
            productId: widget.product.id,
            quantity: '1',
            customerNote: null,
            substitutionPolicy: SubstitutionPolicy.allowSimilar,
          ),
        ),
    () => ref.read(addToCartProvider(widget.product.id)),
  );

  Future<void> _step(CartLine line, {required bool up}) {
    final UnitCode unit = widget.product.unitCode;
    final String? quantity = up
        ? CardQuantity.next(unit, line.quantity)
        : CardQuantity.previous(unit, line.quantity);
    if (quantity == null) {
      return _change(
        () => ref.read(cartListActionsProvider.notifier).remove(line.id),
        () => ref.read(cartListActionsProvider),
      );
    }
    final CartLinePatch patch = CartLinePatch.between(
      line,
      quantity: quantity,
      customerNote: line.customerNote,
      substitutionPolicy: line.substitutionPolicy,
    );
    if (patch.isEmpty) {
      return Future<void>.value();
    }
    return _change(
      () => ref.read(cartLineProvider(line.id).notifier).change(patch),
      () => ref.read(cartLineProvider(line.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CatalogProduct product = widget.product;
    final String id = product.id;
    final bool favorite = isFavorite(ref, product);
    final CartLine? line = ref
        .watch(currentCartProvider)
        .value
        ?.lines
        .where((CartLine l) => l.productId == id)
        .firstOrNull;

    final double imageHeight = widget.imageHeight ?? (_compact ? 84.0 : 112.0);
    final double nameSize = _compact ? 12 : 13;
    final double nameHeight = _compact ? 17 : 20;
    final double priceSize = _compact ? 13 : 15;
    final double unitSize = _compact ? 11 : 12;

    return Material(
      key: ValueKey<String>('product-card-$id'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0F151D16),
              offset: Offset(0, 2),
              blurRadius: 12,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(CatalogPaths.product(id)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: imageHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder:
                                (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) => Center(
                                  child: ProductImage(
                                    url: product.imageUrl,
                                    size: math.max(
                                      0,
                                      math.min(
                                        imageHeight - 8,
                                        constraints.maxWidth - 8,
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            key: ValueKey<String>('heart-$id'),
                            tooltip: favorite
                                ? l10n.favoriteRemove
                                : l10n.favoriteAdd,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            iconSize: 18,
                            color: favorite ? KitColors.danger : KitColors.ink,
                            icon: Icon(
                              favorite ? Icons.favorite : Icons.favorite_border,
                            ),
                            onPressed: _toggleHeart,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: nameSize,
                    height: nameHeight / nameSize,
                    fontWeight: FontWeight.w500,
                    color: KitColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.catalogApproxPrice(
                    MoneyFormat.uzs(product.customerUnitPriceUzs, language),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: priceSize,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
                Text(
                  l10n.catalogPerUnit(
                    CatalogLabels.unit(l10n, product.unitCode),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: unitSize, color: KitColors.muted),
                ),
                const SizedBox(height: 8),
                if (!widget.available)
                  _Unavailable(id: id, height: _compact ? 32 : 38)
                else if (line != null)
                  _Stepper(
                    id: id,
                    height: _compact ? 32 : 38,
                    quantity:
                        '${QuantityRules.display(line.quantity)}\u00A0'
                        '${CatalogLabels.unit(l10n, product.unitCode)}',
                    busy: _cartBusy,
                    minusLabel: l10n.cartStepMinus,
                    plusLabel: l10n.cartStepPlus,
                    onMinus: () => _step(line, up: false),
                    onPlus: () => _step(line, up: true),
                  )
                else
                  SizedBox(
                    height: _compact ? 32 : 38,
                    child: FilledButton(
                      key: ValueKey<String>('add-$id'),
                      style: FilledButton.styleFrom(
                        backgroundColor: KitColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _cartBusy ? null : _add,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.catalogAdd,
                          style: TextStyle(
                            fontSize: _compact ? 12 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.id, required this.height});

  final String id;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<String>('unavailable-$id'),
      height: height,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            AppLocalizations.of(context).catalogUnavailable,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: KitColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.id,
    required this.height,
    required this.quantity,
    required this.busy,
    required this.minusLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final String id;
  final double height;
  final String quantity;
  final bool busy;
  final String minusLabel;
  final String plusLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  Widget _button(Key key, IconData icon, String label, VoidCallback onTap) {
    return SizedBox.square(
      dimension: height,
      child: IconButton(
        key: key,
        tooltip: label,
        padding: EdgeInsets.zero,
        iconSize: 18,
        style: IconButton.styleFrom(
          backgroundColor: KitColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: KitColors.primarySoft,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(icon),
        onPressed: busy ? null : onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _button(
          ValueKey<String>('step-minus-$id'),
          Icons.remove,
          minusLabel,
          onMinus,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                quantity,
                key: ValueKey<String>('step-qty-$id'),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KitColors.ink,
                ),
              ),
            ),
          ),
        ),
        _button(
          ValueKey<String>('step-plus-$id'),
          Icons.add,
          plusLabel,
          onPlus,
        ),
      ],
    );
  }
}
