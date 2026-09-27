import '../../../core/routing/app_paths.dart';

/// The locations inside the Admin area. The area itself is
/// [AppPaths.admin]; the sections the panel's navigation links are declared
/// in [AppPaths], which the shared shell reads.
abstract final class AdminPaths {
  static const String settings = AppPaths.adminSettings;
  static const String categories = AppPaths.adminCategories;
  static const String products = AppPaths.adminProducts;
  static const String newProduct = '$products/new';
  static const String staff = AppPaths.adminStaff;

  /// The route pattern of one product's page.
  static const String productPattern = '$products/:product';

  static String product(String id) => '$products/${Uri.encodeComponent(id)}';
}
