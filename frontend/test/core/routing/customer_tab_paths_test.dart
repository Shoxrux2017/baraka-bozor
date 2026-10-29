import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A tab's path is reached by the bar or `go`, never pushed (`DL-118`): a
/// push from a screen over the tabs would build a second shell.
void main() {
  test("no code pushes a tab's path", () {
    final RegExp push = RegExp(
      r'\.(push|pushReplacement)(<[^>]*>)?\(\s*AppPaths\.'
      r'(customer|customerFavorites|customerOrders|customerProfile)'
      r'\s*[,)]',
    );
    final List<String> hits = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path.replaceAll('\\', '/').contains('/generated/')) {
        continue;
      }
      if (push.hasMatch(entity.readAsStringSync())) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty);
  });
}
