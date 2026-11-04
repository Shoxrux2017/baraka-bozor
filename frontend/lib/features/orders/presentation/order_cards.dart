import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/deadline_chip.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/kit/kit_star.dart';
import '../../../core/widgets/product_image.dart';
import '../domain/customer_orders.dart';
import 'order_card_words.dart';
import 'order_preview.dart';
import 'order_stage_bar.dart';
import 'reorder_sheet.dart';

/// How far an order has come, for the card's progress bar: 1 accepted, 2
/// being shopped or made ready, 3 on the way, 4 delivered; 0 for an order
/// that did not happen.
int orderStage(OrderStatus status) => switch (status) {
  OrderStatus.newOrder || OrderStatus.shoppingAssigned => 1,
  OrderStatus.shopping ||
  OrderStatus.finalPaymentPending ||
  OrderStatus.readyForDelivery ||
  OrderStatus.deliveryAssigned => 2,
  OrderStatus.onTheWay => 3,
  OrderStatus.completed => 4,
  OrderStatus.cancelled => 0,
};

/// The order's status in the Customer's words on a wash of its colour.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color ink, Color wash) = switch (status) {
      OrderStatus.shopping || OrderStatus.finalPaymentPending => (
        KitColors.warningDark,
        KitColors.warningWash,
      ),
      OrderStatus.cancelled => (
        KitColors.danger,
        KitColors.danger.withValues(alpha: 0.08),
      ),
      OrderStatus.completed => (KitColors.muted, KitColors.field),
      _ => (KitColors.primaryDark, KitColors.primaryWash),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          OrderLabels.customerStatus(AppLocalizations.of(context), status),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      ),
    );
  }
}

/// Whether the orders list is the route on top and its tickers are on, which
/// is what `PeriodicRefresh` calls shown: only then does a change speak and
/// buzz (`DL-131`).
bool ordersListShown(BuildContext context) =>
    (ModalRoute.of(context)?.isCurrent ?? true) &&
    TickerMode.valuesOf(context).enabled;

/// An order still in hand (`DL-131`): its status over the four labelled
/// stages, the question waiting for the Customer with the minutes left, and
/// the Courier's phone once it is on the way. The question's strip keeps the
/// deadlines it saw ahead of the phone's clock: it counts down by that clock,
/// folds 400 ms after the last one ran out and says so, and stays folded until
/// a load brings a question (`DL-131` (6)); a deadline already past on the
/// phone when it loaded keeps the strip, without minutes, until the next load
/// (`DL-130` (6)). [glow] and [headline] are counters the list raises when the
/// order changed: the card rings in the brand colour, and the status fades in.
class CurrentOrderCard extends ConsumerStatefulWidget {
  const CurrentOrderCard({
    required this.order,
    this.glow = 0,
    this.headline = 0,
    super.key,
  });

  final OrderSummary order;
  final int glow;
  final int headline;

  @override
  ConsumerState<CurrentOrderCard> createState() => _CurrentOrderCardState();
}

