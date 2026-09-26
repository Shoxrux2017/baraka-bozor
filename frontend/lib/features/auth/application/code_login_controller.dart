import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../domain/app_user.dart';

/// Where a code login stands: which phone the code went to, what the server
/// said about it, how long until another may be sent, and whether a request
/// is in flight.
final class CodeLoginState {
  const CodeLoginState({
    this.phone,
    this.forStaffAccount = false,
    this.requested,
    this.resendInSeconds = 0,
    this.busy = false,
    this.failure,
  });

  /// The E.164 phone the code was requested for.
  final String? phone;

  /// Customer mode from the staff interface: the phone is the staff
  /// account's own and the session that opens is the customer one.
  final bool forStaffAccount;

  final RequestedCode? requested;

  /// Seconds until the server accepts another send; counts down to zero.
  final int resendInSeconds;

  final bool busy;

  final ApiFailure? failure;

  bool get hasCode => requested != null;

  bool get canResend => hasCode && resendInSeconds == 0 && !busy;

  CodeLoginState copyWith({
    String? phone,
    bool? forStaffAccount,
    RequestedCode? requested,
    int? resendInSeconds,
    bool? busy,
    ApiFailure? failure,
    bool clearFailure = false,
  }) {
    return CodeLoginState(
      phone: phone ?? this.phone,
      forStaffAccount: forStaffAccount ?? this.forStaffAccount,
      requested: requested ?? this.requested,
      resendInSeconds: resendInSeconds ?? this.resendInSeconds,
      busy: busy ?? this.busy,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// The code login of `docs/04-user-flows.md` section 2, and the Customer-mode
/// entry of `docs/02-user-roles.md` section 10, which is the same flow with
/// the staff account's own phone.
///
/// Every request carries a generation number; an answer to a request this
/// controller has since superseded — a changed phone, a reset — is discarded
/// (`docs/07-architecture.md` section 28). Only one request runs at a time.
/// A new request starts from a clean state, so nothing of an earlier flow —
/// another phone, the other mode — survives into it; a resend keeps the
/// code it repeats. Whatever a call throws, the screen is usable afterwards.
class CodeLoginController extends Notifier<CodeLoginState> {
  int _generation = 0;
  Timer? _countdown;

  @override
  CodeLoginState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const CodeLoginState();
  }

  SessionController get _session =>
      ref.read(sessionControllerProvider.notifier);

  /// Customer login: asks for a code for [phone].
  Future<bool> requestCode(String phone) => _request(
    phone: phone,
    forStaffAccount: false,
    send: () => _session.requestCustomerCode(phone),
  );

  /// Customer mode: asks for a code for the confirmed staff account's phone.
  Future<bool> requestCodeForStaffAccount() {
    final AppUser? staff = _staffUser();
    if (staff == null) {
      return Future<bool>.value(false);
    }
    return _request(
      phone: staff.phone,
      forStaffAccount: true,
      send: _session.requestCustomerModeCode,
    );
  }

  /// Another code for the same phone. The code already on the way stays
  /// valid, so a refused resend keeps the entry screen and shows why.
  Future<bool> resend() {
    final String? phone = state.phone;
    if (phone == null || !state.hasCode) {
      return Future<bool>.value(false);
    }
    return _request(
      phone: phone,
      forStaffAccount: state.forStaffAccount,
      send: state.forStaffAccount
          ? _session.requestCustomerModeCode
          : () => _session.requestCustomerCode(phone),
      resend: true,
    );
  }

  /// Verifies [code]; on success the session changes and the router moves
  /// on, so this flow is over and its state is cleared.
  Future<bool> verify(String code) async {
    final String? phone = state.phone;
    if (phone == null || state.busy) {
      return false;
    }
    if (state.forStaffAccount && _staffUser()?.phone != phone) {
      // The staff session ended, or another staff account signed in, while
      // the code was on its way; the router has already left this screen.
      _clear();
      return false;
    }

    final int generation = ++_generation;
    state = state.copyWith(busy: true, clearFailure: true);

    try {
      if (state.forStaffAccount) {
        await _session.enterCustomerMode(code: code);
      } else {
        await _session.verifyCustomerCode(phone: phone, code: code);
      }
    } on ApiFailure catch (failure) {
      _fail(generation, failure);
      return false;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure());
      reportUnexpectedError(error, stackTrace, 'while verifying a login code');
      return false;
    }

    if (!_current(generation)) {
      return false;
    }
    _clear();
    return true;
  }

  /// Back to the phone entry, with the phone kept for editing.
  void changePhone() {
    _generation++;
    _countdown?.cancel();
    state = CodeLoginState(phone: state.forStaffAccount ? null : state.phone);
  }

  /// Abandons the flow entirely, for example when Customer mode is
  /// cancelled.
  void reset() {
    _generation++;
    _clear();
  }

  Future<bool> _request({
    required String phone,
    required bool forStaffAccount,
    required Future<RequestedCode> Function() send,
    bool resend = false,
  }) async {
    if (state.busy) {
      return false;
    }

    final int generation = ++_generation;
    if (resend) {
      state = state.copyWith(busy: true, clearFailure: true);
    } else {
      _countdown?.cancel();
      state = CodeLoginState(
        phone: phone,
        forStaffAccount: forStaffAccount,
        busy: true,
      );
    }

    try {
      final RequestedCode requested = await send();
      if (!_current(generation)) {
        return false;
      }
      state = state.copyWith(requested: requested, busy: false);
      _startCountdown(requested.resendAvailableInSeconds);
      return true;
    } on ApiFailure catch (failure) {
      _fail(generation, failure);
      return false;
    } catch (error, stackTrace) {
      _fail(generation, const UnexpectedFailure());
      reportUnexpectedError(error, stackTrace, 'while requesting a login code');
      return false;
    }
  }

  /// Whether a completion still belongs to the current request of a live
  /// controller.
  bool _current(int generation) => generation == _generation && ref.mounted;

  void _fail(int generation, ApiFailure failure) {
    if (_current(generation)) {
      state = state.copyWith(busy: false, failure: failure);
    }
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    state = state.copyWith(resendInSeconds: seconds < 0 ? 0 : seconds);
    if (seconds <= 0) {
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int left = state.resendInSeconds - 1;
      state = state.copyWith(resendInSeconds: left < 0 ? 0 : left);
      if (left <= 0) {
        timer.cancel();
      }
    });
  }

  void _clear() {
    _countdown?.cancel();
    state = const CodeLoginState();
  }

  AppUser? _staffUser() {
    final SessionState? session = ref.read(sessionControllerProvider).value;
    return session is SignedIn ? session.staffUser : null;
  }
}

final NotifierProvider<CodeLoginController, CodeLoginState>
codeLoginControllerProvider =
    NotifierProvider<CodeLoginController, CodeLoginState>(
      CodeLoginController.new,
    );
