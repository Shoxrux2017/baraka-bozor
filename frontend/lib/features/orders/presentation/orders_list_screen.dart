import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/order_dates.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/widgets/deadline_chip.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/stale_data_line.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../application/orders_changes.dart';
import '../domain/customer_orders.dart';
import 'order_cards.dart';
import 'orders_segment.dart';

const Cubic _slide = Cubic(0.2, 0.8, 0.2, 1);

/// The orders each segment counts, in one place (`DL-131`): what its feed
/// holds, none while it has not answered. An order that is leaving
/// «Текущие» with its card still shown is counted there ([leaving]) and left
/// out of «Прошлые» ([held]) until its card has folded.
({int current, int past}) ordersCounts(
  AsyncValue<OrdersFeed> current,
  AsyncValue<OrdersFeed> past, {
  int leaving = 0,
  int held = 0,
}) => (
  current: (current.value?.total ?? 0) + leaving,
  past: (past.value?.total ?? 0) - held,
);

/// A card that stays in «Текущие» for a moment after its order left it, with
/// the summary it shows and the place it had.
class _Leaving {
  _Leaving(this.summary, this.index);

  OrderSummary summary;
  final int index;
}

/// The words of a question the Shopper asks, said with the minutes left when
/// a deadline still runs: «Заказ № 1044: сборщик спрашивает про 1 товар.
/// Осталось 9 минут».
String _questionAnnounced(
  AppLocalizations l10n,
  OrderSummary order,
  DateTime now,
) {
  final DateTime? until = order.questionDeadlines
      .where((DateTime when) => when.isAfter(now))
      .firstOrNull;
  final String said = l10n.orderAnnounced(
    order.orderNumber,
    l10n.orderCardQuestion(order.pendingApprovalCount).toLowerCase(),
  );
  if (until == null) {
    return said;
  }
  final String left = l10n.deadlineLeftSpoken(minutesLeft(until, now));
  return '$said. ${left[0].toUpperCase()}${left.substring(1)}';
}