class _CurrentOrderCardState extends ConsumerState<CurrentOrderCard>
    with TickerProviderStateMixin {
  /// 1 at rest; runs 0 → 1 over 1400 ms while the ring fades.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 1400),
  );

  /// 1 at rest; runs 0 → 1 over 320 ms while the status fades in.
  late final AnimationController _headline = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 320),
  );

  /// The deadlines the load brought that were still ahead of the phone's
  /// clock, earliest first, and how many questions the server counted.
  List<DateTime> _ahead = <DateTime>[];
  int _count = 0;

  /// The strip's time ran out and it has folded.
  bool _expired = false;
  Timer? _wake;
  Timer? _expire;

  /// What the strip and the call button last held, to fold away with it.
  int _stripQuestions = 0;
  DateTime? _stripDeadline;
  String? _phone;

  /// The strip is shown now, as the last build decided; read when it has
  /// folded.
  bool _stripOpen = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(CurrentOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.order, oldWidget.order)) {
      _reset();
    }
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (widget.glow != oldWidget.glow && !still) {
      _glow.forward(from: 0);
    }
    if (widget.headline != oldWidget.headline && !still) {
      _headline.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wake?.cancel();
    _expire?.cancel();
    _glow.dispose();
    _headline.dispose();
    super.dispose();
  }

  /// A load brought this summary: the clock starts over from its deadlines.
  void _reset() {
    final DateTime now = ref.read(clockProvider)();
    _count = widget.order.pendingApprovalCount;
    _ahead = <DateTime>[
      for (final DateTime when in widget.order.questionDeadlines)
        if (when.isAfter(now)) when,
    ];
    _expired = false;
    _expire?.cancel();
    _expire = null;
  }

  /// Wakes the card at the earliest deadline still ahead, and when no
  /// question is open any more folds the strip 400 ms later with a word.
  void _arm(DateTime now, int open, DateTime? until) {
    _wake?.cancel();
    _wake = until == null
        ? null
        : Timer(until.difference(now), () {
            if (mounted) {
              setState(() {});
            }
          });
    if (_count > 0 && open == 0 && !_expired && _expire == null) {
      _expire = Timer(const Duration(milliseconds: 400), () {
        _expire = null;
        if (!mounted) {
          return;
        }
        setState(() => _expired = true);
        if (ordersListShown(context)) {
          announce(
            context,
            AppLocalizations.of(context)
                .orderQuestionsExpiredAnnounced(widget.order.orderNumber),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final OrderSummary order = widget.order;
    final DateTime now = ref.watch(clockProvider)();
    final int open = math.max(
      0,
      _count - _ahead.where((DateTime when) => !when.isAfter(now)).length,
    );
    final DateTime? until = _ahead
        .where((DateTime when) => when.isAfter(now))
        .firstOrNull;
    _arm(now, open, until);
    // Shown while the server counts questions, until the last one ran out and
    // the 400 ms after it have passed.
    final bool stripShown = _count > 0 && !_expired;
    _stripOpen = stripShown;
    if (open > 0) {
      _stripQuestions = open;
      _stripDeadline = until;
    }
    final String? phone = order.courierPhone;
    if (phone != null) {
      _phone = phone;
    }
    final String? callPhone = _phone;
    final int asked = _expired ? 0 : open;
    final int? minutes = until == null ? null : minutesLeft(until, now);
    void openOrder() => context.push(AppPaths.customerOrder(order.id));

    return Semantics(
      container: true,
      button: true,
      onTap: openOrder,
      label: currentOrderSpoken(
        l10n,
        language,
        order,
        now,
        minutesLeft: minutes == 0 ? null : minutes,
        questions: asked,
      ),
      child: _CardShell(
        cardKey: ValueKey<String>('order-${order.id}'),
        onTap: openOrder,
        glow: _glow,
        children: <Widget>[
          ExcludeSemantics(
            child: _CurrentTop(order: order, fade: _headline),
          ),
          Fold(
            shown: stripShown,
            onFolded: () {
              if (!_stripOpen) {
                setState(() => _stripQuestions = 0);
              }
            },
            child: _stripQuestions == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _QuestionStrip(
                      order: order,
                      questions: _stripQuestions,
                      deadline: _stripDeadline,
                      onOpen: openOrder,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          OrderStageBar(
            stage: orderStage(order.status),
            labels: orderListStageLabels(l10n),
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(child: _Bottom(order: order)),
          Fold(
            shown: phone != null,
            onFolded: () {
              if (widget.order.courierPhone == null) {
                setState(() => _phone = null);
              }
            },
            child: callPhone == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      container: true,
                      button: true,
                      label: l10n.callCourierSpoken(order.orderNumber),
                      onTap: () => _call(context, ref, callPhone),
                      excludeSemantics: true,
                      child: OutlinedButton.icon(
                        key: ValueKey<String>('order-call-courier-${order.id}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: KitColors.ink,
                          side: const BorderSide(color: KitColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.call,
                          size: 18,
                          color: KitColors.primary,
                        ),
                        label: Text(
                          l10n.callCourier,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _call(context, ref, callPhone),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String phone) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool opened = await ref.read(phoneCallsProvider).call(phone);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.callFailed(formatPhone(phone)))),
      );
    }
  }
}

/// An order that ended (`DL-131`): its pictures beside its status, what it
/// holds, the way to rate it while the server allows it or the rating it
/// has, and the way to order it again.
class PastOrderCard extends ConsumerWidget {
  const PastOrderCard({required this.order, super.key});

  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DateTime now = ref.watch(clockProvider)();
    final int? rated = order.ratingStars;
    final bool rateable = order.canRate;
    final Widget repeat = RepeatOrderButton(
      orderId: order.id,
      orderNumber: order.orderNumber,
      wide: false,
    );
    void open() => context.push(AppPaths.customerOrder(order.id));

    return Semantics(
      container: true,
      button: true,
      onTap: open,
      label: pastOrderSpoken(l10n, language, order, now),
      child: _CardShell(
        cardKey: ValueKey<String>('order-${order.id}'),
        onTap: open,
        children: <Widget>[
          ExcludeSemantics(
            child: _PreviewHead(
              order: order,
              line:
                  '${l10n.customerOrderTitle(order.orderNumber)} · '
                  '${order.street}, ${order.house}',
              chip: OrderStatusChip(status: order.status),
            ),
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(child: _Bottom(order: order)),
          const SizedBox(height: 12),
          if (rateable || rated != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExcludeSemantics(
                  child: Text(
                    rateable ? l10n.orderRateCaption : l10n.orderRatedCaption,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: KitColors.muted,
                    ),
                  ),
                ),
                _RatingRow(
                  starsWidth: rateable ? 220 : 130,
                  stars: rateable
                      ? OrderRateStars(order: order)
                      : _RatedStars(order: order, stars: rated!),
                  repeat: repeat,
                ),
              ],
            )
          else
            Align(alignment: AlignmentDirectional.centerEnd, child: repeat),
        ],
      ),
    );
  }
}

/// The stars at the start of the row and «Повторить» at its end; when the
/// two do not fit on a line, «Повторить» goes under the stars, still at the
/// end (the page's `space-between` with `margin-left: auto`). The fit is
/// measured from the button's label at the user's text size.
class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.starsWidth,
    required this.stars,
    required this.repeat,
  });

  final double starsWidth;
  final Widget stars;
  final Widget repeat;

  @override
  Widget build(BuildContext context) {
    final double repeatWidth =
        // Padding 14 + 14, the icon 18 and the gap 6, then the label.
        52 +
        textWidth(
          context,
          AppLocalizations.of(context).reorderRepeat,
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        if (starsWidth + 8 + repeatWidth <= box.maxWidth) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[stars, repeat],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(alignment: AlignmentDirectional.centerStart, child: stars),
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerEnd, child: repeat),
          ],
        );
      },
    );
  }
}

