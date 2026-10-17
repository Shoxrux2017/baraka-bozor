import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/unconfirmed_order.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_line_tile.dart';

/// The Customer's cart (`docs/09` section 17): every line with its quantity,
/// current price and estimate, stepped in place, a line no longer sold marked
/// and removable only, and the estimate of the subtotal as the server
/// computed it (`DL-37` (19), (20)). A line opens its product, where its rule
/// and note are changed.
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: l10n.cartTitle),
      body: SafeArea(
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
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      for (final CartLine line in cart.lines)
                        CartLineTile(
                          key: ValueKey<String>(line.id),
                          line: line,
                        ),
                      if (cart.lines.any((CartLine line) => !line.isAvailable))
                        const _UnavailableHint(),
                      const SizedBox(height: 16),
                      Text(
                        l10n.cartSubtotal(
                          MoneyFormat.uzs(
                            cart.estimatedSubtotalUzs,
                            interfaceLanguage(context),
                          ),
                        ),
                        key: const ValueKey<String>('cart-subtotal'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      // A line no longer sold must go first; the server
                      // would refuse it (`docs/09` section 18).
                      FilledButton(
                        key: const ValueKey<String>('go-to-checkout'),
                        onPressed:
                            cart.lines.every(
                              (CartLine line) => line.isAvailable,
                            )
                            ? () {
                                // The "added" notices stay behind, queued
                                // ones too.
                                ScaffoldMessenger.of(context).clearSnackBars();
                                context.push(AppPaths.customerCheckout);
                              }
                            : null,
                        child: Text(l10n.checkoutGo),
                      ),
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
