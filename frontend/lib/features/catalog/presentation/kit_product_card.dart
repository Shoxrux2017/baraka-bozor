import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/application/card_quantity.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/application/cart_quantity_queue.dart';
import '../../cart/domain/cart.dart';
import '../../cart/presentation/cart_feedback.dart';
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

  /// The drawn side of the add button and of the stepper's buttons: a compact
  /// card draws 32 inside its 44 tap square, a regular card draws all 44
  /// (`DL-117`).
  static double buttonSide(KitCardSize size) =>
      size == KitCardSize.compact ? 32 : tapSide;

  /// The side of every tap target of the card (`DL-117`).
  static const double tapSide = 44;

  /// The height of the bottom row: the tap square around the add button.
  static const double bottomRowHeight = tapSide;

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

class _KitProductCardState extends ConsumerState<KitProductCard>
    with SingleTickerProviderStateMixin {
  // One heart change at a time per card: a second tap while one is on its
  // way is ignored, so a double tap never sends two requests.
  bool _heartBusy = false;

  /// How far the stepper has grown out of the "+" square: 0 is the square,
  /// 1 the whole row. It grows in 260 ms and shrinks back in 220 ms
  /// (`DL-119`).
  late final AnimationController _reveal;
  late final Animation<double> _revealCurve;

  /// Whether the stepper, not the "+" row, is in the tree; it stays until the
  /// shrink ends.
  bool _stepperShown = false;

  /// The last quantity the card showed, kept while the stepper shrinks.
  String? _lastShown;

  @override
  void initState() {
    super.initState();
    _reveal =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 220),
        )..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.dismissed && _stepperShown) {
            setState(() => _stepperShown = false);
          }
        });
    _revealCurve = CurvedAnimation(
      parent: _reveal,
      curve: const Cubic(0.2, 0.8, 0.2, 1),
      reverseCurve: const Cubic(0.4, 0, 0.2, 1),
    );
    final CartLine? line = _lineOfCart();
    if (line != null) {
      _stepperShown = true;
      _reveal.value = 1;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  CartLine? _lineOfCart() => ref
      .read(currentCartProvider)
      .value
      ?.lines
      .where((CartLine l) => l.productId == widget.product.id)
      .firstOrNull;

  /// Moves the stepper toward [wanted]: it grows when there is a quantity to
  /// show and shrinks back when there is none. With reduced motion it is
  /// there or not at once.
  void _followQuantity({required bool wanted, required bool reduced}) {
    if (reduced) {
      _stepperShown = wanted;
      _reveal.stop();
      return;
    }
    if (wanted) {
      _stepperShown = true;
      if (_reveal.status != AnimationStatus.forward &&
          _reveal.status != AnimationStatus.completed) {
        _reveal.forward();
      }
    } else if (_stepperShown &&
        _reveal.status != AnimationStatus.reverse &&
        _reveal.status != AnimationStatus.dismissed) {
      _reveal.reverse();
    }
  }

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

  /// The quantity and its unit as a card says it.
  String _quantityText(AppLocalizations l10n, String quantity) =>
      '${QuantityRules.display(quantity)} '
      '${CatalogLabels.unit(l10n, widget.product.unitCode)}';

  /// The first "+": the quantity shows at once and the card says so by a
  /// light haptic and an announcement (`DL-119`).
  Future<void> _add() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String name = widget.product.name(interfaceLanguage(context));
    final Future<ApiFailure?> answer = ref
        .read(cartQuantityQueueProvider.notifier)
        .want(widget.product.id, '1');
    unawaited(HapticFeedback.lightImpact());
    announce(context, l10n.cartCardAdded(name, _quantityText(l10n, '1')));
    showCartFailure(messenger, l10n, await answer);
  }

  /// A step from the quantity the card shows; quick taps become one change
  /// in the queue. At the smallest quantity the minus removes the line.
  Future<void> _step(CartLine? line, String shown, {required bool up}) async {
    final UnitCode unit = widget.product.unitCode;
    final String? quantity = up
        ? CardQuantity.next(unit, shown)
        : CardQuantity.previous(unit, shown);
    final CartQuantityQueue queue = ref.read(
      cartQuantityQueueProvider.notifier,
    );
    if (quantity != null) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      showCartFailure(
        messenger,
        l10n,
        await queue.want(widget.product.id, quantity),
      );
      return;
    }
    if (line == null) {
      // The add is still on its way: nothing to put back yet.
      final AppLocalizations l10n = AppLocalizations.of(context);
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      showCartFailure(messenger, l10n, await queue.remove(widget.product.id));
      return;
    }
    await removeCartLine(
      context,
      ref,
      line: line,
      quantity: shown,
      name: widget.product.name(interfaceLanguage(context)),
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
    final String? shown = shownCartQuantity(
      ref.watch(cartQuantityQueueProvider),
      id,
      line,
    );
    _lastShown = shown ?? _lastShown;
    _followQuantity(
      wanted: shown != null,
      reduced: MediaQuery.disableAnimationsOf(context),
    );

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
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: KitCardType.padding,
                ),
                // Given an exact height, the bottom row is pinned to the
                // bottom.
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: constraints.hasTightHeight
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        children: <Widget>[
                          _sidePadded(
                            SizedBox(
                              height: imageHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: KitColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                            ),
                          ),
                          const SizedBox(height: KitCardType.gapAfterPicture),
                          _sidePadded(
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
                          ),
                          const SizedBox(height: KitCardType.gapAfterName),
                          _sidePadded(
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
                          ),
                          const SizedBox(height: KitCardType.gapAfterPrice),
                          if (constraints.hasTightHeight) const Spacer(),
                          _bottomRow(l10n, line, shown, unitSize),
                        ],
                      ),
                ),
              ),
              // The heart's glyph is 18 square, centred in a 44 tap box that
              // lies inside the card, 6 from its top and right edges, so the
              // glyph stays 19 from them (DL-117).
              Positioned(
                top: 6,
                right: 6,
                child: _Absorb(
                  child: SizedBox.square(
                    dimension: KitCardType.tapSide,
                    child: IconButton(
                      key: ValueKey<String>('heart-$id'),
                      tooltip: favorite
                          ? l10n.favoriteRemove
                          : l10n.favoriteAdd,
                      visualDensity: VisualDensity.standard,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: KitCardType.tapSide,
                        height: KitCardType.tapSide,
                      ),
                      iconSize: 18,
                      color: favorite ? KitColors.danger : KitColors.ink,
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      onPressed: _toggleHeart,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps a part of the card clear of its side edges; the compact bottom row
  /// is the one part that is not padded, so its 44 squares lie in the layout.
  static Widget _sidePadded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KitCardType.padding),
    child: child,
  );

  /// Where the picture sits in a well of [width] by [height]: centred, 0.7 of
  /// the shorter side. The heart's glyph is 18 square in a 44 square box 6
  /// from the card's top and right edges, so it spans 19 to 37 from them, 11
  /// to 29 from the top and the right edge of this well.
  /// When the picture would come within 2 of it, it moves down to 2 below the
  /// glyph; if it no longer fits the well that way, it moves left clear of the
  /// glyph instead; it shrinks only when neither keeps its size.
  static Rect _pictureRect(double width, double height) {
    const double glyphFar = 29;
    const double clearance = 2;
    final double full = math.max(0, 0.7 * math.min(height, width));
    double side = full;
    double top = (height - side) / 2;
    double left = (width - side) / 2;
    final double clearRight = width - glyphFar - clearance;
    final double clearBottom = glyphFar + clearance;
    if (left + side > clearRight && top < clearBottom) {
      if (clearBottom + side <= height) {
        top = clearBottom;
      } else if (clearRight - side >= 0) {
        left = clearRight - side;
      } else {
        top = clearBottom;
        side = math.max(0, height - top);
        left = (width - side) / 2;
      }
    }
    return Rect.fromLTWH(left, top, side, side);
  }

  /// The bottom row: the unit and the "+", the stepper in the cart, or "not
  /// sold". Taps on it never open the product. A regular card pads it like the
  /// rest; a compact card lets it span the card, so that each 44 square holds
  /// its 32 face 6 from the edge (`DL-117`) and lies inside the layout.
  Widget _bottomRow(
    AppLocalizations l10n,
    CartLine? line,
    String? shown,
    double unitSize,
  ) {
    final CatalogProduct product = widget.product;
    final String id = product.id;
    final double side = KitCardType.buttonSide(widget.size);
    final double iconSize = _compact ? 20 : 22;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    // While the stepper shrinks it keeps the last quantity it showed.
    final String? quantity = shown ?? _lastShown;
    final Widget row = SizedBox(
      height: KitCardType.bottomRowHeight,
      child: !widget.available
          ? _Unavailable(id: id, compact: _compact)
          : _stepperShown
          ? LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double full = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: _revealCurve,
                  builder: (BuildContext context, Widget? child) {
                    final double t = reduced ? 1 : _revealCurve.value;
                    return Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        key: ValueKey<String>('step-reveal-$id'),
                        width:
                            KitCardType.tapSide +
                            (full - KitCardType.tapSide) * t,
                        height: KitCardType.bottomRowHeight,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerRight,
                            minWidth: full,
                            maxWidth: full,
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: _Stepper(
                    id: id,
                    side: side,
                    iconSize: iconSize,
                    quantity: quantity == null
                        ? ''
                        : _quantityText(l10n, quantity),
                    isBin:
                        quantity != null &&
                        CardQuantity.previous(product.unitCode, quantity) ==
                            null,
                    minusLabel: l10n.cartStepMinus,
                    binLabel: l10n.cartRemoveLine,
                    plusLabel: l10n.cartStepPlus,
                    onMinus: () {
                      if (shown != null) {
                        _step(line, shown, up: false);
                      }
                    },
                    onPlus: () {
                      if (shown != null) {
                        _step(line, shown, up: true);
                      }
                    },
                  ),
                );
              },
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: _compact ? KitCardType.padding : 0,
                    ),
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
                ),
                _CardButton(
                  buttonKey: ValueKey<String>('add-$id'),
                  faceKey: ValueKey<String>('add-face-$id'),
                  side: side,
                  iconSize: iconSize,
                  icon: Icons.add,
                  label: l10n.catalogAdd,
                  onTap: _add,
                ),
              ],
            ),
    );
    return _Absorb(child: _compact ? row : _sidePadded(row));
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
  const _Unavailable({required this.id, required this.compact});

  final String id;

  /// A compact card's bottom row is not padded, so the label keeps clear of
  /// the card edge itself.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: compact ? KitCardType.padding : 0),
      child: Align(
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
    required this.isBin,
    required this.minusLabel,
    required this.binLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final String id;
  final double side;
  final double iconSize;
  final String quantity;

  /// Whether the minus is the red bin: the quantity is the smallest one.
  final bool isBin;
  final String minusLabel;
  final String binLabel;
  final String plusLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  Widget _button(
    Key key,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool bin = false,
  }) {
    return _CardButton(
      buttonKey: key,
      faceKey: ValueKey<String>('face-${(key as ValueKey<String>).value}'),
      side: side,
      iconSize: iconSize,
      icon: icon,
      label: label,
      bin: bin,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        isBin
            ? _button(
                ValueKey<String>('step-minus-$id'),
                Icons.delete_outline,
                binLabel,
                onMinus,
                bin: true,
              )
            : _button(
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

/// A green button of the card: a face of [side] drawn at the centre of a 44
/// square that takes the tap, so a compact card's 32 face has a 44 target
/// (`DL-117`). A [bin] is the red outlined one that removes the line
/// (`DL-119`).
class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.buttonKey,
    required this.faceKey,
    required this.side,
    required this.iconSize,
    required this.icon,
    required this.label,
    required this.onTap,
    this.bin = false,
  });

  final Key buttonKey;
  final Key faceKey;
  final double side;
  final double iconSize;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool bin;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: KitCardType.tapSide,
      child: IconButton(
        key: buttonKey,
        tooltip: label,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        // An [Ink] face, so the button's press highlight is painted over it.
        icon: Ink(
          key: faceKey,
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: bin ? Colors.white : KitColors.primary,
            borderRadius: BorderRadius.circular(10),
            border: bin
                ? Border.all(color: KitColors.danger, width: 1.5)
                : null,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: bin ? KitColors.danger : Colors.white,
          ),
        ),
      ),
    );
  }
}
