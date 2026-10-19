import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show FutureProviderFamily, NotifierProviderFamily;

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
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

/// The page of one tab of the Customer's orders shown while the list is
/// open; the list opens on the newest orders again, and another account
/// starts over.
class OrdersPageController extends Notifier<int> {
  OrdersPageController(this.tab);

  final OrdersTab tab;

  @override
  int build() {
    ref.watch(customerAccountProvider);
    return 1;
  }

  void goToPage(int page) => state = page;
}

final NotifierProviderFamily<OrdersPageController, int, OrdersTab>
ordersPageProvider = NotifierProvider.autoDispose
    .family<OrdersPageController, int, OrdersTab>(OrdersPageController.new);

/// One tab of the Customer's orders, newest first, one page at a time.
final FutureProviderFamily<Paged<OrderSummary>, OrdersTab>
customerOrdersProvider = FutureProvider.autoDispose
    .family<Paged<OrderSummary>, OrdersTab>((Ref ref, OrdersTab tab) {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<Paged<OrderSummary>>().future;
      }
      return ref
          .watch(customerOrdersRepositoryProvider)
          .orders(tab, ref.watch(ordersPageProvider(tab)));
    });

/// The question to put on the home banner: of the first page of pending
/// questions, the one expiring first; `null` when none waits.
final FutureProvider<PendingQuestion?> pendingQuestionProvider =
    FutureProvider.autoDispose<PendingQuestion?>((Ref ref) async {
      if (ref.watch(customerAccountProvider) == null) {
        return Completer<PendingQuestion?>().future;
      }
      final List<PendingQuestion> questions = await ref
          .watch(customerOrdersRepositoryProvider)
          .pendingQuestions();
      PendingQuestion? first;
      for (final PendingQuestion question in questions) {
        if (first == null || question.expiresAt.isBefore(first.expiresAt)) {
          first = question;
        }
      }
      return first;
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
    ..invalidate(pendingQuestionProvider);
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
/// 48); a cancelled order is a natural repeat anyway.
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
      reload: reload,
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
      reload: (_) {},
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

  /// The question the latest decision answered: its refusal is said while
  /// that question, or none, is on the line, never under one asked since.
  String? get approvalId => _approvalId;

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
    final CustomerApproval? answer = await perform(
      () => orders.decide(orderId, approvalId, sent, key),
      reload: reload,
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
