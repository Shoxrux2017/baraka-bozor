import '../../features/auth/domain/app_user.dart';

/// The fixed entry points of the route table: the areas of
/// `docs/07-architecture.md` section 29 and the screens the client passes
/// through before it reaches one.
abstract final class AppPaths {
  static const String bootstrap = '/';

  static const String auth = '/auth';
  static const String customerCode = '/auth/code';
  static const String staffLogin = '/auth/staff';
  static const String changePassword = '/auth/change-password';
  static const String customerMode = '/auth/customer-mode';
  static const String unreachable = '/auth/unreachable';
  static const String wrongSurface = '/auth/wrong-surface';

  static const String customer = '/customer';
  static const String shopper = '/shopper';
  static const String courier = '/courier';
  static const String operations = '/operations';
  static const String admin = '/admin';
  static const String manager = '/manager';

  /// The area a role works in.
  static String areaOf(UserRole role) => switch (role) {
    UserRole.customer => customer,
    UserRole.shopper => shopper,
    UserRole.courier => courier,
    UserRole.operator => operations,
    UserRole.admin => admin,
    UserRole.manager => manager,
  };

  /// Whether [location] is [area] or a page inside it.
  static bool isInside(String location, String area) =>
      location == area || location.startsWith('$area/');
}
