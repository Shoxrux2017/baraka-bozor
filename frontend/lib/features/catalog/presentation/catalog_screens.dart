import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/language_menu.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'catalog_widgets.dart';

/// The Customer area's home: the catalog's sections and a search over every
/// product (`docs/09-api-contracts.md` section 14). The app bar carries
/// what the area's entry carried before — the language, the active mode
/// while two sessions exist, the way back to the staff area and the way out
/// (`docs/02-user-roles.md` section 10).
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
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final SignedIn? session = state is SignedIn ? state : null;
    final bool twoSessions =
        session != null &&
        session.staffUser != null &&
        session.customerUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: <Widget>[
          if (twoSessions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Chip(
                  key: const ValueKey<String>('active-mode-chip'),
                  label: Text(l10n.customerModeLabel),
                ),
              ),
            ),
          const LanguageMenuButton(),
          if (session?.staffUser != null)
            IconButton(
              key: const ValueKey<String>('switch-to-staff-button'),
              icon: const Icon(Icons.badge_outlined),
              tooltip: l10n.switchToStaff,
              onPressed: () => ref
                  .read(sessionControllerProvider.notifier)
                  .switchMode(SessionMode.staff),
            ),
          if (session != null)
            IconButton(
              key: const ValueKey<String>('logout-button'),
              icon: const Icon(Icons.logout),
              tooltip: l10n.logoutButton,
              onPressed: () => ref
                  .read(sessionControllerProvider.notifier)
                  .logout(session.activeMode),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const ValueKey<String>('catalog-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    ProductListQuery.searchMaxLength,
                  ),
                ],
                decoration: InputDecoration(
                  hintText: l10n.catalogSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty && _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey<String>('catalog-search-clear'),
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.cancelButton,
                          onPressed: _clear,
                        ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onTyped,
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? const _Categories()
                  : ProductList(query: ProductListQuery(search: _query)),
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
    final AppLanguage language = languageOf(context);

    return ref
        .watch(catalogCategoriesProvider)
        .when(
          skipLoadingOnReload: false,
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
    final AppLanguage language = languageOf(context);
    final List<CatalogCategory>? categories = ref
        .watch(catalogCategoriesProvider)
        .value;
    final CatalogCategory? category = categories
        ?.where((CatalogCategory c) => c.id == categoryId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(category?.name(language) ?? '')),
      body: SafeArea(
        child: ProductList(query: ProductListQuery(categoryId: categoryId)),
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
    final AppLanguage language = languageOf(context);
    final AsyncValue<CatalogProduct> product = ref.watch(
      catalogProductProvider(productId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(product.value?.name(language) ?? '')),
      body: SafeArea(
        child: product.when(
          skipLoadingOnReload: false,
          data: (CatalogProduct product) {
            final String? description = product.description(language);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Center(child: ProductImage(url: product.imageUrl, size: 240)),
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
              ],
            );
          },
          error: (Object error, StackTrace _) => _Retry(
            failure: error is ApiFailure ? error : const UnexpectedFailure(),
            onRetry: () => ref.invalidate(catalogProductProvider(productId)),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
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
