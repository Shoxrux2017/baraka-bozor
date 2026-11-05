import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../domain/customer_orders.dart';
import 'customer_orders_controllers.dart';
import 'order_draft.dart';

/// How long the draft stays quiet before the server is asked its sums.
const Duration _quiet = Duration(milliseconds: 400);

/// The sums the editor shows (`DL-132`): the server's answer to the latest
/// draft, or the order's own while the lines are the order's.
@immutable
final class EditSummary {
  const EditSummary({
    required this.shown,
    this.waiting = false,
    this.failed = false,
    this.locked = false,
  });

  /// The last answer, or the order's own sums while the lines are the
  /// order's.
  final OrderEditPreview shown;

  /// The lines changed since [shown].
  final bool waiting;

  /// The last preview failed, or the draft cannot be priced.
  final bool failed;

  /// The server answered `order_editing_locked`.
  final bool locked;

  /// What the order's minimum still lacks; nothing when the sums are not
  /// known.
  int get shortfallUzs => failed ? 0 : shown.minimumShortfallUzs;

  EditSummary copyWith({
    OrderEditPreview? shown,
    bool? waiting,
    bool? failed,
    bool? locked,
  }) => EditSummary(
    shown: shown ?? this.shown,
    waiting: waiting ?? this.waiting,
    failed: failed ?? this.failed,
    locked: locked ?? this.locked,
  );
}

/// Asks the server the sums of the draft as it changes: after 400 ms of
/// quiet, one request at a time, and only the answer to the latest draft is
/// shown. An answer that comes after the account changed is dropped.
class OrderEditSummaryController extends Notifier<EditSummary> {
  OrderEditSummaryController(this.orderId);

  final String orderId;

  Timer? _timer;
  bool _inFlight = false;
  bool _again = false;

  @override
  EditSummary build() {
    ref.watch(customerAccountProvider);
    ref.onDispose(() => _timer?.cancel());
    final CustomerOrder? order = ref.read(customerOrderProvider(orderId)).value;
    if (order == null) {
      throw StateError('the order $orderId has not loaded; no sums to show');
    }
    ref.listen<int>(
      orderDraftProvider(orderId).select((OrderDraft draft) => draft.version),
      (int? _, int _) => _changed(),
    );
    final bool changed = ref.read(orderDraftProvider(orderId)).version != 0;
    if (changed) {
      _timer = Timer(_quiet, _fire);
    }
    return EditSummary(
      shown: OrderEditPreview.ofOrder(order),
      waiting: changed,
    );
  }

  /// A save refused for the minimum: the shortfall it named stands until
  /// the next answer.
  void refusedMinimum({required int minimumUzs, required int shortfallUzs}) {
    final OrderEditPreview shown = state.shown;
    state = state.copyWith(
      shown: OrderEditPreview(
        merchandiseSubtotalUzs: shown.merchandiseSubtotalUzs,
        serviceFeeUzs: shown.serviceFeeUzs,
        deliveryFeeUzs: shown.deliveryFeeUzs,
        totalUzs: shown.totalUzs,
        totalKind: shown.totalKind,
        totalBeforeUzs: shown.totalBeforeUzs,
        totalChangeUzs: shown.totalChangeUzs,
        minimumOrderUzs: minimumUzs,
        minimumShortfallUzs: shortfallUzs,
      ),
    );
  }

  void _changed() {
    if (state.locked) {
      return;
    }
    state = state.copyWith(waiting: true);
    _timer?.cancel();
    _timer = Timer(_quiet, _fire);
  }

  void _fire() {
    _timer = null;
    if (_inFlight) {
      _again = true;
      return;
    }
    _send();
  }

  Future<void> _send() async {
    final CustomerOrder? order = ref.read(customerOrderProvider(orderId)).value;
    if (order == null) {
      return;
    }
    final OrderDraft draft = ref.read(orderDraftProvider(orderId));
    final List<DraftLine> kept = draft.kept;
    if (kept.isEmpty || kept.any((DraftLine line) => !line.quantityValid)) {
      state = state.copyWith(waiting: false, failed: true);
      return;
    }
    if (!linesChange(draft, order)) {
      state = state.copyWith(
        shown: OrderEditPreview.ofOrder(order),
        waiting: false,
        failed: false,
      );
      return;
    }

    final int sent = draft.version;
    final String? account = ref.read(customerAccountProvider);
    _inFlight = true;
    OrderEditPreview? answer;
    ApiFailure? failure;
    try {
      answer = await ref.read(customerOrdersRepositoryProvider).previewEdit(
        orderId,
        <OrderEditLine>[for (final DraftLine line in kept) line.toEdit()],
      );
    } on ApiFailure catch (error) {
      failure = error;
    } catch (error, stackTrace) {
      reportUnexpectedError(
        error,
        stackTrace,
        'while previewing an order edit',
      );
      failure = const UnexpectedFailure();
    }
    _inFlight = false;
    if (!ref.mounted || ref.read(customerAccountProvider) != account) {
      return;
    }

    final bool latest = ref.read(orderDraftProvider(orderId)).version == sent;
    if (failure is ApiRefusal && failure.code == 'order_editing_locked') {
      // The lock is said before the order reloads, so the editor, still
      // mounted, sees it first.
      state = state.copyWith(waiting: false, locked: true);
      ref
        ..invalidate(customerOrderProvider(orderId))
        ..invalidate(customerOrdersProvider);
      return;
    }
    if (latest) {
      if (answer != null) {
        ref
            .read(orderDraftProvider(orderId).notifier)
            .setUnavailable(const <String>{});
        state = state.copyWith(shown: answer, waiting: false, failed: false);
      } else {
        if (failure is ApiRefusal && failure.code == 'product_unavailable') {
          ref
              .read(orderDraftProvider(orderId).notifier)
              .setUnavailable(_named(failure));
        }
        state = state.copyWith(waiting: false, failed: true);
      }
    }
    if (_again) {
      _again = false;
      await _send();
    }
  }

  /// The products the server named, in lower case.
  Set<String> _named(ApiRefusal failure) {
    final Object? named = failure.error.details['product_ids'];
    return <String>{
      if (named is List<Object?>)
        for (final Object? id in named)
          if (id is String) id.toLowerCase(),
    };
  }
}

final NotifierProviderFamily<OrderEditSummaryController, EditSummary, String>
orderEditSummaryProvider = NotifierProvider.autoDispose
    .family<OrderEditSummaryController, EditSummary, String>(
      OrderEditSummaryController.new,
    );
