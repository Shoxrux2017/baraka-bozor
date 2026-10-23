import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_dialog.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../../../core/widgets/panel/panel_fields.dart';
import '../../../core/widgets/panel/panel_layout.dart';
import '../../../core/widgets/panel/panel_page_header.dart';
import '../../../core/widgets/panel/panel_pills.dart';
import '../../../core/widgets/panel/panel_segmented.dart';
import '../../legal/domain/legal_text.dart';
import '../../legal/presentation/legal_blocks.dart';
import '../application/legal_documents_controllers.dart';
import '../domain/legal_documents.dart';

/// The longest text the server takes (`docs/09-api-contracts.md` section 63).
const int _maxLength = 50000;

String _titleOf(AppLocalizations l10n, LegalDocumentKind kind) =>
    switch (kind) {
      LegalDocumentKind.terms => l10n.legalTerms,
      LegalDocumentKind.privacy => l10n.legalPrivacy,
    };

/// The Admin's documents page (`docs/09-api-contracts.md` section 63): the
/// terms of use and the privacy policy as pills, each in Uzbek and Russian
/// behind a language switch, with the text as the app will show it beside
/// the editor and one publish button per text.
class LegalDocumentsScreen extends ConsumerWidget {
  const LegalDocumentsScreen({super.key});

  /// The width of a document card from which the preview stands at the right
  /// of the editor; below it the preview sits under the editor.
  static const double previewBesideWidth = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<LegalDocumentEntry>> documents = ref.watch(
      legalDocumentsControllerProvider,
    );

