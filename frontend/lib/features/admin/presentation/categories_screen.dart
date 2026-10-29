import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/paged.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_dialog.dart';
import '../../../core/widgets/kit/kit_fields.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/panel/panel_action_button.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_filter_chip.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/panel/panel_page_header.dart';
import '../../../core/widgets/panel/panel_pager.dart';
import '../../../core/widgets/panel/panel_table.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'catalog_archive_dialog.dart';
import 'catalog_form_rules.dart';
import 'catalog_image_card.dart';
import 'catalog_widgets.dart';

/// The Admin's categories (`docs/09-api-contracts.md` section 15): the
/// paginated list, archived entries on request, a window to create or edit one
/// with both languages side by side, and archive, which asks first, and
/// restore (`DL-101` (5)). It is a table from a card [tableWidth] wide and
/// cards below it.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  /// From this card width the categories are a table whose columns all show;
  /// below it, cards, which show the same.
  static const double tableWidth = 560;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CategoryQuery query = ref.watch(categoryQueryProvider);
    final AsyncValue<Paged<AdminCategory>> page = ref.watch(
      categoryPageProvider,
    );
    final MutationState actions = ref.watch(categoryListActionsProvider);
    final EdgeInsets padding = panelPagePadding(
      MediaQuery.sizeOf(context).width,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool labelled =
            constraints.maxWidth - padding.horizontal >= 480 &&
            !kitLargeText(context);

        return ListView(
          padding: padding,
          children: <Widget>[
            PanelPageHeader(
              title: l10n.adminSectionCategories,
              subtitle: page.hasValue
                  ? l10n.catalogCategoryCount(page.requireValue.total)
                  : null,
              trailing: PanelHeaderButton(
                buttonKey: const ValueKey<String>('new-category'),
                icon: Icons.add,
                label: l10n.categoryNew,
                labelled: labelled,
                onPressed: () => showCategoryForm(context, null),
              ),
            ),
            const SizedBox(height: 20),
            PanelCard(
              flush: true,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FailureMessage(actions.failure),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PanelFilterChip(
                      chipKey: 'include-archived',
                      icon: query.includeArchived
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      label: l10n.catalogIncludeArchived,
                      selected: query.includeArchived,
                      onTap: () => ref
                          .read(categoryQueryProvider.notifier)
                          .includeArchived(!query.includeArchived),
                    ),
                  ),
                ),
                page.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: !page.hasError,
                  data: (Paged<AdminCategory> page) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (page.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.catalogEmpty),
                        )
                      else
                        LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) =>
                                  constraints.maxWidth >=
                                      CategoriesScreen.tableWidth
                                  ? _CategoriesTable(
                                      categories: page.items,
                                      busy: actions.isBusy,
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
                                          for (final AdminCategory category
                                              in page.items)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _CategoryCard(
                                                category: category,
                                                busy: actions.isBusy,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                        ),
                      PanelPager(
                        page: page,
                        onPage: ref
                            .read(categoryQueryProvider.notifier)
                            .goToPage,
                      ),
                    ],
                  ),
                  error: (Object error, StackTrace _) => LoadFailure(
                    error: error,
                    onRetry: () => ref.invalidate(categoryPageProvider),
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

const Map<int, TableColumnWidth> _columns = <int, TableColumnWidth>{
  0: FlexColumnWidth(3),
  1: FlexColumnWidth(1),
  2: FlexColumnWidth(2),
  3: FixedColumnWidth(104),
};

TextStyle _nameStyle(bool archived) => TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: archived ? KitColors.muted : KitColors.ink,
);

const TextStyle _small = TextStyle(fontSize: 12, color: KitColors.muted);

/// The table: rows of [PanelTable] under the categories' column widths.
class _CategoriesTable extends StatelessWidget {
  const _CategoriesTable({required this.categories, required this.busy});

  final List<AdminCategory> categories;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PanelTable(
      columns: <PanelColumn>[
        (label: l10n.productCategory, width: _columns[0]!, end: false),
        (label: l10n.catalogSortOrder, width: _columns[1]!, end: false),
        (label: l10n.catalogColumnShown, width: _columns[2]!, end: false),
        (label: '', width: _columns[3]!, end: true),
      ],
      rows: <PanelTableRow>[
        for (final AdminCategory category in categories)
          _categoryRow(context, category, busy),
      ],
    );
  }
}

PanelTableRow _categoryRow(
  BuildContext context,
  AdminCategory category,
  bool busy,
) {
  final bool archived = category.state == CatalogEntryState.archived;

  return PanelTableRow(
    key: ValueKey<String>('category-${category.id}'),
    onTap: busy ? null : () => showCategoryForm(context, category),
    lastCellPadding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
    cells: <Widget>[
      _CategoryIdentity(category: category, size: 44),
      Text(
        '${category.sortOrder}',
        style: TextStyle(
          fontSize: 13,
          color: archived ? KitColors.muted : KitColors.ink2,
        ),
      ),
      CatalogStateChip(category.state),
      _CategoryActions(category: category, busy: busy),
    ],
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.busy});

  final AdminCategory category;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool archived = category.state == CatalogEntryState.archived;

    return KitCard(
      key: ValueKey<String>('category-${category.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: busy ? null : () => showCategoryForm(context, category),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Opacity(
            opacity: archived ? 0.5 : 1,
            child: _CategoryThumb(category: category, size: 56),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CategoryNames(category: category),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    CatalogStateChip(category.state),
                    Text(
                      '${l10n.catalogSortOrder}: ${category.sortOrder}',
                      style: _small,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CategoryActions(category: category, busy: busy),
        ],
      ),
    );
  }
}

