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
  const SessionUnreachable({this.retrying = false});

  /// A retry is running: the screen waits for it rather than starting
  /// another.
  final bool retrying;
}

/// Every stored session confirmed, and which one is active.
final class SignedIn extends SessionState {
  const SignedIn({
    required this.activeMode,
    required this.staffUser,
    required this.customerUser,
    this.staffStep,
  }) : assert(
         (activeMode == SessionMode.staff && staffUser != null) ||
             (activeMode == SessionMode.customer && customerUser != null),
         'the active mode must have a user',
       );

  final SessionMode activeMode;
  final AppUser? staffUser;
  final AppUser? customerUser;

  /// The pending password step of a Shopper or Courier whose code was just
  /// verified; the interface asks for the password while it is set.
  final StaffStep? staffStep;

  AppUser get activeUser =>
      activeMode == SessionMode.staff ? staffUser! : customerUser!;

  AppUser? userIn(SessionMode mode) =>
      mode == SessionMode.staff ? staffUser : customerUser;

  /// Only a Shopper or Courier reaches Customer mode from the staff interface
  /// (`docs/02` section 10), not while the first-login gate is set, and only
  /// when the customer session already exists: the code that opened the
  /// app opened it.
  bool get canOfferCustomerMode =>
      staffUser != null &&
      customerUser != null &&
      (staffUser!.role == UserRole.shopper ||
          staffUser!.role == UserRole.courier) &&
      !staffUser!.mustChangePassword;

  SignedIn copyWith({
    SessionMode? activeMode,
    AppUser? staffUser,
    AppUser? customerUser,
    StaffStep? staffStep,
  }) {
    return SignedIn(
      activeMode: activeMode ?? this.activeMode,
      staffUser: staffUser ?? this.staffUser,
      customerUser: customerUser ?? this.customerUser,
      staffStep: staffStep ?? this.staffStep,
    );
  }

  /// The same sessions without the pending step; [copyWith] cannot clear it.
  SignedIn withoutStaffStep() => SignedIn(
    activeMode: activeMode,
    staffUser: staffUser,
    customerUser: customerUser,
  );
}
