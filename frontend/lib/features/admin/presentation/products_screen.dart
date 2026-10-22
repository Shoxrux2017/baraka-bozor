import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/paged.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_action_button.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_filter_chip.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/panel/panel_menu_button.dart';
import '../../../core/widgets/panel/panel_page_header.dart';
import '../../../core/widgets/panel/panel_pager.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'admin_paths.dart';
import 'catalog_archive_dialog.dart';
import 'catalog_widgets.dart';

/// The Admin's products (`docs/09-api-contracts.md` section 15): a
/// paginated list searched by name in either language, filtered by category,
/// archived entries on request, and archive and restore (`DL-101` (2)). It is
/// a table from a card [tableWidth] wide and cards below it. A product opens
/// on its own page for editing and its image.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  /// From this card width the products are a table whose columns all show;
  /// below it, cards, which show the same.
  static const double tableWidth = 800;

  /// From this card width the search, the category and the archive chip stand
  /// in one row; below it the search has a row of its own.
  static const double filtersRowWidth = 640;

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
    final AsyncValue<Paged<AdminProduct>> page = ref.watch(productPageProvider);
    final AsyncValue<List<AdminCategory>> categories = ref.watch(
      categoryOptionsProvider,
    );
    final ProductQuery query = ref.watch(productQueryProvider);
    final ProductQueryController queries = ref.read(
      productQueryProvider.notifier,
    );
    final Map<String, AdminCategory> byId = <String, AdminCategory>{
      for (final AdminCategory category
          in categories.value ?? const <AdminCategory>[])
        category.id: category,
    };
    final EdgeInsets padding = panelPagePadding(
      MediaQuery.sizeOf(context).width,
    );
    final bool filtered = query.search.isNotEmpty || query.categoryId != null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool labelled =
            constraints.maxWidth - padding.horizontal >= 480 &&
            !kitLargeText(context);

        return ListView(
          padding: padding,
          children: <Widget>[
            PanelPageHeader(
              title: l10n.adminSectionProducts,
              subtitle: page.hasValue
                  ? l10n.catalogProductCount(page.requireValue.total)
                  : null,
              trailing: PanelHeaderButton(
                buttonKey: const ValueKey<String>('new-product'),
                icon: Icons.add,
                label: l10n.productNew,
                labelled: labelled,
                onPressed: () => context.go(AdminPaths.newProduct),
              ),
            ),
            const SizedBox(height: 20),
            PanelCard(
              flush: true,
              children: <Widget>[
                Consumer(
                  builder: (BuildContext context, WidgetRef ref, Widget? _) {
                    final FailureMessage message = FailureMessage(
                      ref.watch(productListActionsProvider).failure,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: message,
                    );
                  },
                ),
                _ProductFilters(
                  search: _search,
                  query: query,
                  byId: byId,
                  queries: queries,
                ),
                page.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: !page.hasError,
                  data: (Paged<AdminProduct> page) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (page.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(l10n.catalogEmpty),
                              if (filtered)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    l10n.catalogEmptyHint,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: KitColors.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) =>
                                  constraints.maxWidth >=
                                      ProductsScreen.tableWidth
                                  ? _ProductsTable(
                                      products: page.items,
                                      byId: byId,
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        6,
                                      ),
                                      child: Column(
                                        children: <Widget>[
                                          for (final AdminProduct product
                                              in page.items)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _ProductCard(
                                                product: product,
                                                category:
                                                    byId[product.categoryId],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                        ),
                      PanelPager(page: page, onPage: queries.goToPage),
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
            ),
          ],
        );
      },
    );
  }
}

/// The search, the category menu and the archive chip: one row from a card
/// [ProductsScreen.filtersRowWidth] wide, the search over the other two below
/// it.
class _ProductFilters extends StatelessWidget {
  const _ProductFilters({
    required this.search,
    required this.query,
    required this.byId,
    required this.queries,
  });

  final TextEditingController search;
  final ProductQuery query;
  final Map<String, AdminCategory> byId;
  final ProductQueryController queries;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AdminCategory? chosen = byId[query.categoryId];

