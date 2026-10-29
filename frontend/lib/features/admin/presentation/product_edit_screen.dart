import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_fields.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'admin_paths.dart';
import 'catalog_form_rules.dart';
import 'catalog_image_card.dart';
import 'catalog_widgets.dart';

/// One product's page: its form in three cards, and its picture beside them
/// once it exists (`docs/09-api-contracts.md` sections 15 and 16). With no
/// [productId] it creates a product and then moves to the new product's page,
/// where the picture can be added.
class ProductEditScreen extends ConsumerWidget {
  const ProductEditScreen({required this.productId, super.key});

  /// The page content's width from which the picture stands at the right of
  /// the form; below it the picture is above the form, smaller.
  static const double twoColumnsWidth = 1000;

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? id = productId;
    final AsyncValue<List<AdminCategory>> categories = ref.watch(
      categoryOptionsProvider,
    );

    final AsyncValue<AdminProduct>? product = id == null
        ? null
        : ref.watch(productProvider(id));

    final Widget body = switch ((id, categories)) {
      (_, AsyncError(:final Object error)) => LoadFailure(
        error: error,
        onRetry: () => ref.invalidate(categoryOptionsProvider),
      ),
      (_, AsyncData(:final List<AdminCategory> value)) when id == null =>
        _TwoColumns(
          key: const ValueKey<String>('new-product-columns'),
          form: _ProductForm(product: null, categories: value),
          picture: (bool compact) => CatalogImagePlaceholder(
            title: l10n.productImage,
            text: l10n.productImageAfterSave,
            compact: compact,
            onCard: true,
          ),
        ),
      (final String id, AsyncData(:final List<AdminCategory> value)) =>
        product!.when(
          skipLoadingOnReload: true,
          // A retry after a failed load shows progress; a reload after a
          // save keeps the form, which holds the Admin's edits.
          skipLoadingOnRefresh: !product.hasError,
          data: (AdminProduct product) => _TwoColumns(
            key: ValueKey<String>('product-columns-$id'),
            form: _ProductForm(
              key: ValueKey<String>(product.id),
              product: product,
              categories: value,
            ),
            picture: (bool compact) =>
                _ProductImageCard(product: product, compact: compact),
          ),
          error: (Object error, StackTrace _) => LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(productProvider(id)),
          ),
          loading: () => const _Loading(),
        ),
      _ => const _Loading(),
    };

    return ListView(
      padding: panelPagePadding(MediaQuery.sizeOf(context).width),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey<String>('back-to-products'),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(l10n.productBackToList),
            onPressed: () => context.go(AdminPaths.products),
          ),
        ),
        const SizedBox(height: 8),
        _Heading(
          isNew: id == null,
          product: product?.value,
          categories: categories.value,
        ),
        const SizedBox(height: 20),
        body,
      ],
    );
  }
}

/// The page's title: the saved product's name with its state and its tag, and
/// under it the other language's name and the category.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.isNew,
    required this.product,
    required this.categories,
  });

  /// The page makes a new product; a page of a product that has not loaded
  /// has no title to show.
  final bool isNew;
  final AdminProduct? product;
  final List<AdminCategory>? categories;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AdminProduct? product = this.product;
    AdminCategory? category;
    for (final AdminCategory candidate in categories ?? <AdminCategory>[]) {
      if (candidate.id == product?.categoryId) {
        category = candidate;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (product != null || isNew)
              Text(
                product == null
                    ? l10n.productNew
                    : catalogName(
                        context,
                        uz: product.nameUz,
                        ru: product.nameRu,
                      ),
                key: const ValueKey<String>('product-title'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            if (product != null) CatalogStateChip(product.state),
            if (product != null && product.isFeatured) const FeaturedTag(),
          ],
        ),
        if (product != null && category != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            '${catalogOtherName(context, uz: product.nameUz, ru: product.nameRu)}'
            ' · '
            '${catalogName(context, uz: category.nameUz, ru: category.nameRu)}',
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
        ],
      ],
    );
  }
}

/// The form with the picture at its right from [ProductEditScreen.
/// twoColumnsWidth], and the compact picture above it below that.
///
/// Crossing that width moves the two between a row and a column. Each keeps a
/// [GlobalKey] of its own, so the form's unsaved edits and a picked picture
/// survive the move (a rotated tablet, a resized window). The keys live as
/// long as this widget's state, which the screen gives a new key when the
/// product changes.
class _TwoColumns extends StatefulWidget {
  const _TwoColumns({required this.form, required this.picture, super.key});

  final Widget form;
  final Widget Function(bool compact) picture;

  @override
  State<_TwoColumns> createState() => _TwoColumnsState();
}

