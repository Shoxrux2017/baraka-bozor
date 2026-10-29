import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/session/customer_account.dart';
import '../domain/cart.dart';
import 'cart_controllers.dart';

/// The quantity the Customer set, as a surface shows it until the server
/// answers: the wish, else the cart's line; `null` when the wish is "out of
/// the cart" or there is no line (`DL-119`).
String? shownCartQuantity(
  Map<String, String> wishes,
  String productId,
  CartLine? line,
) {
  final String? wish = wishes[productId];
  if (wish == null) {
    return line?.quantity;
  }
  return wish == CartQuantityQueue.out ? null : wish;
}

/// The one place the Customer's quantity changes of the cart go through, for
/// the product card, the product screen and the cart line alike (`DL-119`).
///
/// A step waits [settleDelay] after the last tap, so quick taps send one
/// change; an add, an exact quantity, a removal and an undo go at once. One
/// request per product runs at a time; a wish made meanwhile is sent after
/// its answer. The state is every wish the server has not answered yet, so
/// a surface can show it. It outlives any screen, so a step is still sent
/// after its screen is left, and another account drops every wish without
/// sending it (`frontend/AGENTS.md` sections 5 and 10).
class CartQuantityQueue extends Notifier<Map<String, String>> {
  /// The wish "this product is out of the cart".
  static const String out = '0';

  /// How long a step waits for the next tap.
  static const Duration settleDelay = Duration(milliseconds: 500);

  /// Counts the accounts this queue has served, so an answer that arrives
  /// after the account changed is ignored.
  int _generation = 0;

  final Map<String, Timer> _timers = <String, Timer>{};
  final Map<String, Completer<ApiFailure?>> _callers =
      <String, Completer<ApiFailure?>>{};
  final Map<String, NewCartLine> _templates = <String, NewCartLine>{};

  /// The product ids with a request on its way, and what each one carries.
  final Map<String, String> _sent = <String, String>{};

  /// The account this queue was built for; a wish never goes to another.
  String? _account;

  @override
  Map<String, String> build() {
    _account = ref.watch(customerAccountProvider);
    ref.onDispose(() {
      _generation++;
      for (final Timer timer in _timers.values) {
        timer.cancel();
      }
      for (final Completer<ApiFailure?> caller in _callers.values) {
        _complete(caller, null);
      }
      _timers.clear();
      _callers.clear();
      _templates.clear();
      _sent.clear();
    });
    return <String, String>{};
  }

  /// A step, or an exact quantity with [now]. It goes at once when the
  /// product has no line in the cart. Completes with the failure of the
  /// request that carried this wish, or `null` when it succeeded or a later
  /// call replaced it.
  Future<ApiFailure?> want(
    String productId,
    String quantity, {
    bool now = false,
  }) => _wish(productId, quantity, now: now);

  /// Takes the product out of the cart at once.
  Future<ApiFailure?> remove(String productId) =>
      _wish(productId, out, now: true);

  /// Puts [line] back at once, with its note and rule. [account] is the one
  /// the line was removed from; when another is signed in now, nothing is
  /// added and the call completes with `null` (`DL-119`).
  Future<ApiFailure?> restore(NewCartLine line, {required String? account}) {
    if (account == null || account != ref.read(customerAccountProvider)) {
      return Future<ApiFailure?>.value();
    }
    return _wish(line.productId, line.quantity, now: true, template: line);
  }

  /// Sends every waiting step now and completes when every product is
  /// answered; `true` when nothing failed.
  Future<bool> settle() async {
    final List<Future<ApiFailure?>> answers = <Future<ApiFailure?>>[];
    for (final String id in state.keys.toList()) {
      _timers.remove(id)?.cancel();
      _send(id);
      final Completer<ApiFailure?>? caller = _callers[id];
      if (caller != null) {
        answers.add(caller.future);
      }
    }
    final List<ApiFailure?> failures = await Future.wait(answers);
    return failures.every((ApiFailure? failure) => failure == null);
  }

  Future<ApiFailure?> _wish(
    String id,
    String quantity, {
    required bool now,
    NewCartLine? template,
  }) {
    final Completer<ApiFailure?>? previous = _callers[id];
    if (previous != null) {
      _complete(previous, null);
    }
    final Completer<ApiFailure?> caller = Completer<ApiFailure?>();
    _callers[id] = caller;
    state = <String, String>{...state, id: quantity};
    if (template != null) {
      _templates[id] = template;
    }
    _timers.remove(id)?.cancel();
    if (now || _lineOf(id) == null) {
      _send(id);
    } else {
      _timers[id] = Timer(settleDelay, () {
        _timers.remove(id);
        _send(id);
      });
    }
    return caller.future;
  }

