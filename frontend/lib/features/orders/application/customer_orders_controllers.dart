import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show
        AsyncNotifierProviderFamily,
        FutureProviderFamily,
        NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/platform/clock.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/state/account_mutation.dart';
import '../../../core/state/mutation_state.dart';
import '../../cart/application/cart_controllers.dart';
import '../data/customer_orders_api.dart';
import '../domain/customer_orders.dart';

final Provider<CustomerOrdersRepository> customerOrdersRepositoryProvider =
    Provider<CustomerOrdersRepository>(
      (Ref ref) => CustomerOrdersRepositoryImpl(
        CustomerOrdersApi(ref.watch(apiClientProvider)),
      ),
    );

const Object _keep = Object();

/// One tab of the Customer's orders as the endless list shows it: every page
/// loaded so far, newest first (`DL-131`).
final class OrdersFeed {
  const OrdersFeed({
    required this.rows,
    required this.total,
    required this.nextPage,
    required this.pages,
    required this.at,
    this.loadingMore = false,
    this.moreFailure,
    this.dropped = const <String>{},
  });

  /// The orders, newest first, none twice.
  final List<OrderSummary> rows;

  /// The server's count, less the rows dropped since the last load.
  final int total;

  /// The page [CustomerOrdersFeed.loadMore] asks for next; null at the end.
  final int? nextPage;

  /// How many pages are loaded.
  final int pages;

  /// When the last whole load came.
  final DateTime at;

  final bool loadingMore;

  /// Why the page after the last one did not come; the rows stay.
  final ApiFailure? moreFailure;

  /// The ids [CustomerOrdersFeed.drop] took off since the last load.
  final Set<String> dropped;

  bool get hasMore => nextPage != null;

  OrdersFeed copyWith({
    List<OrderSummary>? rows,
    int? total,
    Object? nextPage = _keep,
    int? pages,
    bool? loadingMore,
    Object? moreFailure = _keep,
    Set<String>? dropped,
  }) => OrdersFeed(
    rows: rows ?? this.rows,
    total: total ?? this.total,
    nextPage: identical(nextPage, _keep) ? this.nextPage : nextPage as int?,
    pages: pages ?? this.pages,
    at: at,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailure: identical(moreFailure, _keep)
        ? this.moreFailure
        : moreFailure as ApiFailure?,
    dropped: dropped ?? this.dropped,
  );
}

/// One tab of the Customer's orders, a page at a time as the Customer
/// scrolls. A reload — after an invalidation too — asks again for every page
/// the feed had, so a deep list comes back as it was; another account starts
/// at page 1. A page that lands after the feed was rebuilt is dropped by the
/// generation it was asked for (`DL-131`).
class CustomerOrdersFeed extends AsyncNotifier<OrdersFeed> {
  CustomerOrdersFeed(this.tab);

  final OrdersTab tab;

  int _generation = 0;
  int _pages = 1;
  String? _account;

  /// The ids dropped, kept across whole loads of one account, and how many
  /// rows were dropped since the last whole load (the server's total, when
  /// it comes with the next page, still counts them).
  Set<String> _dropped = <String>{};
  int _droppedSinceLoad = 0;

  @override
  Future<OrdersFeed> build() async {
    final int generation = ++_generation;
    final String? account = ref.watch(customerAccountProvider);
    if (account == null) {
      _account = null;
      _pages = 1;
      _dropped = <String>{};
      return Completer<OrdersFeed>().future;
    }
    final int wanted = account == _account ? math.max(1, _pages) : 1;
    if (account != _account) {
      _dropped = <String>{};
    }
    _account = account;
    final CustomerOrdersRepository repository = ref.watch(
      customerOrdersRepositoryProvider,
    );

    final List<OrderSummary> rows = <OrderSummary>[];
    final Set<String> seen = <String>{};
    int total = 0;
    int? next = 1;
    int loaded = 0;
    while (next != null && loaded < wanted) {
      final Paged<OrderSummary> page = await repository.orders(tab, next);
      if (generation != _generation) {
        break;
      }
      for (final OrderSummary row in page.items) {
        if (seen.add(row.id)) {
          rows.add(row);
        }
      }
      total = page.total;
      loaded++;
      next = page.hasNext ? page.page + 1 : null;
    }
    _pages = loaded;
    _dropped = <String>{
      for (final String id in _dropped)
        if (!seen.contains(id)) id,
    };
    _droppedSinceLoad = 0;
    return OrdersFeed(
      dropped: _dropped,
      rows: rows,
      total: total,
      nextPage: next,
      pages: loaded,
      at: ref.read(clockProvider)(),
    );
  }

