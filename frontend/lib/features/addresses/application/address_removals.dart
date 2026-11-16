import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../domain/addresses.dart';
import 'addresses_controllers.dart';

/// An address taken off the list and waiting for its undo bar to close before
/// the server is told (`DL-137`). The account and the build of
/// [AddressRemovals] it was held under are noted when it is held.
final class AddressRemoval {
  AddressRemoval(this.address);

  final Address address;

  String? _account;
  int _build = 0;
  bool _undone = false;

  /// The one send of this removal; every closing of the bar shares it.
  Future<ApiFailure?>? _commit;
}

/// What [AddressRemovals] knows (`DL-137`).
final class AddressRemovalsState {
  const AddressRemovalsState({
    this.held,
    this.hidden = const <String>{},
    this.notRemoved,
  });

  /// The removal waiting for its bar, if any.
  final AddressRemoval? held;

  /// The ids kept off the lists: the held one, those being sent and those the
  /// server removed.
  final Set<String> hidden;

  /// The last address the server did not remove, and why.
  final ({String id, ApiFailure failure})? notRemoved;
}

/// The address removal waiting for its bar, at most one (`DL-137`). An address
/// removed from the list is hidden at once and reaches the server only when
/// the bar closes; the removal held before is sent first, and nothing is sent
/// for another account.
class AddressRemovals extends Notifier<AddressRemovalsState> {
  int _builds = 0;
  VoidCallback? _closeBar;

  /// The sends not yet answered; [flush] waits for all of them.
  final Set<Future<ApiFailure?>> _sending = <Future<ApiFailure?>>{};

  @override
  AddressRemovalsState build() {
    ref.watch(customerAccountProvider);
    _builds++;
    final AppLifecycleListener lifecycle = AppLifecycleListener(
      onHide: () => unawaited(flush()),
    );
    ref.onDispose(() {
      lifecycle.dispose();
      // What the previous account held is dropped unsent; its bar goes.
      final VoidCallback? close = _closeBar;
      _closeBar = null;
      close?.call();
    });
    return const AddressRemovalsState();
  }

  /// Holds [removal] until its bar closes; the removal held before is sent
  /// at once and its bar ended. [closeBar] closes the bar of [removal].
  void hold(AddressRemoval removal, {required VoidCallback closeBar}) {
    final AddressRemoval? previous = state.held;
    if (previous != null) {
      final VoidCallback? closePrevious = _closeBar;
      unawaited(commit(previous));
      closePrevious?.call();
    }
    removal
      .._account = ref.read(customerAccountProvider)
      .._build = _builds;
    _closeBar = closeBar;
    state = AddressRemovalsState(
      held: removal,
      hidden: <String>{...state.hidden, removal.address.id},
    );
  }

  /// «Вернуть»: the address comes back at its place and nothing is sent. The
  /// answer is whether it did: a removal already sent or dropped has nothing
  /// to bring back.
  bool undo(AddressRemoval removal) {
    if (removal._commit != null || removal._undone) {
      return false;
    }
    removal._undone = true;
    if (!_isCurrent(removal)) {
      return false;
    }
    _closeBar = identical(state.held, removal) ? null : _closeBar;
    state = AddressRemovalsState(
      held: identical(state.held, removal) ? null : state.held,
      hidden: <String>{...state.hidden}..remove(removal.address.id),
      notRemoved: state.notRemoved,
    );
    return true;
  }

  /// Sends [removal], once however often it is asked: [flush], the bar's own
  /// end and the next removal all lead to the same send. The answer is why it
  /// failed, `null` when it was sent, undone or not for this account.
  Future<ApiFailure?> commit(AddressRemoval removal) =>
      removal._commit ??= _track(_send(removal));

  Future<ApiFailure?> _track(Future<ApiFailure?> sending) {
    _sending.add(sending);
    return sending..whenComplete(() => _sending.remove(sending));
  }

  /// Sends the removal held, ends its bar and awaits it and every send still
  /// on its way: a list asked for after it sees them all.
  Future<void> flush() async {
    if (!ref.mounted) {
      return;
    }
    final AddressRemoval? held = state.held;
    if (held != null) {
      final VoidCallback? close = _closeBar;
      unawaited(commit(held));
      close?.call();
    }
    await Future.wait(<Future<ApiFailure?>>[..._sending]);
  }

  bool _isCurrent(AddressRemoval removal) =>
      ref.mounted &&
      removal._build == _builds &&
      removal._account == ref.read(customerAccountProvider);

  Future<ApiFailure?> _send(AddressRemoval removal) async {
    if (!ref.mounted) {
      return null;
    }
    if (identical(state.held, removal)) {
      _closeBar = null;
      state = AddressRemovalsState(
        hidden: state.hidden,
        notRemoved: state.notRemoved,
      );
    }
    if (removal._undone || !_isCurrent(removal)) {
      return null;
    }
    ApiFailure? failure;
    try {
      await ref.read(addressesRepositoryProvider).remove(removal.address.id);
    } catch (error, stackTrace) {
      if (error is! ApiFailure) {
        reportUnexpectedError(error, stackTrace, 'while removing an address');
      }
      failure = error is ApiFailure ? error : const UnexpectedFailure();
    }
    if (!_isCurrent(removal)) {
      return null;
    }
    // Already gone on the server is what was asked for.
    if (failure is ApiRefusal &&
        failure.status == 404 &&
        failure.code == 'resource_not_found') {
      failure = null;
    }
    if (failure != null) {
      // The delete may have reached the server: the list is read again,
      // unless the connection was never made.
      if (failure is! NetworkFailure || failure.mayHaveArrived) {
        ref.invalidate(addressesProvider);
      }
      state = AddressRemovalsState(
        held: state.held,
        hidden: <String>{...state.hidden}..remove(removal.address.id),
        notRemoved: (id: removal.address.id, failure: failure),
      );
      return failure;
    }
    ref.invalidate(addressesProvider);
    return null;
  }
}

final NotifierProvider<AddressRemovals, AddressRemovalsState>
addressRemovalsProvider =
    NotifierProvider<AddressRemovals, AddressRemovalsState>(
      AddressRemovals.new,
    );
