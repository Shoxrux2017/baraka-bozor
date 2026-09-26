import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'admin_paths.dart';
import 'catalog_form_rules.dart';
import 'catalog_widgets.dart';
import 'products_screen.dart' show ProductThumbnail;

/// One product's page: its form, and its image once it exists
/// (`docs/09-api-contracts.md` sections 15 and 16). With no [productId] it
/// creates a product and then moves to the new product's page, where the
/// image can be added.
class ProductEditScreen extends ConsumerWidget {
  const ProductEditScreen({required this.productId, super.key});

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? id = productId;
    final AsyncValue<List<AdminCategory>> categories = ref.watch(
      categoryOptionsProvider,
    );

    final Widget body = switch ((id, categories)) {
      (_, AsyncError(:final Object error)) => LoadFailure(
        error: error,
        onRetry: () => ref.invalidate(categoryOptionsProvider),
      ),
      (_, AsyncData(:final List<AdminCategory> value)) when id == null =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ProductForm(product: null, categories: value),
            const SizedBox(height: 16),
            Text(l10n.productImageAfterSave),
          ],
        ),
      (final String id, AsyncData(:final List<AdminCategory> value)) =>
        ref
            .watch(productProvider(id))
            .when(
              skipLoadingOnReload: true,
              data: (AdminProduct product) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _ProductForm(
                    key: ValueKey<String>(product.id),
                    product: product,
                    categories: value,
                  ),
                  const SizedBox(height: 24),
                  _ProductImageCard(product: product),
                ],
              ),
              error: (Object error, StackTrace _) => LoadFailure(
                error: error,
                onRetry: () => ref.invalidate(productProvider(id)),
              ),
              loading: () => const _Loading(),
            ),
      _ => const _Loading(),
    };

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey<String>('back-to-products'),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.productBackToList),
                onPressed: () => context.go(AdminPaths.products),
              ),
            ),
            Text(
              id == null ? l10n.productNew : l10n.productEditTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
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
  PriceMode _priceMode = PriceMode.estimate;
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
    _priceMode = p?.priceMode ?? PriceMode.estimate;
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
    _priceMode,
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
            priceMode: _priceMode,
            marketPriceUzs: CatalogFormRules.marketPriceValue(
              _marketPrice.text,
            ),
            sortOrder: CatalogFormRules.sortOrderValue(_sortOrder.text),
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language =
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
        AppLanguage.uz;
    final MutationState change = ref.watch(productFormControllerProvider);
    final AdminProduct? product = widget.product;

    String? rejected(String apiKey) =>
        _rejected.contains(apiKey) ? l10n.fieldRejected : null;

    Widget field(
      String apiKey,
      TextEditingController controller,
      String label,
      String? Function(String text) rule, {
      int maxLines = 1,
      String? helper,
      String? suffix,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey<String>('field-$apiKey'),
          controller: controller,
          enabled: !change.isBusy,
          minLines: maxLines == 1 ? 1 : 2,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
          onChanged: (String _) => _rejected.remove(apiKey),
          validator: (String? text) => rule(text ?? '') ?? rejected(apiKey),
        ),
      );
    }

    String nameOf(AdminCategory category) =>
        language == AppLanguage.ru ? category.nameRu : category.nameUz;

    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        key: ValueKey<int>(_fills),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              key: const ValueKey<String>('field-category_id'),
              isExpanded: true,
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: l10n.productCategory,
                border: const OutlineInputBorder(),
              ),
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
            ),
            second: field(
              'description_ru',
              _descriptionRu,
              l10n.catalogDescriptionRu,
              (String text) => CatalogFormRules.description(l10n, text),
              maxLines: 4,
            ),
          ),
          SideBySide(
            first: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<UnitCode>(
                key: const ValueKey<String>('field-unit_code'),
                isExpanded: true,
                initialValue: _unit,
                decoration: InputDecoration(
                  labelText: l10n.productUnit,
                  border: const OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<UnitCode>>[
                  for (final UnitCode unit in UnitCode.values)
                    DropdownMenuItem<UnitCode>(
                      value: unit,
                      child: Text(CatalogLabels.unit(l10n, unit)),
                    ),
                ],
                onChanged: change.isBusy
                    ? null
                    : (UnitCode? unit) => setState(() => _unit = unit ?? _unit),
              ),
            ),
            second: field(
              'market_price_uzs',
              _marketPrice,
              l10n.productMarketPrice,
              (String text) => CatalogFormRules.marketPrice(l10n, text),
              suffix: MoneyFormat.currency(language),
              helper: product == null
                  ? null
                  : l10n.productCustomerPrice(
                      MoneyFormat.uzs(product.customerUnitPriceUzs, language),
                    ),
            ),
          ),
          Text(l10n.productPriceMode),
          const SizedBox(height: 8),
          SegmentedButton<PriceMode>(
            key: const ValueKey<String>('field-price_mode'),
            segments: <ButtonSegment<PriceMode>>[
              for (final PriceMode mode in PriceMode.values)
                ButtonSegment<PriceMode>(
                  value: mode,
                  label: Text(CatalogLabels.priceMode(l10n, mode)),
                ),
            ],
            selected: <PriceMode>{_priceMode},
            onSelectionChanged: change.isBusy
                ? null
                : (Set<PriceMode> selected) =>
                      setState(() => _priceMode = selected.single),
          ),
          const SizedBox(height: 12),
          field(
            'sort_order',
            _sortOrder,
            l10n.catalogSortOrder,
            (String text) => CatalogFormRules.sortOrder(l10n, text),
            helper: l10n.catalogSortOrderHint,
          ),
          if (_archived)
            Text(l10n.catalogArchivedNote)
          else
            SwitchListTile(
              key: const ValueKey<String>('field-is_active'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.catalogShownToCustomers),
              value: _active,
              onChanged: change.isBusy
                  ? null
                  : (bool value) => setState(() => _active = value),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey<String>('product-save'),
              onPressed: change.isBusy ? null : _submit,
              child: Text(l10n.saveButton),
            ),
          ),
          FailureMessage(change.failure),
        ],
      ),
    );
  }
}