  /// Loads the next page, once at a time; nothing at the end, while a reload
  /// runs, or after one failed (the screen's retry reloads).
  Future<void> loadMore() async {
    final OrdersFeed? current = state.value;
    final int? page = current?.nextPage;
    if (current == null ||
        page == null ||
        current.loadingMore ||
        state.isLoading ||
        state.hasError ||
        ref.read(customerAccountProvider) == null) {
      return;
    }

    final int generation = _generation;
    state = AsyncData<OrdersFeed>(
      current.copyWith(loadingMore: true, moreFailure: null),
    );

    OrdersFeed next;
    try {
      final Paged<OrderSummary> loaded = await ref
          .read(customerOrdersRepositoryProvider)
          .orders(tab, page);
      final Set<String> shown = <String>{
        for (final OrderSummary row in current.rows) row.id,
        ...current.dropped,
      };
      next = current.copyWith(
        rows: <OrderSummary>[
          ...current.rows,
          for (final OrderSummary row in loaded.items)
            if (shown.add(row.id)) row,
        ],
        total: loaded.total - _droppedSinceLoad,
        nextPage: loaded.hasNext ? loaded.page + 1 : null,
        pages: current.pages + 1,
        loadingMore: false,
        moreFailure: null,
      );
    } on ApiFailure catch (failure) {
      next = current.copyWith(loadingMore: false, moreFailure: failure);
    } catch (error, stackTrace) {
      reportUnexpectedError(error, stackTrace, 'while loading more orders');
      next = current.copyWith(
        loadingMore: false,
        moreFailure: const UnexpectedFailure(),
      );
    }

    if (ref.mounted && generation == _generation) {
      _pages = next.pages;
      state = AsyncData<OrdersFeed>(next);
    }
  }

  /// Takes the order [id] off the feed, whatever the case of the id, before
  /// the feed's own reload answers (`DL-113`). The total goes down by the
  /// rows removed; before the first answer, during a reload, after a
  /// failure, or for an id not shown, nothing changes.
  void drop(String id) {
    final OrdersFeed? current = state.value;
    if (current == null || state.hasError || state.isLoading) {
      return;
    }
    final String wanted = id.toLowerCase();
    final List<OrderSummary> kept = <OrderSummary>[
      for (final OrderSummary row in current.rows)
        if (row.id.toLowerCase() != wanted) row,
    ];
    final int removed = current.rows.length - kept.length;
    if (removed == 0) {
      return;
    }
    _droppedSinceLoad += removed;
    _dropped = <String>{
      ...current.dropped,
      for (final OrderSummary row in current.rows)
        if (row.id.toLowerCase() == wanted) row.id,
    };
    state = AsyncData<OrdersFeed>(
      current.copyWith(
        rows: kept,
        total: math.max(0, current.total - removed),
        dropped: _dropped,
      ),
    );
  }
}

/// One tab of the Customer's orders as an endless list.
final AsyncNotifierProviderFamily<CustomerOrdersFeed, OrdersFeed, OrdersTab>
customerOrdersProvider = AsyncNotifierProvider.autoDispose
    .family<CustomerOrdersFeed, OrdersFeed, OrdersTab>(CustomerOrdersFeed.new);

/// Every question a Shopper waits on, the one expiring first at the head
/// (`DL-125`).
final FutureProvider<List<PendingQuestion>> pendingQuestionsProvider =
    FutureProvider.autoDispose<List<PendingQuestion>>((Ref ref) async {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<List<PendingQuestion>>().future;
      }
      final List<PendingQuestion> questions = await ref
          .watch(customerOrdersRepositoryProvider)
          .pendingQuestions();
      return List<PendingQuestion>.of(questions)..sort(
        (PendingQuestion a, PendingQuestion b) =>
            a.expiresAt.compareTo(b.expiresAt),
      );
    });

/// The questions still open: the last list that loaded, kept while a refresh
/// fails, without those whose time to answer is over. It changes at the
/// moment the earliest of them expires.
final Provider<List<PendingQuestion>> openQuestionsProvider =
    Provider.autoDispose<List<PendingQuestion>>((Ref ref) {
      final List<PendingQuestion> loaded =
          ref.watch(pendingQuestionsProvider).value ??
          const <PendingQuestion>[];
      final DateTime now = ref.watch(clockProvider)();
      final List<PendingQuestion> open = <PendingQuestion>[
        for (final PendingQuestion question in loaded)
          if (question.expiresAt.isAfter(now)) question,
      ];
      if (open.isNotEmpty) {
        final Timer timer = Timer(
          open.first.expiresAt.difference(now),
          ref.invalidateSelf,
        );
        ref.onDispose(timer.cancel);
      }
      return open;
    });

/// One of the Customer's orders.
final FutureProviderFamily<CustomerOrder, String> customerOrderProvider =
    FutureProvider.autoDispose.family<CustomerOrder, String>((
      Ref ref,
      String id,
    ) {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<CustomerOrder>().future;
      }
      return ref.watch(customerOrdersRepositoryProvider).order(id);
    });