    Widget searchField({required double? width}) => SizedBox(
      width: width,
      child: TextField(
        key: const ValueKey<String>('product-search'),
        controller: search,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, color: KitColors.ink),
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(ProductQuery.searchMaxLength),
        ],
        decoration: panelSearchDecoration(
          hint: l10n.productSearch,
          suffix: const _EnterHint(),
        ),
        onSubmitted: queries.search,
      ),
    );

    final Widget menu = PanelMenuButton<String?>(
      buttonKey: 'product-category-filter',
      label: chosen == null
          ? l10n.productAllCategories
          : catalogName(context, uz: chosen.nameUz, ru: chosen.nameRu),
      active: chosen != null,
      items: <PanelMenuItem<String?>>[
        (value: null, label: l10n.productAllCategories),
        for (final AdminCategory category in byId.values)
          (
            value: category.id,
            label: catalogName(
              context,
              uz: category.nameUz,
              ru: category.nameRu,
            ),
          ),
      ],
      onSelected: queries.filterByCategory,
    );

    final Widget chip = PanelFilterChip(
      chipKey: 'include-archived',
      icon: query.includeArchived
          ? Icons.check_box
          : Icons.check_box_outline_blank,
      label: l10n.catalogIncludeArchived,
      selected: query.includeArchived,
      onTap: () => queries.includeArchived(!query.includeArchived),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool inOneRow =
            constraints.maxWidth >= ProductsScreen.filtersRowWidth;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: inOneRow
              ? Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[searchField(width: 320), menu, chip],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    searchField(width: null),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[menu, chip],
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// The small "Enter" key at the end of the search, which says the search
/// runs on Enter. Decoration only, so a screen reader skips it.
class _EnterHint extends StatelessWidget {
  const _EnterHint();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: DecoratedBox(
          key: const ValueKey<String>('search-enter-hint'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: KitColors.line),
          ),
          child: const SizedBox(
            height: 22,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                widthFactor: 1,
                child: Text(
                  'Enter',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: KitColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const Map<int, TableColumnWidth> _columns = <int, TableColumnWidth>{
  0: FlexColumnWidth(3),
  1: FlexColumnWidth(1.4),
  2: FlexColumnWidth(1.3),
  3: FlexColumnWidth(1.2),
  4: FlexColumnWidth(2.2),
  5: FixedColumnWidth(64),
};

TextStyle _nameStyle(bool archived) => TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: archived ? KitColors.muted : KitColors.ink,
);

const TextStyle _small = TextStyle(fontSize: 12, color: KitColors.muted);

/// The table: a header on `card` between two `line` rules, then a row per
/// product, each a table of its own under the same column widths, so a row
/// takes a hover and a tap as a whole and grows with its text.
class _ProductsTable extends StatelessWidget {
  const _ProductsTable({required this.products, required this.byId});

  final List<AdminProduct> products;
  final Map<String, AdminCategory> byId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const BorderSide line = BorderSide(color: KitColors.line);

    Widget header(String text, {TextAlign align = TextAlign.start}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: KitColors.muted,
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(
              color: KitColors.card,
              border: Border.symmetric(horizontal: line),
            ),
            child: Table(
              columnWidths: _columns,
              children: <TableRow>[
                TableRow(
                  children: <Widget>[
                    header(l10n.catalogColumnProduct),
                    header(l10n.productCategory),
                    header(l10n.productMarketPrice, align: TextAlign.end),
                    header(
                      l10n.catalogColumnCustomerPrice,
                      align: TextAlign.end,
                    ),
                    header(l10n.catalogColumnShown),
                    const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
          for (final AdminProduct product in products)
            _ProductRow(product: product, category: byId[product.categoryId]),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.category});

  final AdminProduct product;
  final AdminCategory? category;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language =
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
        AppLanguage.uz;
    final bool archived = product.state == CatalogEntryState.archived;
    final AdminCategory? category = this.category;
    final TextStyle price = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: archived ? KitColors.muted : KitColors.ink,
    );

    Widget cell(Widget child, {Alignment align = Alignment.centerLeft}) =>
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(alignment: align, child: child),
        );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: InkWell(
        key: ValueKey<String>('product-${product.id}'),
        hoverColor: KitColors.field,
        onTap: () => context.go(AdminPaths.product(product.id)),
        child: Table(
          columnWidths: _columns,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                cell(_ProductIdentity(product: product, size: 44)),
                cell(
                  Text(
                    category == null
                        ? ''
                        : catalogName(
                            context,
                            uz: category.nameUz,
                            ru: category.nameRu,
                          ),
                    style: TextStyle(
                      fontSize: 13,
                      color: archived ? KitColors.muted : KitColors.ink2,
                    ),
                  ),
                ),
                cell(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        MoneyFormat.uzs(product.marketPriceUzs, language),
                        textAlign: TextAlign.end,
                        style: price,
                      ),
                      Text(
                        l10n.catalogPerUnit(
                          CatalogLabels.unit(l10n, product.unitCode),
                        ),
                        textAlign: TextAlign.end,
                        style: _small,
                      ),
                    ],
                  ),
                  align: Alignment.centerRight,
                ),
                cell(
                  Text(
                    MoneyFormat.uzs(product.customerUnitPriceUzs, language),
                    textAlign: TextAlign.end,
                    style: price,
                  ),
                  align: Alignment.centerRight,
                ),
                cell(_StateAndLine(product: product, category: category)),
                cell(
                  _RowAction(product: product),
                  align: Alignment.centerRight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.category});

  final AdminProduct product;
  final AdminCategory? category;

  @override
  Widget build(BuildContext context) {
    final bool archived = product.state == CatalogEntryState.archived;
    final AdminCategory? category = this.category;
    final String other = catalogOtherName(
      context,
      uz: product.nameUz,
      ru: product.nameRu,
    );

    return KitCard(
      key: ValueKey<String>('product-${product.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => context.go(AdminPaths.product(product.id)),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // What is left of the row after the picture, the gaps and the
          // button: the prices take the width they need up to half of it, or
          // all but 260 for the names, so that they stand against the button.
          final double free = constraints.maxWidth - 56 - 12 - 12 - 8 - 36;
          final double pricesWidth = math.max(free / 2, free - 260);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Opacity(
                opacity: archived ? 0.5 : 1,
                child: CatalogThumb(url: product.imageUrl, size: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      catalogName(
                        context,
                        uz: product.nameUz,
                        ru: product.nameRu,
                      ),
                      style: _nameStyle(archived),
                    ),
                    Text(
                      category == null
                          ? other
                          : '$other · ${catalogName(context, uz: category.nameUz, ru: category.nameRu)}',
                      style: _small,
                    ),
                    const SizedBox(height: 6),
                    _StateAndLine(product: product, category: category),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Prices(
                product: product,
                archived: archived,
                maxWidth: pricesWidth,
              ),
              const SizedBox(width: 8),
              _RowAction(product: product),
            ],
          );
        },
      ),
    );
  }
}

