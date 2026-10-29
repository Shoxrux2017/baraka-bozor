import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A tab's path is reached by the bar or `go`, never pushed or put in place
/// of a screen over the tabs (`DL-118`): that would build a second shell.
const String _calls = r'(push|pushReplacement|replace)';
const String _namedCalls = r'(pushNamed|pushReplacementNamed|replaceNamed)';
const String _paths =
    r'(customer|customerFavorites|customerOrders|customerProfile)';
const String _names =
    r"""('catalog-home'|'customer-favorites'|'customer-orders'|'customer-profile')""";
const String _literals =
    r"""('/customer'|'/customer/favorites'|'/customer/orders'|'/customer/profile')""";

final List<RegExp> _refused = <RegExp>[
  RegExp(r'\.' + _calls + r'(<[^>]*>)?\(\s*AppPaths\.' + _paths + r'\s*[,)]'),
  RegExp(r'\.' + _calls + r'(<[^>]*>)?\(\s*' + _literals + r'\s*[,)]'),
  RegExp(r'\.' + _namedCalls + r'(<[^>]*>)?\(\s*' + _names + r'\s*[,)]'),
];

bool _refuses(String source) =>
    _refused.any((RegExp pattern) => pattern.hasMatch(source));

void main() {
  test('the scan sees a pushed tab and lets the allowed calls be', () {
    const List<String> hits = <String>[
      'context.push(AppPaths.customerOrders);',
      'router.pushReplacement(AppPaths.customer)',
      'context.replace(AppPaths.customerProfile,',
      'context.push<void>(AppPaths.customerFavorites)',
      "context.push('/customer/orders');",
      "router.replace('/customer')",
      "context.pushNamed('customer-orders');",
      "context.pushReplacementNamed('catalog-home')",
      "context.replaceNamed('customer-profile',",
      "context.pushNamed(\n  'customer-favorites',\n)",
    ];
    const List<String> clean = <String>[
      'context.push(AppPaths.customerOrder(id));',
      'context.go(AppPaths.customerOrders);',
      "context.go('/customer/orders');",
      "context.push('/customer/orders/42');",
      "context.pushNamed('customer-order');",
      'context.push(AppPaths.customerCheckout);',
    ];
    for (final String sample in hits) {
      expect(_refuses(sample), isTrue, reason: sample);
    }
    for (final String sample in clean) {
      expect(_refuses(sample), isFalse, reason: sample);
    }
  });

  test("no code pushes a tab's path", () {
    final List<String> hits = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path.replaceAll('\\', '/').contains('/generated/')) {
        continue;
      }
      if (_refuses(entity.readAsStringSync())) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty);
  });
}
