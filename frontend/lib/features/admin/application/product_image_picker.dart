import '../domain/admin_catalog.dart';
import 'browser_product_image_picker_stub.dart'
    if (dart.library.js_interop) 'browser_product_image_picker.dart';

/// The port through which the panel picks a product image, so the picking
/// path can be tested with a fake file.
abstract interface class ProductImagePicker {
  /// The image the Admin chose, or `null` when they cancelled.
  Future<PickedImage?> pick();

  /// The browser's file dialog. The panel is built for the web only
  /// (`docs/07-architecture.md` section 27), so no other build links a
  /// picker (`DL-28` (6)).
  static ProductImagePicker platform() => const BrowserProductImagePicker();
}
