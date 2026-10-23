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
import 'legal_blocks.dart';

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
        LegalBlocks(blocks),
      ],
    );
  }
}
