import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/long_date.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_scroll_indicator.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/legal_reader.dart';
import '../domain/legal.dart';
import 'legal_blocks.dart';

/// The terms of use or the privacy policy, read signed in or out: the
/// document in the interface language under a large title that hands over to
/// the bar as it scrolls away (`DL-136` (1)).
class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalDocumentKind kind;

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _titleOpacity = ValueNotifier<double>(0);
  final ValueNotifier<double> _edgeOpacity = ValueNotifier<double>(0);

  /// The large title, and the top of the scroll content it is measured from.
  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_follow);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_follow)
      ..dispose();
    _titleOpacity.dispose();
    _edgeOpacity.dispose();
    super.dispose();
  }

  /// The bar's title takes over as the large title's bottom passes under it,
  /// over 22 px; the hairline arrives over the first 8 px of scroll.
  void _follow() {
    final double offset = _scroll.hasClients ? _scroll.offset : 0;
    _edgeOpacity.value = (offset / 8).clamp(0, 1);
    final RenderObject? title = _titleKey.currentContext?.findRenderObject();
    final RenderObject? content = _contentKey.currentContext
        ?.findRenderObject();
    if (title is RenderBox &&
        content is RenderBox &&
        title.attached &&
        content.attached) {
      final double bottom = title
          .localToGlobal(Offset(0, title.size.height), ancestor: content)
          .dy;
      _titleOpacity.value = ((offset - (bottom - 26)) / 22).clamp(0, 1);
    }
  }

  Widget _selectionMenu(BuildContext context, SelectableRegionState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: <ContextMenuButtonItem>[
        for (final ContextMenuButtonItem item in state.contextMenuButtonItems)
          switch (item.type) {
            ContextMenuButtonType.copy => item.copyWith(label: l10n.legalCopy),
            ContextMenuButtonType.selectAll => item.copyWith(
              label: l10n.legalSelectAll,
            ),
            _ => item,
          },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LegalReading reading = ref.watch(legalReaderProvider(widget.kind));
    final LegalDocument? document = reading.document;
    final String name = switch (widget.kind) {
      LegalDocumentKind.terms => l10n.legalTerms,
      LegalDocumentKind.privacy => l10n.legalPrivacy,
    };

    final Widget body;
    if (document != null) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          _follow();
        }
      });
      body = SelectionArea(
        contextMenuBuilder: _selectionMenu,
        child: ListScrollIndicator(
          fullExtent: (ScrollMetrics m) =>
              m.maxScrollExtent + m.viewportDimension,
          child: SingleChildScrollView(
            key: const ValueKey<String>('legal-scroll'),
            controller: _scroll,
            child: _Column(
              contentKey: _contentKey,
              titleKey: _titleKey,
              name: name,
              document: document,
            ),
          ),
        ),
      );
    } else if (reading.unpublished) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            l10n.legalNotPublishedYet,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: KitColors.ink2),
          ),
        ),
      );
    } else if (reading.failure != null) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: LoadFailure(
          error: reading.failure!,
          onRetry: () =>
              ref.read(legalReaderProvider(widget.kind).notifier).retry(),
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      key: const ValueKey<String>('legal-screen'),
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: name,
        titleOpacity: document == null ? null : _titleOpacity,
        edgeOpacity: document == null ? null : _edgeOpacity,
      ),
      body: body,
    );
  }
}

/// The reading column: at most 600 wide, clear of the camera cutout, with the
/// large title, the edition date, a note when the document is not in the
/// interface language, and the blocks.
class _Column extends StatelessWidget {
  const _Column({
    required this.contentKey,
    required this.titleKey,
    required this.name,
    required this.document,
  });

  final GlobalKey contentKey;
  final GlobalKey titleKey;
  final String name;
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final EdgeInsets inset = MediaQuery.paddingOf(context);
    final double titleSize =
        24 + 14 * (textScaleAt(MediaQuery.textScalerOf(context), 16) - 1);
    final String shown = longDate(l10n, document.updatedAt);
    final bool otherLanguage =
        document.language !=
        AppLanguage.tryParse(Localizations.localeOf(context).languageCode);

    return Padding(
      padding: EdgeInsets.only(left: inset.left, right: inset.right),
      child: Align(
        key: contentKey,
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          key: const ValueKey<String>('legal-column'),
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + inset.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  key: titleKey,
                  header: true,
                  child: Text(
                    name,
                    key: const ValueKey<String>('legal-title'),
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: titleSize,
                      height: 1.2,
                      letterSpacing: -0.24,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  key: const ValueKey<String>('legal-date'),
                  label: l10n.legalEditionSpoken(shown),
                  excludeSemantics: true,
                  child: Text(
                    l10n.legalEdition(shown),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: KitColors.muted,
                    ),
                  ),
                ),
                if (otherLanguage) ...<Widget>[
                  const SizedBox(height: 12),
                  _LanguageNote(language: document.language),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 16),
                LegalBlocks(document.blocks),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «This document is only in Russian for now», under the date.
class _LanguageNote extends StatelessWidget {
  const _LanguageNote({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.page,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ExcludeSemantics(
              child: Icon(Icons.info_outline, size: 18, color: KitColors.muted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).legalOnlyIn(language.code),
                key: const ValueKey<String>('legal-language-note'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: KitColors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
