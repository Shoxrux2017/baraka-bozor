import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/legal_documents_controllers.dart';
import '../domain/legal_documents.dart';

/// The Admin's documents page (`docs/09-api-contracts.md` section 63): the
/// terms of use and the privacy policy, each in Uzbek and Russian, with one
/// publish button per text.
class LegalDocumentsScreen extends ConsumerWidget {
  const LegalDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<LegalDocumentEntry>> documents = ref.watch(
      legalDocumentsControllerProvider,
    );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              l10n.legalDocumentsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            documents.when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: !documents.hasError,
              data: (List<LegalDocumentEntry> entries) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final LegalDocumentKind kind in LegalDocumentKind.values)
                    _DocumentSection(
                      kind: kind,
                      entries: <LegalDocumentEntry>[
                        for (final LegalDocumentEntry entry in entries)
                          if (entry.kind == kind) entry,
                      ],
                    ),
                ],
              ),
              error: (Object error, StackTrace _) => _LoadFailure(
                failure: error is ApiFailure
                    ? error
                    : const UnexpectedFailure(),
                onRetry: () => ref.invalidate(legalDocumentsControllerProvider),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One document: a title, a tab per language, and an editor for each.
class _DocumentSection extends StatefulWidget {
  const _DocumentSection({required this.kind, required this.entries});

  final LegalDocumentKind kind;
  final List<LegalDocumentEntry> entries;

  @override
  State<_DocumentSection> createState() => _DocumentSectionState();
}

class _DocumentSectionState extends State<_DocumentSection> {
  AppLanguage _language = AppLanguage.uz;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = switch (widget.kind) {
      LegalDocumentKind.terms => l10n.legalTerms,
      LegalDocumentKind.privacy => l10n.legalPrivacy,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            segments: <ButtonSegment<AppLanguage>>[
              for (final AppLanguage language in AppLanguage.values)
                ButtonSegment<AppLanguage>(
                  value: language,
                  label: Text(
                    key: ValueKey<String>(
                      'legal-tab-${widget.kind.code}-${language.code}',
                    ),
                    switch (language) {
                      AppLanguage.uz => l10n.languageUzbek,
                      AppLanguage.ru => l10n.languageRussian,
                    },
                  ),
                ),
            ],
            selected: <AppLanguage>{_language},
            showSelectedIcon: false,
            onSelectionChanged: (Set<AppLanguage> chosen) =>
                setState(() => _language = chosen.single),
          ),
          const SizedBox(height: 12),
          // Both editors stay built, so a text typed in one language
          // survives a look at the other.
          IndexedStack(
            index: AppLanguage.values.indexOf(_language),
            children: <Widget>[
              for (final AppLanguage language in AppLanguage.values)
                _DocumentEditor(
                  key: ValueKey<String>(
                    'legal-editor-${widget.kind.code}-${language.code}',
                  ),
                  entry: widget.entries.firstWhere(
                    (LegalDocumentEntry e) => e.language == language,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentEditor extends ConsumerStatefulWidget {
  const _DocumentEditor({required this.entry, super.key});

  final LegalDocumentEntry entry;

  @override
  ConsumerState<_DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends ConsumerState<_DocumentEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.entry.body ?? '',
  );

  LegalSlot get _slot =>
      (kind: widget.entry.kind, language: widget.entry.language);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// A blank text is no text, as the server reads it.
  String? get _body => _text.text.trim().isEmpty ? null : _text.text;

  bool get _changed => (_body ?? '') != (widget.entry.body ?? '');

  Future<void> _publish() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? body = _body;

    if (body == null && widget.entry.body != null) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          content: Text(l10n.legalUnpublishConfirm),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.legalPublish),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    final bool saved = await ref
        .read(publishLegalDocumentControllerProvider(_slot).notifier)
        .publish(body);
    if (!saved) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.legalSaved)));
  }

  @override
  void didUpdateWidget(_DocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The server's text is the truth, such as a blank one that became none.
    if (oldWidget.entry.body != widget.entry.body &&
        _text.text != (widget.entry.body ?? '')) {
      _text.text = widget.entry.body ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState mutation = ref.watch(
      publishLegalDocumentControllerProvider(_slot),
    );
    final LegalDocumentEntry entry = widget.entry;
    final DateTime? updatedAt = entry.updatedAt;
    final String status = entry.body == null || updatedAt == null
        ? l10n.legalNotPublished
        : l10n.legalPublishedBy(
            TashkentTime.format(updatedAt),
            entry.updatedByName ?? '—',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: ValueKey<String>(
            'legal-${entry.kind.code}-${entry.language.code}',
          ),
          controller: _text,
          minLines: 10,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (String _) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.legalFormatHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(status),
        FailureMessage(mutation.failure),
        const SizedBox(height: 12),
        FilledButton(
          key: ValueKey<String>(
            'legal-save-${entry.kind.code}-${entry.language.code}',
          ),
          onPressed: _changed && !mutation.isBusy ? _publish : null,
          child: Text(l10n.legalPublish),
        ),
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FailureMessage(failure),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).retryButton),
        ),
      ],
    );
  }
}
