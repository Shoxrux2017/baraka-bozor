import 'dart:async';

import 'package:baraka_bozor/core/legal/legal_document_kind.dart';
import 'package:baraka_bozor/core/localization/app_language.dart';
import 'package:baraka_bozor/core/localization/language_controller.dart';
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/legal/application/legal_providers.dart';
import 'package:baraka_bozor/features/legal/application/legal_reader.dart';
import 'package:baraka_bozor/features/legal/domain/legal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_legal_repository.dart';

/// The interface language without the preference store or the session.
class _TestLanguage extends LanguageController {
  @override
  Future<AppLanguage> build() async => AppLanguage.ru;

  void switchTo(AppLanguage language) =>
      state = AsyncData<AppLanguage>(language);
}

LegalDocument _document(
  AppLanguage language,
  String text, {
  LegalDocumentKind kind = LegalDocumentKind.terms,
}) => LegalDocument(
  kind: kind,
  language: language,
  updatedAt: DateTime.utc(2026, 10, 18),
  blocks: <LegalBlock>[LegalBlock(type: LegalBlockType.paragraph, text: text)],
);

String? _firstText(LegalReading reading) => reading.document?.blocks.first.text;

void main() {
  late FakeLegalRepository repository;
  late ProviderContainer container;
  const LegalDocumentKind kind = LegalDocumentKind.terms;

  ProviderContainer open() {
    final ProviderContainer made = ProviderContainer(
      overrides: [
        legalRepositoryProvider.overrideWithValue(repository),
        languageControllerProvider.overrideWith(_TestLanguage.new),
      ],
    );
    addTearDown(made.dispose);
    return made;
  }

  LegalReading reading() => container.read(legalReaderProvider(kind));

  /// Keeps the reader alive, as a screen does.
  void watch() => container.listen(legalReaderProvider(kind), (_, _) {});

  setUp(() {
    repository = FakeLegalRepository();
    container = open();
  });

  test('a first open loads and keeps a copy', () async {
    repository.documents[(kind, AppLanguage.ru)] = _document(
      AppLanguage.ru,
      'one',
    );

    watch();
    expect(reading().loading, isTrue);
    expect(reading().document, isNull);
    await pumpEventQueue();

    expect(reading().loading, isFalse);
    expect(_firstText(reading()), 'one');
    expect(reading().failure, isNull);
    expect(
      container
          .read(legalCopiesProvider)
          .of(kind, AppLanguage.ru)
          ?.blocks
          .first
          .text,
      'one',
    );
  });

  test('a second open shows the copy at once and refreshes it', () async {
    repository.documents[(kind, AppLanguage.ru)] = _document(
      AppLanguage.ru,
      'one',
    );
    final ProviderSubscription<LegalReading> first = container.listen(
      legalReaderProvider(kind),
      (_, _) {},
    );
    await pumpEventQueue();
    first.close();
    await pumpEventQueue();

    repository.documents[(kind, AppLanguage.ru)] = _document(
      AppLanguage.ru,
      'two',
    );
    watch();
    expect(reading().loading, isTrue);
    expect(_firstText(reading()), 'one');
    await pumpEventQueue();

    expect(reading().loading, isFalse);
    expect(_firstText(reading()), 'two');
    expect(
      container
          .read(legalCopiesProvider)
          .of(kind, AppLanguage.ru)
          ?.blocks
          .first
          .text,
      'two',
    );
  });

  test('offline with a copy keeps the copy and the failure', () async {
    container
        .read(legalCopiesProvider)
        .keep(kind, AppLanguage.ru, _document(AppLanguage.ru, 'one'));
    repository.documentFailure = const NetworkFailure();

    watch();
    await pumpEventQueue();

    expect(reading().loading, isFalse);
    expect(_firstText(reading()), 'one');
    expect(reading().failure, isA<NetworkFailure>());
  });

  test(
    'offline without a copy has only the failure, and retry loads',
    () async {
      repository.documentFailure = const NetworkFailure();

      watch();
      await pumpEventQueue();
      expect(reading().document, isNull);
      expect(reading().failure, isA<NetworkFailure>());
      expect(reading().loading, isFalse);

      repository
        ..documentFailure = null
        ..documents[(kind, AppLanguage.ru)] = _document(AppLanguage.ru, 'one');
      final Future<void> retry = container
          .read(legalReaderProvider(kind).notifier)
          .retry();
      expect(reading().loading, isTrue);
      await retry;

      expect(reading().loading, isFalse);
      expect(reading().failure, isNull);
      expect(_firstText(reading()), 'one');
    },
  );

  test('unpublished drops the copy', () async {
    container
        .read(legalCopiesProvider)
        .keep(kind, AppLanguage.ru, _document(AppLanguage.ru, 'one'));
    repository.documents[(kind, AppLanguage.ru)] = null;

    watch();
    await pumpEventQueue();

    expect(reading().unpublished, isTrue);
    expect(reading().document, isNull);
    expect(reading().loading, isFalse);
    expect(
      container.read(legalCopiesProvider).of(kind, AppLanguage.ru),
      isNull,
    );
  });

  test('an answer for another language is not shown', () async {
    repository.documents[(kind, AppLanguage.ru)] = _document(
      AppLanguage.ru,
      'ru text',
    );
    repository.documents[(kind, AppLanguage.uz)] = _document(
      AppLanguage.uz,
      'uz text',
    );
    final Completer<void> hold = Completer<void>();
    repository.documentHold = hold;
    watch();
    await container.read(languageControllerProvider.future);
    await pumpEventQueue();
    expect(repository.documentCalls, [(kind, AppLanguage.ru)]);

    repository.documentHold = null;
    (container.read(languageControllerProvider.notifier) as _TestLanguage)
        .switchTo(AppLanguage.uz);
    await pumpEventQueue();
    expect(_firstText(reading()), 'uz text');

    hold.complete();
    await pumpEventQueue();

    expect(_firstText(reading()), 'uz text');
    expect(reading().loading, isFalse);
    expect(
      container
          .read(legalCopiesProvider)
          .of(kind, AppLanguage.ru)
          ?.blocks
          .first
          .text,
      'ru text',
    );
  });

  test('retry while loading sends nothing more', () async {
    final Completer<void> hold = Completer<void>();
    repository.documentHold = hold;
    repository.documents[(kind, AppLanguage.ru)] = _document(
      AppLanguage.ru,
      'one',
    );

    watch();
    await pumpEventQueue();
    await container.read(legalReaderProvider(kind).notifier).retry();

    expect(repository.documentCalls, hasLength(1));
    hold.complete();
    await pumpEventQueue();
    expect(_firstText(reading()), 'one');
  });
}