/// The last order, shown in the empty «Текущие» (`DL-131`): its pictures,
/// its names, when it was placed and what it cost, and the outlined way to
/// order it again. A tap opens the order.
class LastOrderCard extends ConsumerWidget {
  const LastOrderCard({required this.order, super.key});

  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DateTime now = ref.watch(clockProvider)();
    void open() => context.push(AppPaths.customerOrder(order.id));

    return Semantics(
      container: true,
      button: true,
      onTap: open,
      label: pastOrderSpoken(l10n, language, order, now),
      child: _CardShell(
        cardKey: ValueKey<String>('order-last-${order.id}'),
        onTap: open,
        children: <Widget>[
          ExcludeSemantics(
            child: _PreviewHead(
              order: order,
              line:
                  '${orderWhen(l10n, order.createdAt, now)} · '
                  '${_amountText(l10n, language, order)}',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: RepeatOrderButton(
              orderId: order.id,
              orderNumber: order.orderNumber,
              wide: false,
              outlined: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// The head of a past or last-order card: the pictures (with the status
/// [chip] beside them, at most half the row), the names, then one small
/// [line].
class _PreviewHead extends StatelessWidget {
  const _PreviewHead({required this.order, required this.line, this.chip});

  final OrderSummary order;
  final String line;
  final Widget? chip;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool wraps = textScaleAt(MediaQuery.textScalerOf(context), 12) > 1.3;
    final String names = previewNames(
      l10n,
      interfaceLanguage(context),
      order.preview,
    );
    final Widget? chip = this.chip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: OrderPictures(preview: order.preview)),
              if (chip != null) ...<Widget>[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
                  child: chip,
                ),
              ],
            ],
          ),
        ),
        if (names.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            names,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: KitColors.ink,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          line,
          maxLines: wraps ? null : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
      ],
    );
  }
}

