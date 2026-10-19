import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/product_image.dart';
import '../../catalog/application/catalog_controllers.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../catalog/presentation/search_screen.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

/// Picks a product to add to an order (`docs/03` section 11, `DL-52`): a
/// search over the whole catalog the Customer sees, or one category's
/// products, each marked when it is already in the order. It answers the
/// product picked; the editor decides what that means.
class OrderProductPickerScreen extends ConsumerStatefulWidget {
  const OrderProductPickerScreen({
    required this.orderId,
    this.productIds,
    super.key,
  });

  final String orderId;

  /// The products the editor keeps in the order, in lower case; `null` when
  /// the picker was opened by its address alone, and the order's open lines
  /// stand in.
  final Set<String>? productIds;

  @override
  ConsumerState<OrderProductPickerScreen> createState() =>
      _OrderProductPickerScreenState();
}

class _OrderProductPickerScreenState
    extends ConsumerState<OrderProductPickerScreen> {
  static const OutlineInputBorder _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide.none,
  );

  final TextEditingController _search = TextEditingController();
  Timer? _pause;
  String _query = '';
  CatalogCategory? _category;

  @override
  void dispose() {
    _pause?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onTyped(String text) {
    _pause?.cancel();
    _pause = Timer(SearchScreen.searchPause, () {
      if (mounted) {
        setState(() => _query = ProductListQuery.searchOf(text));
      }
    });
  }

  void _clear() {
    _pause?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  /// Back to the editor with [product]; opened by its address alone, the
  /// picker has no editor to answer and opens the order's with it.
  void _pick(CatalogProduct product) {
    final GoRouter router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop(product);
    } else {
      router.go(AppPaths.customerOrderEdit(widget.orderId), extra: product);
    }
  }

  /// The products the order keeps, in lower case: what the editor sent, or
  /// the order's open lines when there is no editor.
  Set<String> _inOrder() {
    final Set<String>? sent = widget.productIds;
    if (sent != null) {
      return sent;
    }
    final List<CustomerOrderLine> lines =
        ref.watch(customerOrderProvider(widget.orderId)).value?.openLines ??
        const <CustomerOrderLine>[];
    return <String>{
      for (final CustomerOrderLine line in lines) line.productId.toLowerCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    // A search looks through the whole catalog, as the catalog's does; the
    // category chosen comes back once the search is cleared.
    final CatalogCategory? category = _query.isEmpty ? _category : null;
    final Set<String> inOrder = _inOrder();

    return PopScope(
      // Back from a category's products returns to the categories.
      canPop: category == null,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          setState(() => _category = null);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(title: l10n.orderAddTitle),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  key: const ValueKey<String>('pick-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(
                      ProductListQuery.searchMaxLength,
                    ),
                  ],
                  style: const TextStyle(fontSize: 14, color: KitColors.ink),
                  decoration: InputDecoration(
                    hintText: l10n.catalogSearchHint,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: KitColors.muted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: KitColors.muted,
                    ),
                    suffixIcon: _query.isEmpty && _search.text.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey<String>('pick-search-clear'),
                            icon: const Icon(Icons.clear),
                            tooltip: l10n.catalogSearchClear,
                            onPressed: _clear,
                          ),
                    filled: true,
                    fillColor: KitColors.field,
                    border: _fieldBorder,
                    enabledBorder: _fieldBorder,
                    focusedBorder: _fieldBorder,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onTyped,
                ),
              ),
              if (category != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: InputChip(
                      key: const ValueKey<String>('pick-category'),
                      label: Text(category.name(language)),
                      deleteButtonTooltipMessage: l10n.catalogCategoriesTitle,
                      onDeleted: () => setState(() => _category = null),
                    ),
                  ),
                ),
              Expanded(
                child: _query.isEmpty && category == null
                    ? _PickCategories(
                        onPick: (CatalogCategory picked) =>
                            setState(() => _category = picked),
                      )
                    : ProductList(
                        query: ProductListQuery(
                          categoryId: category?.id,
                          search: _query,
                        ),
                        itemBuilder:
                            (BuildContext context, CatalogProduct product) =>
                                _PickRow(
                                  product: product,
                                  inOrder: inOrder.contains(
                                    product.id.toLowerCase(),
                                  ),
                                  onPick: () => _pick(product),
                                ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The catalog's sections, to choose one to pick from.
class _PickCategories extends ConsumerWidget {
  const _PickCategories({required this.onPick});

  final ValueChanged<CatalogCategory> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final AsyncValue<List<CatalogCategory>> sections = ref.watch(
      catalogCategoriesProvider,
    );

    return sections.when(
      skipLoadingOnRefresh: !sections.hasError,
      data: (List<CatalogCategory> categories) => categories.isEmpty
          ? Center(child: Text(l10n.catalogNoProducts))
          : ListView(
              key: const ValueKey<String>('pick-categories'),
              children: <Widget>[
                for (final CatalogCategory category in categories)
                  ListTile(
                    key: ValueKey<String>('pick-category-${category.id}'),
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category.name(language)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onPick(category),
                  ),
              ],
            ),
      error: (Object error, StackTrace _) => Padding(
        padding: const EdgeInsets.all(16),
        child: LoadFailure(
          error: error,
          onRetry: () => ref.invalidate(catalogCategoriesProvider),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

/// One product to pick (drawing 29к): picture, name, the price and its unit,
/// and at the right the round plus — or, for a product already in the order,
/// the mark saying so. The whole row picks it; the editor says when it was
/// already there.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.product,
    required this.inOrder,
    required this.onPick,
  });

  final CatalogProduct product;
  final bool inOrder;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);

    return InkWell(
      key: ValueKey<String>('product-${product.id}'),
      onTap: onPick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KitColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: ProductImage(url: product.imageUrl, size: 44),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name(language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      product.priceMode == PriceMode.estimate
                          ? l10n.cartLineEstimate(
                              MoneyFormat.uzs(
                                product.customerUnitPriceUzs,
                                language,
                              ),
                            )
                          : MoneyFormat.uzs(
                              product.customerUnitPriceUzs,
                              language,
                            ),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KitColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    l10n.catalogPerUnit(
                      CatalogLabels.unit(l10n, product.unitCode),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (inOrder)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: InkWell(
                  key: ValueKey<String>('pick-in-order-${product.id}'),
                  onTap: onPick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: KitColors.primaryDark,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.orderPickInOrder,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: KitColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SizedBox.square(
                dimension: 36,
                child: IconButton(
                  key: ValueKey<String>('pick-${product.id}'),
                  tooltip: l10n.orderAddProduct,
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    backgroundColor: KitColors.primary,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.add),
                  onPressed: onPick,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