class _TwoColumnsState extends State<_TwoColumns> {
  final GlobalKey _formKey = GlobalKey(debugLabel: 'product form');
  final GlobalKey _pictureKey = GlobalKey(debugLabel: 'product picture');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide =
            constraints.maxWidth >= ProductEditScreen.twoColumnsWidth;
        final Widget form = KeyedSubtree(key: _formKey, child: widget.form);
        final Widget picture = KeyedSubtree(
          key: _pictureKey,
          child: widget.picture(!wide),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: form),
              const SizedBox(width: 20),
              SizedBox(width: 360, child: picture),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[picture, const SizedBox(height: 16), form],
        );
      },
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({
    required this.product,
    required this.categories,
    super.key,
  });

  final AdminProduct? product;
  final List<AdminCategory> categories;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _nameUz = TextEditingController();
  final TextEditingController _nameRu = TextEditingController();
  final TextEditingController _descriptionUz = TextEditingController();
  final TextEditingController _descriptionRu = TextEditingController();
  final TextEditingController _marketPrice = TextEditingController();
  final TextEditingController _sortOrder = TextEditingController();
  String? _categoryId;
  UnitCode _unit = UnitCode.kg;
  bool _featured = false;
  bool _active = true;
  Set<String> _rejected = <String>{};

  /// The product the fields were last filled from. An edit is compared with
  /// it, so a save sends only what the Admin changed (`DL-28` (9)).
  AdminProduct? _base;

  /// What the last fill put in the fields, to tell unsaved edits apart.
  List<Object?> _filled = const <Object?>[];

  /// Counts the fills: the dropdowns keep their own value, so they start
  /// over with each fill.
  int _fills = 0;

  bool get _archived => widget.product?.state == CatalogEntryState.archived;

  @override
  void initState() {
    super.initState();
    _fill(widget.product);
  }

  @override
  void didUpdateWidget(_ProductForm old) {
    super.didUpdateWidget(old);
    // A reload — after a save, an image change or a conflict — brings the
    // product as the server has it now. The form follows it unless the
    // Admin has unsaved edits, which stay (`DL-28` (9)).
    final AdminProduct? product = widget.product;
    if (product != null &&
        product != old.product &&
        listEquals(_fieldValues(), _filled)) {
      _fill(product);
    }
  }

  void _fill(AdminProduct? p) {
    _base = p;
    _nameUz.text = p?.nameUz ?? '';
    _nameRu.text = p?.nameRu ?? '';
    _descriptionUz.text = p?.descriptionUz ?? '';
    _descriptionRu.text = p?.descriptionRu ?? '';
    _marketPrice.text = p == null ? '' : MoneyFormat.grouped(p.marketPriceUzs);
    _sortOrder.text = '${p?.sortOrder ?? 0}';
    _categoryId = p?.categoryId;
    _unit = p?.unitCode ?? UnitCode.kg;
    _featured = p?.isFeatured ?? false;
    _active = p?.isActive ?? true;
    _rejected = <String>{};
    _filled = _fieldValues();
    _fills++;
  }

  List<Object?> _fieldValues() => <Object?>[
    _nameUz.text,
    _nameRu.text,
    _descriptionUz.text,
    _descriptionRu.text,
    _marketPrice.text,
    _sortOrder.text,
    _categoryId,
    _unit,
    _featured,
    _active,
  ];

  @override
  void dispose() {
    _nameUz.dispose();
    _nameRu.dispose();
    _descriptionUz.dispose();
    _descriptionRu.dispose();
    _marketPrice.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  /// The categories a product may be placed in: the unarchived ones, and the
  /// product's own even if archived since, which an edit may re-send
  /// (`DL-20` (4)).
  List<AdminCategory> get _choices => <AdminCategory>[
    for (final AdminCategory category in widget.categories)
      if (category.archivedAt == null ||
          category.id == widget.product?.categoryId)
        category,
  ];

  Future<void> _submit() async {
    _rejected = <String>{};
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    final String savedText = AppLocalizations.of(context).productSaved;
    final AdminProduct? base = _base;
    final AdminProduct? saved = await ref
        .read(productFormControllerProvider.notifier)
        .save(
          base,
          ProductDraft(
            categoryId: _categoryId!,
            nameUz: _nameUz.text.trim(),
            nameRu: _nameRu.text.trim(),
            descriptionUz: CatalogFormRules.optional(_descriptionUz.text),
            descriptionRu: CatalogFormRules.optional(_descriptionRu.text),
            unitCode: _unit,
            marketPriceUzs: CatalogFormRules.marketPriceValue(
              _marketPrice.text,
            ),
            sortOrder: CatalogFormRules.sortOrderValue(_sortOrder.text),
            isFeatured: _featured,
            isActive: _archived ? null : _active,
          ),
        );

    // The Admin may have left the page while the save ran; what they went
    // to stays on screen.
    if (!mounted) {
      return;
    }
    if (saved == null) {
      _rejected = rejectedFields(
        ref.read(productFormControllerProvider).failure,
      );
      _form.currentState?.validate();
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(savedText)));
    if (base == null) {
      // The new product's page takes the empty form's place, in the
      // browser's history too.
      Router.neglect(
        context,
        () => GoRouter.of(context).go(AdminPaths.product(saved.id)),
      );
    } else {
      setState(() => _fill(saved));
    }
  }

  /// The category the form has chosen, among all the categories.
  AdminCategory? get _chosenCategory {
    for (final AdminCategory category in widget.categories) {
      if (category.id == _categoryId) {
        return category;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language =
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
        AppLanguage.uz;
    final MutationState change = ref.watch(productFormControllerProvider);
    final AdminProduct? product = _base ?? widget.product;

    String? rejected(String apiKey) =>
        _rejected.contains(apiKey) ? l10n.fieldRejected : null;

    Widget field(
      String apiKey,
      TextEditingController controller,
      String label,
      String? Function(String text) rule, {
      int maxLines = 1,
      int? maxLength,
      String? helper,
      String? suffix,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: KitLabeledField(
          label: label,
          field: TextFormField(
            key: ValueKey<String>('field-$apiKey'),
            controller: controller,
            enabled: !change.isBusy,
            minLines: maxLines == 1 ? 1 : 3,
            maxLines: maxLines,
            maxLength: maxLength,
            maxLengthEnforcement: maxLength == null
                ? null
                : MaxLengthEnforcement.none,
            style: const TextStyle(fontSize: 13, color: KitColors.ink),
            decoration: panelFieldDecoration(helper: helper, suffix: suffix),
            onChanged: (String _) => _rejected.remove(apiKey),
            validator: (String? text) => rule(text ?? '') ?? rejected(apiKey),
          ),
        ),
      );
    }

    String nameOf(AdminCategory category) =>
        catalogName(context, uz: category.nameUz, ru: category.nameRu);

    final InputDecoration selectDecoration = panelFieldDecoration();
    final AdminCategory? chosen = _chosenCategory;
    final String? categoryNote = _archived || !_active || chosen == null
        ? null
        : switch (chosen.state) {
            CatalogEntryState.active => null,
            CatalogEntryState.hidden => l10n.productCategoryHiddenNote(
              nameOf(chosen),
            ),
            CatalogEntryState.archived => l10n.productCategoryArchivedNote(
              nameOf(chosen),
            ),
          };

    final List<Widget> shownRows = <Widget>[
      if (_archived)
        CatalogShownRow(
          child: KitNote(
            icon: Icons.inventory_2_outlined,
            tone: KitTone.grey,
            text: Text(
              l10n.catalogArchivedNote,
              style: const TextStyle(fontSize: 12, color: KitColors.ink2),
            ),
          ),
        )
      else
        CatalogSwitchRow(
          switchKey: const ValueKey<String>('field-is_active'),
          title: l10n.catalogShownToCustomers,
          hint: l10n.productShownHint,
          value: _active,
          onChanged: change.isBusy
              ? null
              : (bool value) => setState(() => _active = value),
        ),
      if (categoryNote != null)
        CatalogShownRow(
          child: KitNote(
            key: const ValueKey<String>('product-category-note'),
            icon: Icons.info_outline,
            tone: KitTone.amber,
            text: Text(
              categoryNote,
              style: const TextStyle(
                fontSize: 12,
                color: KitColors.warningDark,
              ),
            ),
          ),
        ),
      CatalogSwitchRow(
        switchKey: const ValueKey<String>('field-is_featured'),
        title: l10n.productFeatured,
        hint: l10n.productFeaturedHint,
        value: _featured,
        onChanged: change.isBusy
            ? null
            : (bool value) => setState(() => _featured = value),
      ),
    ];

    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        key: ValueKey<int>(_fills),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PanelCard(
            title: l10n.productSectionMain,
            children: <Widget>[
              const SizedBox(height: 16),
              SideBySide(
                first: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: KitLabeledField(
                    label: l10n.productCategory,
                    field: DropdownButtonFormField<String>(
                      key: const ValueKey<String>('field-category_id'),
                      isExpanded: true,
                      initialValue: _categoryId,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KitColors.ink,
                      ),
                      decoration: selectDecoration,
                      items: <DropdownMenuItem<String>>[
                        for (final AdminCategory category in _choices)
                          DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(
                              nameOf(category),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: change.isBusy
                          ? null
                          : (String? id) {
                              _rejected.remove('category_id');
                              setState(() => _categoryId = id);
                            },
                      validator: (String? id) =>
                          (id == null ? l10n.fieldRequired : null) ??
                          rejected('category_id'),
                    ),
                  ),
                ),
                second: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: KitLabeledField(
                    label: l10n.productUnit,
                    field: DropdownButtonFormField<UnitCode>(
                      key: const ValueKey<String>('field-unit_code'),
                      isExpanded: true,
                      initialValue: _unit,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KitColors.ink,
                      ),
                      decoration: selectDecoration,
                      items: <DropdownMenuItem<UnitCode>>[
                        for (final UnitCode unit in UnitCode.values)
                          DropdownMenuItem<UnitCode>(
                            value: unit,
                            child: Text(CatalogLabels.unit(l10n, unit)),
                          ),
                      ],
                      onChanged: change.isBusy
                          ? null
                          : (UnitCode? unit) =>
                                setState(() => _unit = unit ?? _unit),
                    ),
                  ),
                ),
              ),
              SideBySide(
                first: field(
                  'name_uz',
                  _nameUz,
                  l10n.catalogNameUz,
                  (String text) => CatalogFormRules.name(
                    l10n,
                    text,
                    CatalogFormRules.productNameMax,
                  ),
                ),
                second: field(
                  'name_ru',
                  _nameRu,
                  l10n.catalogNameRu,
                  (String text) => CatalogFormRules.name(
                    l10n,
                    text,
                    CatalogFormRules.productNameMax,
                  ),
                ),
              ),
              SideBySide(
                first: field(
                  'description_uz',
                  _descriptionUz,
                  l10n.catalogDescriptionUz,
                  (String text) => CatalogFormRules.description(l10n, text),
                  maxLines: 4,
                  maxLength: 2000,
                  helper: l10n.catalogOptional,
                ),
                second: field(
                  'description_ru',
                  _descriptionRu,
                  l10n.catalogDescriptionRu,
                  (String text) => CatalogFormRules.description(l10n, text),
                  maxLines: 4,
                  maxLength: 2000,
                  helper: l10n.catalogOptional,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PanelCard(
            title: l10n.productSectionPrice,
            children: <Widget>[
              const SizedBox(height: 4),
              Text(
                l10n.productMarkupNote,
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
              const SizedBox(height: 16),
              SideBySide(
                first: field(
                  'market_price_uzs',
                  _marketPrice,
                  l10n.productMarketPrice,
                  (String text) => CatalogFormRules.marketPrice(l10n, text),
                  suffix: MoneyFormat.currency(language),
                  helper: l10n.productPriceHint(
                    CatalogLabels.unit(l10n, _unit),
                  ),
                ),
                second: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CustomerPriceBox(
                    key: const ValueKey<String>('customer-price'),
                    product: product,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PanelCard(
            title: l10n.productSectionShown,
            children: <Widget>[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: field(
                    'sort_order',
                    _sortOrder,
                    l10n.catalogSortOrder,
                    (String text) => CatalogFormRules.sortOrder(l10n, text),
                    helper: l10n.catalogSortOrderHint,
                  ),
                ),
              ),
              for (final Widget row in shownRows) ...<Widget>[
                const Divider(height: 1, thickness: 1, color: KitColors.line),
                row,
              ],
            ],
          ),
          const SizedBox(height: 16),
          FailureMessage(change.failure),
          KitCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const ValueKey<String>('product-save'),
                style: kitFilled(height: 46),
                onPressed: change.isBusy ? null : _submit,
                child: Text(l10n.saveButton),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The price Customers see, as the server computed it for the saved market
/// price. It is not recomputed while the Admin types: the markup is the
/// server's (`BR-PRICE-001`).
class _CustomerPriceBox extends StatelessWidget {
  const _CustomerPriceBox({required this.product, super.key});

  final AdminProduct? product;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language =
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
        AppLanguage.uz;
    final AdminProduct? product = this.product;

    if (product == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            l10n.productCustomerPriceLater,
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primaryWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.productCustomerPriceTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KitColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                Text(
                  MoneyFormat.uzs(product.customerUnitPriceUzs, language),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
                Text(
                  l10n.catalogPerUnit(
                    CatalogLabels.unit(l10n, product.unitCode),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.productCustomerPriceBasis(
                MoneyFormat.uzs(product.marketPriceUzs, language),
              ),
              style: const TextStyle(fontSize: 11, color: KitColors.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

/// The product's picture, through the card the category dialog shares.
class _ProductImageCard extends ConsumerWidget {
  const _ProductImageCard({required this.product, required this.compact});

  final AdminProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProductImageController images = ref.read(
      productImageControllerProvider.notifier,
    );
    return CatalogImageCard(
      imageUrl: product.imageUrl,
      onUpload: (PickedImage image) => images.upload(product.id, image),
      onRemove: () => images.remove(product.id),
      change: ref.watch(productImageControllerProvider),
      keyPrefix: '',
      compact: compact,
      onCard: true,
      compactPictureSize: 120,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
