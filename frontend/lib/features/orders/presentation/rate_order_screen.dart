import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/server_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

const int _commentMax = 500;

/// The Customer rates a delivered order (drawings 30 to 30б): stars, the
/// reasons at one to three of them, an optional comment. The server decides
/// whether the order can still be rated (`DL-92` item 6).
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
  final TextEditingController _comment = TextEditingController();
  late int? _stars =
      widget.stars != null && widget.stars! >= 1 && widget.stars! <= 5
      ? widget.stars
      : null;
  final Set<RatingReason> _reasons = <RatingReason>{};
  bool _checked = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.customerOrder(widget.orderId));
    }
  }

  int get _length => trimLikeServer(_comment.text).runes.length;

  bool get _low => _stars != null && _stars! <= 3;

  void _choose(int stars) {
    setState(() {
      _stars = stars;
      if (stars > 3) {
        _reasons.clear();
      }
    });
  }

  Future<void> _send() async {
    final int? stars = _stars;
    if (stars == null || _length > _commentMax) {
      return;
    }
    final RateController rating = ref.read(
      rateProvider(widget.orderId).notifier,
    );
    final String comment = trimLikeServer(_comment.text);
    final CustomerOrder? order = await rating.rate(stars, <RatingReason>[
      if (stars <= 3)
        for (final RatingReason reason in RatingReason.values)
          if (_reasons.contains(reason)) reason,
    ], comment.isEmpty ? null : comment);
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
    final int? stars = _stars;
    final ApiFailure? failure = sending.failure;
    final bool windowClosed =
        failure is ApiRefusal && failure.code == 'rating_window_closed';
    final bool tooLong = _length > _commentMax;
    final bool busy = sending.isBusy;
    final bool canSend = stars != null && !tooLong && !busy && !windowClosed;

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.primaryWash,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 72,
                      child: Icon(
                        Icons.shopping_bag,
                        size: 32,
                        color: KitColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.rateQuestion(order.orderNumber),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.rateHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: KitColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    for (int star = 1; star <= 5; star++)
                      Semantics(
                        button: true,
                        selected: stars == star,
                        label: l10n.rateStarsLabel(star),
                        excludeSemantics: true,
                        child: InkResponse(
                          key: ValueKey<String>('rate-star-$star'),
                          radius: 26,
                          onTap: () => _choose(star),
                          child: SizedBox.square(
                            dimension: 52,
                            child: Icon(
                              stars != null && star <= stars
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 44,
                              color: stars != null && star <= stars
                                  ? KitColors.warning
                                  : KitColors.line,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (stars != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _word(l10n, stars),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                  ),
                ],
                if (_low) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    l10n.rateWhatWrong,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final RatingReason reason in RatingReason.values)
                        FilterChip(
                          key: ValueKey<String>('rate-reason-${reason.code}'),
                          label: _reasons.contains(reason)
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: KitColors.primaryDark,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        OrderLabels.ratingReason(l10n, reason),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(OrderLabels.ratingReason(l10n, reason)),
                          selected: _reasons.contains(reason),
                          showCheckmark: false,
                          selectedColor: KitColors.primaryWash,
                          backgroundColor: KitColors.field,
                          onSelected: (bool on) => setState(
                            () => on
                                ? _reasons.add(reason)
                                : _reasons.remove(reason),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey<String>('rate-comment'),
                  controller: _comment,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.rateComment,
                    hintText: _low
                        ? l10n.rateCommentHintBad
                        : l10n.rateCommentHintGood,
                    counterText: '$_length / $_commentMax',
                    errorText: tooLong ? l10n.fieldTooLong(_commentMax) : null,
                  ),
                ),
                if (_low) ...<Widget>[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: KitColors.primaryWash,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.support_agent,
                            size: 22,
                            color: KitColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.rateOperatorWillCall,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: KitColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
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

  static String _word(AppLocalizations l10n, int stars) => switch (stars) {
    1 => l10n.rateStar1,
    2 => l10n.rateStar2,
    3 => l10n.rateStar3,
    4 => l10n.rateStar4,
    _ => l10n.rateStar5,
  };
}
