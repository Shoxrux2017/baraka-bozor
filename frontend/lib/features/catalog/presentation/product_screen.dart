import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/failure_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/domain/cart.dart';
import '../../cart/presentation/cart_paths.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../favorites/application/favorites_controllers.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'more_in_category.dart';
import 'product_bar.dart';

/// One product (drawing 18): its picture, name, approximate price and what an
/// estimate means, its description, the rule for when it is missing and a
/// note to the Shopper, more of its category, and a bottom bar with the
/// stepper and "В корзину". A product that can no longer be seen shows that
/// it is gone (drawing 18b).
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();
  String _quantity = '1';
  SubstitutionPolicy _policy = SubstitutionPolicy.allowSimilar;
  bool _heartBusy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Whether this product's page is still the one the Customer sees.
  bool get _current => mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  Future<void> _toggleHeart(CatalogProduct product) async {
    if (_heartBusy) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
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

  Future<void> _add(CatalogProduct product) async {
    if (!_form.currentState!.validate()) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Kept before the wait: the snackbar may outlive this page.
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String note = trimLikeServer(_note.text);

    final Cart? answer = await ref
        .read(addToCartProvider(product.id).notifier)
        .add(
          NewCartLine(
            productId: product.id,
            quantity: _quantity,
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
    final ApiFailure? failure = ref.read(addToCartProvider(product.id)).failure;
    // A product already in the cart has been answered by the refreshed cart:
    // no second line is made.
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CatalogProduct> product = ref.watch(
      catalogProductProvider(widget.productId),
    );
    final CatalogProduct? shown = product.value;
    final AsyncValue<Cart> cart = ref.watch(currentCartProvider);
    final MutationState adding = ref.watch(addToCartProvider(widget.productId));
    // The add waits while the cart is on its way: an add to a cart not yet
    // seen could not be told from one already holding the product.
    final bool cartKnown = cart.hasValue || cart.hasError;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: l10n.productTitle,
        actions: <Widget>[
          if (shown != null) _Heart(product: shown, onTap: _toggleHeart),
        ],
      ),
      body: UnderActiveMode(
        child: product.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: !product.hasError,
          data: (CatalogProduct product) => _Page(
            product: product,
            form: _form,
            note: _note,
            policy: _policy,
            onPolicy: (SubstitutionPolicy policy) =>
                setState(() => _policy = policy),
          ),
          error: (Object error, StackTrace _) {
            final ApiFailure failure = error is ApiFailure
                ? error
                : const UnexpectedFailure();
            if (failure is ApiRefusal && failure.status == 404) {
              return const _Gone();
            }
            return _Retry(
              failure: failure,
              onRetry: () =>
                  ref.invalidate(catalogProductProvider(widget.productId)),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
      bottomNavigationBar: shown == null
          ? null
          : ProductBar(
              product: shown,
              quantity: _quantity,
              onQuantity: (String quantity) =>
                  setState(() => _quantity = quantity),
              actionKey: const ValueKey<String>('add-to-cart'),
              actionLabel: l10n.productAddToCart,
              onAction: cartKnown ? () => _add(shown) : null,
              busy: adding.isBusy,
            ),
    );
  }
}

class _Heart extends ConsumerWidget {
  const _Heart({required this.product, required this.onTap});

  final CatalogProduct product;
  final ValueChanged<CatalogProduct> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool favorite = isFavorite(ref, product);
    return IconButton(
      key: const ValueKey<String>('product-heart'),
      tooltip: favorite ? l10n.favoriteRemove : l10n.favoriteAdd,
      color: favorite ? KitColors.danger : KitColors.ink,
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
      onPressed: () => onTap(product),
    );
  }
}

/// The scrolling page; what the Customer sets lives in the screen's state,
/// so it survives the page being built again.
class _Page extends StatelessWidget {
  const _Page({
    required this.product,
    required this.form,
    required this.note,
    required this.policy,
    required this.onPolicy,
  });

  final CatalogProduct product;
  final GlobalKey<FormState> form;
  final TextEditingController note;
  final SubstitutionPolicy policy;
  final ValueChanged<SubstitutionPolicy> onPolicy;

  static const double side = 20;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final String? description = product.description(language);
    final double wellHeight = math.min(
      250,
      MediaQuery.sizeOf(context).width * 0.67,
    );

    return SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: side),
              child: SizedBox(
                height: wellHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KitColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: ProductImage(
                      url: product.imageUrl,
                      size: wellHeight * 0.68,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(side, 16, side, 0),
              child: Text(
                product.name(language),
                key: const ValueKey<String>('product-name'),
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(side, 8, side, 0),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: <Widget>[
                  Text(
                    l10n.catalogApproxPrice(
                      MoneyFormat.uzs(product.customerUnitPriceUzs, language),
                    ),
                    key: const ValueKey<String>('product-price'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                  Text(
                    l10n.catalogPerUnit(
                      CatalogLabels.unit(l10n, product.unitCode),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: KitColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (product.priceMode == PriceMode.estimate)
              Padding(
                padding: const EdgeInsets.fromLTRB(side, 12, side, 0),
                child: _EstimatePanel(text: l10n.catalogEstimateExplain),
              ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(side, 12, side, 0),
                child: _Description(text: description),
              ),
            const SizedBox(height: 16),
            const _Rule(),
            _Section(
              title: l10n.productIfMissing,
              child: RadioGroup<SubstitutionPolicy>(
                groupValue: policy,
                onChanged: (SubstitutionPolicy? option) {
                  if (option != null) {
                    onPolicy(option);
                  }
                },
                child: Column(
                  key: const ValueKey<String>('line-substitution'),
                  children: <Widget>[
                    for (final SubstitutionPolicy option
                        in SubstitutionPolicy.values)
                      _RuleRow(
                        option: option,
                        label: OrderLabels.substitution(l10n, option),
                        onTap: () => onPolicy(option),
                      ),
                  ],
                ),
              ),
            ),
            const _Rule(),
            _Section(
              title: l10n.cartNote,
              child: _NoteField(controller: note),
            ),
            const SizedBox(height: 8),
            MoreInCategory(product: product),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: _Page.side),
    child: Divider(height: 1, thickness: 1, color: KitColors.line),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_Page.side, 16, _Page.side, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EstimatePanel extends StatelessWidget {
  const _EstimatePanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primaryWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.info_outline,
              size: 20,
              color: KitColors.primaryDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: KitColors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The description, three lines until the Customer reads on.
class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  static const int foldedLines = 3;
  static const TextStyle style = TextStyle(
    fontSize: 13,
    height: 1.6,
    color: KitColors.ink2,
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: foldedLines,
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: constraints.maxWidth);
        final bool longer = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.text,
              key: const ValueKey<String>('product-description'),
              maxLines: _expanded ? null : foldedLines,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
              style: style,
            ),
            if (longer)
              TextButton(
                key: const ValueKey<String>('product-more'),
                style: TextButton.styleFrom(
                  foregroundColor: KitColors.primaryDark,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? l10n.productReadLess : l10n.productReadMore,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.option,
    required this.label,
    required this.onTap,
  });

  final SubstitutionPolicy option;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('substitution-${option.code}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: <Widget>[
            IgnorePointer(
              child: Radio<SubstitutionPolicy>(
                value: option,
                activeColor: KitColors.primary,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: KitColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: const ValueKey<String>('line-note'),
          controller: controller,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontSize: 14, color: KitColors.ink),
          decoration: InputDecoration(
            hintText: l10n.productNoteHint,
            hintStyle: const TextStyle(fontSize: 14, color: KitColors.muted),
            filled: true,
            fillColor: KitColors.field,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (String? text) =>
              trimLikeServer(text ?? '').runes.length > cartNoteMaxLength
              ? l10n.fieldTooLong(cartNoteMaxLength)
              : null,
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (BuildContext context, TextEditingValue value, Widget? _) =>
              Text(
                '${value.text.runes.length} / $cartNoteMaxLength',
                key: const ValueKey<String>('product-note-count'),
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
        ),
      ],
    );
  }
}

/// Drawing 18b: the product is no longer in the catalog (a `404`), which
/// asking again cannot bring back (`DL-28` (12)).
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        key: const ValueKey<String>('product-gone'),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: KitColors.primaryWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.remove_shopping_cart,
                size: 44,
                color: KitColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.productGoneTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.productGoneText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: KitColors.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey<String>('product-gone-action'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KitColors.primary,
                side: const BorderSide(color: KitColors.primary),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.go(AppPaths.customer),
              child: Text(l10n.productGoneAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Something that could not be loaded: the reason and a retry.
class _Retry extends StatelessWidget {
  const _Retry({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FailureMessage(failure),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey<String>('retry-load'),
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
