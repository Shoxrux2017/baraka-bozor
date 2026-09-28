import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/server_text.dart';
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
/// `allow_similar_substitution`. What the Customer set survives scrolling
/// out of the page. A product already in the cart is answered by opening
/// its line there — while this product's page is still the one shown.
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

class _AddToCartSectionState extends ConsumerState<AddToCartSection>
    with AutomaticKeepAliveClientMixin<AddToCartSection> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _note = TextEditingController();
  SubstitutionPolicy _policy = SubstitutionPolicy.allowSimilar;

  // The page is a lazy list: without this, scrolling the section out of
  // view would forget the quantity, the note and the rule.
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Whether this product's page is still the one the Customer sees.
  bool get _current => mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  Future<void> _add() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Kept before the wait: the snackbar may outlive this page.
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String note = trimLikeServer(_note.text);

    final Cart? answer = await ref
        .read(addToCartProvider(widget.productId).notifier)
        .add(
          NewCartLine(
            productId: widget.productId,
            quantity: QuantityRules.normalize(widget.unit, _quantity.text)!,
            customerNote: note.isEmpty ? null : note,
            substitutionPolicy: _policy,
          ),
        );
    if (!_current) {
      return;
    }
    if (answer != null) {
      // A new notice replaces the last rather than queueing behind it.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.cartAdded),
            // With an action a snackbar would otherwise stay until dismissed,
            // over the checkout's confirmation among others.
            persist: false,
            action: SnackBarAction(
              label: l10n.cartOpen,
              onPressed: () => router.push(CartPaths.cart),
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
        await router.push(CartPaths.line(line));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
