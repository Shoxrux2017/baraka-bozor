import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_paths.dart';

/// The way to the cart from the Customer's screens, with the number of its
/// lines (the kit's shopping bag with a green count). The count is the
/// signed-in Customer's own, never another account's, and is announced once,
/// in words. The count bumps when the cart grows (`DL-118`); [onBrand] draws
/// it for a green header: a white bag and a white count.
class CartButton extends ConsumerStatefulWidget {
  const CartButton({this.onBrand = false, super.key});

  final bool onBrand;

  @override
  ConsumerState<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends ConsumerState<CartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// To 1.3 at 40 % of the time and back, both with an ease-out.
  late final Animation<double> _scale = _bump.drive(
    TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.3,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
    ]),
  );

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  void _onCart(AsyncValue<Cart>? previous, AsyncValue<Cart> next) {
    final Cart? before = previous?.value;
    final Cart? after = next.value;
    if (before == null ||
        after == null ||
        !after.grewFrom(before) ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _bump.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Cart> cart = ref.watch(currentCartProvider);
    ref.listen<AsyncValue<Cart>>(currentCartProvider, _onCart);
    // The last count known for this account, a failed reload included.
    final int count = cart.value?.itemCount ?? 0;
    final bool onBrand = widget.onBrand;

    final Widget icon = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        Icon(
          Icons.shopping_bag_outlined,
          size: 26,
          color: onBrand ? Colors.white : KitColors.ink,
        ),
        if (count > 0)
          Positioned(
            top: onBrand ? 1 : -7,
            right: onBrand ? 1 : -9,
            child: ScaleTransition(
              key: const ValueKey<String>('cart-badge-bump'),
              scale: _scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: onBrand ? Colors.white : KitColors.primary,
                  borderRadius: BorderRadius.circular(onBrand ? 9 : 10),
                  border: onBrand
                      ? null
                      : Border.all(color: Colors.white, width: 2),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ExcludeSemantics(
                      child: Text(
                        '$count',
                        key: const ValueKey<String>('cart-count'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: onBrand ? KitColors.primaryDark : Colors.white,
                          fontSize: onBrand ? 11 : 10,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return IconButton(
      key: const ValueKey<String>('open-cart'),
      tooltip: l10n.cartBadge(count),
      style: onBrand
          ? IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      icon: icon,
      onPressed: () => context.push(CartPaths.cart),
    );
  }
}

/// The note to the Shopper: at most 300 characters, counted as the server
/// counts them — code points, not what the eye sees as one (`DL-30` (7)).
const int cartNoteMaxLength = 300;

/// What the Customer sets on a line — the quantity in its unit, a note to
/// the Shopper and what to do when the product is not there — as the
/// fields of a form its owner validates.
class LineOptionsFields extends StatelessWidget {
  const LineOptionsFields({
    required this.unit,
    required this.quantity,
    required this.note,
    required this.policy,
    required this.onPolicy,
    this.quantityFocus,
    this.noteFocus,
    super.key,
  });

  final UnitCode unit;
  final TextEditingController quantity;
  final TextEditingController note;
  final SubstitutionPolicy policy;
  final ValueChanged<SubstitutionPolicy> onPolicy;

  /// The fields' focus, for a form that takes the Customer to one to
  /// correct.
  final FocusNode? quantityFocus;
  final FocusNode? noteFocus;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        QuantityField(unit: unit, controller: quantity, focus: quantityFocus),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey<String>('line-note'),
          controller: note,
          focusNode: noteFocus,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.cartNote,
            border: const OutlineInputBorder(),
          ),
          validator: (String? text) =>
              trimLikeServer(text ?? '').runes.length > cartNoteMaxLength
              ? l10n.fieldTooLong(cartNoteMaxLength)
              : null,
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            l10n.cartSubstitution,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        // A radio for each rule, so a long rule wraps rather than being cut.
        RadioGroup<SubstitutionPolicy>(
          groupValue: policy,
          onChanged: (SubstitutionPolicy? option) {
            if (option != null) {
              onPolicy(option);
            }
          },
          child: Column(
            key: const ValueKey<String>('line-substitution'),
            children: <Widget>[
              for (final SubstitutionPolicy option in SubstitutionPolicy.values)
                RadioListTile<SubstitutionPolicy>(
                  key: ValueKey<String>('substitution-${option.code}'),
                  value: option,
                  contentPadding: EdgeInsets.zero,
                  title: Text(OrderLabels.substitution(l10n, option)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A quantity in [unit]: a decimal field for a unit that takes a fraction,
/// a field between a minus and a plus for one that does not
/// (`tasks/WAVE_2.md` W2-12). The text is the quantity; it is never read
/// as a floating-point number.
class QuantityField extends StatelessWidget {
  const QuantityField({
    required this.unit,
    required this.controller,
    this.focus,
    super.key,
  });

  final UnitCode unit;
  final TextEditingController controller;
  final FocusNode? focus;

  void _step(int delta) {
    final int current = int.tryParse(controller.text.trim()) ?? 0;
    final int next = (current + delta).clamp(1, QuantityRules.maxWhole);
    controller.text = '$next';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool fraction = unit.takesFraction;

    final Widget field = TextFormField(
      key: const ValueKey<String>('line-quantity'),
      controller: controller,
      focusNode: focus,
      keyboardType: TextInputType.numberWithOptions(decimal: fraction),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          RegExp(fraction ? r'[0-9.,]' : '[0-9]'),
        ),
        LengthLimitingTextInputFormatter(fraction ? 8 : 4),
      ],
      decoration: InputDecoration(
        labelText: l10n.cartQuantity,
        suffixText: CatalogLabels.unit(l10n, unit),
        border: const OutlineInputBorder(),
      ),
      validator: (String? text) =>
          QuantityRules.normalize(unit, text ?? '') != null
          ? null
          : fraction
          ? l10n.cartQuantityFraction
          : l10n.cartQuantityWhole,
    );

    if (fraction) {
      return field;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        IconButton(
          key: const ValueKey<String>('quantity-decrease'),
          tooltip: l10n.cartDecrease,
          icon: const Icon(Icons.remove),
          onPressed: () => _step(-1),
        ),
        Expanded(child: field),
        IconButton(
          key: const ValueKey<String>('quantity-increase'),
          tooltip: l10n.cartIncrease,
          icon: const Icon(Icons.add),
          onPressed: () => _step(1),
        ),
      ],
    );
  }
}

/// A line's quantity as its editor starts it: as the person reads it, or
/// empty when the line's product has since become a whole unit and the
/// quantity kept its decimals — the Customer sets it anew rather than
/// editing a number the field would read differently.
String editableQuantity(UnitCode unit, String quantity) =>
    QuantityRules.normalize(unit, quantity) == null
    ? ''
    : QuantityRules.display(quantity);
