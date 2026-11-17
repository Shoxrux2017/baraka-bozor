import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/legal_providers.dart';
import '../domain/legal.dart';

/// The line under the sign-in button (kit drawing 02a): "by continuing you
/// accept" the published documents, each a link that opens it. It names only
/// the documents that are published and is absent while the index loads,
/// when it failed and when nothing is published, as the server records
/// consent only for published documents (`DL-94` item 3).
///
/// The sentence is painted as one paragraph; over the words of each link
/// lies a target at least 44 tall (`DL-139`). A reader meets the sentence as
/// one stop, then each link as its own.
class ConsentLine extends ConsumerWidget {
  const ConsentLine({super.key});

  // Private-use characters standing in for the placeholders, so the message
  // is split into text and links wherever the translation puts them.
  static const String _termsMark = '\u{E000}';
  static const String _privacyMark = '\u{E001}';
  static final RegExp _marks = RegExp('$_termsMark|$_privacyMark');

  static const TextStyle _base = TextStyle(
    fontSize: 12,
    height: 1.55,
    color: KitColors.muted,
  );
  static const TextStyle _link = TextStyle(
    fontSize: 12,
    height: 1.55,
    fontWeight: FontWeight.w600,
    color: KitColors.primaryDark,
  );

  /// Room above and below the text, so a 44 tall target centred on a line
  /// stays inside the line's box.
  static const double _pad = 13;
  static const double _minTarget = 44;

  static List<_Part> _parts(String message, AppLocalizations l10n) {
    final List<_Part> parts = <_Part>[];
    int cursor = 0;
    for (final RegExpMatch match in _marks.allMatches(message)) {
      if (match.start > cursor) {
        parts.add(_Part(message.substring(cursor, match.start), null));
      }
      parts.add(
        match.group(0) == _termsMark
            ? _Part(l10n.consentTermsLink, LegalDocumentKind.terms)
            : _Part(l10n.consentPrivacyLink, LegalDocumentKind.privacy),
      );
      cursor = match.end;
    }
    if (cursor < message.length) {
      parts.add(_Part(message.substring(cursor), null));
    }
    return parts;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final List<_Part> parts = _parts(message, l10n);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final Locale locale = Localizations.localeOf(context);
    final TextDirection direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final TextPainter painter = _layout(
          parts,
          scaler,
          locale,
          direction,
          width,
        );
        final double height = painter.height;
        final List<Widget> targets = <Widget>[];
        final List<Widget> words = <Widget>[];
        int offset = 0;
        for (final _Part part in parts) {
          final LegalDocumentKind? kind = part.kind;
          if (kind != null) {
            final List<Rect> lines = _lines(
              painter.getBoxesForSelection(
                TextSelection(
                  baseOffset: offset,
                  extentOffset: offset + part.text.length,
                ),
              ),
            );
            for (int i = 0; i < lines.length; i++) {
              targets.add(
                _target(context, kind, part.text, lines[i], width, i == 0),
              );
              words.add(
                Positioned.fromRect(
                  rect: lines[i],
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push<void>(AppPaths.legal(kind)),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              );
            }
          }
          offset += part.text.length;
        }
        painter.dispose();

        return SizedBox(
          key: const ValueKey<String>('consent-line'),
          width: width,
          height: height + 2 * _pad,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(0),
                  label: parts.map((_Part p) => p.text).join(),
                  textDirection: direction,
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _ConsentPainter(
                        parts,
                        scaler,
                        locale,
                        direction,
                        width,
                      ),
                    ),
                  ),
                ),
              ),
              ...targets,
              // The words themselves win over a neighbouring line's 44 tall
              // target that reaches over them.
              ...words,
            ],
          ),
        );
      },
    );
  }

  /// The line boxes of a link: the boxes of one line joined, in reading
  /// order, moved down by the padding.
  static List<Rect> _lines(List<TextBox> boxes) {
    final List<Rect> lines = <Rect>[];
    for (final TextBox box in boxes) {
      final Rect rect = box.toRect().shift(const Offset(0, _pad));
      final int at = lines.indexWhere(
        (Rect line) => (line.top - rect.top).abs() < 1,
      );
      if (at < 0) {
        lines.add(rect);
      } else {
        lines[at] = lines[at].expandToInclude(rect);
      }
    }
    lines.sort((Rect a, Rect b) => a.top.compareTo(b.top));
    return lines;
  }

  static Widget _target(
    BuildContext context,
    LegalDocumentKind kind,
    String words,
    Rect line,
    double width,
    bool first,
  ) {
    final bool terms = kind == LegalDocumentKind.terms;
    final double w = line.width < _minTarget ? _minTarget : line.width;
    final double left = (line.center.dx - w / 2).clamp(
      0.0,
      (width - w).clamp(0.0, double.infinity),
    );
    final Widget hit = GestureDetector(
      key: first
          ? ValueKey<String>(terms ? 'consent-terms' : 'consent-privacy')
          : null,
      behavior: HitTestBehavior.opaque,
      // Pushed, so back returns to the phone screen as it was.
      onTap: () => context.push<void>(AppPaths.legal(kind)),
      child: const SizedBox.expand(),
    );
    return Positioned(
      left: left,
      top: line.center.dy - _minTarget / 2,
      width: w,
      height: _minTarget,
      child: first
          ? Semantics(
              container: true,
              link: true,
              sortKey: OrdinalSortKey(terms ? 1 : 2),
              label: words,
              child: hit,
            )
          : ExcludeSemantics(child: hit),
    );
  }

  static TextPainter _layout(
    List<_Part> parts,
    TextScaler scaler,
    Locale locale,
    TextDirection direction,
    double width,
  ) {
    return TextPainter(
      text: TextSpan(
        style: _base,
        children: <InlineSpan>[
          for (final _Part part in parts)
            TextSpan(text: part.text, style: part.kind == null ? null : _link),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
    )..layout(minWidth: width, maxWidth: width);
  }
}

/// A run of the sentence: plain text, or the words of one document's link.
class _Part {
  const _Part(this.text, this.kind);

  final String text;
  final LegalDocumentKind? kind;
}

class _ConsentPainter extends CustomPainter {
  const _ConsentPainter(
    this.parts,
    this.scaler,
    this.locale,
    this.direction,
    this.width,
  );

  final List<_Part> parts;
  final TextScaler scaler;
  final Locale locale;
  final TextDirection direction;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final TextPainter painter = ConsentLine._layout(
      parts,
      scaler,
      locale,
      direction,
      width,
    );
    painter.paint(canvas, const Offset(0, ConsentLine._pad));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_ConsentPainter old) =>
      old.scaler != scaler ||
      old.locale != locale ||
      old.direction != direction ||
      old.width != width ||
      old.parts.map((_Part p) => p.text).join() !=
          parts.map((_Part p) => p.text).join();
}
