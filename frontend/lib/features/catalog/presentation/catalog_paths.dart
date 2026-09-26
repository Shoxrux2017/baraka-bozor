import '../../../core/routing/app_paths.dart';

/// The Customer catalog's locations. Its home is the Customer area itself,
/// [AppPaths.customer].
abstract final class CatalogPaths {
  static const String categoryPattern =
      '${AppPaths.customer}/categories/:category';
  static const String productPattern = '${AppPaths.customer}/products/:product';

  static String category(String id) =>
      '${AppPaths.customer}/categories/${Uri.encodeComponent(id)}';

  static String product(String id) =>
      '${AppPaths.customer}/products/${Uri.encodeComponent(id)}';
}
