import '../../features/auth/domain/app_user.dart';
import '../storage/token_store.dart';

/// Which of the two sessions the interface is acting as
/// (`docs/02-user-roles.md` section 10). A mode maps one-to-one to a slot.
enum SessionMode {
  staff(SessionSlot.staff),
  customer(SessionSlot.customer);

  const SessionMode(this.slot);

  final SessionSlot slot;
}

/// What the client knows about its sessions after bootstrap.
sealed class SessionState {
  const SessionState();
}

/// No token in either slot.
final class SignedOut extends SessionState {
  const SignedOut();
}

/// At least one token exists but the server could not be reached to confirm
/// it. Every token is kept; the person may retry.
final class SessionUnreachable extends SessionState {
  const SessionUnreachable();
}

/// Every stored session confirmed, and which one is active.
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

  AppUser? userIn(SessionMode mode) =>
      mode == SessionMode.staff ? staffUser : customerUser;

  /// Only a Shopper or Courier reaches Customer mode from the staff interface
  /// (`docs/02` section 10), and not while the first-login gate is set.
  bool get canOfferCustomerMode =>
      staffUser != null &&
      (staffUser!.role == UserRole.shopper ||
          staffUser!.role == UserRole.courier) &&
      !staffUser!.mustChangePassword;

  SignedIn copyWith({
    SessionMode? activeMode,
    AppUser? staffUser,
    AppUser? customerUser,
  }) {
    return SignedIn(
      activeMode: activeMode ?? this.activeMode,
      staffUser: staffUser ?? this.staffUser,
      customerUser: customerUser ?? this.customerUser,
    );
  }
}
