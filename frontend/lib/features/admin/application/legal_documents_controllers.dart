import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/staff_account.dart';
import '../../../core/state/mutation_state.dart';
import '../data/legal_documents_api.dart';
import '../domain/legal_documents.dart';
import 'admin_mutation.dart';

final Provider<LegalDocumentsApi> legalDocumentsApiProvider =
    Provider<LegalDocumentsApi>(
      (Ref ref) => LegalDocumentsApi(ref.watch(apiClientProvider)),
    );

/// The four documents as the server has them, loaded while the documents
/// page is open. Without a staff account there is nothing to load: the
/// session guard is taking the screen away.
class LegalDocumentsController extends AsyncNotifier<List<LegalDocumentEntry>> {
  @override
  Future<List<LegalDocumentEntry>> build() {
    if (ref.watch(staffAccountProvider) == null) {
      return Completer<List<LegalDocumentEntry>>().future;
    }
    return ref.read(legalDocumentsApiProvider).list();
  }

  /// Shows the entry the server answered in place of the one it replaces.
  void showSaved(LegalDocumentEntry saved) {
    final List<LegalDocumentEntry>? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<List<LegalDocumentEntry>>(<LegalDocumentEntry>[
      for (final LegalDocumentEntry entry in current)
        entry.kind == saved.kind && entry.language == saved.language
            ? saved
            : entry,
    ]);
  }
}

final AsyncNotifierProvider<LegalDocumentsController, List<LegalDocumentEntry>>
legalDocumentsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      LegalDocumentsController,
      List<LegalDocumentEntry>
    >(LegalDocumentsController.new);

/// Which of the four documents.
typedef LegalSlot = ({LegalDocumentKind kind, AppLanguage language});

/// Publishes one document in one language; each of the four has its own
/// state, so a failure shows under the editor it belongs to and one busy
/// editor does not hold the others.
class PublishLegalDocumentController extends AdminMutation {
  PublishLegalDocumentController(this.slot);

  final LegalSlot slot;

  /// `true` when the server answered and the page shows its entry.
  Future<bool> publish(String? body) async {
    final String? account = ref.read(staffAccountProvider);

    return run(() async {
      final LegalDocumentEntry saved = await ref
          .read(legalDocumentsApiProvider)
          .publish(slot.kind, slot.language, body);

      if (!ref.mounted || ref.read(staffAccountProvider) != account) {
        throw const CancelledFailure();
      }
      ref.read(legalDocumentsControllerProvider.notifier).showSaved(saved);
    });
  }
}

final NotifierProviderFamily<
  PublishLegalDocumentController,
  MutationState,
  LegalSlot
>
publishLegalDocumentControllerProvider = NotifierProvider.autoDispose
    .family<PublishLegalDocumentController, MutationState, LegalSlot>(
      PublishLegalDocumentController.new,
    );
