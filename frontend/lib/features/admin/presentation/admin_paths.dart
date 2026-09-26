import '../../../core/routing/app_paths.dart';

/// The locations inside the Admin area. The area itself is
/// [AppPaths.admin]; the session guard keeps an Admin inside it.
abstract final class AdminPaths {
  static const String settings = '${AppPaths.admin}/settings';
}
