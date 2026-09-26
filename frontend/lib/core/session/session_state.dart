import '../../features/auth/domain/app_user.dart';
import '../storage/token_store.dart';

/// Which of the two sessions the interface is acting as
/// (`docs/02-user-roles.md` section 10). A mode maps one-to-one to a slot.
enum SessionMode {
  staff(SessionSlot.staff),
  customer(SessionSlot.customer);

  const SessionMode(this.slot);

  final SessionSlot slot;

  static SessionMode forSlot(SessionSlot slot) =>
      slot == SessionSlot.staff ? SessionMode.staff : SessionMode.customer;
}

/// What the client knows about its sessions after bootstrap.
sealed class SessionState {
  const SessionState();
}

/// No token in either slot.
final class SignedOut extends SessionState {
  const SignedOut();
}

/// A token exists but the server could not be reached to confirm who it is.
/// The token is kept; the person may retry.
final class SessionUnreachable extends SessionState {
  const SessionUnreachable();
}

/// At least one confirmed session, and which one is active.
final class SignedIn extends SessionState {
  const SignedIn({
    required this.activeMode,
    required this.staffUser,
    required this.customerUser,
  }) : assert(
         (activeMode == SessionMode.staff && staffUser != null) ||
             (activeMode == SessionMode.customer && customerUser != null),
         'the active mode must have a user',
       );

  final SessionMode activeMode;
  final AppUser? staffUser;
  final AppUser? customerUser;

  AppUser get activeUser =>
      activeMode == SessionMode.staff ? staffUser! : customerUser!;

  bool get hasStaff => staffUser != null;

  bool get hasCustomer => customerUser != null;

  /// Only a Shopper or Courier reaches Customer mode from the staff interface
  /// (`docs/02` section 10); the switch back is available whenever both exist.
  bool get canOfferCustomerMode =>
      staffUser != null &&
      (staffUser!.role == UserRole.shopper ||
          staffUser!.role == UserRole.courier) &&
      !staffUser!.mustChangePassword;

  SignedIn copyWith({
    SessionMode? activeMode,
    AppUser? staffUser,
    AppUser? customerUser,
    bool clearStaff = false,
    bool clearCustomer = false,
  }) {
    return SignedIn(
      activeMode: activeMode ?? this.activeMode,
      staffUser: clearStaff ? null : (staffUser ?? this.staffUser),
      customerUser: clearCustomer ? null : (customerUser ?? this.customerUser),
    );
  }
}
