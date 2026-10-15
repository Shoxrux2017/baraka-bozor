import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/presentation/add_to_cart.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_widgets.dart';

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