/// A change to one order from its screens. After it — and after a conflict,
/// the order gone, or an uncertain outcome — the order and the list load
/// again, so a `409` shows the order as it now is (`DL-28` (11)).
abstract class OrderMutation extends AccountMutation {
  OrderMutation(this.orderId);

  final String orderId;

  @override
  Provider<String?> get account => customerAccountProvider;

  CustomerOrdersRepository get orders =>
      ref.read(customerOrdersRepositoryProvider);

  void reload(Object? _) => ref
    ..invalidate(customerOrderProvider(orderId))
    ..invalidate(customerOrdersProvider)
    ..invalidate(pendingQuestionsProvider);
}

/// The order's edit: every line it keeps and the delivery wish.
class OrderEditController extends OrderMutation {
  OrderEditController(super.orderId);

  Future<CustomerOrder?> edit(
    List<OrderEditLine> lines,
    String? deliveryTimeNote,
  ) => perform(
    () => orders.edit(orderId, lines, deliveryTimeNote),
    reload: reload,
  );
}

final NotifierProviderFamily<OrderEditController, MutationState, String>
orderEditProvider = NotifierProvider.autoDispose
    .family<OrderEditController, MutationState, String>(
      OrderEditController.new,
    );

/// The order's direct cancellation, under an `Idempotency-Key` kept until
/// an answer says for sure whether it cancelled (`docs/09` sections 22 and
/// 48); a cancelled order is a natural repeat anyway. A sure cancellation
/// takes the order off the current orders under the page at once; a request
/// for a cancellation leaves it there (`DL-113`).
class OrderCancelController extends OrderMutation {
  OrderCancelController(super.orderId);

  String? _key;
  String? _reason;

  /// Whether a cancel was sent and no answer has said for sure what it did;
  /// a retry then sends [unconfirmedReason] again, under the same key, so the
  /// server sees the same request.
  bool get unconfirmed => _key != null;

  String? get unconfirmedReason => _reason;

  Future<CustomerOrder?> cancel(String? reason) async {
    // A tap while a cancel runs is not another attempt, and leaves the key.
    if (state.isBusy) {
      return null;
    }
    if (_key == null) {
      _key = newIdempotencyKey();
      _reason = reason;
    }
    final String key = _key!;
    final String? sent = _reason;
    final CustomerOrder? order = await perform(
      () => orders.cancel(orderId, sent, key),
      reload: (CustomerOrder? cancelled) {
        // The drop comes first: a feed that is reloading ignores it.
        if (cancelled?.status == OrderStatus.cancelled &&
            ref.exists(customerOrdersProvider(OrdersTab.current))) {
          ref
              .read(customerOrdersProvider(OrdersTab.current).notifier)
              .drop(orderId);
        }
        reload(cancelled);
      },
    );
    if (!_uncertain(ref.mounted ? state.failure : null)) {
      _key = null;
      _reason = null;
    }
    return order;
  }
}

final NotifierProviderFamily<OrderCancelController, MutationState, String>
orderCancelProvider = NotifierProvider.autoDispose
    .family<OrderCancelController, MutationState, String>(
      OrderCancelController.new,
    );

/// Whether an answer leaves it open what a keyed request did: no refusal, a
/// `5xx`, or an `idempotency_in_progress` (`docs/09` section 48).
bool _uncertain(ApiFailure? failure) =>
    failure != null &&
    (failure is! ApiRefusal ||
        failure.status >= 500 ||
        failure.code == 'idempotency_in_progress');

/// The order's reorder into the cart, under an `Idempotency-Key` kept until
/// an answer says for sure what it did (`docs/09` sections 26 and 48). After
/// a sure answer the cart loads again.
class ReorderController extends OrderMutation {
  ReorderController(super.orderId);

  String? _key;

  Future<ReorderResult?> reorder() async {
    // A tap while a reorder runs is not another attempt, and leaves the key.
    if (state.isBusy) {
      return null;
    }
    final String key = _key ??= newIdempotencyKey();
    final ReorderResult? result = await perform(
      () => orders.reorder(orderId, key),
      reload: (_) => ref.invalidate(cartProvider),
    );
    if (!_uncertain(ref.mounted ? state.failure : null)) {
      _key = null;
      if (ref.mounted) {
        ref.invalidate(cartProvider);
      }
    }
    return result;
  }
}

final NotifierProviderFamily<ReorderController, MutationState, String>
reorderProvider = NotifierProvider.autoDispose
    .family<ReorderController, MutationState, String>(ReorderController.new);

/// The Customer's rating of the order. It carries no key: the identical
/// repeat is the retry (`docs/09` section 49).
class RateController extends OrderMutation {
  RateController(super.orderId);

