import '../../../core/routing/app_paths.dart';

/// The Customer catalog's locations. Its home is the Customer area itself,
/// [AppPaths.customer].
abstract final class CatalogPaths {
  /// Every category, four to a row.
  static const String categories = '${AppPaths.customer}/categories';
  static const String categoryPattern =
      '${AppPaths.customer}/categories/:category';
  static const String productPattern = '${AppPaths.customer}/products/:product';

  /// The recommended products, and every product with its sort.
  static const String recommended = '${AppPaths.customer}/recommended';
  static const String products = '${AppPaths.customer}/products';

  /// The search screen.
  static const String search = AppPaths.customerSearch;

  static String category(String id) =>
      '${AppPaths.customer}/categories/${Uri.encodeComponent(id)}';

  static String product(String id) =>
      '${AppPaths.customer}/products/${Uri.encodeComponent(id)}';
}
