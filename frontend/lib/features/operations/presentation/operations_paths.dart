import '../../../core/routing/app_paths.dart';

/// The locations inside the board. The board itself is
/// [AppPaths.operations].
abstract final class OperationsPaths {
  static const String orders = '${AppPaths.operations}/orders';

  /// The route pattern of one order's page.
  static const String orderPattern = '$orders/:order';

  static String order(String id) => '$orders/${Uri.encodeComponent(id)}';
}
