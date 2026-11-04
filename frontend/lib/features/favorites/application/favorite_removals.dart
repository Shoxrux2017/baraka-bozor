import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../../catalog/application/catalog_controllers.dart';
import '../../catalog/domain/catalog.dart';
import '../domain/favorites_repository.dart';
import 'favorites_controllers.dart';

/// Favourites taken off the screen and waiting for their undo bar to close
/// before the server is told (`DL-129`). The account and the build of
/// [FavoriteRemovals] it was held under are noted when it is held.
final class FavoriteRemoval {
  FavoriteRemoval({
    required this.query,
    required this.withdrawal,
    required this.productIds,
    required this.everyNotSold,
  });

  final ProductListQuery query;
  final ListWithdrawal withdrawal;

  /// The cards that left, whose hearts were marked off.
  final List<String> productIds;

  /// True for «Убрать все»: one call removes every not-sold favourite.
  final bool everyNotSold;

  String? _account;
  int _build = 0;
  bool _undone = false;

  /// The one send of this removal; every closing of the bar shares it.
  Future<ApiFailure?>? _commit;
}

/// The removal waiting for its bar, at most one (`DL-129`). A heart taken off
/// on the favourites screen reaches the server only when the bar closes; the
/// other removal is sent first, and nothing is sent for another account.
class FavoriteRemovals extends Notifier<FavoriteRemoval?> {
  int _builds = 0;
  VoidCallback? _closeBar;

  @override
  FavoriteRemoval? build() {
    ref.watch(customerAccountProvider);
    _builds++;
    ref.onDispose(() {
      // What the previous account held is dropped unsent; its bar goes.
      final VoidCallback? close = _closeBar;
      _closeBar = null;
      close?.call();
    });
    return null;
  }

  bool get holding => state != null;

  /// Holds [removal] until its bar closes; the removal held before is sent
  /// first. [closeBar] closes the bar of [removal].
  void hold(FavoriteRemoval removal, {required VoidCallback closeBar}) {
    final FavoriteRemoval? previous = state;
    if (previous != null) {
      unawaited(commit(previous));
    }
    removal
      .._account = ref.read(customerAccountProvider)
      .._build = _builds;
    _closeBar = closeBar;
    state = removal;
  }

  /// «Вернуть»: the cards come back at their places and nothing is sent.
  void undo(FavoriteRemoval removal) {
    if (removal._commit != null || removal._undone) {
      return;
    }
    removal._undone = true;
    _release(removal);
    if (!_isCurrent(removal)) {
      return;
    }
    _list(removal)?.restore(removal.withdrawal);
    ref.read(favoriteOverridesProvider.notifier).forget(removal.productIds);
  }

  /// Sends [removal], once however often it is asked: [flush], the bar's own
  /// end and the next removal all lead to the same send. The answer is why it
  /// failed, `null` when it was sent, undone or not for this account.
  Future<ApiFailure?> commit(FavoriteRemoval removal) =>
      removal._commit ??= _send(removal);

  /// Closes the bar of the removal held and awaits its sending.
  Future<void> flush() async {
    final FavoriteRemoval? held = state;
    if (held == null) {
      return;
    }
    final VoidCallback? close = _closeBar;
    final Future<ApiFailure?> sent = commit(held);
    close?.call();
    await sent;
  }

  bool _isCurrent(FavoriteRemoval removal) =>
      ref.mounted &&
      removal._build == _builds &&
      removal._account == ref.read(customerAccountProvider);

  void _release(FavoriteRemoval removal) {
    if (identical(state, removal)) {
      state = null;
      _closeBar = null;
    }
  }

  ProductListController? _list(FavoriteRemoval removal) {
    final list = productListProvider(removal.query);
    return ref.exists(list) ? ref.read(list.notifier) : null;
  }

  Future<ApiFailure?> _send(FavoriteRemoval removal) async {
    _release(removal);
    if (removal._undone || !_isCurrent(removal)) {
      return null;
    }
    final FavoritesRepository favorites = ref.read(favoritesRepositoryProvider);
    ApiFailure? failure;
    try {
      if (removal.everyNotSold) {
        await favorites.removeNotSold();
      } else {
        for (final String id in removal.productIds) {
          await favorites.remove(id);
        }
      }
    } catch (error, stackTrace) {
      if (error is! ApiFailure) {
        reportUnexpectedError(error, stackTrace, 'while removing favourites');
      }
      failure = error is ApiFailure ? error : const UnexpectedFailure();
    }
    if (!_isCurrent(removal)) {
      return null;
    }
    if (failure != null) {
      _list(removal)?.restore(removal.withdrawal);
      ref.read(favoriteOverridesProvider.notifier).forget(removal.productIds);
      return failure;
    }
    _list(removal)?.settle(removal.withdrawal);
    return null;
  }
}

final NotifierProvider<FavoriteRemovals, FavoriteRemoval?>
favoriteRemovalsProvider = NotifierProvider<FavoriteRemovals, FavoriteRemoval?>(
  FavoriteRemovals.new,
);
