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

  // Inside the Customer area, where more than one feature links: the
  // catalog's home opens the profile, the profile the addresses.
  static const String customerProfile = '$customer/profile';
  static const String customerAddresses = '$customer/addresses';
  static const String customerNewAddress = '$customerAddresses/new';
  static const String customerAddressPattern = '$customerAddresses/:address';
  // The cart links to the checkout.
  static const String customerCheckout = '$customer/checkout';
  // The catalog, the cart and the checkout link to the Customer's orders.
  static const String customerOrders = '$customer/orders';
  static const String customerOrderPattern = '$customerOrders/:order';
  static const String customerOrderEditPattern = '$customerOrderPattern/edit';

  static String customerOrder(String id) =>
      '$customerOrders/${Uri.encodeComponent(id)}';

  static String customerOrderEdit(String id) => '${customerOrder(id)}/edit';

  static String customerAddress(String id) =>
      '$customerAddresses/${Uri.encodeComponent(id)}';

  // Inside the Admin area, where the panel's shared navigation links
  // (`features/shells/presentation/panel_shell.dart`).
  static const String adminCategories = '$admin/categories';
  static const String adminProducts = '$admin/products';
  static const String adminStaff = '$admin/staff';
  static const String adminSettings = '$admin/settings';

  /// Where a role lands: its area, except the Admin's, which is the board
  /// (`DL-37` (17)).
  static String homeOf(UserRole role) => switch (role) {
    UserRole.customer => customer,
    UserRole.shopper => shopper,
    UserRole.courier => courier,
    UserRole.operator => operations,
    UserRole.admin => operations,
    UserRole.manager => manager,
  };

  /// The areas a role works in: its own, and for the Admin the board as
  /// well (`DL-37` (17)).
  static List<String> areasOf(UserRole role) => switch (role) {
    UserRole.admin => const <String>[admin, operations],
    _ => <String>[homeOf(role)],
  };

  /// Whether [location] is [area] or a page inside it.
  static bool isInside(String location, String area) =>
      location == area || location.startsWith('$area/');

  /// The bootstrap screen, remembering [requested] as `next`, so the page a
  /// reload asked for opens once the session is known (`DL-46` (1)).
  static String bootstrapKeeping(Uri requested) => Uri(
    path: bootstrap,
    queryParameters: <String, String>{'next': requested.toString()},
  ).toString();
}
