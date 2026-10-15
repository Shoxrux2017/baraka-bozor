import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../addresses/presentation/delivery_address_widgets.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'all_categories_screen.dart';
import 'catalog_paths.dart';
import 'category_tile.dart';
import 'kit_product_card.dart';
import 'kit_product_grid.dart';
import 'sort_sheet.dart';

/// The Customer area's home in the kit's look (`DL-80`, drawings 10 and 10a):
/// where the order goes with the cart at its right, the search with the
/// filter button, then the categories and the recommended products — or,
/// while a query stands, the products it finds — over the tab bar. The active
/// mode shows at the top while two sessions exist, with the way back to the
/// staff area on it (`DL-75`, `docs/02-user-roles.md` section 10).
class CatalogHomeScreen extends ConsumerStatefulWidget {
  const CatalogHomeScreen({super.key});

  /// How long typing must pause before a search is sent, so a word typed
  /// quickly asks once rather than once per letter.
  static const Duration searchPause = Duration(milliseconds: 300);

  /// The most of the screen's height the header takes before it scrolls, so
  /// a large text on a small phone still leaves the sections room.
  static const double headerShare = 0.6;

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

  /// Asks the order, then opens every product in it.
  Future<void> _openSort() async {
    final ProductSort? chosen = await showSortSheet(
      context,
      ref.read(productSortProvider),
    );
    if (chosen == null || !mounted) {
      return;
    }
    ref.read(productSortProvider.notifier).set(chosen);
    context.push<void>(CatalogPaths.products);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductSort sort = ref.watch(productSortProvider);
    final double maxHeader =
        MediaQuery.sizeOf(context).height * CatalogHomeScreen.headerShare;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CustomerTabBar(current: CustomerTab.home),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // The same widgets whatever the body shows, so typing never
            // loses the field's focus.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeader),
              child: SingleChildScrollView(
                key: const ValueKey<String>('home-header'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const ActiveModeBar(action: _SwitchToStaffButton()),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 4, 0),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: DeliveryAddressLine()),
                          SizedBox(width: 8),
                          CartButton(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: _searchField(l10n)),
                          const SizedBox(width: 10),
                          _FilterButton(
                            label: l10n.sortTitle,
                            onTap: _openSort,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? const _Sections()
                  : KitProductGrid(
                      query: ProductListQuery(search: _query, sort: sort),
                      empty: Text(
                        l10n.catalogEmpty,
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return TextField(
      key: const ValueKey<String>('catalog-search'),
      controller: _search,
      textInputAction: TextInputAction.search,
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(ProductListQuery.searchMaxLength),
      ],
      style: const TextStyle(color: KitColors.ink, fontSize: 14),
      decoration: InputDecoration(
        hintText: l10n.catalogSearchHint,
        hintStyle: const TextStyle(color: KitColors.muted, fontSize: 14),
        filled: true,
        fillColor: KitColors.field,
        constraints: const BoxConstraints(minHeight: 50),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: const Icon(Icons.search, color: KitColors.muted),
        suffixIcon: _query.isEmpty && _search.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey<String>('catalog-search-clear'),
                icon: const Icon(Icons.clear, color: KitColors.muted),
                tooltip: l10n.catalogSearchClear,
                onPressed: _clear,
              ),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
      onChanged: _onTyped,
    );
  }
}

/// The filter button beside the search: it asks the order of the products.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: KitColors.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey<String>('open-sort'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: const SizedBox.square(
            dimension: 50,
            child: Icon(Icons.tune, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// The categories and the recommended products, which scroll together.
class _Sections extends ConsumerWidget {
  const _Sections();

  /// The categories the home shows before "Все".
  static const int shownCategories = 8;
  static const int columns = 4;
  static const double gap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<CatalogCategory>> categories = ref.watch(
      catalogCategoriesProvider,
    );

    return SingleChildScrollView(
      key: const ValueKey<String>('home-body'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionTitle(
            title: l10n.homeCategories,
            seeAllKey: 'open-categories',
            onSeeAll: () => context.push<void>(CatalogPaths.categories),
          ),
          categories.when(
            skipLoadingOnReload: false,
            skipLoadingOnRefresh: !categories.hasError,
            data: (List<CatalogCategory> rows) => rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.catalogNoProducts,
                      textAlign: TextAlign.center,
                    ),
                  )
                : _CategoryGrid(
                    categories: rows.take(shownCategories).toList(),
                  ),
            error: (Object error, StackTrace _) => CategoriesFailure(
              failure: error is ApiFailure ? error : const UnexpectedFailure(),
              onRetry: () => ref.invalidate(catalogCategoriesProvider),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          const _Recommended(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.seeAllKey,
    required this.onSeeAll,
  });

  final String title;
  final String seeAllKey;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          TextButton(
            key: ValueKey<String>(seeAllKey),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onSeeAll,
            child: Text(AppLocalizations.of(context).homeSeeAll),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<CatalogCategory> categories;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double tile =
        (width - 32 - _Sections.gap * (_Sections.columns - 1)) /
        _Sections.columns;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: _Sections.gap,
        runSpacing: _Sections.gap,
        children: <Widget>[
          for (final CatalogCategory category in categories)
            InkWell(
              key: ValueKey<String>('category-${category.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  context.push<void>(CatalogPaths.category(category.id)),
              child: CategoryTile(category: category, size: tile),
            ),
        ],
      ),
    );
  }
}

/// "Рекомендуем": up to ten recommended products in a row. The section is
/// absent while there is none, while it loads and when it fails: the home
/// stands without it.
class _Recommended extends ConsumerWidget {
  const _Recommended();

  static const int shown = 10;
  static const double cardWidth = 150;
  static const double imageHeight = 130;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<CatalogProduct> items =
        ref
            .watch(
              productListProvider(const ProductListQuery(featuredOnly: true)),
            )
            .value
            ?.items ??
        const <CatalogProduct>[];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final double extent = kitCardExtent(
      MediaQuery.textScalerOf(context),
      size: KitCardSize.regular,
      imageHeight: imageHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          title: l10n.recommendedTitle,
          seeAllKey: 'open-recommended',
          onSeeAll: () => context.push<void>(CatalogPaths.recommended),
        ),
        SizedBox(
          height: extent,
          child: ListView.separated(
            key: const ValueKey<String>('recommended-row'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length < shown ? items.length : shown,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) => SizedBox(
              width: cardWidth,
              child: KitProductCard(
                product: items[index],
                imageHeight: imageHeight,
              ),
            ),
          ),
        ),
      ],
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