  Future<CustomerOrder?> rate(
    int stars,
    List<RatingReason> reasons,
    String? comment,
  ) {
    // A tap while a rating runs is not another one.
    if (state.isBusy) {
      return Future<CustomerOrder?>.value();
    }
    return perform(
      () => orders.rate(orderId, stars, reasons, comment),
      reload: reload,
    );
  }
}

final NotifierProviderFamily<RateController, MutationState, String>
rateProvider = NotifierProvider.autoDispose
    .family<RateController, MutationState, String>(RateController.new);

/// The decisions on one order's questions sent without a sure answer, by
/// question: the key and the decision sent, which a retry sends again as it
/// was (`docs/09` section 48, `DL-71`). A decision enters only once an
/// answer failed to say what it did, and leaves at the first sure answer.
/// The order's screen watches this, so they last while the order is shown.
class UnansweredDecisionsController
    extends Notifier<Map<String, UnansweredRequest<ApprovalDecision>>> {
  UnansweredDecisionsController(this.orderId);

  final String orderId;

  @override
  Map<String, UnansweredRequest<ApprovalDecision>> build() {
    ref.watch(customerAccountProvider);
    return const <String, UnansweredRequest<ApprovalDecision>>{};
  }

  void set(String approvalId, UnansweredRequest<ApprovalDecision>? request) {
    final Map<String, UnansweredRequest<ApprovalDecision>> next =
        <String, UnansweredRequest<ApprovalDecision>>{...state};
    if (request == null) {
      next.remove(approvalId);
    } else {
      next[approvalId] = request;
    }
    state = next;
  }
}

final NotifierProviderFamily<
  UnansweredDecisionsController,
  Map<String, UnansweredRequest<ApprovalDecision>>,
  String
>
unansweredDecisionsProvider = NotifierProvider.autoDispose
    .family<
      UnansweredDecisionsController,
      Map<String, UnansweredRequest<ApprovalDecision>>,
      String
    >(UnansweredDecisionsController.new);

/// A line, as its order names it.
typedef OrderLineRef = ({String orderId, String lineId});

/// The Customer's answers to a line's questions (`docs/09` section 23),
/// keyed: without a sure answer the key and the decision wait in
/// [unansweredDecisionsProvider], and a retry sends them again. After it,
/// and after a refusal — the question expired, already answered, or the
/// order changed — the order and the list load again (`DL-28` (11)). It
/// belongs to the line rather than to the question, so a refusal stays said
/// once the reload has taken the question away (`DL-71`).
class ApprovalDecisionController extends OrderMutation {
  ApprovalDecisionController(this.line) : super(line.orderId);

  final OrderLineRef line;

  String? _approvalId;
  ApprovalDecision? _sending;
  ({String approvalId, ApprovalDecision decision})? _settled;

  /// The question the latest decision answered: its refusal is said while
  /// that question, or none, is on the line, never under one asked since.
  String? get approvalId => _approvalId;

  /// The decision the server answered `200`, kept until another decision on
  /// the line starts: the screen folds the question it answered, and says
  /// what was agreed while the order loads again (`DL-130`).
  ({String approvalId, ApprovalDecision decision})? get settled => _settled;

  /// The decision on its way, while one runs.
  ApprovalDecision? get sending => state.isBusy ? _sending : null;

  Future<CustomerApproval?> decide(
    String approvalId,
    ApprovalDecision decision,
  ) async {
    // A tap while a decision runs is not another one.
    if (state.isBusy) {
      return null;
    }
    final UnansweredRequest<ApprovalDecision>? unanswered = ref.read(
      unansweredDecisionsProvider(orderId),
    )[approvalId];
    final String key = unanswered?.key ?? newIdempotencyKey();
    final ApprovalDecision sent = unanswered?.sent ?? decision;
    _approvalId = approvalId;
    _sending = sent;
    _settled = null;
    final CustomerApproval? answer = await perform(
      () => orders.decide(orderId, approvalId, sent, key),
      reload: (CustomerApproval? answered) {
        if (answered != null) {
          _settled = (approvalId: approvalId, decision: sent);
        }
        reload(answered);
      },
    );
    if (ref.mounted) {
      ref
          .read(unansweredDecisionsProvider(orderId).notifier)
          .set(
            approvalId,
            leavesOutcomeUnknown(state.failure)
                ? UnansweredRequest<ApprovalDecision>(key, sent)
                : null,
          );
    }
    return answer;
  }
}

final NotifierProviderFamily<
  ApprovalDecisionController,
  MutationState,
  OrderLineRef
>
approvalDecisionProvider = NotifierProvider.autoDispose
    .family<ApprovalDecisionController, MutationState, OrderLineRef>(
      ApprovalDecisionController.new,
    );
