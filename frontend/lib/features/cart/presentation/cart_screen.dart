import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/orders/unconfirmed_order.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../catalog/presentation/recommended_row.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_address_card.dart';
import 'cart_footer.dart';
import 'cart_line_tile.dart';
import 'cart_minimum_notice.dart';
import 'cart_summary.dart';

/// The Customer's cart (`docs/09` section 17): every line with its quantity,
/// current price and estimate, stepped in place, a line no longer sold marked
/// and removable only, what is missing to the minimum order, the recommended
/// products not yet in it, the amounts and the delivery address as the server
/// computed them (`DL-37` (19), (20)). A line opens its product, where its
/// rule and note are changed.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Prices and availability change: the cart is asked for again whenever
    // the Customer opens it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    final String? customer = ref.read(customerAccountProvider);
    if (customer != null) {
      await ref.read(cartProvider(customer).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Cart> cart = ref.watch(currentCartProvider);

    // The footer is the Scaffold's own bottom bar, so a notice rises above it
    // instead of covering the button.
    final Cart? loaded = cart.hasError ? null : cart.value;
    final bool hasFooter = loaded != null && loaded.lines.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: l10n.cartTitle),
      bottomNavigationBar: hasFooter
          ? SafeArea(top: false, child: CartFooter(cart: loaded))
          : null,
      body: SafeArea(
        bottom: !hasFooter,
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            if (ref.watch(unconfirmedOrderProvider))
              MaterialBanner(
                key: const ValueKey<String>('cart-unconfirmed-order'),
                content: Text(l10n.cartUnconfirmedOrder),
                actions: <Widget>[
                  TextButton(
                    key: const ValueKey<String>('cart-check-unconfirmed'),
                    onPressed: () => context.push(AppPaths.customerCheckout),
                    child: Text(l10n.cartCheckUnconfirmed),
                  ),
                ],
              ),
            Expanded(
              child: cart.when(
                skipLoadingOnRefresh: !cart.hasError,
                data: (Cart cart) {
                  if (cart.lines.isEmpty) {
                    return const _EmptyCart();
                  }
                  return ListView(
                    key: const ValueKey<String>('cart-lines'),
                    padding: const EdgeInsets.only(top: 16),
                    children: <Widget>[
                      for (final CartLine line in cart.lines)
                        // The key sits on the list's own child, so a line that
                        // leaves does not hand its State to the next one.
                        Padding(
                          key: ValueKey<String>(line.id),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: CartLineTile(line: line),
                        ),
                      if (cart.hasUnavailable)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: _UnavailableHint(),
                        ),
                      CartMinimumNotice(cart: cart),
                      RecommendedRow(
                        title: l10n.cartAddMoreTitle,
                        excludedProductIds: <String>{
                          for (final CartLine line in cart.lines)
                            line.productId,
                        },
                        showAll: false,
                        rowKey: 'cart-add-more',
                      ),
                      const SizedBox(height: 8),
                      CartSummary(cart: cart),
                      const CartAddressCard(),
                    ],
                  );
                },
                error: (Object error, StackTrace _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadFailure(error: error, onRetry: _refresh),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cart with nothing in it (drawing 19а).
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      key: const ValueKey<String>('cart-empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.primaryWash,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 96,
                child: Icon(
                  Icons.shopping_basket_outlined,
                  size: 44,
                  color: KitColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.cartEmptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cartEmptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: KitColors.muted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey<String>('cart-to-catalog'),
              style: FilledButton.styleFrom(
                backgroundColor: KitColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 54),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.go(AppPaths.customer),
              child: Text(
                l10n.productGoneAction,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why a line no longer sold must go before the order can be placed.
class _UnavailableHint extends StatelessWidget {
  const _UnavailableHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 18,
                color: KitColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).cartUnavailableHint,
                  style: const TextStyle(fontSize: 13, color: KitColors.ink2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
