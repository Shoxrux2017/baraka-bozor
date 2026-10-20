import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/tashkent_time.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/legal_providers.dart';
import '../domain/legal.dart';

/// The terms of use or the privacy policy (kit drawings 34 and 35), read
/// signed in or out: the published document in the interface language, its
/// edition date, then its headings, paragraphs and list items in order.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({required this.kind, super.key});

  final LegalDocumentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<LegalDocument?> document = ref.watch(
      legalDocumentProvider(kind),
    );

    return Scaffold(
      key: const ValueKey<String>('legal-screen'),
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: switch (kind) {
          LegalDocumentKind.terms => l10n.legalTerms,
          LegalDocumentKind.privacy => l10n.legalPrivacy,
        },
      ),
      body: document.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: LoadFailure(
            error: error,
            onRetry: () => ref.invalidate(legalDocumentProvider(kind)),
          ),
        ),
        data: (LegalDocument? loaded) => loaded == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.legalNotPublishedYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: KitColors.ink2),
                  ),
                ),
              )
            : _Body(document: loaded),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<LegalBlock> blocks = document.blocks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l10n.legalEdition(TashkentTime.date(document.updatedAt)),
            style: const TextStyle(fontSize: 13, color: KitColors.muted),
          ),
        ),
        for (int i = 0; i < blocks.length; i++)
          _Block(
            block: blocks[i],
            first: i == 0,
            afterParagraph:
                i > 0 && blocks[i - 1].type == LegalBlockType.paragraph,
          ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.block,
    required this.first,
    required this.afterParagraph,
  });

  final LegalBlock block;
  final bool first;
  final bool afterParagraph;

  static const TextStyle _text = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    color: KitColors.ink2,
  );

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      LegalBlockType.heading => Padding(
        padding: EdgeInsets.only(top: first ? 4 : 22, bottom: 6),
        child: Semantics(
          header: true,
          child: Text(
            block.text,
            style: const TextStyle(
              fontSize: 15,
              height: 22 / 15,
              fontWeight: FontWeight.w700,
              color: KitColors.primaryDark,
            ),
          ),
        ),
      ),
      LegalBlockType.paragraph => Padding(
        padding: EdgeInsets.only(top: afterParagraph ? 6 : 0),
        child: Text(block.text, style: _text),
      ),
      LegalBlockType.item => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(width: 18, child: Text('•', style: _text)),
          Expanded(child: Text(block.text, style: _text)),
        ],
      ),
    };
  }
}
