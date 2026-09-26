@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:baraka_bozor/features/admin/application/browser_product_image_picker.dart';
import 'package:baraka_bozor/features/admin/domain/admin_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// The file input the picker put in the document, if any.
web.HTMLInputElement? pickerInput() =>
    web.document.querySelector('input[type=file]') as web.HTMLInputElement?;

/// The panel's image picker in a real browser: the file input it opens,
/// what a chosen file comes back as, and a closed dialog.
void main() {
  test('a chosen file comes back as its bytes and name', () async {
    final Future<PickedImage?> picked = const BrowserProductImagePicker()
        .pick();
    final web.HTMLInputElement input = pickerInput()!;
    expect(input.accept, BrowserProductImagePicker.accepted);

    final web.DataTransfer transfer = web.DataTransfer();
    transfer.items.add(
      web.File(
        <web.BlobPart>[
          Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47]).toJS,
        ].toJS,
        'pomidor.png',
      ),
    );
    input
      ..files = transfer.files
      ..dispatchEvent(web.Event('change'));

    final PickedImage image = (await picked)!;
    expect(image.name, 'pomidor.png');
    expect(image.bytes, <int>[0x89, 0x50, 0x4E, 0x47]);
    expect(pickerInput(), isNull);
  });

  test('a closed dialog answers nothing and leaves nothing behind', () async {
    final Future<PickedImage?> picked = const BrowserProductImagePicker()
        .pick();

    pickerInput()!.dispatchEvent(web.Event('cancel'));

    expect(await picked, isNull);
    expect(pickerInput(), isNull);
  });
}
