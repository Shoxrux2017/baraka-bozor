import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/orders/unconfirmed_order.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/product_image.dart';
import '../application/cart_controllers.dart';
import '../domain/cart.dart';
import 'cart_widgets.dart';

/// The Customer's cart (`docs/09` section 17): every line with its quantity,
/// current price and estimate, a line no longer sold marked and removable
/// only, and the estimate of the subtotal as the server computed it
/// (`DL-37` (19), (20)). A line opens its editor; [openLineId] opens one at
/// once, as a duplicate "add to cart" asks.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({this.openLineId, super.key});

  final String? openLineId;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _opened = false;

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

  Future<void> _edit(CartLine line) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Only its own buttons and the back gesture close it, and not while its
    // change runs.
    enableDrag: false,
    builder: (BuildContext context) => _LineEditor(line: line),
  );

  /// Opens the line [CartScreen.openLineId] names, once, when it is there.
  void _openAsked(Cart cart) {
    final String? id = widget.openLineId;
    if (_opened || id == null) {
      return;
    }
    final CartLine? line = cart.line(id);
    if (line == null || !line.isAvailable) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _edit(line);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Cart> cart = ref.watch(currentCartProvider);
    final MutationState actions = ref.watch(cartListActionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartTitle)),
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
                  _openAsked(cart);
                  if (cart.lines.isEmpty) {
                    return Center(
                      key: const ValueKey<String>('cart-empty'),
                      child: Text(l10n.cartEmpty),
                    );
                  }
                  return ListView(
                    key: const ValueKey<String>('cart-lines'),
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      for (final CartLine line in cart.lines)
                        _LineTile(
                          line: line,
                          busy: actions.isBusy,
                          onEdit: () => _edit(line),
                        ),
                      FailureMessage(actions.failure),
                      if (cart.lines.any((CartLine line) => !line.isAvailable))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(l10n.cartUnavailableHint),
                        ),
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
                            ? () => context.push(AppPaths.customerCheckout)
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

class _LineTile extends ConsumerWidget {
  const _LineTile({
    required this.line,
    required this.busy,
    required this.onEdit,
  });

  final CartLine line;
  final bool busy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final int? price = line.customerUnitPriceUzs;
    final int? total = line.estimatedLineTotalUzs;
    final String? note = line.customerNote;

    return Card(
      child: ListTile(
        key: ValueKey<String>('cart-line-${line.id}'),
        leading: ProductImage(url: line.imageUrl, size: 48),
        title: Text(line.name(language)),
        subtitle: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: <Widget>[
            Text('${QuantityRules.display(line.quantity)} $unit'),
            if (price != null && total != null) ...<Widget>[
              Text(
                l10n.catalogPricePerUnit(
                  MoneyFormat.uzs(price, language),
                  unit,
                ),
              ),
              Text(
                line.priceMode == PriceMode.estimate
                    ? l10n.cartLineEstimate(MoneyFormat.uzs(total, language))
                    : MoneyFormat.uzs(total, language),
              ),
            ] else
              Text(
                l10n.cartLineUnavailable,
                key: ValueKey<String>('cart-line-unavailable-${line.id}'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Text(OrderLabels.substitution(l10n, line.substitutionPolicy)),
            if (note != null) Text(note),
          ],
        ),
        onTap: line.isAvailable ? onEdit : null,
        trailing: IconButton(
          key: ValueKey<String>('remove-line-${line.id}'),
          tooltip: l10n.cartRemoveLine,
          icon: const Icon(Icons.delete_outline),
          onPressed: busy
              ? null
              : () =>
                    ref.read(cartListActionsProvider.notifier).remove(line.id),
        ),
      ),
    );
  }
}

/// The editor of one line: its quantity, note and rule. What did not
/// change is not sent, and a save that changes nothing sends nothing
/// (`DL-28` (9)); the sheet stays while the change runs and closes with its
/// answer.
class _LineEditor extends ConsumerStatefulWidget {
  const _LineEditor({required this.line});

  final CartLine line;

  @override
  ConsumerState<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends ConsumerState<_LineEditor> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _quantity = TextEditingController(
    text: editableQuantity(widget.line.unit, widget.line.quantity),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.line.customerNote ?? '',
  );
  late SubstitutionPolicy _policy = widget.line.substitutionPolicy;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final String note = trimLikeServer(_note.text);
    final CartLinePatch patch = CartLinePatch.between(
      widget.line,
      quantity: QuantityRules.normalize(widget.line.unit, _quantity.text)!,
      customerNote: note.isEmpty ? null : note,
      substitutionPolicy: _policy,
    );
    if (patch.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final Cart? answer = await ref
        .read(cartLineProvider(widget.line.id).notifier)
        .change(patch);
    if (answer != null && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState state = ref.watch(cartLineProvider(widget.line.id));

    return PopScope(
      canPop: !state.isBusy,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              key: const ValueKey<String>('line-editor'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.line.name(interfaceLanguage(context)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                LineOptionsFields(
                  unit: widget.line.unit,
                  quantity: _quantity,
                  note: _note,
                  policy: _policy,
                  onPolicy: (SubstitutionPolicy policy) =>
                      setState(() => _policy = policy),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey<String>('save-line'),
                  onPressed: state.isBusy ? null : _save,
                  child: state.isBusy
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: l10n.cartSaving,
                          ),
                        )
                      : Text(l10n.saveButton),
                ),
                FailureMessage(state.failure),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
