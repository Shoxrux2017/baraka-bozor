import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_paths.dart';

/// The way to the cart from the Customer's screens, with the number of its
/// lines. The count is the signed-in Customer's own, never another
/// account's, and is announced once, in words.
class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Cart> cart = ref.watch(currentCartProvider);
    final int count = cart.hasError ? 0 : cart.value?.itemCount ?? 0;

    return IconButton(
      key: const ValueKey<String>('open-cart'),
      tooltip: l10n.cartBadge(count),
      icon: Badge(
        isLabelVisible: count > 0,
        label: ExcludeSemantics(
          child: Text('$count', key: const ValueKey<String>('cart-count')),
        ),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
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
    super.key,
  });

  final UnitCode unit;
  final TextEditingController quantity;
  final TextEditingController note;
  final SubstitutionPolicy policy;
  final ValueChanged<SubstitutionPolicy> onPolicy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        QuantityField(unit: unit, controller: quantity),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey<String>('line-note'),
          controller: note,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.cartNote,
            border: const OutlineInputBorder(),
          ),
          validator: (String? text) =>
              (text ?? '').trim().runes.length > cartNoteMaxLength
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
    super.key,
  });

  final UnitCode unit;
  final TextEditingController controller;

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