/// The market price over its unit and the customer price, at the width they
/// need up to [maxWidth].
class _Prices extends StatelessWidget {
  const _Prices({
    required this.product,
    required this.archived,
    required this.maxWidth,
  });

  final AdminProduct product;
  final bool archived;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language =
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
        AppLanguage.uz;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            MoneyFormat.uzs(product.marketPriceUzs, language),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: archived ? KitColors.muted : KitColors.ink,
            ),
          ),
          Text(
            '${l10n.catalogPerUnit(CatalogLabels.unit(l10n, product.unitCode))}'
            ' · '
            '${l10n.catalogForCustomer(MoneyFormat.uzs(product.customerUnitPriceUzs, language))}',
            textAlign: TextAlign.end,
            style: _small,
          ),
        ],
      ),
    );
  }
}

/// The picture with the two names beside it.
class _ProductIdentity extends StatelessWidget {
  const _ProductIdentity({required this.product, required this.size});

  final AdminProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool archived = product.state == CatalogEntryState.archived;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Opacity(
          opacity: archived ? 0.5 : 1,
          child: CatalogThumb(url: product.imageUrl, size: size),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: _Names(product: product, archived: archived),
        ),
      ],
    );
  }
}

/// The name in the panel's language over the other one, smaller.
class _Names extends StatelessWidget {
  const _Names({required this.product, required this.archived});

  final AdminProduct product;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          catalogName(context, uz: product.nameUz, ru: product.nameRu),
          style: _nameStyle(archived),
        ),
        Text(
          catalogOtherName(context, uz: product.nameUz, ru: product.nameRu),
          style: _small,
        ),
      ],
    );
  }
}

/// The state chip with the featured tag, and under them what the category
/// does to a product that is shown.
class _StateAndLine extends StatelessWidget {
  const _StateAndLine({required this.product, required this.category});

  final AdminProduct product;
  final AdminCategory? category;

  @override
  Widget build(BuildContext context) {
    final String? line = categoryHidesLine(
      AppLocalizations.of(context),
      product.state,
      category,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            CatalogStateChip(product.state),
            if (product.isFeatured)
              FeaturedTag(key: ValueKey<String>('featured-${product.id}')),
          ],
        ),
        if (line != null) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.visibility_off_outlined,
                  size: 15,
                  color: KitColors.warningDark,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KitColors.warningDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The row's action: archive, which asks first in a window, or restore, which
/// is one tap because it only gives back what was there (`DL-101` (2)).
class _RowAction extends ConsumerWidget {
  const _RowAction({required this.product});

  final AdminProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy = ref.watch(
      productListActionsProvider.select((state) => state.isBusy),
    );
    final ProductListActions actions = ref.read(
      productListActionsProvider.notifier,
    );
    final bool archived = product.state == CatalogEntryState.archived;
    final String label = archived ? l10n.catalogRestore : l10n.catalogArchive;
    VoidCallback? onTap;
    if (!busy) {
      onTap = archived
          ? () => actions.restore(product.id)
          : () => showArchiveDialog(
              context,
              title: l10n.productArchiveTitle,
              explanation: l10n.productArchiveExplained,
              subject: _ProductIdentity(product: product, size: 44),
              state: productListActionsProvider,
              archive: () async => await actions.archive(product.id) != null,
            );
    }

    return PanelActionButton(
      buttonKey: ValueKey<String>(
        '${archived ? 'restore' : 'archive'}-${product.id}',
      ),
      icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
      tooltip: label,
      onTap: onTap,
    );
  }
}
