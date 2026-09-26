import '../../../core/routing/app_paths.dart';

/// The locations inside the Admin area. The area itself is
/// [AppPaths.admin]; the session guard keeps an Admin inside it.
abstract final class AdminPaths {
  static const String settings = '${AppPaths.admin}/settings';
  static const String categories = '${AppPaths.admin}/categories';
  static const String products = '${AppPaths.admin}/products';
  static const String newProduct = '$products/new';
  static const String staff = '${AppPaths.admin}/staff';

  /// The route pattern of one product's page.
  static const String productPattern = '$products/:product';

  static String product(String id) => '$products/${Uri.encodeComponent(id)}';
}
