import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards DL-117: text is never drawn in the fill green (`KitColors.primary`)
/// or the icon amber (`KitColors.warning`); it uses `primaryDark` and
/// `warningDark`.
List<String> kitTextColourViolations(String path, String source) {
  final List<String> hits = <String>[];
  final RegExp styleCall = RegExp(r'TextStyle\((?:[^()]|\([^()]*\))*\)');
  final RegExp textColour = RegExp(
    r'\bcolor:[^,)]*KitColors\.(primary|warning)(?![A-Za-z])',
  );
  for (final RegExpMatch call in styleCall.allMatches(source)) {
    for (final RegExpMatch hit in textColour.allMatches(call.group(0)!)) {
      hits.add('$path: ${hit.group(0)}');
    }
  }
  final RegExp foreground = RegExp(
    r'\b(foregroundColor|foreground):\s*KitColors\.(primary|warning)(?![A-Za-z])',
  );
  for (final RegExpMatch hit in foreground.allMatches(source)) {
    hits.add('$path: ${hit.group(0)}');
  }
  return hits;
}

void main() {
  test('finds fill colours in text', () {
    expect(
      kitTextColourViolations(
        'a.dart',
        'TextStyle(fontSize: 12, color: KitColors.primary)',
      ),
      hasLength(1),
    );
    expect(
      kitTextColourViolations(
        'a.dart',
        'TextStyle(color: on ? KitColors.warning : KitColors.muted)',
      ),
      hasLength(1),
    );
    expect(
      kitTextColourViolations(
        'a.dart',
        'kitOutlined(foreground: KitColors.primary)',
      ),
      hasLength(1),
    );
  });

  test('leaves text colours, icons and fills alone', () {
    for (final String source in <String>[
      'TextStyle(color: KitColors.primaryDark)',
      'Icon(Icons.add, color: KitColors.primary)',
      'BoxDecoration(color: KitColors.primary)',
      'TextStyle(color: KitColors.warningDark)',
    ]) {
      expect(
        kitTextColourViolations('a.dart', source),
        isEmpty,
        reason: source,
      );
    }
  });

  test('no text is drawn in the fill green or the icon amber', () {
    expect(
      File('lib/app/router.dart').existsSync(),
      isTrue,
      reason: 'tests must run from the package root',
    );
    final List<String> violations = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final String path = entity.path.replaceAll(r'\', '/');
      if (path == 'lib/core/widgets/brand_wordmark.dart' ||
          path.startsWith('lib/core/localization/generated/')) {
        continue;
      }
      violations.addAll(
        kitTextColourViolations(path, entity.readAsStringSync()),
      );
    }
    expect(violations.join('\n'), isEmpty);
  });
}
