import 'package:go_router/go_router.dart';

/// What the router shows right now.
extension VisibleLocation on GoRouter {
  /// The path of the page on top, a pushed page included, or `null` while
  /// the router has no page yet. A push for the order on this page needs no
  /// banner.
  String? get visiblePath {
    if (routerDelegate.currentConfiguration.isEmpty) {
      return null;
    }
    return state.uri.path;
  }
}
