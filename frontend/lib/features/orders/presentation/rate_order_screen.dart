import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/localization/failure_text.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../application/rate_draft.dart';
import '../domain/customer_orders.dart';
import 'rate_order_footer.dart';
import 'rate_order_form.dart';
import 'rating_stars.dart';

/// What the rating screen returns when it leaves with an outcome (`DL-134`):
/// the rating was sent, or the order had been rated before. Every other way
/// out returns `null`.
enum RateExit { sent, already }

/// The Customer rates a delivered order (`DL-134`): stars, the reasons at one
/// to three of them, an optional comment. The server decides whether the
/// order can still be rated (`DL-92` item 6).
class RateOrderScreen extends ConsumerStatefulWidget {
  const RateOrderScreen({required this.orderId, this.stars, super.key});

  final String orderId;

  /// The stars tapped before the screen opened; anything outside 1 to 5 is
  /// ignored.
  final int? stars;

  @override
  ConsumerState<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends ConsumerState<RateOrderScreen> {
  late final TextEditingController _comment;
  late RateDraft _draft;

  /// The rating whose answer was lost: while it is set the form is locked and
  /// the next send repeats exactly this.
  RateBody? _sent;

  /// The answer came: the check stands before the screen goes.
  bool _ok = false;

  /// The window is closed: the calm face replaces the form.
  bool _closed = false;

  bool _checked = false;
  bool _left = false;
  Timer? _standing;

  @override
  void initState() {
    super.initState();
    final RateDraft? kept = ref.read(rateDraftsProvider)[widget.orderId];
    final int? tapped = widget.stars;
    _draft = (kept ?? RateDraft.empty).copyWith(
      stars: tapped != null && tapped >= 1 && tapped <= 5 ? tapped : null,
    );
    _comment = TextEditingController(text: _draft.comment);
    if (kept != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _announceRestored();
        }
      });
    }
  }

  @override
  void dispose() {
    _standing?.cancel();
    _comment.dispose();
    super.dispose();
  }

  /// A kept draft came back: the reader hears the stars with it.
  void _announceRestored() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? stars = _draft.stars;
    announce(
      context,
      stars == null
          ? l10n.rateDraftRestored
          : '${l10n.rateStarsValue(stars, RateOrderForm.wordOf(l10n, stars))}. '
                '${l10n.rateDraftRestored}',
    );
  }

  bool get _busy => ref.read(rateProvider(widget.orderId)).isBusy;

  /// Leaves the screen with [result]; the draft is the caller's to settle.
  void _exit([RateExit? result]) {
    if (_left || !mounted) {
      return;
    }
    _left = true;
    if (context.canPop()) {
      context.pop(result);
    } else {
      context.go(AppPaths.customerOrder(widget.orderId));
    }
  }

  /// Keeps what was written for the order's card, also from the locked face:
  /// the card shows it only while the server says the order can be rated, so a
  /// rating that did land never shows it (`DL-134` (9)). Only the closed face
  /// keeps nothing.
  void _keepOrDrop() {
    final RateDrafts drafts = ref.read(rateDraftsProvider.notifier);
    if (_closed) {
      drafts.drop(widget.orderId);
    } else {
      drafts.keep(widget.orderId, _draft);
    }
  }

  /// × and the way back.
  void _close() {
    if (_busy || _ok) {
      return;
    }
    _keepOrDrop();
    _exit();
  }

  void _leaveSettled([RateExit? result]) {
    ref.read(rateDraftsProvider.notifier).drop(widget.orderId);
    _exit(result);
  }

  /// The stars changed. A tap or a slide says the new value and, when the
  /// reasons appear or hide with chosen ones, that too; a screen reader's step
  /// says only the latter, since the reader speaks the value itself.
  void _onStars(int stars, RatingInput how) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool wasLow = isLowRating(_draft.stars);
    final bool isLow = isLowRating(stars);
    final String? extra = isLow && !wasLow
        ? l10n.rateReasonsShown
        : !isLow && wasLow && _draft.reasons.isNotEmpty
        ? l10n.rateReasonsHidden
        : null;
    setState(() => _draft = _draft.copyWith(stars: stars));
    if (how == RatingInput.reader) {
      if (extra != null) {
        announce(context, extra);
      }
      return;
    }
    final String value = l10n.rateStarsValue(
      stars,
      RateOrderForm.wordOf(l10n, stars),
    );
    final String said = RegExp(r'[.?!]$').hasMatch(value) ? value : '$value.';
    announce(context, extra == null ? said : '$said $extra');
  }

  Future<void> _send() async {
    final RateBody? body = _sent ?? _draft.body;
    if (body == null ||
        (_sent == null && _draft.tooLong) ||
        _busy ||
        _ok ||
        _closed) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final AppLocalizations l10n = AppLocalizations.of(context);
    announce(context, l10n.rateSendingSpoken);
    final CustomerOrder? order = await ref
        .read(rateProvider(widget.orderId).notifier)
        .rate(body.stars, body.reasons, body.comment);
    if (!mounted) {
      return;
    }
    final CustomerRating? rating = order?.rating;
    if (rating != null) {
      _succeed(rating.stars);
      return;
    }
    // An answer without the rating is no proof it was saved.
    final RateFailure? face = order != null
        ? RateFailure.unsure
        : rateFailureOf(ref.read(rateProvider(widget.orderId)).failure);
    switch (face) {
      case null:
        return;
      case RateFailure.unsent:
        if (_sent != null) {
          _lose(body);
        } else {
          announce(context, l10n.rateUnsentSpoken);
        }
      case RateFailure.unsure:
        _lose(body);
      case RateFailure.already:
        _leaveSettled(RateExit.already);
      case RateFailure.notRateable:
        _leaveSettled();
      case RateFailure.closed:
        ref.read(rateDraftsProvider.notifier).drop(widget.orderId);
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _closed = true);
        announce(context, '${l10n.rateClosedTitle}. ${l10n.rateClosedText}');
      case RateFailure.refused:
        if (_sent != null) {
          announce(context, l10n.rateUnsureSpoken);
        }
    }
  }

  /// The answer did not come: the rating may be saved, so the form freezes
  /// and the next send repeats [body].
  void _lose(RateBody body) {
    setState(() => _sent = body);
    announce(context, AppLocalizations.of(context).rateUnsureSpoken);
  }

  /// The rating is saved: the check stands, then the screen goes.
  void _succeed(int stars) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    unawaited(HapticFeedback.lightImpact());
    final String said = l10n.rateSentSpoken(stars);
    announce(
      context,
      isLowRating(stars) ? '$said ${l10n.rateOperatorWillContact}' : said,
    );
    ref.read(rateDraftsProvider.notifier).drop(widget.orderId);
    setState(() => _ok = true);
    _standing = Timer(
      Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 500 : 650,
      ),
      () => _exit(RateExit.sent),
    );
  }

  /// The first look at the order decides whether there is anything to rate:
  /// one already rated has nothing to ask, a delivered one past its window
  /// shows the calm face, any other leaves; later loads (the one after a lost
  /// answer) change nothing.
  void _settleOnOpen(CustomerOrder order) {
    _checked = true;
    if (order.rating != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _leaveSettled();
        }
      });
    } else if (!order.canRate) {
      if (order.status == OrderStatus.completed) {
        _closed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(rateDraftsProvider.notifier).drop(widget.orderId);
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _leaveSettled();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerOrder> order = ref.watch(
      customerOrderProvider(widget.orderId),
    );
    final MutationState sending = ref.watch(rateProvider(widget.orderId));
    if (!_checked && order.hasValue && !order.isLoading) {
      _settleOnOpen(order.requireValue);
    }
    final bool frozen = sending.isBusy || _ok;

    return PopScope(
      canPop: !frozen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop && !_left) {
          _left = true;
          _keepOrDrop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(
          title: l10n.rateTitle,
          leading: IconButton(
            key: const ValueKey<String>('rate-close'),
            icon: const Icon(Icons.close, color: KitColors.ink),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _close,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: order.hasValue
              ? _body(context, order.requireValue, sending)
              : order.hasError
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadFailure(
                    error: order.error!,
                    onRetry: () =>
                        ref.invalidate(customerOrderProvider(widget.orderId)),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    CustomerOrder order,
    MutationState sending,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ApiFailure? failure = sending.failure;
    final RateFailure? face = rateFailureOf(failure);
    final bool busy = sending.isBusy;
    final bool locked = _sent != null;
    final bool unsent = face == RateFailure.unsent;
    final String? refusal = face == RateFailure.refused
        ? failureText(l10n, failure!)
        : null;
    final bool canSend =
        _draft.body != null && !_draft.tooLong && !busy && !_ok;
    final RateFooterMode mode = _closed
        ? RateFooterMode.closed
        : _ok
        ? RateFooterMode.sent
        : busy
        ? RateFooterMode.sending
        : RateFooterMode.form;
    final VoidCallback? action = switch (mode) {
      RateFooterMode.closed => _leaveSettled,
      RateFooterMode.form =>
        locked || canSend ? () => unawaited(_send()) : null,
      _ => null,
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: _closed
                    ? _ClosedFace(l10n: l10n)
                    : RateOrderForm(
                        order: order,
                        draft: _draft,
                        onDraft: (RateDraft draft) =>
                            setState(() => _draft = draft),
                        onStars: _onStars,
                        comment: _comment,
                        frozen: busy || _ok,
                        locked: locked,
                      ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.7,
              ),
              child: RateOrderFooter(
                mode: mode,
                locked: locked,
                tooLong: _draft.tooLong,
                unsent: unsent,
                refusal: refusal,
                onPressed: action,
                onRetry: () => unawaited(_send()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The window has closed: a calm face instead of the form (`DL-134`).
class _ClosedFace extends StatelessWidget {
  const _ClosedFace({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return RateRise(
      child: Padding(
        key: const ValueKey<String>('rate-closed'),
        padding: const EdgeInsets.fromLTRB(8, 40, 8, 0),
        child: Column(
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.page,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 72,
                child: Icon(Icons.schedule, size: 34, color: KitColors.muted),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.rateClosedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.rateClosedText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: KitColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
