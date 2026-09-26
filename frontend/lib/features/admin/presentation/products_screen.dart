import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/paged.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'admin_paths.dart';
import 'catalog_widgets.dart';

/// The Admin's products (`docs/09-api-contracts.md` section 15): a
/// paginated list searched by name in either language, filtered by category,
/// archived entries on request, and archive and restore. A product opens on
/// its own page for editing and its image.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(productQueryProvider).search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ProductQuery query = ref.watch(productQueryProvider);
    final ProductQueryController queries = ref.read(
      productQueryProvider.notifier,
    );
    final AsyncValue<Paged<AdminProduct>> page = ref.watch(productPageProvider);
    final AsyncValue<List<AdminCategory>> categories = ref.watch(
      categoryOptionsProvider,
    );
    final MutationState change = ref.watch(catalogChangeControllerProvider);
    final Map<String, AdminCategory> byId = <String, AdminCategory>{
      for (final AdminCategory category
          in categories.value ?? const <AdminCategory>[])
        category.id: category,
    };

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              l10n.adminSectionProducts,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              key: const ValueKey<String>('new-product'),
              icon: const Icon(Icons.add),
              label: Text(l10n.productNew),
              onPressed: () => context.go(AdminPaths.newProduct),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey<String>('product-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l10n.productSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: queries.search,
              ),
            ),
            DropdownButton<String?>(
              key: const ValueKey<String>('product-category-filter'),
              value: byId.containsKey(query.categoryId)
                  ? query.categoryId
                  : null,
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(
                  child: Text(l10n.productAllCategories),
                ),
                for (final AdminCategory category in byId.values)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(_nameOf(context, category)),
                  ),
              ],
              onChanged: queries.filterByCategory,
            ),
            FilterChip(
              key: const ValueKey<String>('include-archived'),
              label: Text(l10n.catalogIncludeArchived),
              selected: query.includeArchived,
              onSelected: queries.includeArchived,
            ),
          ],
        ),
        const SizedBox(height: 16),
        FailureMessage(change.failure),
        page.when(
          skipLoadingOnReload: false,
          data: (Paged<AdminProduct> page) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (page.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.catalogEmpty),
                ),
              for (final AdminProduct product in page.items)
                _ProductRow(
                  product: product,
                  category: byId[product.categoryId],
                  busy: change.isBusy,
                ),
              PaginationBar(page: page, onPage: queries.goToPage),
            ],
          ),
          error: (Object error, StackTrace _) => LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(productPageProvider),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends ConsumerWidget {
  const _ProductRow({
    required this.product,
    required this.category,
    required this.busy,
  });

  final AdminProduct product;
  final AdminCategory? category;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language =
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
        AppLanguage.uz;
    final CatalogChangeController change = ref.read(
      catalogChangeControllerProvider.notifier,
    );
    final bool archived = product.state == CatalogEntryState.archived;

    return Card(
      child: ListTile(
        key: ValueKey<String>('product-${product.id}'),
        leading: ProductThumbnail(url: product.imageUrl, size: 48),
        title: Text('${product.nameUz} · ${product.nameRu}'),
        subtitle: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            EntryStateChip(product.state),
            if (category != null) Text(_nameOf(context, category!)),
            Text(
              '${CatalogLabels.priceMode(l10n, product.priceMode)}: '
              '${MoneyFormat.uzs(product.marketPriceUzs, language)} / '
              '${CatalogLabels.unit(l10n, product.unitCode)}',
            ),
            Text(
              l10n.productCustomerPrice(
                MoneyFormat.uzs(product.customerUnitPriceUzs, language),
              ),
            ),
          ],
        ),
        onTap: () => context.go(AdminPaths.product(product.id)),
        trailing: IconButton(
          key: ValueKey<String>(
            '${archived ? 'restore' : 'archive'}-${product.id}',
          ),
          tooltip: archived ? l10n.catalogRestore : l10n.catalogArchive,
          icon: Icon(
            archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          ),
          onPressed: busy
              ? null
              : () => archived
                    ? change.restoreProduct(product.id)
                    : change.archiveProduct(product.id),
        ),
      ),
    );
  }
}

/// A product's image, or a placeholder when it has none or it cannot be
/// loaded.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({required this.url, required this.size, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = SizedBox.square(
      dimension: size,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size / 2,
        semanticLabel: AppLocalizations.of(context).productNoImage,
      ),
    );
    final String? url = this.url;
    if (url == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
            placeholder,
      ),
    );
  }
}

/// A category's name in the interface language.
String _nameOf(BuildContext context, AdminCategory category) =>
    Localizations.localeOf(context).languageCode == AppLanguage.ru.code
    ? category.nameRu
    : category.nameUz;
