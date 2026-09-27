import '../../features/auth/domain/app_user.dart';
import 'generated/app_localizations.dart';

/// A role's name in the interface language: the staff screen's roles and
/// the actor of an order's history.
String roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
  UserRole.shopper => l10n.roleShopper,
  UserRole.courier => l10n.roleCourier,
  UserRole.operator => l10n.roleOperator,
  UserRole.admin => l10n.roleAdmin,
  UserRole.manager => l10n.roleManager,
  UserRole.customer => l10n.shellCustomer,
};
