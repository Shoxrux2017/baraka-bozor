import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../data/legal_api.dart';
import '../domain/legal.dart';

final Provider<LegalRepository> legalRepositoryProvider =
    Provider<LegalRepository>(
      (Ref ref) => LegalApi(ref.watch(apiClientProvider)),
    );

/// The published documents in the interface language; it follows the
/// language when it changes.
final FutureProvider<LegalIndex> legalIndexProvider =
    FutureProvider.autoDispose<LegalIndex>((Ref ref) async {
      final AppLanguage language = await ref.watch(
        languageControllerProvider.future,
      );
      return ref.watch(legalRepositoryProvider).index(language);
    });

/// One document in the interface language; `null` when none is published.
final legalDocumentProvider = FutureProvider.autoDispose
    .family<LegalDocument?, LegalDocumentKind>((
      Ref ref,
      LegalDocumentKind kind,
    ) async {
      final AppLanguage language = await ref.watch(
        languageControllerProvider.future,
      );
      return ref.watch(legalRepositoryProvider).document(kind, language);
    });
