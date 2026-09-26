import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../domain/admin_catalog.dart';
import 'product_image_picker.dart';

/// The browser's file dialog, offering the three image types the server
/// takes (`BR-CAT-004`). The dialog answers with the chosen file, or with
/// `cancel` when the Admin closes it.
class BrowserProductImagePicker implements ProductImagePicker {
  const BrowserProductImagePicker();

  static const String accepted = 'image/jpeg,image/png,image/webp';

  @override
  Future<PickedImage?> pick() {
    final Completer<PickedImage?> picked = Completer<PickedImage?>();
    final web.HTMLInputElement input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = accepted;
    input.style.display = 'none';
    // Some browsers report the choice only for an input in the document.
    web.document.body!.append(input);

    void settle(FutureOr<PickedImage?> Function() outcome) {
      input.remove();
      if (!picked.isCompleted) {
        picked.complete(Future<PickedImage?>.sync(outcome));
      }
    }

    input
      ..addEventListener(
        'change',
        (web.Event _) {
          settle(() => _read(input.files?.item(0)));
        }.toJS,
      )
      ..addEventListener(
        'cancel',
        (web.Event _) {
          settle(() => null);
        }.toJS,
      )
      ..click();
    return picked.future;
  }

  static Future<PickedImage?> _read(web.File? file) async {
    if (file == null) {
      return null;
    }
    final JSArrayBuffer buffer = await file.arrayBuffer().toDart;
    return PickedImage(bytes: buffer.toDart.asUint8List(), name: file.name);
  }
}
