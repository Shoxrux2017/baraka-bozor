import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/formatting/tashkent_time.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/platform/clock.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/customer_tab_bar.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/periodic_refresh.dart';
import '../../../core/widgets/stale_data_line.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';
import 'cancel_sheet.dart';
import 'order_cards.dart';
import 'order_questions.dart';
import 'order_rating_card.dart';
import 'order_sections.dart';
import 'question_pill.dart';

/// The Customer's orders, newest first, in two tabs: the ones in hand and the
/// ones that ended (`docs/09` section 20, `DL-92` item 3). An order with a
/// question waiting for their answer says so, and the tab in hand is kept
/// current while shown.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrdersTab _tab = OrdersTab.current;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<OrdersFeed> page = ref.watch(customerOrdersProvider(_tab));
    final bool refreshing =
        _tab == OrdersTab.current &&
        page.hasValue &&
        !page.hasError &&
        !page.isLoading;

    return CustomerTabScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(
          title: l10n.homeNavOrders,
          automaticallyImplyLeading: false,
          actions: const <Widget>[CartButton()],
        ),
        bottomNavigationBar: const CustomerTabBar(current: CustomerTab.orders),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _TabSwitch(
                  tab: _tab,
                  onTab: (OrdersTab tab) => setState(() => _tab = tab),
                ),
              ),
              Expanded(
                child: PeriodicRefresh(
                  interval: const Duration(seconds: 30),
                  active: refreshing,
                  onRefresh: () =>
                      ref.invalidate(customerOrdersProvider(OrdersTab.current)),
                  child: page.when(
                    skipLoadingOnReload: false,
                    skipLoadingOnRefresh: !page.hasError,
                    data: (OrdersFeed feed) => feed.rows.isEmpty
                        ? _Empty(tab: _tab)
                        : ListView(
                            key: const ValueKey<String>('orders-list'),
                            primary: true,
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            children: <Widget>[
                              for (final OrderSummary order in feed.rows)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _tab == OrdersTab.current
                                      ? CurrentOrderCard(order: order)
                                      : PastOrderCard(order: order),
                                ),
                            ],
                          ),
                    error: (Object error, StackTrace _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: LoadFailure(
                        error: error,
                        onRetry: () =>
                            ref.invalidate(customerOrdersProvider(_tab)),
                      ),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two tabs as one segmented control; the chosen one is green.
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.tab, required this.onTab});

  final OrdersTab tab;
  final ValueChanged<OrdersTab> onTab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    Widget segment(OrdersTab value, String key, String label) {
      final bool chosen = tab == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: chosen,
          excludeSemantics: true,
          label: label,
          child: Material(
            key: ValueKey<String>(key),
            color: chosen ? KitColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onTab(value),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: chosen ? Colors.white : KitColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: <Widget>[
              segment(
                OrdersTab.current,
                'orders-tab-current',
                l10n.ordersTabCurrent,
              ),
              const SizedBox(width: 4),
              segment(OrdersTab.past, 'orders-tab-past', l10n.ordersTabPast),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab with no orders: the way to the first one, or what will be here.
class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final OrdersTab tab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool current = tab == OrdersTab.current;

    return Center(
      key: const ValueKey<String>('orders-empty'),
      child: SingleChildScrollView(
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
            Text(
              current ? l10n.myOrdersEmpty : l10n.ordersPastEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
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
              FilledButton(
                key: const ValueKey<String>('orders-empty-shop'),
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.go(AppPaths.customer),
                child: Text(
                  l10n.ordersEmptyAction,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One of the Customer's orders (`docs/09` section 20, drawings 29 to 29Ð·):
/// where it stands, the questions waiting for their answer, the lines with
/// what was bought or replaced, the amounts and their kind, the payment, the
/// address and the wish, the Courier once it is on the way; and, while the
/// server allows it, the way to edit the order, to cancel it, or to ask an
/// Operator to cancel it. An open order is kept current while shown
/// (`DL-54` (15)). Pulling refreshes; a refresh that fails keeps the order
/// under a line that says when it is from (`DL-130`).
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  String get orderId => widget.orderId;

  /// When the order on screen was loaded, by the phone's clock.
  DateTime? _shownAt;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<CustomerOrder>>(
      customerOrderProvider(orderId),
      (AsyncValue<CustomerOrder>? _, AsyncValue<CustomerOrder> next) {
        if (next.hasValue && !next.hasError && !next.isLoading) {
          _shownAt = ref.read(clockProvider)();
        }
      },
      fireImmediately: true,
    );
  }

  static const Set<OrderStatus> _ended = <OrderStatus>{
    OrderStatus.completed,
    OrderStatus.cancelled,
  };

  /// A shown order still open, with no load running and none failed.
  static bool _refreshing(AsyncValue<CustomerOrder> order) =>
      order.hasValue &&
      !order.hasError &&
      !order.isLoading &&
      !_ended.contains(order.value!.status);

  Future<void> _refresh() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    String message;
    try {
      ref
        ..invalidate(customerOrderProvider(orderId))
        ..invalidate(customerOrdersProvider);
      await ref.read(customerOrderProvider(orderId).future);
      message = l10n.refreshDone;
    } on Object catch (error) {
      // The Customer may have left while the load was on its way.
      if (!mounted) {
        return;
      }
      final String reason = error is NetworkFailure
          ? l10n.staleOffline
          : l10n.staleFailed;
      final DateTime? at = _shownAt;
      message =
          ref.read(customerOrderProvider(orderId)).value == null || at == null
          ? reason
          : l10n.staleSpoken(reason, TashkentTime.time(at));
    }
    if (mounted) {
      announce(context, message);
    }
  }

  Future<void> _cancel(
    BuildContext context, {
    required int orderNumber,
    required bool request,
  }) async {
    final OrderCancelController cancelling = ref.read(
      orderCancelProvider(orderId).notifier,
    );
    final String? reason = await showCancelSheet(
      context,
      orderNumber: orderNumber,
      request: request,
      unconfirmed: cancelling.unconfirmed,
      reason: cancelling.unconfirmedReason,
    );
    if (reason == null || !context.mounted) {
      return;
    }
    final String trimmed = trimLikeServer(reason);
    await cancelling.cancel(trimmed.isEmpty ? null : trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerOrder> order = ref.watch(
      customerOrderProvider(orderId),
    );
    final CustomerOrder? shown = order.value;
    final Object? error = order.hasError ? order.error : null;
    final ApiFailure? failure = error == null
        ? null
        : (error is ApiFailure ? error : const UnexpectedFailure());
    final MutationState cancelling = ref.watch(orderCancelProvider(orderId));
    // The decisions sent without a sure answer last while the order is shown.
    ref.watch(unansweredDecisionsProvider(orderId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: order.value == null
            ? ''
            : l10n.customerOrderTitle(order.value!.orderNumber),
      ),
      bottomNavigationBar: shown != null && OrderFooter.shows(shown, cancelling)
          ? OrderFooter(
              order: shown,
              cancelling: cancelling,
              onEdit: () => context.push(AppPaths.customerOrderEdit(shown.id)),
              onCancel: () => _cancel(
                context,
                orderNumber: shown.orderNumber,
                request: false,
              ),
              onRequestCancel: () => _cancel(
                context,
                orderNumber: shown.orderNumber,
                request: true,
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              child: PeriodicRefresh(
                interval: const Duration(seconds: 15),
                active: _refreshing(order),
                // The list loads again too, so it is current on the way back.
                onRefresh: () => ref
                  ..invalidate(customerOrderProvider(orderId))
                  ..invalidate(customerOrdersProvider),
                child: shown == null
                    ? (error == null
                          ? const Center(child: CircularProgressIndicator())
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: LoadFailure(
                                error: error,
                                onRetry: () => ref.invalidate(
                                  customerOrderProvider(orderId),
                                ),
                              ),
                            ))
                    : Column(
                        children: <Widget>[
                          if (failure != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                              child: StaleDataLine(
                                key: const ValueKey<String>('stale-line'),
                                failure: failure,
                                shownAt: _shownAt,
                                onRetry: _refresh,
                                busy: order.isLoading,
                              ),
                            ),
                          Expanded(
                            child: RefreshIndicator(
                              color: KitColors.primary,
                              onRefresh: _refresh,
                              child: _Order(order: shown),
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
}

/// The order in the kit's order: the status, the request, the Courier, the
/// questions, the lines, the amounts and the facts. While the Courier is on
/// the way the facts come right after them, for the payment due and the
/// address to hand.
class _Order extends ConsumerStatefulWidget {
  const _Order({required this.order});

  final CustomerOrder order;

  @override
  ConsumerState<_Order> createState() => _OrderState();
}

/// Where a question that arrived while the order was open stands: measured
/// while folded, then unfolded where it is seen, or shown still above the
/// reading (`DL-130`).
enum _ArrivalPhase { measuring, unfolding, still }

class _Arrival {
  _Arrival(this.questionId);

  final String questionId;
  final GlobalKey cardKey = GlobalKey();
  _ArrivalPhase phase = _ArrivalPhase.measuring;
}

/// A line row the reading is held to, and where its top stood in the list.
typedef _Anchor = ({String id, bool dropped, double top});

class _OrderState extends ConsumerState<_Order> {
  /// The line rows' keys, by line id, to place the reading.
  final Map<String, GlobalKey> _keptKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _droppedKeys = <String, GlobalKey>{};

  /// The route's primary controller, so iOS's tap on the status bar still
  /// scrolls the order to the top. Not created here, not disposed here.
  ScrollController? _primary;

  ScrollController get _scroll => _primary!;

  /// The questions that arrived while the order was open, by question id.
  final Map<String, _Arrival> _arrivals = <String, _Arrival>{};

  /// The arrived questions above the reading, whose pill shows.
  final Set<String> _pillFor = <String>{};

  /// How many times each line, by id, was washed by an answer to its
  /// question (`DL-130`).
  final Map<String, int> _flash = <String, int>{};

  /// The question the Customer just said yes to, by line, until the order
  /// loads again and says what was agreed.
  final Map<String, CustomerQuestion> _yes = <String, CustomerQuestion>{};

  /// Lines whose answer was a no: they are washed again once they stand in
  /// the removed group, which is built after the answer.
  final Set<String> _refused = <String>{};

  /// The question a settled no answered, by line, until the order loads again
  /// and the line no longer carries it.
  final Map<String, String> _no = <String, String>{};

  void _settled(
    String lineId,
    ApprovalDecision decision,
    CustomerQuestion? question,
  ) {
    setState(() {
      _flash[lineId] = (_flash[lineId] ?? 0) + 1;
      if (decision == ApprovalDecision.reject) {
        _yes.remove(lineId);
        _refused.add(lineId);
        if (question != null) {
          _no[lineId] = question.id;
        }
      } else if (question != null) {
        _yes[lineId] = question;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollController primary = PrimaryScrollController.of(context);
    if (!identical(primary, _primary)) {
      _primary?.removeListener(_watchPill);
      _primary = primary..addListener(_watchPill);
    }
  }

  @override
  void dispose() {
    _primary?.removeListener(_watchPill);
    super.dispose();
  }

  /// The pill goes once the card's top is in view.
  void _watchPill({bool again = false}) {
    if (_pillFor.isEmpty) {
      return;
    }
    final Set<String> hidden = <String>{
      for (final String id in _pillFor)
        if (_topAbove(_arrivals[id]) ?? false) id,
    };
    if (hidden.length != _pillFor.length) {
      setState(() => _pillFor.retainAll(hidden));
    }
    // A card not built yet may come into being with this scroll: look again
    // once the frame has laid it out.
    if (!again &&
        !_pillRechecked &&
        hidden.any(
          (String id) => _arrivals[id]?.cardKey.currentContext == null,
        )) {
      _pillRechecked = true;
      WidgetsBinding.instance
        ..addPostFrameCallback((_) {
          _pillRechecked = false;
          if (mounted) {
            _watchPill(again: true);
          }
        })
        ..ensureVisualUpdate();
    }
  }

  bool _pillRechecked = false;

  /// Whether the card's top is above the view's top. A card that is not
  /// built stands above the lines' view by construction, so it counts as
  /// above; `null` when it is built but cannot be placed.
  bool? _topAbove(_Arrival? arrival) {
    final BuildContext? context = arrival?.cardKey.currentContext;
    if (context == null) {
      return true;
    }
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
      box,
    );
    if (viewport == null || !_scroll.hasClients) {
      return null;
    }
    return viewport.getOffsetToReveal(box, 0).offset < _scroll.position.pixels;
  }

  void _toTop() {
    setState(_pillFor.clear);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// A load that brought a question not on the screen before, or a line
  /// bought since: the question unfolds where it is seen, or arrives above the
  /// reading without moving it; the lines flash and it is all said.
  void _news(
    List<CustomerOrderLine> asked,
    List<CustomerOrderLine> bought,
    _Anchor? anchor,
  ) {
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    double correction = 0;
    final Set<String> above = <String>{};
    for (final CustomerOrderLine line in asked) {
      final _Arrival? arrival = _arrivals[line.question!.id];
      if (arrival != null && (_topAbove(arrival) ?? false)) {
        above.add(arrival.questionId);
        // A card not built has no height to hold: it is laid out where the
        // list keeps its place.
        final RenderObject? box = arrival.cardKey.currentContext
            ?.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          correction += box.size.height;
        }
      }
    }
    // What changed above the reading in this load, the cards aside.
    correction += _anchorShift(anchor);
    setState(() {
      for (final CustomerOrderLine line in asked) {
        final _Arrival? arrival = _arrivals[line.question!.id];
        if (arrival != null) {
          arrival.phase = above.contains(arrival.questionId)
              ? _ArrivalPhase.still
              : _ArrivalPhase.unfolding;
        }
        _flash[line.id] = (_flash[line.id] ?? 0) + 1;
      }
      _pillFor.addAll(above);
      for (final CustomerOrderLine line in bought) {
        _flash[line.id] = (_flash[line.id] ?? 0) + 1;
      }
    });
    if (correction.abs() > 0.01 && _scroll.hasClients) {
      final ScrollPosition position = _scroll.position;
      position.correctBy(correction);
      // The fling is the position's own activity, which only it tells.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      final ScrollActivity? activity = position.activity;
      if (position is ScrollPositionWithSingleContext &&
          activity is BallisticScrollActivity) {
        // A fling's simulation holds absolute positions: it starts again
        // from the corrected one, at the speed it had.
        position.goBallistic(activity.velocity);
      }
    }
    for (final CustomerOrderLine line in asked) {
      final String name = line.name(language);
      announce(context, switch (line.question!.type) {
        ApprovalType.priceOverTolerance => l10n.questionArrivedPrice(name),
        ApprovalType.substitution => l10n.questionArrivedSubstitution(name),
        ApprovalType.reducedQuantity => l10n.questionArrivedQuantity(name),
      });
    }
    if (bought.length == 1) {
      announce(
        context,
        l10n.lineBoughtSpoken(
          bought.first.name(language),
          MoneyFormat.uzs(bought.first.lineTotalUzs, language),
        ),
      );
    } else if (bought.length > 1) {
      announce(context, l10n.linesBoughtSpoken(bought.length));
    }
  }

  /// The first line row whose top is at or under the view's top, and where
  /// that top stands in the list; the reading is held to it when the order
  /// changes (`DL-130`).
  _Anchor? _anchorOf(CustomerOrder order) {
    if (!_scroll.hasClients || _scroll.position.pixels <= 0) {
      return null;
    }
    for (final (bool dropped, List<CustomerOrderLine> lines)
        in <(bool, List<CustomerOrderLine>)>[
          (false, keptLines(order)),
          (true, droppedLines(order)),
        ]) {
      for (final CustomerOrderLine line in lines) {
        final double? top = _rowTop(_rowKey(line.id, dropped: dropped));
        if (top != null && top >= _scroll.position.pixels) {
          return (id: line.id, dropped: dropped, top: top);
        }
      }
    }
    return null;
  }

  double? _rowTop(GlobalKey key) {
    final RenderObject? box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return null;
    }
    return RenderAbstractViewport.maybeOf(box)
        ?.getOffsetToReveal(box, 0)
        .offset;
  }

  GlobalKey _rowKey(String lineId, {required bool dropped}) =>
      (dropped ? _droppedKeys : _keptKeys).putIfAbsent(lineId, GlobalKey.new);

  /// How far the anchor row has moved in the list since it was recorded.
  double _anchorShift(_Anchor? anchor) {
    if (anchor == null) {
      return 0;
    }
    final double? top = _rowTop(_rowKey(anchor.id, dropped: anchor.dropped));
    return top == null ? 0 : top - anchor.top;
  }

  void _watchNews(CustomerOrder before) {
    final CustomerOrder order = widget.order;
    final _Anchor? anchor = identical(before, order) ? null : _anchorOf(before);
    final Set<String> known = <String>{
      for (final CustomerOrderLine line in before.lines)
        if (line.question != null) line.question!.id,
    };
    final Map<String, OrderItemStatus> statuses = <String, OrderItemStatus>{
      for (final CustomerOrderLine line in before.lines) line.id: line.status,
    };
    final List<CustomerOrderLine> asked = <CustomerOrderLine>[
      for (final CustomerOrderLine line in <CustomerOrderLine>[
        ...keptLines(order),
        ...droppedLines(order),
      ])
        // The phone's clock takes nothing away: the server sends it open.
        if (line.question != null && !known.contains(line.question!.id)) line,
    ];
    final List<CustomerOrderLine> bought = <CustomerOrderLine>[
      for (final CustomerOrderLine line in order.lines)
        if (line.status == OrderItemStatus.purchased &&
            statuses[line.id] != null &&
            statuses[line.id] != OrderItemStatus.purchased)
          line,
    ];
    _pillFor.retainAll(<String>{
      for (final CustomerOrderLine line in order.lines)
        if (line.question != null) line.question!.id,
    });
    if (asked.isEmpty && bought.isEmpty && anchor == null) {
      return;
    }
    for (final CustomerOrderLine line in asked) {
      _arrivals[line.question!.id] = _Arrival(line.question!.id);
    }
    // After the build that lays the folded cards and the rows out.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _news(asked, bought, anchor),
    );
  }

  @override
  void didUpdateWidget(_Order oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An answer shown until the order loads again goes once the line no
    // longer carries the question it answered.
    final Map<String, String?> carried = <String, String?>{
      for (final CustomerOrderLine line in widget.order.lines)
        line.id: line.question?.id,
    };
    _yes.removeWhere(
      (String id, CustomerQuestion question) => carried[id] != question.id,
    );
    _no.removeWhere((String id, String question) => carried[id] != question);
    _watchNews(oldWidget.order);
    final Set<String> before = <String>{
      for (final CustomerOrderLine line in droppedLines(oldWidget.order))
        line.id,
    };
    final List<String> arrived = <String>[
      for (final CustomerOrderLine line in droppedLines(widget.order))
        if (!before.contains(line.id) && _refused.remove(line.id)) line.id,
    ];
    if (arrived.isNotEmpty) {
      // After the row's first build, which never flashes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            for (final String id in arrived) {
              _flash[id] = (_flash[id] ?? 0) + 1;
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrder order = widget.order;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DateTime now = ref.watch(clockProvider)();
    final CustomerCancellationRequest? request = order.cancellationRequest;
    final OrderCourier? courier = order.courier;
    final List<CustomerOrderLine> kept = keptLines(order);
    final List<CustomerOrderLine> dropped = droppedLines(order);
    final Widget info = OrderInfoSection(order: order, now: now);
    final bool onTheWay = order.status == OrderStatus.onTheWay;

    // Every child has a key of its own, so one that comes or goes (the
    // request card, the Courier, the removed group) never rebuilds those after
    // it: their folds and their fades go on (`DL-130`).
    Widget slot(String name, Widget child) =>
        KeyedSubtree(key: ValueKey<String>('order-slot-$name'), child: child);
    // The questions of the lines kept and dropped, in the order's own order,
    // so a card that moves with its line does not jump past the others.
    final Set<String> shown = <String>{
      for (final CustomerOrderLine line in kept) line.id,
      for (final CustomerOrderLine line in dropped) line.id,
    };

    final Widget list = ListView(
      key: const ValueKey<String>('order'),
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        slot('status', OrderStatusCard(order: order, now: now)),
        if (request != null) ...<Widget>[
          slot('request-gap', const SizedBox(height: 16)),
          slot('request', CancellationRequestCard(request: request)),
        ],
        if (courier != null) ...<Widget>[
          slot('courier-gap', const SizedBox(height: 16)),
          slot('courier', CourierCard(courier: courier)),
        ],
        if (order.canRate) ...<Widget>[
          slot('rating-gap', const SizedBox(height: 16)),
          slot('rating', RateOrderCard(order: order)),
        ] else if (order.rating != null) ...<Widget>[
          slot('rating-gap', const SizedBox(height: 16)),
          slot('rating', RatedOrderCard(rating: order.rating!)),
        ],
        if (onTheWay) ...<Widget>[
          slot('info-gap', const SizedBox(height: 16)),
          slot('info', info),
        ],
        // One child, so a line coming or going moves nothing below it and the
        // lines that follow keep their state while they fold (`DL-130`).
        slot(
          'questions',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The removed lines too: a no moves its line there while its
              // card still folds (`DL-130`).
              for (final CustomerOrderLine line in order.lines)
                if (shown.contains(line.id))
                  _QuestionBlock(
                    key: ValueKey<String>(line.id),
                    orderId: order.id,
                    line: line,
                    language: language,
                    arrival: line.question == null
                        ? null
                        : _arrivals[line.question!.id],
                    onSettled: _settled,
                  ),
            ],
          ),
        ),
        slot('header-gap', const SizedBox(height: 20)),
        slot(
          'header',
          Semantics(
            header: true,
            child: Text(
              l10n.checkoutItems(kept.length),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
        ),
        slot('header-space', const SizedBox(height: 4)),
        slot(
          'kept',
          FoldingColumn<CustomerOrderLine>(
            items: kept,
            keyOf: (CustomerOrderLine line) => line.id,
            itemBuilder: (BuildContext context, CustomerOrderLine line) =>
                KeyedSubtree(
                  key: _rowKey(line.id, dropped: false),
                  child: OrderLineRow(
                    line: line,
                    orderStatus: order.status,
                    flash: _flash[line.id] ?? 0,
                    answeredYes: _yes[line.id],
                    refused: _no.containsKey(line.id),
                  ),
                ),
          ),
        ),
        if (dropped.isNotEmpty)
          slot(
            'removed',
            Column(
              key: const ValueKey<String>('order-removed-group'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.orderRemovedGroup(dropped.length),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FoldingColumn<CustomerOrderLine>(
                  items: dropped,
                  keyOf: (CustomerOrderLine line) => line.id,
                  itemBuilder: (BuildContext context, CustomerOrderLine line) =>
                      KeyedSubtree(
                        key: _rowKey(line.id, dropped: true),
                        child: OrderLineRow(
                          line: line,
                          orderStatus: order.status,
                          flash: _flash[line.id] ?? 0,
                        ),
                      ),
                ),
              ],
            ),
          ),
        slot('divider-gap', const SizedBox(height: 12)),
        slot(
          'divider',
          const Divider(height: 1, thickness: 1, color: KitColors.line),
        ),
        slot('amounts-gap', const SizedBox(height: 12)),
        slot('amounts', OrderAmounts(order: order)),
        if (!onTheWay) ...<Widget>[
          slot('info-gap', const SizedBox(height: 20)),
          slot('info', info),
        ],
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        list,
        if (_pillFor.isNotEmpty)
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: Align(
              alignment: Alignment.topCenter,
              child: QuestionPill(onTap: _toTop),
            ),
          ),
      ],
    );
  }
}

/// A line's question waiting for the Customer, or that its time ran out; and
/// a refusal of their answer. The refusal belongs to the question it
/// answered: it is said while that question, or none, is on the line, and
/// not under a question asked since.
///
/// The phone's clock expires only a card it showed running: at the card's
/// `expiresAt` it turns expired at once, is announced and the order loads
/// again, and stays expired whatever a reload says. A question first seen past
/// that time while the server sends it open stays answerable, and the server
/// judges (`DL-130` (6), `DL-59` (3)).
///
/// A question the Customer's answer settled, the server answering `200`,
/// takes no tap and folds away at once, with a haptic and an announcement,
/// and is not drawn again whatever a reload that fails leaves; the card
/// being folded stays through the reload that moves its line (`DL-130`).
class _QuestionBlock extends ConsumerStatefulWidget {
  const _QuestionBlock({
    required this.orderId,
    required this.line,
    required this.language,
    required this.arrival,
    required this.onSettled,
    super.key,
  });

  final String orderId;
  final CustomerOrderLine line;
  final AppLanguage language;

  /// How the line's question came in, when it arrived while the order was
  /// open.
  final _Arrival? arrival;

  /// Called once per settled answer, with the question it answered when the
  /// line still carried it.
  final void Function(
    String lineId,
    ApprovalDecision decision,
    CustomerQuestion? question,
  )
  onSettled;

  @override
  ConsumerState<_QuestionBlock> createState() => _QuestionBlockState();
}

class _QuestionBlockState extends ConsumerState<_QuestionBlock> {
  Timer? _timer;
  String? _timerFor;

  /// The questions whose deadline passed while this line was shown.
  final Set<String> _expired = <String>{};

  /// The settled answer already handled, by question id.
  String? _handled;

  /// The card folding away after its answer, as the line stood then.
  ({CustomerOrderLine line, CustomerQuestion question})? _folding;

  /// The arrival of the question drawn, kept while its card folds after an
  /// answer, so the card keeps its fold.
  _Arrival? _arrival;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _watchDeadline(CustomerQuestion? question, DateTime now) {
    final String? key = question == null || _expired.contains(question.id)
        ? null
        : '${question.id}@${question.expiresAt.toIso8601String()}';
    if (key == _timerFor) {
      return;
    }
    _timer?.cancel();
    _timerFor = key;
    if (question == null || key == null) {
      return;
    }
    final Duration wait = question.expiresAt.difference(now);
    if (wait <= Duration.zero) {
      return;
    }
    _timer = Timer(wait, () {
      if (!mounted) {
        return;
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      setState(() => _expired.add(question.id));
      announce(
        context,
        l10n.questionExpiredSpoken(widget.line.name(widget.language)),
      );
      ref.invalidate(customerOrderProvider(widget.orderId));
    });
  }

  void _answered(({String approvalId, ApprovalDecision decision}) answer) {
    if (_handled == answer.approvalId) {
      return;
    }
    _handled = answer.approvalId;
    final CustomerOrderLine line = widget.line;
    final CustomerQuestion? asked = line.question?.id == answer.approvalId
        ? line.question
        : null;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = line.name(widget.language);
    HapticFeedback.lightImpact();
    if (answer.decision == ApprovalDecision.reject) {
      announce(context, l10n.orderRejectedSpoken(name));
    } else if (asked?.type == ApprovalType.substitution) {
      announce(
        context,
        l10n.orderAgreedReplacementSpoken(
          asked!.replacement!.name(widget.language),
        ),
      );
    } else {
      final AgreedTerms? terms = asked == null
          ? line.agreed
          : agreedTermsOf(asked);
      if (terms != null) {
        announce(
          context,
          l10n.orderAgreedSpoken(
            name,
            agreedText(l10n, line, terms, widget.language),
          ),
        );
      }
    }
    widget.onSettled(line.id, answer.decision, asked);
    if (asked != null) {
      setState(() => _folding = (line: line, question: asked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String orderId = widget.orderId;
    final CustomerOrderLine line = widget.line;
    final AppLanguage language = widget.language;
    final DateTime now = ref.watch(clockProvider)();
    final OrderLineRef lineRef = (orderId: orderId, lineId: line.id);
    ref.listen<MutationState>(approvalDecisionProvider(lineRef), (
      MutationState? before,
      MutationState next,
    ) {
      final ({String approvalId, ApprovalDecision decision})? answer = ref
          .read(approvalDecisionProvider(lineRef).notifier)
          .settled;
      if (before != null && before.isBusy && !next.isBusy && answer != null) {
        _answered(answer);
      }
    });
    // A question the Customer's answer settled is not asked again, whatever
    // the order shows until it loads again.
    final bool settled =
        line.question != null &&
        ref
                .read(approvalDecisionProvider(lineRef).notifier)
                .settled
                ?.approvalId ==
            line.question!.id;
    final CustomerQuestion? sent = settled ? null : line.question;
    final bool pastDeadline = sent != null && _expired.contains(sent.id);
    final CustomerQuestion? question = pastDeadline ? null : sent;
    _watchDeadline(question, now);
    final MutationState deciding = ref.watch(
      approvalDecisionProvider((orderId: orderId, lineId: line.id)),
    );
    final String? answered = ref
        .read(
          approvalDecisionProvider((orderId: orderId, lineId: line.id))
              .notifier,
        )
        .approvalId;

    // A refusal stays under the line it answered after the question is gone.
    final ApiFailure? refusal = question == null || question.id == answered
        ? deciding.failure
        : null;
    final bool expired = !settled && (line.questionExpired || pastDeadline);
    final ({CustomerOrderLine line, CustomerQuestion question})? folding =
        _folding;
    final CustomerQuestion? card = folding?.question ?? question;
    if (card == null && !expired && refusal == null) {
      return const SizedBox.shrink();
    }
    _arrival = widget.arrival ?? _arrival;
    final _Arrival? arrival = _arrival?.questionId == card?.id
        ? _arrival
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (card != null)
          // One Fold from the card's first draw to its end, so the answer
          // only turns `shown` off.
          IgnorePointer(
            ignoring: folding != null,
            child: Fold(
              // Shown still above the reading, under a key of its own.
              key: arrival == null
                  ? null
                  : ValueKey<String>(
                      'arrival-${arrival.questionId}-'
                      '${arrival.phase == _ArrivalPhase.still}',
                    ),
              shown:
                  folding == null && arrival?.phase != _ArrivalPhase.measuring,
              onFolded: () => setState(() => _folding = null),
              child: Padding(
                key: arrival?.cardKey,
                padding: const EdgeInsets.only(top: 16),
                child: OrderQuestionCard(
                  orderId: orderId,
                  line: folding?.line ?? line,
                  question: card,
                  deciding: deciding,
                  language: language,
                ),
              ),
            ),
          )
        else if (expired)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OrderQuestionExpired(line: line),
          )
        else if (refusal != null)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              line.name(language),
              key: ValueKey<String>('question-refusal-name-${line.id}'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KitColors.ink2,
              ),
            ),
          ),
        FailureMessage(refusal),
      ],
    );
  }
}