/// The category's picture, or its first letter when it has none.
class _CategoryThumb extends StatelessWidget {
  const _CategoryThumb({required this.category, required this.size});

  final AdminCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CatalogThumb(
      key: ValueKey<String>('category-thumb-${category.id}'),
      url: category.imageUrl,
      size: size,
      letter: catalogName(
        context,
        uz: category.nameUz,
        ru: category.nameRu,
      ).characters.first.toUpperCase(),
    );
  }
}

/// The name in the panel's language over the other one, smaller.
class _CategoryNames extends StatelessWidget {
  const _CategoryNames({required this.category});

  final AdminCategory category;

  @override
  Widget build(BuildContext context) {
    final bool archived = category.state == CatalogEntryState.archived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          catalogName(context, uz: category.nameUz, ru: category.nameRu),
          style: _nameStyle(archived),
        ),
        Text(
          catalogOtherName(context, uz: category.nameUz, ru: category.nameRu),
          style: _small,
        ),
      ],
    );
  }
}

/// The picture with the two names beside it.
class _CategoryIdentity extends StatelessWidget {
  const _CategoryIdentity({required this.category, required this.size});

  final AdminCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool archived = category.state == CatalogEntryState.archived;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Opacity(
          opacity: archived ? 0.5 : 1,
          child: _CategoryThumb(category: category, size: size),
        ),
        const SizedBox(width: 12),
        Flexible(child: _CategoryNames(category: category)),
      ],
    );
  }
}

/// A row's two actions: edit, which opens the window as the row does, and
/// archive, which asks first in a window, or restore, which is one tap because
/// it only gives back what was there (`DL-101` (5)).
class _CategoryActions extends ConsumerWidget {
  const _CategoryActions({required this.category, required this.busy});

  final AdminCategory category;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CategoryListActions actions = ref.read(
      categoryListActionsProvider.notifier,
    );
    final bool archived = category.state == CatalogEntryState.archived;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PanelActionButton(
          buttonKey: ValueKey<String>('edit-${category.id}'),
          tooltip: l10n.catalogEdit,
          icon: Icons.edit_outlined,
          onTap: busy ? null : () => showCategoryForm(context, category),
        ),
        PanelActionButton(
          buttonKey: ValueKey<String>(
            '${archived ? 'restore' : 'archive'}-${category.id}',
          ),
          tooltip: archived ? l10n.catalogRestore : l10n.catalogArchive,
          icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          onTap: busy
              ? null
              : archived
              ? () => actions.restore(category.id)
              : () => showArchiveDialog(
                  context,
                  title: l10n.categoryArchiveTitle,
                  explanation: l10n.categoryArchiveExplained,
                  subject: _CategoryIdentity(category: category, size: 44),
                  state: categoryListActionsProvider,
                  archive: () async =>
                      await actions.archive(category.id) != null,
                ),
        ),
      ],
    );
  }
}

