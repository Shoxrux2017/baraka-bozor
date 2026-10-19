import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';

/// A product list that loads its next page when its end comes into view,
/// with the state of that last page at the bottom: loading, a failure with a
/// retry, or nothing at the end. Each product is a row [itemBuilder] makes.
class ProductList extends ConsumerWidget {
  const ProductList({
    required this.query,
    required this.itemBuilder,
    super.key,
  });

  final ProductListQuery query;
  final Widget Function(BuildContext context, CatalogProduct product)
  itemBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<ProductListState> list = ref.watch(
      productListProvider(query),
    );

    return list.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: !list.hasError,
      data: (ProductListState state) {
        if (state.items.isEmpty) {
          return Center(
            child: Padding(
              padding: _centred(context),
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
              return itemBuilder(context, state.items[index]);
            }
            return ProductListEnd(query: query, state: state);
          },
        );
      },
      error: (Object error, StackTrace _) => Center(
        child: Padding(
          padding: _centred(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FailureMessage(
                error is ApiFailure ? error : const UnexpectedFailure(),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey<String>('retry-load'),
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

/// The room around a centred message: under the home's floating bar the body
/// runs behind it, so the message stops above it (zero elsewhere).
EdgeInsets _centred(BuildContext context) =>
    EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom);

/// The last row of a list with more to load: it asks for the next page as
/// it is built, and after a failure offers the retry instead.
class ProductListEnd extends ConsumerWidget {
  const ProductListEnd({required this.query, required this.state, super.key});

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
