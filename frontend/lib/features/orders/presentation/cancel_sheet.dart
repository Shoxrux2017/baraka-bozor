import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/failure_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../application/cancel_draft.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';
import 'cancel_sheet_form.dart';

/// How the cancel sheet ended (`DL-133`): the order is cancelled, a request
/// for its cancellation is with the Operator, or the Customer chose to edit
/// the order instead.
enum CancelSheetExit { cancelled, requested, edit }

/// The sheet that cancels an order, or asks an Operator to (`DL-133`). It
/// sends the cancel itself and stays open until the answer is on the sheet;
/// the exit says what the server answered, `null` when the sheet closed with
/// no outcome. What was typed is kept by the order's cancel controller, so a
/// closed and reopened sheet shows it again.
Future<CancelSheetExit?> showCancelSheet(
  BuildContext context, {
  required String orderId,
}) => showModalBottomSheet<CancelSheetExit>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext sheet) => CancelSheet(orderId: orderId),
);

/// The cancel sheet's body: one sheet whose face follows the order and the
/// cancel's state in place (`DL-133`): direct, request, retry of a send
/// whose answer was lost, or closed when the order allows neither.
class CancelSheet extends ConsumerStatefulWidget {
  const CancelSheet({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<CancelSheet> {
  late final TextEditingController _words = TextEditingController(
    text: _controller.draft.text,
  );
  final FocusNode _focus = FocusNode();
  Timer? _closing;

  /// What the Customer chose and wrote; the controller keeps a copy so a
  /// closed sheet shows it again.
  late CancelDraft _draft = _controller.draft;

  /// The Operator's question came up: a 422 on the reason.
  bool _forcedRequest = false;

  /// Whether a cancel was sent from this sheet, not an earlier one.
  bool _sentHere = false;

  /// Set from the send's start to the sheet's end: the face stays as it was
  /// while the cancel is on its way and while the outcome shows.
  CancelSheetMode? _held;
  bool _done = false;
  bool _doneCancelled = false;

  bool? _openedDirect;
  String? _lastNote;

  OrderCancelController get _controller =>
      ref.read(orderCancelProvider(widget.orderId).notifier);

  @override
  void initState() {
    super.initState();
    _words.addListener(_remember);
  }

  @override
  void dispose() {
    _closing?.cancel();
    _words.removeListener(_remember);
    _words.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _remember() {
    if (_draft.text != _words.text) {
      _change(_draft.copyWith(text: _words.text));
    }
  }

  void _change(CancelDraft draft) {
    if (!mounted || _held != null || _done) {
      return;
    }
    _controller.draft = draft;
    setState(() => _draft = draft);
  }

  /// The tip's «Изменить заказ»: the sheet ends and the order page opens the
  /// editor, so the cancel's draft is not kept.
  void _edit() {
    if (_held != null || _done) {
      return;
    }
    _focus.unfocus();
    _controller.draft = CancelDraft.empty;
    Navigator.of(context).pop(CancelSheetExit.edit);
  }

  Future<void> _send(CustomerOrder order, CancelSheetMode mode) async {
    if (_held != null) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OrderCancelController controller = _controller;
    final bool again = mode == CancelSheetMode.retry;
    final bool request = again
        ? controller.unconfirmedRequest
        : mode == CancelSheetMode.request;
    String? reason;
    if (again) {
      reason = controller.unconfirmedReason;
    } else {
      final String composed = _composed(l10n);
      if (cancelBlock(composed, request: request) != null) {
        return;
      }
      reason = composed.isEmpty ? null : composed;
    }

    setState(() {
      _held = mode;
      _sentHere = true;
    });
    announce(
      context,
      request ? l10n.requestSendingSpoken : l10n.cancelSendingSpoken,
    );
    final CustomerOrder? answered = await controller.cancel(
      reason,
      request: request,
    );
    if (!mounted) {
      return;
    }
    final ApiFailure? failure = ref
        .read(orderCancelProvider(widget.orderId))
        .failure;

    if (answered != null) {
      _show(answered);
    } else if (failure == null || failure is CancelledFailure) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _held = null;
        _forcedRequest = _forcedRequest || cancelNeedsReason(failure);
      });
      if (!controller.unconfirmed && !cancelNeedsReason(failure)) {
        final String? words = failureText(l10n, failure);
        if (words != null) {
          announce(context, words);
        }
      }
    }
  }

  /// The outcome on the sheet, which closes 550 ms later.
  void _show(CustomerOrder answered) {
    final bool cancelled = answered.status == OrderStatus.cancelled;
    _controller.draft = CancelDraft.empty;
    setState(() {
      _done = true;
      _doneCancelled = cancelled;
    });
    _closing = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        Navigator.of(context).pop(
          cancelled ? CancelSheetExit.cancelled : CancelSheetExit.requested,
        );
      }
    });
  }

  String _composed(AppLocalizations l10n) => composeCancelReason(
    _draft,
    (CancelChip chip) => cancelChipLabel(l10n, chip),
  );

  void _keep() {
    _controller.draft = CancelDraft.empty;
    Navigator.of(context).pop();
  }

  String _unsureNote(AppLocalizations l10n, MutationState state) {
    final String kind = _controller.unconfirmedRequest ? 'request' : 'other';
    final ApiFailure? failure = state.failure;
    if (failure is NetworkFailure && _sentHere) {
      return l10n.cancelUnsureNow(kind);
    }
    if (failure == null || failure is NetworkFailure) {
      return l10n.cancelUnsureLater(kind);
    }
    return l10n.cancelUnsureServer(kind);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerOrder> loaded = ref.watch(
      customerOrderProvider(widget.orderId),
    );
    final MutationState state = ref.watch(orderCancelProvider(widget.orderId));
    final CustomerOrder? order = loaded.value;
    if (order == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final OrderCancelController controller = _controller;
    final bool busy = state.isBusy;
    final bool holding = _held != null || _done;
    final CancelSheetMode mode =
        _held ??
        cancelSheetMode(
          order,
          unconfirmed: controller.unconfirmed,
          forcedRequest: _forcedRequest,
        );
    _openedDirect ??= mode == CancelSheetMode.direct;
    final bool switched = mode == CancelSheetMode.request && _openedDirect!;
    final bool retry = mode == CancelSheetMode.retry;
    final bool request = retry
        ? controller.unconfirmedRequest
        : mode == CancelSheetMode.request;

    final String? note = holding
        ? _lastNote
        : retry
        ? _unsureNote(l10n, state)
        : switched
        ? l10n.cancelSheetRaced
        : null;
    if (note != _lastNote) {
      _lastNote = note;
      if (note != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            announce(context, note);
          }
        });
      }
    }

    final String title = retry
        ? (request ? l10n.requestSheetUnsureTitle : l10n.cancelSheetUnsureTitle)
        : request
        ? l10n.requestSheetTitle(order.orderNumber)
        : l10n.cancelSheetTitle(order.orderNumber);

    final ApiFailure? failure = state.failure;
    final bool strip =
        _sentHere &&
        !holding &&
        mode != CancelSheetMode.closed &&
        failure != null &&
        !controller.unconfirmed &&
        !cancelNeedsReason(failure) &&
        failureText(l10n, failure) != null;

    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 16) > 1.3;

    return PopScope(
      canPop: !busy && !_done && keyboard == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && !busy && !_done) {
          _focus.unfocus();
        }
      },
      child: GestureDetector(
        onVerticalDragStart: busy || _done ? (_) {} : null,
        // The page's own refresh waits while a sheet covers it, so the sheet
        // keeps the order current for itself (`DL-133`).
        child: PeriodicRefresh(
          interval: const Duration(seconds: 15),
          active: !busy && !holding,
          onRefresh: () =>
              ref.invalidate(customerOrderProvider(widget.orderId)),
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Column(
              key: const ValueKey<String>('cancel-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: KitColors.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  key: const ValueKey<String>(
                                    'cancel-sheet-title',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: KitColors.ink,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey<String>('cancel-sheet-close'),
                              tooltip: MaterialLocalizations.of(context)
                                  .closeButtonTooltip,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              icon: const Icon(
                                Icons.close,
                                color: KitColors.ink,
                              ),
                              onPressed: busy || _done
                                  ? null
                                  : () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: KitColors.line,
                        ),
                        if (mode == CancelSheetMode.closed)
                          _ClosedStrip(text: _closedWords(l10n, order))
                        else if (retry) ...<Widget>[
                          _AmberNote(
                            key: const ValueKey<String>('cancel-unsure'),
                            icon: Icons.sync_problem,
                            text: note ?? '',
                          ),
                          _Quote(reason: controller.unconfirmedReason),
                        ] else ...<Widget>[
                          if (switched)
                            _AmberNote(
                              key: const ValueKey<String>('cancel-raced'),
                              icon: Icons.info_outline,
                              text: l10n.cancelSheetRaced,
                            )
                          else
                            Padding(
                              key: const ValueKey<String>('cancel-hint'),
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                request
                                    ? l10n.requestSheetHint
                                    : l10n.cancelSheetHint,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: KitColors.ink2,
                                ),
                              ),
                            ),
                          KeyedSubtree(
                            key: const ValueKey<String>('cancel-field'),
                            child: CancelReasonForm(
                              draft: _draft,
                              request: request,
                              canEdit: order.canEdit,
                              onChanged: _change,
                              onEdit: _edit,
                              text: _words,
                              focus: _focus,
                              locked: holding,
                            ),
                          ),
                        ],
                        if (strip)
                          _Strip(
                            words: failureText(l10n, failure)!,
                            onRetry: () => _send(order, mode),
                          ),
                      ],
                    ),
                  ),
                ),
                _footer(
                  l10n,
                  order,
                  mode,
                  request: request,
                  busy: busy,
                  large: large,
                  keyboard: keyboard > 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _closedWords(AppLocalizations l10n, CustomerOrder order) {
    if (order.status == OrderStatus.cancelled) {
      return l10n.orderStateCancelled;
    }
    if (order.cancellationRequest?.status ==
        CancellationRequestStatus.pending) {
      return l10n.cancelAlreadyAsked;
    }
    return l10n.errorOrderCancellationNotAllowed;
  }

  Widget _footer(
    AppLocalizations l10n,
    CustomerOrder order,
    CancelSheetMode mode, {
    required bool request,
    required bool busy,
    required bool large,
    required bool keyboard,
  }) {
    final bool sending = _held != null && !_done;
    final bool closed = mode == CancelSheetMode.closed;
    final bool retry = mode == CancelSheetMode.retry;
    final CancelBlock? block = retry || sending || _done
        ? null
        : cancelBlock(_composed(l10n), request: request);

    final Widget keep = Opacity(
      opacity: sending || _done ? 0.55 : 1,
      child: OutlinedButton(
        key: const ValueKey<String>('cancel-keep'),
        style: OutlinedButton.styleFrom(
          foregroundColor: KitColors.ink,
          disabledForegroundColor: KitColors.ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: KitColors.line),
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: sending || _done ? null : _keep,
        child: Text(
          l10n.orderCancelKeepKit,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );

    const TextStyle sendStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final Widget label;
    if (_done) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _doneCancelled
                  ? l10n.orderStateCancelled
                  : l10n.cancelSheetRequested,
              textAlign: TextAlign.center,
              style: sendStyle,
            ),
          ),
        ],
      );
    } else if (sending) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              request ? l10n.cancelSheetSending : l10n.cancelSheetCancelling,
              textAlign: TextAlign.center,
              style: sendStyle,
            ),
          ),
        ],
      );
    } else if (block != null) {
      label = Text(
        block == CancelBlock.empty
            ? l10n.cancelSheetNeedReason
            : l10n.cancelSheetTooLong(cancelReasonLimit),
        textAlign: TextAlign.center,
        style: sendStyle,
      );
    } else {
      label = Text(
        retry
            ? l10n.cancelSheetSendAgain
            : request
            ? l10n.cancelSheetSendRequest
            : l10n.cancelSheetConfirm,
        textAlign: TextAlign.center,
        style: sendStyle,
      );
    }

    final Widget send = FilledButton(
      key: const ValueKey<String>('cancel-confirm'),
      style: FilledButton.styleFrom(
        backgroundColor: KitColors.danger,
        foregroundColor: Colors.white,
        disabledBackgroundColor: KitColors.buttonOff,
        disabledForegroundColor: KitColors.muted,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: sending || _done
          ? () {}
          : block != null
          ? null
          : () => _send(order, mode),
      child: label,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + (keyboard ? 0 : MediaQuery.paddingOf(context).bottom),
        ),
        child: closed
            ? keep
            : large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[send, const SizedBox(height: 10), keep],
              )
            : Row(
                children: <Widget>[
                  Expanded(child: keep),
                  const SizedBox(width: 12),
                  Expanded(child: send),
                ],
              ),
      ),
    );
  }
}

