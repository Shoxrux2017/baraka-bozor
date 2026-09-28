import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../catalog/application/catalog_controllers.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/catalog_screens.dart';
import '../../catalog/presentation/catalog_widgets.dart';

/// Picks a product to add to an order (`docs/03` section 11, `DL-52`): a
/// search over the whole catalog the Customer sees, or one category's
/// products. It answers the product picked; the editor decides what that
/// means.
class OrderProductPickerScreen extends ConsumerStatefulWidget {
  const OrderProductPickerScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderProductPickerScreen> createState() =>
      _OrderProductPickerScreenState();
}

class _OrderProductPickerScreenState
    extends ConsumerState<OrderProductPickerScreen> {
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    // A search looks through the whole catalog, as the catalog's does; the
    // category chosen comes back once the search is cleared.
    final CatalogCategory? category = _query.isEmpty ? _category : null;

    return PopScope(
      // Back from a category's products returns to the categories.
      canPop: category == null,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          setState(() => _category = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.orderAddTitle)),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  key: const ValueKey<String>('pick-search'),
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
                            key: const ValueKey<String>('pick-search-clear'),
                            icon: const Icon(Icons.clear),
                            tooltip: l10n.catalogSearchClear,
                            onPressed: _clear,
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onTyped,
                ),
              ),
              if (category != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        onPick: _pick,
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