/// The Customer's orders, newest first, in two tabs: the ones in hand and the
/// ones that ended (`docs/09` section 20, `DL-92` item 3, `DL-131`). Both
/// tabs stay mounted with their own scroll place, so switching loads nothing
/// again. «Текущие» is kept current while shown and keeps its cards under a
/// line that says when they are from when a refresh fails; «Прошлые» is an
/// endless list under month headings.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrdersTab _tab = OrdersTab.current;

  /// The scroll place of each tab; the shown one is the screen's primary
  /// controller, so a re-tap on «Заказы» scrolls it to the top (`DL-118`).
  final Map<OrdersTab, ScrollController> _scrolls =
      <OrdersTab, ScrollController>{
        OrdersTab.current: ScrollController(),
        OrdersTab.past: ScrollController(),
      };

  /// How many times the past count rose, one bump each, and the count it
  /// rose from.
  int _pastBumps = 0;
  int? _pastTotal;

  /// The last value of «Текущие» compared, the value of another account that
  /// is still carried while the new one loads (never compared), and the
  /// account they belong to (`DL-131`).
  OrdersFeed? _seen;
  OrdersFeed? _carried;
  String? _account;

  /// The list was covered, or its tab hidden, since the last value compared.
  bool _coveredSinceSeen = false;

  /// Raised for an order when its card is to glow, and when its status is to
  /// fade in.
  final Map<String, int> _glows = <String, int>{};
  final Map<String, int> _headlines = <String, int>{};

  /// The cards of orders that left «Текущие» and are still shown, and the ones
  /// «Прошлые» holds back from its count until their cards have folded.
  final Map<String, _Leaving> _leaving = <String, _Leaving>{};
  final Set<String> _held = <String>{};
  final Set<Timer> _timers = <Timer>{};

  /// What the build found to say or load, run after its frame.
  final List<VoidCallback> _effects = <VoidCallback>[];

  ScrollController get _pastScroll => _scrolls[OrdersTab.past]!;

  @override
  void initState() {
    super.initState();
    _pastScroll.addListener(_loadMoreNearTheEnd);
    _account = ref.read(customerAccountProvider);
  }

  /// Compares the value of «Текущие» this build sees with the one before, drop
  /// states included: what changed between them is drawn softly and, while the
  /// list is shown, said by the effects the build leaves for after the frame.
  /// A reload that kept its rows, the first value and a value of another
  /// account give no changes. It runs in the build, which a covered screen
  /// does not, so an order page over the list keeps it from loading
  /// (`DL-131`).
  void _observe(AsyncValue<OrdersFeed> current, String? account) {
    final OrdersFeed? feed = current.value;
    if (feed == null) {
      return;
    }
    if (account != _account) {
      _account = account;
      _carried = feed;
      _seen = null;
      _forgetLeaving();
    }
    final OrdersFeed? before = _seen;
    if (identical(feed, _carried) || identical(feed, before)) {
      return;
    }
    _seen = feed;
    final bool covered = _coveredSinceSeen;
    _coveredSinceSeen = false;
    if (before != null) {
      _showChanges(before, feed, covered: covered);
    }
  }

  void _forgetLeaving() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _leaving.clear();
    _held.clear();
  }

  void _later(Duration after, VoidCallback run) {
    late final Timer timer;
    timer = Timer(after, () {
      _timers.remove(timer);
      if (mounted) {
        run();
      }
    });
    _timers.add(timer);
  }

  /// Says [words] to a screen reader, with a light buzz when [buzz], once the
  /// frame that drew the change is done.
  void _say(String words, {bool buzz = false}) {
    _effects.add(() {
      if (buzz) {
        unawaited(HapticFeedback.lightImpact());
      }
      announce(context, words);
    });
  }

  void _glow(String orderId, {bool headline = false}) {
    _glows[orderId] = (_glows[orderId] ?? 0) + 1;
    if (headline) {
      _headlines[orderId] = (_headlines[orderId] ?? 0) + 1;
    }
  }

  void _showChanges(
    OrdersFeed before,
    OrdersFeed after, {
    required bool covered,
  }) {
    final CurrentChanges changes = currentChanges(
      before.rows,
      after.rows,
      dropped: after.dropped,
    );
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime now = ref.read(clockProvider)();
    // A change found after the list was covered, by an order page or another
    // tab, is drawn quietly: the Customer was elsewhere when it came.
    final bool shown = ordersListShown(context) && !covered;

    for (final OrderSummary order in changes.appeared) {
      _leaving.remove(order.id);
    }
    for (final OrderSummary order in changes.questionsArrived) {
      if (shown) {
        _say(_questionAnnounced(l10n, order, now), buzz: true);
      }
    }
    for (final OrderSummary order in changes.questionsGrew) {
      if (shown) {
        _glow(order.id);
        _say(_questionAnnounced(l10n, order, now), buzz: true);
      }
    }
    for (final (:OrderSummary order, from: OrderStatus _) in changes.moved) {
      if (shown) {
        _glow(order.id, headline: true);
        _say(
          order.status == OrderStatus.onTheWay
              ? l10n.orderOnTheWayAnnounced(order.orderNumber)
              : l10n.orderAnnounced(
                  order.orderNumber,
                  OrderLabels.customerStatus(l10n, order.status).toLowerCase(),
                ),
        );
      }
    }
    for (final OrderSummary order in changes.left) {
      final int index = before.rows.indexWhere(
        (OrderSummary row) => row.id == order.id,
      );
      _leaving[order.id] = _Leaving(order, index);
      _effects.add(() => unawaited(_settle(order.id)));
    }
  }

  /// An order is gone from «Текущие» without the Customer's hand: «Прошлые»
  /// loads again and says what became of it. Found ended, its card shows the
  /// end, glows, says so and folds 1.7 s later; not found, or when the load
  /// fails, the card leaves at once without words.
  Future<void> _settle(String id) async {
    OrderSummary? ended;
    try {
      final AsyncNotifierProvider<CustomerOrdersFeed, OrdersFeed> past =
          customerOrdersProvider(OrdersTab.past);
      if (!ref.read(past).isLoading) {
        ref.invalidate(past);
      }
      final OrdersFeed feed = await ref.read(past.future);
      ended = feed.rows
          .where(
            (OrderSummary row) =>
                row.id == id &&
                (row.status == OrderStatus.completed ||
                    row.status == OrderStatus.cancelled),
          )
          .firstOrNull;
    } on Object {
      ended = null;
    }
    final _Leaving? leaving = _leaving[id];
    if (!mounted || leaving == null) {
      return;
    }
    if (ended == null) {
      setState(() => _leaving.remove(id));
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool shown = ordersListShown(context);
    setState(() {
      leaving.summary = ended!;
      _held.add(id);
      if (shown) {
        _glow(id, headline: true);
      }
    });
    if (shown) {
      announce(
        context,
        ended.status == OrderStatus.completed
            ? l10n.orderDeliveredAnnounced(ended.orderNumber)
            : l10n.orderCancelledAnnounced(ended.orderNumber),
      );
    }
    _later(const Duration(milliseconds: 1700), () {
      setState(() => _leaving.remove(id));
      // The count follows once the card has folded (260 ms, at once when
      // the motion is reduced).
      _later(
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        () => setState(() => _held.remove(id)),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ordersListShown(context)) {
      _coveredSinceSeen = true;
    }
  }

  @override
  void dispose() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _pastScroll.removeListener(_loadMoreNearTheEnd);
    for (final ScrollController scroll in _scrolls.values) {
      scroll.dispose();
    }
    super.dispose();
  }

  /// Loads the next past page once less than 720 px of list lies below.
  void _loadMoreNearTheEnd() {
    if (!mounted || _tab != OrdersTab.past || !_pastScroll.hasClients) {
      return;
    }
    final OrdersFeed? feed = ref
        .read(customerOrdersProvider(OrdersTab.past))
        .value;
    if (feed == null ||
        !feed.hasMore ||
        feed.loadingMore ||
        feed.moreFailure != null) {
      return;
    }
    if (_pastScroll.position.extentAfter < 720) {
      ref.read(customerOrdersProvider(OrdersTab.past).notifier).loadMore();
    }
  }

  void _select(OrdersTab tab) {
    if (tab != _tab) {
      setState(() => _tab = tab);
      return;
    }
    final ScrollController scroll = _scrolls[tab]!;
    if (!scroll.hasClients) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(0);
    } else {
      scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// A pull or the stale line's button: loads the tab again from its first
  /// page and says how it went, with the time of what stays when it failed.
  Future<void> _refresh(OrdersTab tab) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    String message;
    try {
      ref.invalidate(customerOrdersProvider(tab));
      await ref.read(customerOrdersProvider(tab).future);
      message = l10n.refreshDone;
    } on Object catch (error) {
      // The Customer may have left while the load was on its way.
      if (!mounted) {
        return;
      }
      final String reason = error is NetworkFailure
          ? l10n.staleOffline
          : l10n.staleFailed;
      final DateTime? at = ref.read(customerOrdersProvider(tab)).value?.at;
      message = at == null
          ? reason
          : l10n.staleSpoken(reason, TashkentTime.time(at));
    }
    if (mounted) {
      announce(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<OrdersFeed> current = ref.watch(
      customerOrdersProvider(OrdersTab.current),
    );
    final AsyncValue<OrdersFeed> past = ref.watch(
      customerOrdersProvider(OrdersTab.past),
    );
    _observe(current, ref.watch(customerAccountProvider));
    if (_effects.isNotEmpty) {
      final List<VoidCallback> run = List<VoidCallback>.of(_effects);
      _effects.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          for (final VoidCallback effect in run) {
            effect();
          }
        }
      });
    }
    final int held = _held.isEmpty
        ? 0
        : (past.value?.rows ?? const <OrderSummary>[])
              .where((OrderSummary row) => _held.contains(row.id))
              .length;
    final ({int current, int past}) counts = ordersCounts(
      current,
      past,
      leaving: _leaving.length,
      held: held,
    );
    // Read here, not by a listener: the build is paused while the screen is
    // covered, and a listener would keep «Прошлые» loading under an order.
    final int? pastTotal = past.value == null ? null : counts.past;
    if (pastTotal != null) {
      final int? was = _pastTotal;
      if (was != null && pastTotal > was) {
        _pastBumps++;
      }
      _pastTotal = pastTotal;
    }
    if (_tab == OrdersTab.past) {
      // A build that leaves the list shorter than the screen asks for more.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMoreNearTheEnd(),
      );
    }

    return PrimaryScrollController(
      controller: _scrolls[_tab]!,
      child: CustomerTabScope(
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: kitAppBar(
            title: l10n.homeNavOrders,
            automaticallyImplyLeading: false,
            actions: const <Widget>[CartButton()],
          ),
          bottomNavigationBar: const CustomerTabBar(
            current: CustomerTab.orders,
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                const ActiveModeBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: OrdersSegment(
                    tab: _tab,
                    currentCount: counts.current,
                    pastCount: counts.past,
                    pastBumps: _pastBumps,
                    onTab: _select,
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _Pane(
                        tab: OrdersTab.current,
                        shown: _tab == OrdersTab.current,
                        child: _currentPane(current, past),
                      ),
                      _Pane(
                        tab: OrdersTab.past,
                        shown: _tab == OrdersTab.past,
                        child: _pastPane(past),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _failure(OrdersTab tab, Object error) => Padding(
    padding: const EdgeInsets.all(16),
    child: LoadFailure(
      error: error,
      onRetry: () => ref.invalidate(customerOrdersProvider(tab)),
    ),
  );

  Widget _skeleton(OrdersTab tab) => ListView(
    controller: _scrolls[tab],
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    children: <Widget>[_Skeleton(tab: tab)],
  );

  /// «Текущие»: kept current every 30 s while shown, whether the last load
  /// failed or not.
  Widget _currentPane(
    AsyncValue<OrdersFeed> current,
    AsyncValue<OrdersFeed> past,
  ) {
    final OrdersFeed? feed = current.value;
    final List<OrderSummary> rows = feed == null
        ? const <OrderSummary>[]
        : _withLeaving(feed.rows);
    final Object? error = current.hasError ? current.error : null;
    final ApiFailure? failure = error == null
        ? null
        : (error is ApiFailure ? error : const UnexpectedFailure());

    return PeriodicRefresh(
      interval: const Duration(seconds: 30),
      active: feed != null && !current.isLoading,
      onRefresh: () =>
          ref.invalidate(customerOrdersProvider(OrdersTab.current)),
      child: feed == null
          ? (error == null
                ? _skeleton(OrdersTab.current)
                : _failure(OrdersTab.current, error))
          : _FadeIn(
              duration: const Duration(milliseconds: 220),
              child: Column(
                children: <Widget>[
                  _StaleSlot(
                    failure: failure,
                    shownAt: feed.at,
                    busy: current.isLoading,
                    onRetry: () => _refresh(OrdersTab.current),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: KitColors.primary,
                      onRefresh: () => _refresh(OrdersTab.current),
                      child: rows.isEmpty && _held.isEmpty
                          ? _emptyCurrent(past)
                          : CustomScrollView(
                              key: const ValueKey<String>('orders-list'),
                              controller: _scrolls[OrdersTab.current],
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: <Widget>[
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    24,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: FoldingColumn<OrderSummary>(
                                      items: rows,
                                      keyOf: (OrderSummary order) => order.id,
                                      itemBuilder:
                                          (
                                            BuildContext context,
                                            OrderSummary order,
                                          ) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: CurrentOrderCard(
                                              order: order,
                                              glow: _glows[order.id] ?? 0,
                                              headline:
                                                  _headlines[order.id] ?? 0,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// The loaded rows with the cards of leaving orders put back where they
  /// stood, as they last looked.
  List<OrderSummary> _withLeaving(List<OrderSummary> rows) {
    if (_leaving.isEmpty) {
      return rows;
    }
    final List<OrderSummary> shown = <OrderSummary>[...rows];
    for (final _Leaving leaving in _leaving.values) {
      if (shown.every((OrderSummary row) => row.id != leaving.summary.id)) {
        shown.insert(math.min(leaving.index, shown.length), leaving.summary);
      }
    }
    return shown;
  }

  /// No orders in hand: the last order when there is one, the invitation to
  /// shop when there never was, skeletons while «Прошлые» has not answered.
  Widget _emptyCurrent(AsyncValue<OrdersFeed> past) {
    final OrdersFeed? history = past.value;
    final Widget content;
    if (history != null && history.rows.isNotEmpty) {
      content = _EmptyWithLast(
        last: history.rows.first,
        pastCount: history.total,
        onAllPast: () => _select(OrdersTab.past),
      );
    } else if (history == null && !past.hasError) {
      content = _Skeleton(
        tab: OrdersTab.current,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      );
    } else {
      content = const _Empty(tab: OrdersTab.current);
    }
    return _ScrollingEmpty(
      controller: _scrolls[OrdersTab.current]!,
      child: content,
    );
  }

  /// «Прошлые»: an endless list under month headings; a pull loads it again
  /// from the first page, the offset kept.
  Widget _pastPane(AsyncValue<OrdersFeed> past) {
    final OrdersFeed? feed = past.value;
    if (feed == null) {
      return past.hasError
          ? _failure(OrdersTab.past, past.error!)
          : _skeleton(OrdersTab.past);
    }
    return _FadeIn(
      duration: const Duration(milliseconds: 220),
      child: RefreshIndicator(
        color: KitColors.primary,
        onRefresh: () => _refresh(OrdersTab.past),
        child: feed.rows.isEmpty
            ? _ScrollingEmpty(
                controller: _scrolls[OrdersTab.past]!,
                child: const _Empty(tab: OrdersTab.past),
              )
            : _PastList(
                feed: feed,
                controller: _scrolls[OrdersTab.past]!,
                onRetryMore: () => ref
                    .read(customerOrdersProvider(OrdersTab.past).notifier)
                    .loadMore(),
              ),
      ),
    );
  }
}

/// One tab's place in the stack: only the shown one is on screen, the other
/// is kept with its state and its tickers off. The shown one comes in from
/// its side (`DL-131`).
class _Pane extends StatelessWidget {
  const _Pane({required this.tab, required this.shown, required this.child});

  final OrdersTab tab;
  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !shown,
    child: TickerMode(
      enabled: shown,
      child: _PaneIn(tab: tab, shown: shown, child: child),
    ),
  );
}

/// Slides its tab in from 28 px on its side while it fades in over 300 ms;
/// with reduced motion it only fades, over 200 ms.
class _PaneIn extends StatefulWidget {
  const _PaneIn({required this.tab, required this.shown, required this.child});

  final OrdersTab tab;
  final bool shown;
  final Widget child;

  @override
  State<_PaneIn> createState() => _PaneInState();
}

class _PaneInState extends State<_PaneIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void didUpdateWidget(_PaneIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown && !oldWidget.shown) {
      _controller.duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 200 : 300,
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    final double side = widget.tab == OrdersTab.past ? 28 : -28;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = (still ? Curves.easeOut : _slide).transform(
          _controller.value,
        );
        return Opacity(
          key: ValueKey<String>('orders-pane-fade-${widget.tab.code}'),
          opacity: t,
          child: Transform.translate(
            key: ValueKey<String>('orders-pane-slide-${widget.tab.code}'),
            offset: Offset(still ? 0 : side * (1 - t), 0),
            child: child,
          ),
        );
      },
    );
  }
}

/// Fades its child in once when it is first built, over [duration]; with
/// reduced motion, or without a [duration], it is there at once. [onDone] says
/// when it has faded in.
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, this.duration, this.onDone, super.key});

  final Duration? duration;
  final VoidCallback? onDone;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.duration == null ? 1 : 0,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || widget.duration == null) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      widget.onDone?.call();
    } else {
      _controller.forward().whenComplete(() => widget.onDone?.call());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    child: widget.child,
  );
}

/// The line over «Текущие» that says a refresh failed, in a [Fold] that opens
/// when it does and closes once the cards are current again.
class _StaleSlot extends StatefulWidget {
  const _StaleSlot({
    required this.failure,
    required this.shownAt,
    required this.busy,
    required this.onRetry,
  });

  final ApiFailure? failure;
  final DateTime shownAt;
  final bool busy;
  final VoidCallback onRetry;

  @override
  State<_StaleSlot> createState() => _StaleSlotState();
}

class _StaleSlotState extends State<_StaleSlot> {
  /// The last failure, kept to fold the line away with its words.
  ApiFailure? _last;

  @override
  Widget build(BuildContext context) {
    final ApiFailure? failure = widget.failure;
    if (failure != null) {
      _last = failure;
    }
    final ApiFailure? line = _last;

    return Fold(
      shown: failure != null,
      onFolded: () {
        if (widget.failure == null && _last != null) {
          setState(() => _last = null);
        }
      },
      child: line == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: StaleDataLine(
                key: const ValueKey<String>('stale-line'),
                failure: line,
                shownAt: widget.shownAt,
                onRetry: widget.onRetry,
                busy: widget.busy,
              ),
            ),
    );
  }
}

/// A row of the past list: a month heading, an order, or the end of what is
/// loaded.
sealed class _PastItem {
  const _PastItem();
}

final class _Heading extends _PastItem {
  const _Heading(this.text, {required this.first});

  final String text;
  final bool first;
}

final class _Order extends _PastItem {
  const _Order(this.order);

  final OrderSummary order;
}

final class _MoreSkeleton extends _PastItem {
  const _MoreSkeleton();
}

final class _MoreFailed extends _PastItem {
  const _MoreFailed();
}

/// The past orders under month headings, laid out lazily. A page that comes
/// in at the end fades in over 250 ms; below the last order stand two
/// skeletons while more is to come, or «Нет связи · Повторить».
class _PastList extends ConsumerStatefulWidget {
  const _PastList({
    required this.feed,
    required this.controller,
    required this.onRetryMore,
  });

  final OrdersFeed feed;
  final ScrollController controller;
  final VoidCallback onRetryMore;

  @override
  ConsumerState<_PastList> createState() => _PastListState();
}

class _PastListState extends ConsumerState<_PastList> {
  /// The orders shown before this build; null until the first.
  Set<String>? _known;

  /// The orders that came in after the first and are still fading in.
  final Set<String> _fresh = <String>{};

  List<_PastItem> _items(AppLocalizations l10n, DateTime now) {
    final OrdersFeed feed = widget.feed;
    final List<_PastItem> items = <_PastItem>[];
    String? month;
    for (final OrderSummary order in feed.rows) {
      final String heading = monthHeading(l10n, order.createdAt, now);
      if (heading != month) {
        month = heading;
        items.add(_Heading(heading, first: items.isEmpty));
      }
      items.add(_Order(order));
    }
    if (feed.moreFailure != null) {
      items.add(const _MoreFailed());
    } else if (feed.hasMore) {
      items
        ..add(const _MoreSkeleton())
        ..add(const _MoreSkeleton());
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime now = ref.watch(clockProvider)();
    final List<_PastItem> items = _items(l10n, now);
    final Set<String> ids = <String>{
      for (final OrderSummary order in widget.feed.rows) order.id,
    };
    final Set<String>? known = _known;
    if (known != null) {
      _fresh.addAll(ids.difference(known));
    }
    _known = ids;

    return CustomScrollView(
      key: const ValueKey<String>('orders-past-list'),
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) =>
                switch (items[index]) {
                  _Heading(:final String text, :final bool first) => Padding(
                    padding: EdgeInsets.fromLTRB(2, first ? 2 : 14, 2, 10),
                    child: Semantics(
                      header: true,
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                    ),
                  ),
                  _Order(:final OrderSummary order) => _FadeIn(
                    key: ValueKey<String>('orders-past-${order.id}'),
                    duration: _fresh.contains(order.id)
                        ? const Duration(milliseconds: 250)
                        : null,
                    onDone: () => _fresh.remove(order.id),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PastOrderCard(order: order),
                    ),
                  ),
                  _MoreSkeleton() => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SkeletonCard(
                      key: const ValueKey<String>('orders-more-skeleton'),
                    ),
                  ),
                  _MoreFailed() => ConstrainedBox(
                    key: const ValueKey<String>('orders-more-row'),
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          l10n.staleOffline,
                          style: const TextStyle(
                            fontSize: 13,
                            color: KitColors.ink2,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(fontSize: 13, color: KitColors.ink2),
                        ),
                        TextButton(
                          key: const ValueKey<String>('orders-more-retry'),
                          onPressed: widget.onRetryMore,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: KitColors.primaryDark,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(l10n.retryButton),
                        ),
                      ],
                    ),
                  ),
                },
          ),
        ),
      ],
    );
  }
}