/// Opens the category window: empty for a new category, filled for
/// [category].
///
/// The window stays open while its save runs — neither a tap outside nor
/// Escape closes it then — and closes itself with what the server stored,
/// which the caller confirms once it is still on screen. A tap outside never
/// closes it, so a half-filled form is not lost (`DL-28` (10)).
Future<void> showCategoryForm(
  BuildContext context,
  AdminCategory? category,
) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final AdminCategory? saved = await showKitDialog<AdminCategory>(
    context: context,
    dialogKey: 'category-dialog',
    maxWidth: 720,
    barrierDismissible: false,
    title: category == null ? l10n.categoryNew : l10n.categoryEditTitle,
    subtitle: category == null
        ? null
        : catalogName(context, uz: category.nameUz, ru: category.nameRu),
    builder: (BuildContext context) => _CategoryForm(category: category),
  );
  if (saved != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).categorySaved)),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({required this.category});

  final AdminCategory? category;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _nameUz;
  late final TextEditingController _nameRu;
  late final TextEditingController _descriptionUz;
  late final TextEditingController _descriptionRu;
  late final TextEditingController _sortOrder;
  late bool _active;
  Set<String> _rejected = <String>{};
  late String? _imageUrl;

  bool get _archived => widget.category?.state == CatalogEntryState.archived;

  @override
  void initState() {
    super.initState();
    final AdminCategory? c = widget.category;
    _nameUz = TextEditingController(text: c?.nameUz ?? '');
    _nameRu = TextEditingController(text: c?.nameRu ?? '');
    _descriptionUz = TextEditingController(text: c?.descriptionUz ?? '');
    _descriptionRu = TextEditingController(text: c?.descriptionRu ?? '');
    _sortOrder = TextEditingController(text: '${c?.sortOrder ?? 0}');
    _active = c?.isActive ?? true;
    _imageUrl = c?.imageUrl;
  }

  @override
  void dispose() {
    _nameUz.dispose();
    _nameRu.dispose();
    _descriptionUz.dispose();
    _descriptionRu.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _rejected = <String>{};
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    final AdminCategory? category = widget.category;
    final CategoryDraft draft = CategoryDraft(
      nameUz: _nameUz.text.trim(),
      nameRu: _nameRu.text.trim(),
      descriptionUz: CatalogFormRules.optional(_descriptionUz.text),
      descriptionRu: CatalogFormRules.optional(_descriptionRu.text),
      sortOrder: CatalogFormRules.sortOrderValue(_sortOrder.text),
      isActive: _archived ? null : _active,
    );
    final AdminCategory? saved = await ref
        .read(categoryFormControllerProvider.notifier)
        .save(category, draft);

    if (!mounted) {
      return;
    }
    if (saved != null) {
      Navigator.of(context).pop(saved);
      return;
    }
    _rejected = rejectedFields(
      ref.read(categoryFormControllerProvider).failure,
    );
    _form.currentState?.validate();
  }

  Future<void> _uploadImage(PickedImage image) async {
    final AdminCategory? saved = await ref
        .read(categoryImageControllerProvider.notifier)
        .upload(widget.category!.id, image);
    if (mounted && saved != null) {
      setState(() => _imageUrl = saved.imageUrl);
    }
  }

  Future<void> _removeImage() async {
    final AdminCategory? saved = await ref
        .read(categoryImageControllerProvider.notifier)
        .remove(widget.category!.id);
    if (mounted && saved != null) {
      setState(() => _imageUrl = saved.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState saving = ref.watch(categoryFormControllerProvider);
    final MutationState imageChange = ref.watch(
      categoryImageControllerProvider,
    );
    final MutationState change = saving.isBusy || !imageChange.isBusy
        ? saving
        : imageChange;

    Widget field(
      String apiKey,
      TextEditingController controller,
      String label,
      String? Function(String text) rule, {
      int maxLines = 1,
      int? maxLength,
      String? helper,
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
            decoration: panelFieldDecoration(helper: helper),
            onChanged: (String _) => _rejected.remove(apiKey),
            validator: (String? text) =>
                rule(text ?? '') ??
                (_rejected.contains(apiKey) ? l10n.fieldRejected : null),
          ),
        ),
      );
    }

    final Widget cancel = OutlinedButton(
      key: const ValueKey<String>('category-cancel'),
      style: kitOutlined(height: 48),
      onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
      child: Text(l10n.cancelButton),
    );
    final Widget save = FilledButton(
      key: const ValueKey<String>('category-save'),
      style: kitFilled(height: 48),
      onPressed: change.isBusy ? null : _submit,
      child: Text(l10n.saveButton),
    );

    return PopScope(
      canPop: !change.isBusy,
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SideBySide(
              first: field(
                'name_uz',
                _nameUz,
                l10n.catalogNameUz,
                (String text) => CatalogFormRules.name(
                  l10n,
                  text,
                  CatalogFormRules.categoryNameMax,
                ),
              ),
              second: field(
                'name_ru',
                _nameRu,
                l10n.catalogNameRu,
                (String text) => CatalogFormRules.name(
                  l10n,
                  text,
                  CatalogFormRules.categoryNameMax,
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
            SideBySide(
              first: field(
                'sort_order',
                _sortOrder,
                l10n.catalogSortOrder,
                (String text) => CatalogFormRules.sortOrder(l10n, text),
                helper: l10n.catalogSortOrderHint,
              ),
              second: const SizedBox.shrink(),
            ),
            const Divider(height: 1, thickness: 1, color: KitColors.line),
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
                hint: l10n.categoryShownHint,
                value: _active,
                onChanged: change.isBusy
                    ? null
                    : (bool value) => setState(() => _active = value),
              ),
            const Divider(height: 1, thickness: 1, color: KitColors.line),
            const SizedBox(height: 16),
            if (widget.category == null)
              CatalogImagePlaceholder(
                title: l10n.categoryImage,
                text: l10n.categoryImageAfterSave,
                compact: true,
              )
            else
              CatalogImageCard(
                imageUrl: _imageUrl,
                onUpload: _uploadImage,
                onRemove: _removeImage,
                change: imageChange,
                keyPrefix: 'category-',
                compact: true,
                removeExplained: l10n.categoryRemoveImageExplained,
                title: l10n.categoryImage,
                removeConfirm: l10n.categoryRemoveImageConfirm,
              ),
            FailureMessage(saving.failure),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= 480 && !kitLargeText(context)) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      SizedBox(width: 160, child: cancel),
                      const SizedBox(width: 12),
                      SizedBox(width: 160, child: save),
                    ],
                  );
                }
                return KitActionPair(secondary: cancel, primary: save);
              },
            ),
          ],
        ),
      ),
    );
  }
}