/// The card on its shadow. While [glow] runs (0 to 1) a 3 px ring of the brand
/// colour fades from 0.55 to 0 over the shadow (`DL-131`); at 1 there is none.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.cardKey,
    required this.onTap,
    required this.children,
    this.glow,
  });

  final Key cardKey;
  final VoidCallback onTap;
  final List<Widget> children;
  final Animation<double>? glow;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);

    final Widget card = Material(
      color: Colors.white,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    const BoxShadow kit = BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 2),
    );

    return AnimatedBuilder(
      animation: glow ?? const AlwaysStoppedAnimation<double>(1),
      child: card,
      builder: (BuildContext context, Widget? child) {
        final double t = glow?.value ?? 1;
        return DecoratedBox(
          key: cardKey,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: <BoxShadow>[
              kit,
              if (t < 1)
                BoxShadow(
                  color: KitColors.primary.withValues(
                    alpha: 0.55 * (1 - Curves.easeOut.transform(t)),
                  ),
                  spreadRadius: 3,
                ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// The current card's head (`DL-131`): the picture, the status as the
/// headline, the order's number with its count and the address under it in
/// small type.
class _CurrentTop extends StatelessWidget {
  const _CurrentTop({required this.order, required this.fade});

  final OrderSummary order;

  /// 1 at rest; the status fades in while it runs up from 0.
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool wraps = textScaleAt(MediaQuery.textScalerOf(context), 12) > 1.3;
    const TextStyle small = TextStyle(fontSize: 12, color: KitColors.muted);
    final String number = l10n.customerOrderTitle(order.orderNumber);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox.square(
            dimension: 56,
            child: Center(child: ProductImage(url: order.imageUrl, size: 48)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FadeTransition(
                opacity: CurvedAnimation(parent: fade, curve: Curves.easeOut),
                child: Text(
                  OrderLabels.customerStatus(l10n, order.status),
                  key: ValueKey<String>('order-status-${order.id}'),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.itemCount > 0
                    ? '$number · ${l10n.orderItemCount(order.itemCount)}'
                    : number,
                maxLines: wraps ? null : 1,
                overflow: TextOverflow.ellipsis,
                style: small,
              ),
              Text(
                '${order.street}, ${order.house}',
                maxLines: wraps ? null : 1,
                overflow: TextOverflow.ellipsis,
                style: small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the server says the order costs, with «≈» for an estimate, or that
/// nothing is due.
String _amountText(
  AppLocalizations l10n,
  AppLanguage language,
  OrderSummary order,
) {
  final int? total = order.totalUzs;
  return total == null
      ? l10n.totalNothingDue
      : order.totalKind == TotalKind.estimate
      ? l10n.cartLineEstimate(MoneyFormat.uzs(total, language))
      : MoneyFormat.uzs(total, language);
}

/// When the order was placed and what the server says it costs.
class _Bottom extends ConsumerWidget {
  const _Bottom({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DateTime now = ref.watch(clockProvider)();
    final String amount = _amountText(l10n, language, order);

    final Text date = Text(
      orderWhen(l10n, order.createdAt, now),
      style: const TextStyle(fontSize: 12, color: KitColors.muted),
    );
    const TextStyle sumStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: KitColors.ink,
    );

    // Under large text the sum takes its own line and keeps its size.
    if (textScaleAt(MediaQuery.textScalerOf(context), 12) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          date,
          const SizedBox(height: 2),
          Text(amount, style: sumStyle),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(child: date),
        const SizedBox(width: 8),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(amount, maxLines: 1, style: sumStyle),
            ),
          ),
        ),
      ],
    );
  }
}

/// The question waiting for the Customer on a current card: how many lines
/// the Shopper asks about, the minutes left, and «Ответить». Under large
/// text the button takes the strip's whole width under the words.
class _QuestionStrip extends StatelessWidget {
  const _QuestionStrip({
    required this.order,
    required this.questions,
    required this.deadline,
    required this.onOpen,
  });

  final OrderSummary order;
  final int questions;
  final DateTime? deadline;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool stacked =
        textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final DateTime? until = deadline;
    final Widget words = ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.help, size: 20, color: KitColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.orderCardQuestion(questions),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                  ),
                ),
                if (until != null) ...<Widget>[
                  const SizedBox(height: 5),
                  DeadlineChip(deadline: until),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final Widget answer = Semantics(
      container: true,
      button: true,
      label: l10n.questionAnswerSpoken(order.orderNumber),
      onTap: onOpen,
      excludeSemantics: true,
      child: FilledButton(
        key: ValueKey<String>('order-answer-${order.id}'),
        style: FilledButton.styleFrom(
          backgroundColor: KitColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onOpen,
        child: Text(
          l10n.questionAnswer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return DecoratedBox(
      key: ValueKey<String>('order-waiting-${order.id}'),
      decoration: BoxDecoration(
        color: KitColors.warningWash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KitColors.warning, width: 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      words,
                      const SizedBox(height: 8),
                      answer,
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(child: words),
                      const SizedBox(width: 8),
                      answer,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The five stars of a finished order's card (`DL-131`): the Customer's way
/// to rate it. A tap lights the stars up to it with a pop, buzzes, and opens
/// the rating screen with them chosen; back from it they are unlit again.
class OrderRateStars extends StatefulWidget {
  const OrderRateStars({required this.order, super.key});

  final OrderSummary order;

  @override
  State<OrderRateStars> createState() => _OrderRateStarsState();
}

class _OrderRateStarsState extends State<OrderRateStars>
    with SingleTickerProviderStateMixin {
  static const int _popMs = 340;
  static const int _stepMs = 45;
  static const Cubic _ease = Cubic(0.2, 0.8, 0.2, 1);

  late final AnimationController _pop = AnimationController(vsync: this);
  int _chosen = 0;
  int _totalMs = _popMs;

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  /// The star's scale [t] of the way through its pop: 1 → 1.32 at 35 %,
  /// 0.94 at 70 %, 1 at the end.
  double _scale(double t) {
    if (t <= 0 || t >= 1) {
      return 1;
    }
    final (double from, double to, double a, double b) = t < 0.35
        ? (1, 1.32, 0, 0.35)
        : t < 0.7
        ? (1.32, 0.94, 0.35, 0.7)
        : (0.94, 1, 0.7, 1);
    return from + (to - from) * _ease.transform((t - a) / (b - a));
  }

  Future<void> _rate(int stars) async {
    if (_chosen != 0) {
      return;
    }
    setState(() => _chosen = stars);
    unawaited(HapticFeedback.lightImpact());
    if (!MediaQuery.disableAnimationsOf(context)) {
      _totalMs = _stepMs * (stars - 1) + _popMs;
      _pop.duration = Duration(milliseconds: _totalMs);
      await _pop.forward(from: 0);
      if (!mounted) {
        return;
      }
    }
    await context.push(
      AppPaths.customerOrderRate(widget.order.id, stars: stars),
    );
    if (mounted) {
      setState(() => _chosen = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Semantics(
      container: true,
      label: l10n.orderRateCaption,
      child: AnimatedBuilder(
        animation: _pop,
        builder: (BuildContext context, Widget? _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int star = 1; star <= 5; star++)
              Semantics(
                container: true,
                button: true,
                label: l10n.orderRateStarsSpoken(
                  widget.order.orderNumber,
                  star,
                ),
                onTap: () => _rate(star),
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _rate(star),
                  child: SizedBox.square(
                    key: ValueKey<String>(
                      'order-rate-${widget.order.id}-$star',
                    ),
                    dimension: 44,
                    child: Center(
                      child: Transform.scale(
                        scale: _scale(
                          (_pop.value * _totalMs - _stepMs * (star - 1)) /
                              _popMs,
                        ),
                        child: KitStar(filled: star <= _chosen, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The stars of a rated order's card: five small ones, no buttons, read as
/// one phrase.
class _RatedStars extends StatelessWidget {
  const _RatedStars({required this.order, required this.stars});

  final OrderSummary order;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>('order-stars-${order.id}'),
      container: true,
      label: AppLocalizations.of(context).orderRatedSpoken(stars),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 1; i <= 5; i++)
            SizedBox(
              width: 26,
              height: 30,
              child: Center(child: KitStar(filled: i <= stars, size: 22)),
            ),
        ],
      ),
    );
  }
}