/// The product's image: the current one, a picked one waiting to be sent,
/// the way to choose another and the way to remove it.
class _ProductImageCard extends ConsumerStatefulWidget {
  const _ProductImageCard({required this.product});

  final AdminProduct product;

  @override
  ConsumerState<_ProductImageCard> createState() => _ProductImageCardState();
}

class _ProductImageCardState extends ConsumerState<_ProductImageCard> {
  PickedImage? _picked;
  String? _problem;

  Future<void> _choose() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PickedImage? image;
    try {
      image = await ref.read(productImagePickerProvider).pick();
    } on Object catch (error, stackTrace) {
      // A file moved or deleted after it was chosen cannot be read.
      reportUnexpectedError(error, stackTrace, 'while reading a picked image');
      if (mounted) {
        setState(() {
          _picked = null;
          _problem = l10n.productImageUnreadable;
        });
      }
      return;
    }
    if (!mounted || image == null) {
      return;
    }
    final String? problem = image.isTooLarge
        ? l10n.productImageTooLarge
        : image.looksLikeAcceptedImage
        ? null
        : l10n.productImageWrongType;
    setState(() {
      _problem = problem;
      _picked = problem == null ? image : null;
    });
  }

  Future<void> _upload() async {
    final PickedImage? image = _picked;
    if (image == null) {
      return;
    }
    final AdminProduct? updated = await ref
        .read(productImageControllerProvider.notifier)
        .upload(widget.product.id, image);
    if (mounted && updated != null) {
      setState(() => _picked = null);
    }
  }

  Future<void> _remove() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            content: Text(l10n.productRemoveImageConfirm),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancelButton),
              ),
              FilledButton(
                key: const ValueKey<String>('confirm-remove-image'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.productRemoveImage),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await ref
        .read(productImageControllerProvider.notifier)
        .remove(widget.product.id);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(productImageControllerProvider);
    final PickedImage? picked = _picked;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.productImage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.productImageRules),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: <Widget>[
                ProductThumbnail(
                  key: const ValueKey<String>('current-image'),
                  url: widget.product.imageUrl,
                  size: 160,
                ),
                if (picked != null)
                  ClipRRect(
                    key: const ValueKey<String>('picked-image'),
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      picked.bytes,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (BuildContext context, Object error, StackTrace? _) =>
                              const SizedBox.square(
                                dimension: 160,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('choose-image'),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.productChooseImage),
                  onPressed: change.isBusy ? null : _choose,
                ),
                if (picked != null)
                  FilledButton.icon(
                    key: const ValueKey<String>('upload-image'),
                    icon: const Icon(Icons.upload),
                    label: Text(l10n.productUploadImage),
                    onPressed: change.isBusy ? null : _upload,
                  ),
                if (widget.product.imageUrl != null && picked == null)
                  TextButton.icon(
                    key: const ValueKey<String>('remove-image'),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.productRemoveImage),
                    onPressed: change.isBusy ? null : _remove,
                  ),
              ],
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _problem!,
                  key: const ValueKey<String>('image-problem'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FailureMessage(change.failure),
          ],
        ),
      ),
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
