import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_paths.dart';
import 'cart_widgets.dart';

/// "Add to cart" on a product's screen (`docs/09` section 17): the quantity
/// in the product's unit, a note and the substitution rule, which starts at
/// `allow_similar_substitution`. A product already in the cart is answered
/// by opening its line there.
class AddToCartSection extends ConsumerStatefulWidget {
  const AddToCartSection({
    required this.productId,
    required this.unit,
    super.key,
  });

  final String productId;
  final UnitCode unit;

  @override
  ConsumerState<AddToCartSection> createState() => _AddToCartSectionState();
}

class _AddToCartSectionState extends ConsumerState<AddToCartSection> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _note = TextEditingController();
  SubstitutionPolicy _policy = SubstitutionPolicy.allowSimilar;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String note = _note.text.trim();
    final AddToCartController cart = ref.read(
      addToCartProvider(widget.productId).notifier,
    );

    final Cart? answer = await cart.add(
      NewCartLine(
        productId: widget.productId,
        quantity: QuantityRules.normalize(widget.unit, _quantity.text)!,
        customerNote: note.isEmpty ? null : note,
        substitutionPolicy: _policy,
      ),
    );
    if (!mounted) {
      return;
    }
    if (answer != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cartAdded),
          action: SnackBarAction(
            label: l10n.cartOpen,
            onPressed: () => context.push(CartPaths.cart),
          ),
        ),
      );
      return;
    }
    final ApiFailure? failure = ref
        .read(addToCartProvider(widget.productId))
        .failure;
    if (failure is ApiRefusal && failure.code == 'cart_item_already_exists') {
      final Object? line = failure.error.details['cart_item_id'];
      if (line is String) {
        await context.push(CartPaths.line(line));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(addToCartProvider(widget.productId));

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LineOptionsFields(
            unit: widget.unit,
            quantity: _quantity,
            note: _note,
            policy: _policy,
            onPolicy: (SubstitutionPolicy policy) =>
                setState(() => _policy = policy),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey<String>('add-to-cart'),
            icon: state.isBusy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.cartSaving,
                    ),
                  )
                : const Icon(Icons.add_shopping_cart),
            label: Text(l10n.cartAdd),
            onPressed: state.isBusy ? null : _add,
          ),
          FailureMessage(state.failure),
        ],
      ),
    );
  }
}
