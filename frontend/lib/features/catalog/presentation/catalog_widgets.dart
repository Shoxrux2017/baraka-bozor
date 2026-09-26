import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';

/// The interface language, for choosing between a name's two versions.
AppLanguage languageOf(BuildContext context) =>
    AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
    AppLanguage.uz;

/// A product's price as the Customer reads it: the customer price per unit,
/// and for an estimate the words that say so (`BR-PRICE-003`).
class PriceLine extends StatelessWidget {
  const PriceLine({required this.product, this.style, super.key});

  final CatalogProduct product;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String price = l10n.catalogPricePerUnit(
      MoneyFormat.uzs(product.customerUnitPriceUzs, languageOf(context)),
      CatalogLabels.unit(l10n, product.unitCode),
    );

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(price, style: style),
        if (product.priceMode == PriceMode.estimate)
          Text(
            l10n.catalogEstimateNote,
            key: const ValueKey<String>('estimate-note'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}

/// A product's image, or a placeholder.
class ProductImage extends StatelessWidget {
  const ProductImage({required this.url, required this.size, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = SizedBox.square(
      dimension: size,
      child: Icon(Icons.shopping_basket_outlined, size: size / 2),
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

/// A product list that loads its next page when its end comes into view,
/// with the state of that last page at the bottom: loading, a failure with a
/// retry, or nothing at the end.
class ProductList extends ConsumerWidget {
  const ProductList({required this.query, super.key});

  final ProductListQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ProductListState> list = ref.watch(
      productListProvider(query),
    );

    return list.when(
      skipLoadingOnReload: false,
      data: (ProductListState state) {
        if (state.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                query.search.isEmpty
                    ? l10n.catalogNoProducts
                    : l10n.catalogEmpty,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          key: const ValueKey<String>('product-list'),
          itemCount: state.items.length + (state.hasMore ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index < state.items.length) {
              return ProductTile(product: state.items[index]);
            }
            return _ListEnd(query: query, state: state);
          },
        );
      },
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FailureMessage(
                error is ApiFailure ? error : const UnexpectedFailure(),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(productListProvider(query)),
                child: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

/// The last row of a list with more to load: it asks for the next page as
/// it is built, and after a failure offers the retry instead.
class _ListEnd extends ConsumerWidget {
  const _ListEnd({required this.query, required this.state});

  final ProductListQuery query;
  final ProductListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProductListController list = ref.read(
      productListProvider(query).notifier,
    );
    final ApiFailure? failure = state.moreFailure;

    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            FailureMessage(failure),
            TextButton(
              key: const ValueKey<String>('load-more'),
              onPressed: list.loadMore,
              child: Text(AppLocalizations.of(context).catalogLoadMore),
            ),
          ],
        ),
      );
    }

    if (!state.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => list.loadMore());
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({required this.product, super.key});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = languageOf(context);

    return ListTile(
      key: ValueKey<String>('product-${product.id}'),
      leading: ProductImage(url: product.imageUrl, size: 56),
      title: Text(product.name(language)),
      subtitle: PriceLine(product: product),
      onTap: () => context.push(CatalogPaths.product(product.id)),
    );
  }
}
