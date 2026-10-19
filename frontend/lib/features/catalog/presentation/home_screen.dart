import 'package:flutter/material.dart';
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
import '../../orders/presentation/question_banner.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'all_categories_screen.dart';
import 'catalog_paths.dart';
import 'category_tile.dart';
import 'recommended_row.dart';
import 'section_title.dart';
import 'sort_sheet.dart';

/// The Customer area's home in the kit's look (`DL-80`, drawings 10 and 10a):
/// where the order goes with the cart at its right, the search field, which
/// opens the search screen (`DL-83`), with the filter button, then the
/// categories and the recommended products, over the tab bar. The active mode
/// shows at the top while two sessions exist, with the way back to the staff
/// area on it (`DL-75`, `docs/02-user-roles.md` section 10).
class CatalogHomeScreen extends ConsumerWidget {
  const CatalogHomeScreen({super.key});

  /// The most of the screen's height above the keyboard that the header
  /// takes before it scrolls, so a large text on a small phone still leaves
  /// the sections room.
  static const double headerShare = 0.6;

  /// Asks the order, then opens every product in it.
  Future<void> _openSort(BuildContext context, WidgetRef ref) async {
    final ProductSort? chosen = await showSortSheet(
      context,
      ref.read(productSortProvider),
    );
    if (chosen == null || !context.mounted) {
      return;
    }
    ref.read(productSortProvider.notifier).set(chosen);
    context.push<void>(CatalogPaths.products);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // A share of the screen above the keyboard, so the keyboard never leaves
    // the body less room than the header's cap allows.
    final double maxHeader =
        (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom) *
        CatalogHomeScreen.headerShare;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const CustomerTabBar(current: CustomerTab.home),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeader),
              child: _header(context, ref, l10n),
            ),
            const Expanded(child: _Sections()),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return SingleChildScrollView(
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
                Expanded(child: _SearchEntry(hint: l10n.catalogSearchHint)),
                const SizedBox(width: 10),
                _FilterButton(
                  label: l10n.sortTitle,
                  onTap: () => _openSort(context, ref),
                ),
              ],
            ),
          ),
          const QuestionBanner(),
        ],
      ),
    );
  }
}

/// The search field of the home: it looks like the field and opens the
/// search screen when tapped.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      onTap: () => context.push<void>(CatalogPaths.search),
      child: Material(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey<String>('catalog-search'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push<void>(CatalogPaths.search),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search, color: KitColors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KitColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      onTap: onTap,
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
          SectionTitle(
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
          const RecommendedRow(),
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
