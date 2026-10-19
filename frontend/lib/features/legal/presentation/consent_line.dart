import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/legal_providers.dart';
import '../domain/legal.dart';

/// The line under the sign-in phone (kit drawing 02a): "by continuing you
/// accept" the published documents, each a link that opens it. It names only
/// the documents that are published and is absent while the index loads,
/// when it failed and when nothing is published, as the server records
/// consent only for published documents (`DL-94` item 3).
class ConsentLine extends ConsumerStatefulWidget {
  const ConsentLine({super.key});

  @override
  ConsumerState<ConsentLine> createState() => _ConsentLineState();
}

class _ConsentLineState extends ConsumerState<ConsentLine> {
  // Private-use characters standing in for the placeholders, so the message
  // is split into text and links wherever the translation puts them.
  static const String _termsMark = '\u{E000}';
  static const String _privacyMark = '\u{E001}';
  static final RegExp _marks = RegExp('$_termsMark|$_privacyMark');

  static const TextStyle _base = TextStyle(
    fontSize: 11,
    height: 1.55,
    color: KitColors.muted,
  );
  static const TextStyle _link = TextStyle(
    fontSize: 11,
    height: 1.55,
    fontWeight: FontWeight.w600,
    color: KitColors.primary,
  );

  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()
      ..onTap = () => _open(LegalDocumentKind.terms);
    _privacy = TapGestureRecognizer()
      ..onTap = () => _open(LegalDocumentKind.privacy);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  // Pushed, so back returns to the phone screen as it was.
  void _open(LegalDocumentKind kind) {
    context.push<void>(AppPaths.legal(kind));
  }

  List<InlineSpan> _spans(String message, AppLocalizations l10n) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch match in _marks.allMatches(message)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: message.substring(cursor, match.start)));
      }
      final bool terms = match.group(0) == _termsMark;
      spans.add(
        TextSpan(
          text: terms ? l10n.consentTermsLink : l10n.consentPrivacyLink,
          style: _link,
          recognizer: terms ? _terms : _privacy,
        ),
      );
      cursor = match.end;
    }
    if (cursor < message.length) {
      spans.add(TextSpan(text: message.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final LegalIndex? index = ref.watch(legalIndexProvider).value;
    if (index == null || !index.hasAny) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    final String message = index.terms != null && index.privacy != null
        ? l10n.consentAll(_termsMark, _privacyMark)
        : index.terms != null
        ? l10n.consentTermsOnly(_termsMark)
        : l10n.consentPrivacyOnly(_privacyMark);

    return Text.rich(
      TextSpan(style: _base, children: _spans(message, l10n)),
      key: const ValueKey<String>('consent-line'),
      textAlign: TextAlign.center,
    );
  }
}