  CartLine? _lineOf(String productId) {
    final String? account = ref.read(customerAccountProvider);
    final Cart? cart = account == null
        ? null
        : ref.read(cartProvider(account)).value;
    if (cart == null) {
      return null;
    }
    for (final CartLine line in cart.lines) {
      if (line.productId == productId) {
        return line;
      }
    }
    return null;
  }

  void _complete(Completer<ApiFailure?> caller, ApiFailure? failure) {
    if (!caller.isCompleted) {
      caller.complete(failure);
    }
  }

  /// Ends the wish of [id]: its state, timer and template go, and the newest
  /// caller hears [failure].
  void _done(String id, ApiFailure? failure) {
    _timers.remove(id)?.cancel();
    _templates.remove(id);
    if (state.containsKey(id)) {
      state = <String, String>{...state}..remove(id);
    }
    final Completer<ApiFailure?>? caller = _callers.remove(id);
    if (caller != null) {
      _complete(caller, failure);
    }
  }

  void _send(String id) {
    // The rebuild for another account may not have run yet; a wish made for
    // the last account is dropped here, never sent into this one's cart.
    if (ref.read(customerAccountProvider) != _account) {
      _done(id, null);
      return;
    }
    if (_sent.containsKey(id)) {
      return;
    }
    final String? quantity = state[id];
    if (quantity == null) {
      return;
    }
    final CartLine? line = _lineOf(id);
    final NewCartLine? template = _templates[id];
    if (quantity == out && line == null) {
      _done(id, null);
      return;
    }
    if (quantity != out &&
        line != null &&
        QuantityRules.thousandths(quantity) ==
            QuantityRules.thousandths(line.quantity)) {
      _done(id, null);
      return;
    }
    _sent[id] = quantity;
    unawaited(_run(id, quantity, line, template));
  }

  Future<void> _run(
    String id,
    String quantity,
    CartLine? line,
    NewCartLine? template,
  ) async {
    final int generation = _generation;
    ApiFailure? failure;
    bool answered;
    if (quantity == out) {
      final ProviderSubscription<Object?> hold = ref.listen(
        cartLineProvider(line!.id),
        (_, _) {},
      );
      try {
        answered =
            await ref.read(cartLineProvider(line.id).notifier).remove() != null;
        if (!ref.mounted || generation != _generation) {
          return;
        }
        failure = ref.read(cartLineProvider(line.id)).failure;
      } finally {
        hold.close();
      }
    } else if (line == null) {
      final ProviderSubscription<Object?> hold = ref.listen(
        addToCartProvider(id),
        (_, _) {},
      );
      try {
        answered =
            await ref
                .read(addToCartProvider(id).notifier)
                .add(
                  NewCartLine(
                    productId: id,
                    quantity: quantity,
                    customerNote: template?.customerNote,
                    substitutionPolicy:
                        template?.substitutionPolicy ??
                        SubstitutionPolicy.allowSimilar,
                  ),
                ) !=
            null;
        if (!ref.mounted || generation != _generation) {
          return;
        }
        failure = ref.read(addToCartProvider(id)).failure;
      } finally {
        hold.close();
      }
    } else {
      final ProviderSubscription<Object?> hold = ref.listen(
        cartLineProvider(line.id),
        (_, _) {},
      );
      try {
        answered =
            await ref
                .read(cartLineProvider(line.id).notifier)
                .change(
                  CartLinePatch.between(
                    line,
                    quantity: quantity,
                    customerNote: line.customerNote,
                    substitutionPolicy: line.substitutionPolicy,
                  ),
                ) !=
            null;
        if (!ref.mounted || generation != _generation) {
          return;
        }
        failure = ref.read(cartLineProvider(line.id)).failure;
      } finally {
        hold.close();
      }
    }

    if (generation != _generation) {
      return;
    }
    _sent.remove(id);
    if (!answered) {
      // The reloaded cart shows what the server holds, so a line that was
      // already there and a cancelled change are no failure to show.
      final bool quiet =
          failure == null ||
          failure is CancelledFailure ||
          (failure is ApiRefusal && failure.code == 'cart_item_already_exists');
      _done(id, quiet ? null : failure);
      return;
    }
    if (state[id] == quantity) {
      _done(id, null);
    } else if (!_timers.containsKey(id)) {
      _send(id);
    }
  }
}

/// Not auto-disposed: a step outlives the screen that made it.
final NotifierProvider<CartQuantityQueue, Map<String, String>>
cartQuantityQueueProvider =
    NotifierProvider<CartQuantityQueue, Map<String, String>>(
      CartQuantityQueue.new,
    );
