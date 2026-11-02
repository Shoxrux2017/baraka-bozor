import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the product screen changes the cart only through the queue', () {
    final String source = File(
      'lib/features/catalog/presentation/product_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('addToCartProvider')));
    expect(source, isNot(contains('cartLineProvider')));
  });
}
