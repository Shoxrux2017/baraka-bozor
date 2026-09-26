import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/paged.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'catalog_form_rules.dart';
import 'catalog_widgets.dart';

/// The Admin's categories (`docs/09-api-contracts.md` section 15): the
/// paginated list, archived entries on request, a form to create or edit one
/// with both languages side by side, and archive and restore.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CategoryQuery query = ref.watch(categoryQueryProvider);
    final AsyncValue<Paged<AdminCategory>> page = ref.watch(
      categoryPageProvider,
    );
    final MutationState actions = ref.watch(categoryListActionsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              l10n.adminSectionCategories,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilterChip(
              key: const ValueKey<String>('include-archived'),
              label: Text(l10n.catalogIncludeArchived),
              selected: query.includeArchived,
              onSelected: ref
                  .read(categoryQueryProvider.notifier)
                  .includeArchived,
            ),
            FilledButton.icon(
              key: const ValueKey<String>('new-category'),
              icon: const Icon(Icons.add),
              label: Text(l10n.categoryNew),
              onPressed: () => showCategoryForm(context, null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FailureMessage(actions.failure),
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
                ),
              for (final AdminCategory category in page.items)
                _CategoryRow(category: category, busy: actions.isBusy),
              PaginationBar(
                page: page,
                onPage: ref.read(categoryQueryProvider.notifier).goToPage,
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
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.category, required this.busy});

  final AdminCategory category;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CategoryListActions actions = ref.read(
      categoryListActionsProvider.notifier,
    );
    final bool archived = category.state == CatalogEntryState.archived;

    return Card(
      child: ListTile(
        key: ValueKey<String>('category-${category.id}'),
        title: Text('${category.nameUz} · ${category.nameRu}'),
        subtitle: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            EntryStateChip(category.state),
            Text('${l10n.catalogSortOrder}: ${category.sortOrder}'),
          ],
        ),
        trailing: Wrap(
          children: <Widget>[
            IconButton(
              key: ValueKey<String>('edit-${category.id}'),
              tooltip: l10n.catalogEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy
                  ? null
                  : () => showCategoryForm(context, category),
            ),
            IconButton(
              key: ValueKey<String>(
                '${archived ? 'restore' : 'archive'}-${category.id}',
              ),
              tooltip: archived ? l10n.catalogRestore : l10n.catalogArchive,
              icon: Icon(
                archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              onPressed: busy
                  ? null
                  : () => archived
                        ? actions.restore(category.id)
                        : actions.archive(category.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the category form: empty for a new category, filled for [category].
///
/// The dialog stays open while its save runs — neither a tap outside nor
/// Escape closes it then — and closes itself with what the server stored,
/// which the caller confirms once it is still on screen.
Future<void> showCategoryForm(
  BuildContext context,
  AdminCategory? category,
) async {
  final AdminCategory? saved = await showDialog<AdminCategory>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _CategoryDialog(category: category),
  );
  if (saved != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).categorySaved)),
    );
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({required this.category});

  final AdminCategory? category;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _nameUz;
  late final TextEditingController _nameRu;
  late final TextEditingController _descriptionUz;
  late final TextEditingController _descriptionRu;
  late final TextEditingController _sortOrder;
  late bool _active;
  Set<String> _rejected = <String>{};

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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(categoryFormControllerProvider);

    Widget field(
      String apiKey,
      TextEditingController controller,
      String label,
      String? Function(String text) rule, {
      int maxLines = 1,
      String? helper,
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
            border: const OutlineInputBorder(),
          ),
          onChanged: (String _) => _rejected.remove(apiKey),
          validator: (String? text) =>
              rule(text ?? '') ??
              (_rejected.contains(apiKey) ? l10n.fieldRejected : null),
        ),
      );
    }

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        title: Text(
          widget.category == null ? l10n.categoryNew : l10n.categoryEditTitle,
        ),
        content: SizedBox(
          width: 720,
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
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
                    ),
                    second: field(
                      'description_ru',
                      _descriptionRu,
                      l10n.catalogDescriptionRu,
                      (String text) => CatalogFormRules.description(l10n, text),
                      maxLines: 4,
                    ),
                  ),
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
                  FailureMessage(change.failure),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('category-save'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}
