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

/// The type of one card size: font sizes and the name's line height, in
/// logical pixels before the text scale. The card and [kitCardExtent] share
/// them, so the height asked for always matches the text drawn.
class KitCardType {
  const KitCardType._(
    this.nameSize,
    this.nameHeight,
    this.priceSize,
    this.unitSize,
  );

  final double nameSize;
  final double nameHeight;
  final double priceSize;
  final double unitSize;

  static const KitCardType compact = KitCardType._(12, 17, 13, 11);
  static const KitCardType regular = KitCardType._(13, 20, 15, 12);

  static KitCardType of(KitCardSize size) =>
      size == KitCardSize.compact ? compact : regular;

  /// The side of the add button and of the stepper's buttons.
  static double buttonSide(KitCardSize size) =>
      size == KitCardSize.compact ? 32 : 36;

  /// The height of the bottom row: the tap area around the add button.
  static const double bottomRowHeight = 40;

  /// The card's padding and the gaps between its parts; [kitCardExtent]
  /// adds them up.
  static const double padding = 8;
  static const double gapAfterPicture = 8;
  static const double gapAfterName = 4;
  static const double gapAfterPrice = 8;

  /// The price line's height as a multiple of its font size.
  static const double priceLineHeight = 1.25;
}

/// A product in a Customer list (`DL-80`, `DL-81`): picture, heart, name, the
/// approximate price, and a bottom row with the unit at the left and a green
/// "+" at the right — one tap adds one unit — which, once the product is in
/// the cart, becomes the quantity stepper.
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
    final CatalogProduct product = widget.product;
    final bool current = favoriteOf(
      ref.read(favoriteOverridesProvider),
      product,
    );
    setState(() => _heartBusy = true);
    final ApiFailure? failure = await ref
        .read(favoriteOverridesProvider.notifier)
        .change(product.id, current: current);
    if (mounted) {
      setState(() => _heartBusy = false);
    }
    if (failure != null) {
      final String text =
          failure is ApiRefusal && failure.code == 'favorites_full'
          ? l10n.favoritesFull
          : l10n.favoriteFailed;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
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
    if (!mounted) {
      return;
    }
    setState(() => _cartBusy = false);
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

  Future<void> _add() {
    // Taken before the wait: the card may show another product by then.
    final String productId = widget.product.id;
    return _change(
      () => ref
          .read(addToCartProvider(productId).notifier)
          .add(
            NewCartLine(
              productId: productId,
              quantity: '1',
              customerNote: null,
              substitutionPolicy: SubstitutionPolicy.allowSimilar,
            ),
          ),
      () => ref.read(addToCartProvider(productId)),
    );
  }

  Future<void> _step(CartLine line, {required bool up}) {
    final UnitCode unit = widget.product.unitCode;
    final String? quantity = up
        ? CardQuantity.next(unit, line.quantity)
        : CardQuantity.previous(unit, line.quantity);
    if (quantity == null) {
      return _change(
        () => ref.read(cartLineProvider(line.id).notifier).remove(),
        () => ref.read(cartLineProvider(line.id)),
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
    final KitCardType type = KitCardType.of(widget.size);
    final double nameSize = type.nameSize;
    final double nameHeight = type.nameHeight;
    final double priceSize = type.priceSize;
    final double unitSize = type.unitSize;
    // A favourite no longer sold is greyed (`DL-78` (5)).
    final bool available = widget.available;
    final Color textColor = available ? KitColors.ink : KitColors.muted;

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
            padding: const EdgeInsets.all(KitCardType.padding),
            // Given an exact height, the bottom row is pinned to the bottom.
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: constraints.hasTightHeight
                        ? MainAxisSize.max
                        : MainAxisSize.min,
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
                                      ) {
                                        final Rect rect = _pictureRect(
                                          constraints.maxWidth,
                                          imageHeight,
                                        );
                                        return Stack(
                                          children: <Widget>[
                                            Positioned.fromRect(
                                              rect: rect,
                                              child: Opacity(
                                                key: ValueKey<String>(
                                                  'picture-$id',
                                                ),
                                                opacity: available ? 1 : 0.45,
                                                child: ProductImage(
                                                  url: product.imageUrl,
                                                  size: rect.width,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _Absorb(
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
                                    color: favorite
                                        ? KitColors.danger
                                        : KitColors.ink,
                                    icon: Icon(
                                      favorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                    onPressed: _toggleHeart,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: KitCardType.gapAfterPicture),
                      Text(
                        product.name(language),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: nameSize,
                          height: nameHeight / nameSize,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: KitCardType.gapAfterName),
                      Text(
                        l10n.catalogApproxPrice(
                          MoneyFormat.uzs(
                            product.customerUnitPriceUzs,
                            language,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: priceSize,
                          height: KitCardType.priceLineHeight,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: KitCardType.gapAfterPrice),
                      if (constraints.hasTightHeight) const Spacer(),
                      _bottomRow(l10n, line, unitSize),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }

  /// Where the picture sits in a well of [width] by [height]: centred, 0.7 of
  /// the shorter side. When that would reach the heart's box at the top right
  /// (the 32 square button in its 40 square tap target), it moves down to 2
  /// below the box, and shrinks only if the well is too short for that.
  static Rect _pictureRect(double width, double height) {
    const double heart = 40;
    const double clearance = 2;
    double side = math.max(0, 0.7 * math.min(height, width));
    double top = (height - side) / 2;
    final double left = (width - side) / 2;
    if (left + side > width - heart && top < heart) {
      top = heart + clearance;
      if (top + side > height) {
        side = math.max(0, height - top);
      }
    }
    return Rect.fromLTWH((width - side) / 2, top, side, side);
  }

  /// The bottom row: the unit and the "+", the stepper in the cart, or "not
  /// sold". Taps on it never open the product.
  Widget _bottomRow(AppLocalizations l10n, CartLine? line, double unitSize) {
    final CatalogProduct product = widget.product;
    final String id = product.id;
    final double side = KitCardType.buttonSide(widget.size);
    final double iconSize = _compact ? 20 : 22;
    return _Absorb(
      child: SizedBox(
        height: KitCardType.bottomRowHeight,
        child: !widget.available
            ? _Unavailable(id: id)
            : line != null
            ? _Stepper(
                id: id,
                side: side,
                iconSize: iconSize,
                quantity:
                    '${QuantityRules.display(line.quantity)} '
                    '${CatalogLabels.unit(l10n, product.unitCode)}',
                busy: _cartBusy,
                minusLabel: l10n.cartStepMinus,
                plusLabel: l10n.cartStepPlus,
                onMinus: () => _step(line, up: false),
                onPlus: () => _step(line, up: true),
              )
            : Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.catalogPerUnit(
                        CatalogLabels.unit(l10n, product.unitCode),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: unitSize,
                        color: KitColors.muted,
                      ),
                    ),
                  ),
                  // The tap area is the whole 40-square slot, the visible
                  // button the smaller square inside it.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: _cartBusy ? () {} : _add,
                    child: SizedBox.square(
                      dimension: KitCardType.bottomRowHeight,
                      child: Center(
                        child: SizedBox.square(
                          dimension: side,
                          child: IconButton(
                            key: ValueKey<String>('add-$id'),
                            tooltip: l10n.catalogAdd,
                            padding: EdgeInsets.zero,
                            iconSize: iconSize,
                            style: IconButton.styleFrom(
                              backgroundColor: KitColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: KitColors.primarySoft,
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            onPressed: _cartBusy ? null : _add,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Takes the taps on a control, enabled or not, so that a tap on a disabled
/// one never reaches the card and opens the product.
class _Absorb extends StatelessWidget {
  const _Absorb({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTap: () {},
    child: child,
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          AppLocalizations.of(context).catalogUnavailable,
          key: ValueKey<String>('unavailable-$id'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: KitColors.muted,
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.id,
    required this.side,
    required this.iconSize,
    required this.quantity,
    required this.busy,
    required this.minusLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final String id;
  final double side;
  final double iconSize;
  final String quantity;
  final bool busy;
  final String minusLabel;
  final String plusLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  Widget _button(Key key, IconData icon, String label, VoidCallback onTap) {
    return SizedBox.square(
      dimension: side,
      child: IconButton(
        key: key,
        tooltip: label,
        padding: EdgeInsets.zero,
        iconSize: iconSize,
        style: IconButton.styleFrom(
          backgroundColor: KitColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: KitColors.primarySoft,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