    return ListView(
      padding: panelPagePadding(MediaQuery.sizeOf(context).width),
      children: <Widget>[
        PanelPageHeader(
          title: l10n.legalDocumentsTitle,
          subtitle: l10n.legalDocumentsSubtitle,
        ),
        const SizedBox(height: 18),
        documents.when(
          skipLoadingOnReload: false,
          skipLoadingOnRefresh: !documents.hasError,
          data: (List<LegalDocumentEntry> entries) =>
              _Documents(entries: entries),
          error: (Object error, StackTrace _) => _LoadFailure(
            failure: error is ApiFailure ? error : const UnexpectedFailure(),
            onRetry: () => ref.invalidate(legalDocumentsControllerProvider),
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

/// The two documents: a pill for each and, under them, the chosen one.
class _Documents extends StatefulWidget {
  const _Documents({required this.entries});

  final List<LegalDocumentEntry> entries;

  @override
  State<_Documents> createState() => _DocumentsState();
}

class _DocumentsState extends State<_Documents> {
  LegalDocumentKind _kind = LegalDocumentKind.terms;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PanelPillRow(
          wrap: true,
          pills: <Widget>[
            for (final LegalDocumentKind kind in LegalDocumentKind.values)
              PanelPill(
                key: ValueKey<String>('legal-doc-${kind.code}'),
                label: _titleOf(l10n, kind),
                selected: kind == _kind,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Every document stays built, so a text typed in one survives a look
        // at the other.
        IndexedStack(
          index: LegalDocumentKind.values.indexOf(_kind),
          children: <Widget>[
            for (final LegalDocumentKind kind in LegalDocumentKind.values)
              _DocumentSection(
                kind: kind,
                entries: <LegalDocumentEntry>[
                  for (final LegalDocumentEntry entry in widget.entries)
                    if (entry.kind == kind) entry,
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// One document: an editor for each language, the chosen one shown.
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
    // Both editors stay built, so a text typed in one language survives a
    // look at the other.
    return IndexedStack(
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
            published: <AppLanguage, bool>{
              for (final LegalDocumentEntry e in widget.entries)
                e.language: e.body != null,
            },
            language: _language,
            onLanguage: (AppLanguage chosen) =>
                setState(() => _language = chosen),
          ),
      ],
    );
  }
}

class _DocumentEditor extends ConsumerStatefulWidget {
  const _DocumentEditor({
    required this.entry,
    required this.published,
    required this.language,
    required this.onLanguage,
    super.key,
  });

  final LegalDocumentEntry entry;

  /// Which language of this document is published, for the switch's dots.
  final Map<AppLanguage, bool> published;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguage;

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
      final bool? confirmed = await showKitDialog<bool>(
        context: context,
        dialogKey: 'legal-unpublish-dialog',
        title: l10n.legalUnpublishConfirm,
        badge: const KitDialogBadge(
          Icons.visibility_off_outlined,
          danger: true,
        ),
        builder: (BuildContext dialog) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.legalUnpublishExplained(_titleOf(l10n, widget.entry.kind)),
              style: const TextStyle(fontSize: 13, color: KitColors.ink2),
            ),
            const SizedBox(height: 20),
            kitDialogButtons(
              context: dialog,
              busy: false,
              confirmKey: const ValueKey<String>('legal-unpublish-confirm'),
              confirm: l10n.legalUnpublish,
              destructive: true,
              submit: () => Navigator.of(dialog).pop(true),
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
    final String title = _titleOf(l10n, entry.kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool beside =
                constraints.maxWidth >= LegalDocumentsScreen.previewBesideWidth;

            return PanelCard(
              flush: true,
              children: <Widget>[
                _Header(
                  entry: entry,
                  published: widget.published,
                  language: widget.language,
                  onLanguage: widget.onLanguage,
                ),
                const Divider(height: 1, thickness: 1, color: KitColors.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: beside
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: _editor(l10n)),
                            const SizedBox(width: 20),
                            SizedBox(width: 380, child: _preview(l10n, title)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _editor(l10n),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 380,
                                ),
                                child: _preview(l10n, title),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
        FailureMessage(mutation.failure),
        const SizedBox(height: 16),
        KitCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _changed
                    ? Row(
                        children: <Widget>[
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: KitColors.warning,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 8, height: 8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.legalUnsaved,
                              style: const TextStyle(
                                fontSize: 12,
                                color: KitColors.muted,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 16),
              FilledButton(
                key: ValueKey<String>(
                  'legal-save-${entry.kind.code}-${entry.language.code}',
                ),
                style: kitFilled(height: 46),
                onPressed: _changed && !mutation.isBusy ? _publish : null,
                child: Text(l10n.legalPublish),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editor(AppLocalizations l10n) {
    final int length = _text.text.runes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: ValueKey<String>(
            'legal-${widget.entry.kind.code}-${widget.entry.language.code}',
          ),
          controller: _text,
          minLines: 20,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 22 / 12.5,
            color: KitColors.ink,
          ),
          decoration: panelFieldDecoration(),
          onChanged: (String _) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.legalFormatHint,
                style: const TextStyle(fontSize: 11, color: KitColors.muted),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${MoneyFormat.grouped(length)} / '
              '${MoneyFormat.grouped(_maxLength)}',
              style: TextStyle(
                fontSize: 11,
                color: length > _maxLength ? KitColors.danger : KitColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preview(AppLocalizations l10n, String title) {
    final bool blank = _body == null;

    return Column(
      key: ValueKey<String>(
        'legal-preview-${widget.entry.kind.code}-${widget.entry.language.code}',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.smartphone, size: 17, color: KitColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.legalPreviewTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KitColors.muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: KitColors.ink, width: 6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: KitColors.ink,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: KitColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: KitColors.line),
                SizedBox(
                  height: 452,
                  child: blank
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.description_outlined,
                                  size: 34,
                                  color: KitColors.muted,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.legalPreviewEmpty(title),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: KitColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: LegalBlocks(
                            legalBlocksOf(_text.text),
                            scale: 0.86,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The language switch of a document card with whether the shown text is
/// published at its right.
class _Header extends StatelessWidget {
  const _Header({
    required this.entry,
    required this.published,
    required this.language,
    required this.onLanguage,
  });

  final LegalDocumentEntry entry;
  final Map<AppLanguage, bool> published;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? updatedAt = entry.updatedAt;
    final bool isPublished = entry.body != null && updatedAt != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: <Widget>[
          PanelSegmented<AppLanguage>(
            selected: language,
            onSelected: onLanguage,
            segments: <PanelSegment<AppLanguage>>[
              for (final AppLanguage option in AppLanguage.values)
                (
                  value: option,
                  label: switch (option) {
                    AppLanguage.uz => l10n.languageUzbek,
                    AppLanguage.ru => l10n.languageRussian,
                  },
                  key: ValueKey<String>(
                    'legal-tab-${entry.kind.code}-${option.code}',
                  ),
                  dot: published[option] == true
                      ? KitColors.primary
                      : KitColors.warning,
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isPublished ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: isPublished ? KitColors.primaryDark : KitColors.warning,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isPublished
                      ? l10n.legalPublishedBy(
                          TashkentTime.format(updatedAt),
                          entry.updatedByName ?? '—',
                        )
                      : l10n.legalNotPublished,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPublished ? KitColors.ink2 : KitColors.warningDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
