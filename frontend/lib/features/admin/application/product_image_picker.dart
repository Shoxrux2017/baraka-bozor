import 'package:image_picker/image_picker.dart';

import '../domain/admin_catalog.dart';

/// The port through which the panel picks a product image, so the picking
/// path can be tested with a fake file.
abstract interface class ProductImagePicker {
  /// The image the Admin chose, or `null` when they cancelled.
  Future<PickedImage?> pick();
}

/// The browser's file dialog, limited to images, through `image_picker`.
class DialogProductImagePicker implements ProductImagePicker {
  const DialogProductImagePicker();

  @override
  Future<PickedImage?> pick() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) {
      return null;
    }
    return PickedImage(bytes: await file.readAsBytes(), name: file.name);
  }
}
