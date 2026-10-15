import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'catalog_paths.dart';
import 'category_tile.dart';

/// Every category, four to a row (drawing 11); a tile opens the category.
class AllCategoriesScreen extends ConsumerWidget {
  const AllCategoriesScreen({super.key});

  static const int _columns = 4;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<CatalogCategory>> categories = ref.watch(
      catalogCategoriesProvider,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          l10n.catalogCategoriesTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
      ),
      body: categories.when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: !categories.hasError,
        data: (List<CatalogCategory> rows) {
          if (rows.isEmpty) {
            return Center(child: Text(l10n.catalogNoProducts));
          }
          final double width = MediaQuery.sizeOf(context).width;
          final double tile = (width - 32 - _gap * (_columns - 1)) / _columns;
          final double label =
              MediaQuery.textScalerOf(context).scale(12) * 1.25;
          return GridView.builder(
            key: const ValueKey<String>('category-grid'),
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              crossAxisSpacing: _gap,
              mainAxisSpacing: _gap,
              mainAxisExtent: tile + 6 + label * 2 + 2,
            ),
            itemCount: rows.length,
            itemBuilder: (BuildContext context, int index) => InkWell(
              key: ValueKey<String>('category-${rows[index].id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(CatalogPaths.category(rows[index].id)),
              child: CategoryTile(category: rows[index]),
            ),
          );
        },
        error: (Object error, StackTrace _) => CategoriesFailure(
          failure: error is ApiFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(catalogCategoriesProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// The failure of loading the categories, with the retry.
class CategoriesFailure extends StatelessWidget {
  const CategoriesFailure({
    required this.failure,
    required this.onRetry,
    super.key,
  });

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
