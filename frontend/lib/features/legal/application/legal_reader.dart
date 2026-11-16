import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/network/api_failure.dart';
import '../domain/legal.dart';
import 'legal_providers.dart';

/// What the document screen shows for one kind (`DL-136` (4)): the text on
/// screen, whether it is being refreshed, and why the last load failed.
final class LegalReading {
  const LegalReading({
    this.document,
    this.unpublished = false,
    this.failure,
    this.loading = false,
  });

  /// The text on screen: the fresh answer, or the saved copy until it comes.
  final LegalDocument? document;

  /// Neither language of the document is published.
  final bool unpublished;

  /// The last load's failure; the [document] on screen stays.
  final ApiFailure? failure;

  /// A load is out.
  final bool loading;

  LegalReading _loading() => LegalReading(
    document: document,
    unpublished: unpublished,
    failure: failure,
    loading: true,
  );
}

/// The documents read this session, kept per kind and interface language, so
/// reopening one shows it at once (`DL-136` (5)). A plain map, not provider
/// state: a load writes it while no screen is watching. Keyed by the
/// interface language, not the document's, so a document that fell back to
/// the other language is still found.
final class LegalCopies {
  final Map<(LegalDocumentKind, AppLanguage), LegalDocument> _copies =
      <(LegalDocumentKind, AppLanguage), LegalDocument>{};

  LegalDocument? of(LegalDocumentKind kind, AppLanguage language) =>
      _copies[(kind, language)];

  void keep(
    LegalDocumentKind kind,
    AppLanguage language,
    LegalDocument document,
  ) => _copies[(kind, language)] = document;

  void drop(LegalDocumentKind kind, AppLanguage language) =>
      _copies.remove((kind, language));
}

final Provider<LegalCopies> legalCopiesProvider = Provider<LegalCopies>(
  (Ref ref) => LegalCopies(),
);

/// One document's reader. It follows the interface language; an answer that
/// comes after the language changed or the reader was let go is never shown
/// (`docs/07` section 28), though it still becomes its own language's copy.
class LegalReader extends Notifier<LegalReading> {
  LegalReader(this.kind);

  final LegalDocumentKind kind;

  /// Counts the builds, so only the load of the latest language lands.
  int _generation = 0;
  AppLanguage? _language;
  late final LegalCopies _copies = ref.read(legalCopiesProvider);

  @override
  LegalReading build() {
    final int generation = ++_generation;
    final AppLanguage? language = ref.watch(languageControllerProvider).value;
    _language = language;
    if (language == null) {
      return const LegalReading(loading: true);
    }
    scheduleMicrotask(() => _load(language, generation));
    return LegalReading(document: _copies.of(kind, language), loading: true);
  }

  /// Loads again after a failure; does nothing while a load is out.
  Future<void> retry() async {
    final AppLanguage? language = _language;
    if (language == null || state.loading) {
      return;
    }
    state = state._loading();
    await _load(language, _generation);
  }

  Future<void> _load(AppLanguage language, int generation) async {
    final LegalRepository repository = ref.read(legalRepositoryProvider);
    bool current() => ref.mounted && generation == _generation;
    try {
      final LegalDocument? document = await repository.document(kind, language);
      if (document == null) {
        _copies.drop(kind, language);
      } else {
        _copies.keep(kind, language, document);
      }
      if (current()) {
        state = LegalReading(document: document, unpublished: document == null);
      }
    } on ApiFailure catch (failure) {
      if (current()) {
        state = LegalReading(document: state.document, failure: failure);
      }
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while loading a document');
      if (current()) {
        state = LegalReading(
          document: state.document,
          failure: const UnexpectedFailure(),
        );
      }
    }
  }
}

final NotifierProviderFamily<LegalReader, LegalReading, LegalDocumentKind>
legalReaderProvider = NotifierProvider.autoDispose
    .family<LegalReader, LegalReading, LegalDocumentKind>(LegalReader.new);
