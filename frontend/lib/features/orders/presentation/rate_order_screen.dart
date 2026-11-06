import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../application/rate_draft.dart';
import '../domain/customer_orders.dart';
import 'rate_order_form.dart';
import 'rating_stars.dart';

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
  bool _checked = false;

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

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.customerOrder(widget.orderId));
    }
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
    final RateBody? body = _draft.body;
    if (body == null || _draft.tooLong) {
      return;
    }
    final CustomerOrder? order = await ref
        .read(rateProvider(widget.orderId).notifier)
        .rate(body.stars, body.reasons, body.comment);
    if (!mounted) {
      return;
    }
    final ApiFailure? failure = ref.read(rateProvider(widget.orderId)).failure;
    final bool settled =
        failure is ApiRefusal &&
        (failure.code == 'order_already_rated' ||
            failure.code == 'order_not_rateable');
    if (order != null || settled) {
      _leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerOrder> order = ref.watch(
      customerOrderProvider(widget.orderId),
    );
    final MutationState sending = ref.watch(rateProvider(widget.orderId));

    // An order that cannot be rated when the screen opens has nothing to
    // ask; later loads (the one after sending) do not send the Customer away.
    if (!_checked && order.hasValue && !order.isLoading) {
      _checked = true;
      if (!order.requireValue.canRate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _leave();
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: l10n.rateTitle,
        leading: IconButton(
          key: const ValueKey<String>('rate-close'),
          icon: const Icon(Icons.close, color: KitColors.ink),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: _leave,
        ),
      ),
      body: SafeArea(
        child: order.hasValue
            ? _form(context, order.requireValue, sending)
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
    );
  }

  Widget _form(
    BuildContext context,
    CustomerOrder order,
    MutationState sending,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ApiFailure? failure = sending.failure;
    final bool windowClosed =
        failure is ApiRefusal && failure.code == 'rating_window_closed';
    final bool busy = sending.isBusy;
    final bool canSend =
        _draft.body != null && !_draft.tooLong && !busy && !windowClosed;

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: RateOrderForm(
              order: order,
              draft: _draft,
              onDraft: (RateDraft draft) => setState(() => _draft = draft),
              onStars: _onStars,
              comment: _comment,
              frozen: false,
              locked: false,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (windowClosed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.rateWindowClosed,
                      style: const TextStyle(color: KitColors.danger),
                    ),
                  ),
                )
              else
                FailureMessage(failure),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey<String>('rate-send'),
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: busy
                      ? KitColors.primary
                      : KitColors.line,
                  disabledForegroundColor: busy
                      ? Colors.white
                      : KitColors.muted,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: canSend ? _send : null,
                child: busy
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              l10n.rateSending,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        l10n.rateSend,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
