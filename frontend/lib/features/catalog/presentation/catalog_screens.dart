import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'catalog_widgets.dart';
import 'customer_home_header.dart';
import 'customer_home_nav.dart';

/// The Customer area's home (design 4a): the green header — the search over
/// every product, the cart and the delivery address — over the catalog's
/// sections (`docs/09-api-contracts.md` section 14), with the floating bar to
/// the orders and the profile. The profile holds the language and the way out;
/// the active mode shows at the top of the header while two sessions exist,
/// with the way back to the staff area on it (`DL-75`,
/// `docs/02-user-roles.md` section 10).
class CatalogHomeScreen extends ConsumerStatefulWidget {
  const CatalogHomeScreen({super.key});

  /// How long typing must pause before a search is sent, so a word typed
  /// quickly asks once rather than once per letter.
  static const Duration searchPause = Duration(milliseconds: 300);

  @override
  ConsumerState<CatalogHomeScreen> createState() => _CatalogHomeScreenState();
}

class _CatalogHomeScreenState extends ConsumerState<CatalogHomeScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _pause;
  String _query = '';

  @override
  void dispose() {
    _pause?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onTyped(String text) {
    _pause?.cancel();
    _pause = Timer(CatalogHomeScreen.searchPause, () {
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons over the green header.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: const CustomerHomeNav(),
        body: Column(
          children: <Widget>[
            CustomerHomeHeader(
              modeAction: const _SwitchToStaffButton(),
              search: TextField(
                key: const ValueKey<String>('catalog-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    ProductListQuery.searchMaxLength,
                  ),
                ],
                style: const TextStyle(color: BrandColors.ink, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: l10n.catalogSearchHint,
                  hintStyle: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 14.5,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: BrandColors.ink,
                  ),
                  suffixIcon: _query.isEmpty && _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey<String>('catalog-search-clear'),
                          icon: const Icon(
                            Icons.clear,
                            color: BrandColors.muted,
                          ),
                          tooltip: l10n.catalogSearchClear,
                          onPressed: _clear,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(23),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onTyped,
              ),
            ),
            Expanded(
              // The header took the top inset; the bottom one, which the
              // floating bar adds, stays for the lists to pad by. The
              // Builder reads the body's inset, not the screen's.
              child: Builder(
                builder: (BuildContext body) => MediaQuery.removePadding(
                  context: body,
                  removeTop: true,
                  child: _query.isEmpty
                      ? const _Categories()
                      : ProductList(query: ProductListQuery(search: _query)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);

    final AsyncValue<List<CatalogCategory>> sections = ref.watch(
      catalogCategoriesProvider,
    );
    return sections.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: !sections.hasError,
      data: (List<CatalogCategory> categories) => categories.isEmpty
          ? Center(child: Text(l10n.catalogNoProducts))
          : ListView(
              key: const ValueKey<String>('category-list'),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    l10n.catalogCategoriesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final CatalogCategory category in categories)
                  ListTile(
                    key: ValueKey<String>('category-${category.id}'),
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category.name(language)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(CatalogPaths.category(category.id)),
                  ),
              ],
            ),
      error: (Object error, StackTrace _) => _Retry(
        failure: error is ApiFailure ? error : const UnexpectedFailure(),
        onRetry: () => ref.invalidate(catalogCategoriesProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

/// One category's products, loaded as the Customer scrolls.
class CategoryProductsScreen extends ConsumerWidget {
  const CategoryProductsScreen({required this.categoryId, super.key});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLanguage language = interfaceLanguage(context);
    final List<CatalogCategory>? categories = ref
        .watch(catalogCategoriesProvider)
        .value;
    final CatalogCategory? category = categories
        ?.where((CatalogCategory c) => c.id == categoryId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(category?.name(language) ?? ''),
        actions: const <Widget>[CartButton()],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: ProductList(
                query: ProductListQuery(categoryId: categoryId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One product: its image, its name in the interface language with the
/// other language's under it, the price per unit and what an estimate means,
/// and its description.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final AsyncValue<CatalogProduct> product = ref.watch(
      catalogProductProvider(productId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(product.value?.name(language) ?? ''),
        actions: const <Widget>[CartButton()],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: product.when(
                skipLoadingOnReload: false,
                skipLoadingOnRefresh: !product.hasError,
                data: (CatalogProduct product) {
                  final String? description = product.description(language);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      Center(
                        child: ProductImage(url: product.imageUrl, size: 240),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        product.name(language),
                        key: const ValueKey<String>('product-name'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        product.otherName(language),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      PriceLine(
                        product: product,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (product.priceMode == PriceMode.estimate) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(l10n.catalogEstimateExplain),
                      ],
                      if (description != null) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(description),
                      ],
                      const SizedBox(height: 16),
                      AddToCartSection(
                        productId: product.id,
                        unit: product.unitCode,
                      ),
                    ],
                  );
                },
                error: (Object error, StackTrace _) => _Retry(
                  failure: error is ApiFailure
                      ? error
                      : const UnexpectedFailure(),
                  onRetry: () =>
                      ref.invalidate(catalogProductProvider(productId)),
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

/// Something that could not be loaded: the reason, and a retry unless the
/// thing does not exist — a product archived or hidden since the list was
/// read — which asking again cannot bring back (`DL-28` (12)).
class _Retry extends StatelessWidget {
  const _Retry({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FailureMessage(failure),
            if (!(failure is ApiRefusal &&
                (failure as ApiRefusal).status == 404)) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey<String>('retry-load'),
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).retryButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The way back to the staff area for a Shopper or Courier in Customer
/// mode, in one step (`docs/02-user-roles.md` section 10).
class _SwitchToStaffButton extends ConsumerWidget {
  const _SwitchToStaffButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      key: const ValueKey<String>('switch-to-staff-button'),
      onPressed: () => ref
          .read(sessionControllerProvider.notifier)
          .switchMode(SessionMode.staff),
      child: Text(
        AppLocalizations.of(context).switchToStaff,
        textAlign: TextAlign.end,
      ),
    );
  }
}
