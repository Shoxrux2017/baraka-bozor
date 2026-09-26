import '../domain/admin_catalog.dart';
import 'product_image_picker.dart';

/// Outside the browser there is no panel, and so nothing to pick with
/// (`docs/07-architecture.md` section 27).
class BrowserProductImagePicker implements ProductImagePicker {
  const BrowserProductImagePicker();

  @override
  Future<PickedImage?> pick() =>
      throw UnsupportedError('product images are picked in the web panel');
}