/// Three skeleton cards standing where the first orders will be, said as one
/// «Загружаем заказы».
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.tab, this.padding = EdgeInsets.zero});

  final OrdersTab tab;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      container: true,
      excludeSemantics: true,
      label: AppLocalizations.of(context).ordersLoading,
      child: Column(
        key: ValueKey<String>('orders-skeleton-${tab.code}'),
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _SkeletonCard(
                key: ValueKey<String>('orders-skeleton-card'),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A card's silhouette: the picture, three lines, then the date and the sum.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({super.key});

  Widget _bar(double factor, double height) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FractionallySizedBox(
      widthFactor: factor,
      child: SkeletonBar(width: double.infinity, height: height, radius: 8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBar(width: 56, height: 56, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: <Widget>[
                        _bar(0.7, 14),
                        const SizedBox(height: 8),
                        _bar(0.45, 12),
                        const SizedBox(height: 8),
                        _bar(0.55, 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const <Widget>[
                SkeletonBar(width: 90, height: 12, radius: 8),
                SkeletonBar(width: 80, height: 15, radius: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An empty state that scrolls, so a pull still refreshes it: [child] fills
/// at least the tab.
class _ScrollingEmpty extends StatelessWidget {
  const _ScrollingEmpty({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) =>
        SingleChildScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: child,
          ),
        ),
  );
}

/// A tab with no orders at all: the way to the first one, or what will be
/// here.
class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final OrdersTab tab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool current = tab == OrdersTab.current;

    return Center(
      key: const ValueKey<String>('orders-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.primaryWash,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 96,
                child: Icon(
                  Icons.receipt_long,
                  size: 44,
                  color: KitColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                current ? l10n.myOrdersEmpty : l10n.ordersPastEmpty,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            ),
            if (current) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l10n.ordersEmptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: KitColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              const _ShopButton(),
            ],
          ],
        ),
      ),
    );
  }
}

/// «За покупками»: to the catalog.
class _ShopButton extends StatelessWidget {
  const _ShopButton();

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const ValueKey<String>('orders-empty-shop'),
    style: FilledButton.styleFrom(
      backgroundColor: KitColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 54),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: () => context.go(AppPaths.customer),
    child: Text(
      AppLocalizations.of(context).ordersEmptyAction,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
}

/// «Сейчас заказов в работе нет» with the last order to repeat, the way to
/// shop and the link to «Прошлые» (`DL-131`).
class _EmptyWithLast extends ConsumerWidget {
  const _EmptyWithLast({
    required this.last,
    required this.pastCount,
    required this.onAllPast,
  });

  final OrderSummary last;
  final int pastCount;
  final VoidCallback onAllPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime now = ref.watch(clockProvider)();
    final String day = orderDay(l10n, last.createdAt, now);
    final String lowerDay = day.isEmpty
        ? day
        : day[0].toLowerCase() + day.substring(1);

    return Padding(
      key: const ValueKey<String>('orders-last-empty'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              color: KitColors.primaryWash,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 72,
              child: Icon(
                Icons.receipt_long,
                size: 34,
                color: KitColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              l10n.ordersCurrentEmptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.ordersLastOrderText(lowerDay),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: KitColors.muted,
            ),
          ),
          const SizedBox(height: 18),
          LastOrderCard(order: last),
          const SizedBox(height: 16),
          const SizedBox(width: double.infinity, child: _ShopButton()),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            excludeSemantics: true,
            label: l10n.ordersAllPastSpoken(pastCount),
            onTap: onAllPast,
            child: TextButton(
              key: const ValueKey<String>('orders-all-past'),
              onPressed: onAllPast,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: KitColors.primaryDark,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l10n.ordersAllPast(pastCount)),
            ),
          ),
        ],
      ),
    );
  }
}
