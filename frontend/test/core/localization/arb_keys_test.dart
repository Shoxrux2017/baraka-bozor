import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The top-level keys of an ARB file in the order they appear, repeats
/// included. `jsonDecode` and `flutter gen-l10n` keep only the last of two
/// equal keys, so a repeat silently replaces the earlier text.
List<String> topLevelKeys(String source) {
  final List<String> keys = <String>[];
  int depth = 0;
  int index = 0;
  while (index < source.length) {
    final String char = source[index];
    if (char == '"') {
      final int start = index + 1;
      index = start;
      while (source[index] != '"') {
        index += source[index] == r'\' ? 2 : 1;
      }
      final String text = source.substring(start, index);
      index++;
      int next = index;
      while (next < source.length && source[next].trim().isEmpty) {
        next++;
      }
      if (depth == 1 && next < source.length && source[next] == ':') {
        keys.add(text);
      }
      continue;
    }
    if (char == '{' || char == '[') {
      depth++;
    } else if (char == '}' || char == ']') {
      depth--;
    }
    index++;
  }
  return keys;
}

List<String> repeated(List<String> keys) {
  final Set<String> seen = <String>{};
  return keys.where((String key) => !seen.add(key)).toList();
}

void main() {
  test('the scan finds a repeated top-level key and ignores nested ones', () {
    const String source = '''
{
  "a": "first {n}",
  "@a": {"placeholders": {"n": {"type": "String"}}},
  "b": "say \\"a\\": twice",
  "@b": {"placeholders": {"n": {"type": "String"}}},
  "a": "second"
}
''';

    expect(topLevelKeys(source), <String>['a', '@a', 'b', '@b', 'a']);
    expect(repeated(topLevelKeys(source)), <String>['a']);
  });

  for (final String locale in <String>['uz', 'ru']) {
    test('app_$locale.arb defines every key once', () {
      final List<String> keys = topLevelKeys(
        File('lib/core/localization/l10n/app_$locale.arb').readAsStringSync(),
      );

      expect(keys, isNotEmpty);
      expect(repeated(keys), isEmpty);
    });
  }
}
