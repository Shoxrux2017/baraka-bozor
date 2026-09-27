/// Text as the server keeps it. Laravel trims every input string with
/// `Str::trim` (`TrimStrings`): whitespace and a list of invisible
/// characters — the zero-width and directional marks, the byte order mark,
/// the Hangul fillers and others — from both ends. The client trims the same
/// before sending, and before comparing what it sent with what came back.
String trimLikeServer(String text) => text.replaceAll(_ends, '');

/// `Str::INVISIBLE_CHARACTERS` of Laravel 13, with `\s` and NUL.
const String _invisible =
    r'\u{0009}\u{0020}\u{00A0}\u{00AD}\u{034F}\u{061C}\u{115F}\u{1160}'
    r'\u{17B4}\u{17B5}\u{180E}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}'
    r'\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{200B}\u{200C}'
    r'\u{200D}\u{200E}\u{200F}\u{202F}\u{205F}\u{2060}\u{2061}\u{2062}'
    r'\u{2063}\u{2064}\u{2065}\u{206A}\u{206B}\u{206C}\u{206D}\u{206E}'
    r'\u{206F}\u{3000}\u{2800}\u{3164}\u{FEFF}\u{FFA0}\u{1D159}\u{1D173}'
    r'\u{1D174}\u{1D175}\u{1D176}\u{1D177}\u{1D178}\u{1D179}\u{1D17A}'
    r'\u{E0020}\u{0000}';

final RegExp _ends = RegExp(
  '^[\\s$_invisible]+|[\\s$_invisible]+\$',
  unicode: true,
);