/// An amber note on the sheet: the race with shopping, or the send whose
/// answer was lost.
class _AmberNote extends StatelessWidget {
  const _AmberNote({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KitColors.warningWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: KitColors.warningDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: KitColors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The reason of a send being repeated, in quotes.
class _Quote extends StatelessWidget {
  const _Quote({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        key: const ValueKey<String>('cancel-quote'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: KitColors.page,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          reason == null
              ? l10n.cancelSheetNoReason
              : l10n.cancelSheetQuote(reason!),
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: KitColors.ink2,
          ),
        ),
      ),
    );
  }
}

/// What the order's state says when it allows no cancel and no request.
class _ClosedStrip extends StatelessWidget {
  const _ClosedStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Container(
      key: const ValueKey<String>('cancel-closed'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KitColors.dangerWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error, size: 20, color: KitColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: KitColors.ink2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A refusal of the send, with the button that sends again.
class _Strip extends StatelessWidget {
  const _Strip({required this.words, required this.onRetry});

  final String words;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final Widget text = Text(
      words,
      style: const TextStyle(fontSize: 13, height: 1.35, color: KitColors.ink2),
    );
    final Widget retry = OutlinedButton(
      key: const ValueKey<String>('cancel-strip-retry'),
      style: OutlinedButton.styleFrom(
        foregroundColor: KitColors.danger,
        backgroundColor: Colors.white,
        side: BorderSide.none,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onRetry,
      child: Text(
        l10n.retryButton,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        key: const ValueKey<String>('cancel-strip'),
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: KitColors.dangerWash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.error,
                          size: 20,
                          color: KitColors.danger,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  retry,
                ],
              )
            : Row(
                children: <Widget>[
                  const Icon(Icons.error, size: 20, color: KitColors.danger),
                  const SizedBox(width: 10),
                  Expanded(child: text),
                  const SizedBox(width: 8),
                  retry,
                ],
              ),
      ),
    );
  }
}
