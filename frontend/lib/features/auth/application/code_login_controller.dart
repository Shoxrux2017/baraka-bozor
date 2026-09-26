import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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

  Future<bool> resend() {
    final String? phone = state.phone;
    if (phone == null) {
      return Future<bool>.value(false);
    }
    return state.forStaffAccount
        ? requestCodeForStaffAccount()
        : requestCode(phone);
  }

  /// Verifies [code]; on success the session changes and the router moves
  /// on, so this flow is over and its state is cleared.
  Future<bool> verify(String code) async {
    final String? phone = state.phone;
    if (phone == null || state.busy) {
      return false;
    }
    if (state.forStaffAccount && _staffUser() == null) {
      // The staff session ended while the code was on its way; the router
      // has already left this screen.
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
      if (generation == _generation) {
        state = state.copyWith(busy: false, failure: failure);
      }
      return false;
    }

    if (generation != _generation) {
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
  }) async {
    if (state.busy) {
      return false;
    }

    final int generation = ++_generation;
    state = state.copyWith(
      phone: phone,
      forStaffAccount: forStaffAccount,
      busy: true,
      clearFailure: true,
    );

    try {
      final RequestedCode requested = await send();
      if (generation != _generation) {
        return false;
      }
      state = state.copyWith(requested: requested, busy: false);
      _startCountdown(requested.resendAvailableInSeconds);
      return true;
    } on ApiFailure catch (failure) {
      if (generation == _generation) {
        state = state.copyWith(busy: false, failure: failure);
      }
      return false;
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
