import '../../../core/routing/app_paths.dart';

/// The cart's location inside the Customer area.
abstract final class CartPaths {
  static const String cart = '${AppPaths.customer}/cart';

  /// The cart with the editor of one line open, as a duplicate "add to
  /// cart" answers (`docs/09` section 17).
  static String line(String id) =>
      Uri(path: cart, queryParameters: <String, String>{'line': id}).toString();
}
