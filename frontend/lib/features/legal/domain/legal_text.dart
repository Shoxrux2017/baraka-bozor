import 'legal.dart';

/// PHP's `trim` strips these and nothing else, so the preview cuts a line
/// where the server does.
final RegExp _edge = RegExp(r'^[ \t\n\r\x00\x0B]+|[ \t\n\r\x00\x0B]+$');

String _trim(String text) => text.replaceAll(_edge, '');

/// The blocks of an Admin's plain text, as the server reads it
/// (`App\Modules\Legal\LegalText::blocks`, `DL-94` (1)): a line starting
/// `## ` is a heading, one starting `- ` a list item, any other non-blank
/// line a paragraph; a bare `##` or `-` and a marker with no text are left
/// out, and nothing is read as markup. Used only for the Admin's preview; the
/// server parses what is published.
List<LegalBlock> legalBlocksOf(String body) {
  final List<LegalBlock> blocks = <LegalBlock>[];

  for (final String rawLine in body.split(RegExp(r'\r\n|\r|\n'))) {
    final String line = _trim(rawLine);

    if (line.isEmpty || line == '##' || line == '-') {
      continue;
    }

    final LegalBlockType type;
    final String text;
    if (line.startsWith('## ')) {
      type = LegalBlockType.heading;
      text = _trim(line.substring(3));
    } else if (line.startsWith('- ')) {
      type = LegalBlockType.item;
      text = _trim(line.substring(2));
    } else {
      type = LegalBlockType.paragraph;
      text = line;
    }

    if (text.isNotEmpty) {
      blocks.add(LegalBlock(type: type, text: text));
    }
  }

  return blocks;
}
