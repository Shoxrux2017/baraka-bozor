import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

/// The order's editor (`docs/09` section 21, `DL-43`): the lines the
/// Customer still orders, each with its quantity, note and rule and the way
/// to take it out, the products the Customer adds from the catalog
/// (`DL-52`), and the delivery wish. It sends the whole list the order is to
/// keep, and nothing when that is what the order already holds; a line taken
/// out is dropped from the list, and at least one must stay, at most
/// [orderMaxLines]. An order the server no longer lets change (`can_edit`)
/// is not edited: after a refusal the order loads again and the editor gives
/// way to saying so.
class OrderEditScreen extends ConsumerWidget {
  const OrderEditScreen({required this.orderId, this.adding, super.key});

  final String orderId;

  /// A product picked before the editor was open, to add at once.
  final CatalogProduct? adding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CustomerOrder> order = ref.watch(
      customerOrderProvider(orderId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderEditTitle)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Expanded(
              // A reload that failed shows the failure, and a retry its
              // progress, never the form held before.
              child: switch (order) {
                AsyncValue<CustomerOrder>(hasError: true, isLoading: true) =>
                  const Center(child: CircularProgressIndicator()),
                AsyncValue<CustomerOrder>(:final Object error) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadFailure(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(customerOrderProvider(orderId)),
                  ),
                ),
                AsyncValue<CustomerOrder>(:final CustomerOrder value)
                    when !value.canEdit =>
                  _Closed(orderId: value.id),
                AsyncValue<CustomerOrder>(:final CustomerOrder value) =>
                  _Editor(
                    key: ValueKey<String>(value.id),
                    order: value,
                    adding: adding,
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Leaves the editor for the order: back to it when the editor was opened
/// over it, to it when the editor was opened by its address alone.
void _backToOrder(GoRouter router, String orderId) {
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(AppPaths.customerOrder(orderId));
  }
}

/// The order can no longer be changed; the way back to it.
class _Closed extends StatelessWidget {
  const _Closed({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListView(
      key: const ValueKey<String>('edit-closed'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(l10n.orderEditClosed),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey<String>('edit-back-to-order'),
          onPressed: () => _backToOrder(GoRouter.of(context), orderId),
          child: Text(l10n.orderOpen),
        ),
      ],
    );
  }
}

/// What the Customer sets on one line: a line already ordered, or a product
/// this edit adds.
final class _LineDraft {
  _LineDraft.ordered(CustomerOrderLine this.line)
    : product = null,
      productId = line.productId,
      unit = line.unit,
      quantity = TextEditingController(
        text: editableQuantity(line.unit, line.quantity),
      ),
      note = TextEditingController(text: line.customerNote ?? ''),
      policy = line.substitutionPolicy;

  _LineDraft.added(CatalogProduct this.product)
    : line = null,
      productId = product.id,
      unit = product.unitCode,
      quantity = TextEditingController(text: '1'),
      note = TextEditingController(),
      policy = SubstitutionPolicy.allowSimilar;

  /// The line as the editor found it, or `null` for a product this edit
  /// adds.
  final CustomerOrderLine? line;

  /// The product this edit adds, at its price now, or `null` for a line
  /// already ordered.
  final CatalogProduct? product;
  final String productId;
  final UnitCode unit;
  final TextEditingController quantity;
  final TextEditingController note;
  SubstitutionPolicy policy;
  bool removed = false;

  /// The server named the product as one the Customer can no longer order.
  bool unavailable = false;

  /// Its card, to bring into view.
  final GlobalKey card = GlobalKey();

  /// Its fields' focus, to take the Customer to one to correct.
  final FocusNode quantityFocus = FocusNode();
  final FocusNode noteFocus = FocusNode();

  /// What its card and buttons are known by.
  String get key => line?.id ?? 'added-$productId';

  String name(AppLanguage language) =>
      line?.name(language) ?? product!.name(language);

  /// The first of its fields holding what the server would refuse, as their
  /// validators judge them, or `null` when both are right.
  FocusNode? get wrongField =>
      QuantityRules.normalize(unit, quantity.text) == null
      ? quantityFocus
      : trimLikeServer(note.text).runes.length > cartNoteMaxLength
      ? noteFocus
      : null;

  OrderEditLine toEdit() {
    final String text = trimLikeServer(note.text);
    return OrderEditLine(
      productId: productId,
      quantity: QuantityRules.normalize(unit, quantity.text)!,
      customerNote: text.isEmpty ? null : text,
      substitutionPolicy: policy,
    );
  }

  void dispose() {
    quantity.dispose();
    note.dispose();
    quantityFocus.dispose();
    noteFocus.dispose();
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.order, this.adding, super.key});

  /// The order as last loaded, which a reload replaces under the drafts.
  final CustomerOrder order;
  final CatalogProduct? adding;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final List<_LineDraft> _lines = <_LineDraft>[
    for (final CustomerOrderLine line in widget.order.openLines)
      _LineDraft.ordered(line),
  ];
  late final TextEditingController _wish = TextEditingController(
    text: widget.order.deliveryTimeNote ?? '',
  );
  bool _noneLeft = false;

  @override
  void initState() {
    super.initState();
    final CatalogProduct? adding = widget.adding;
    if (adding != null) {
      _take(adding);
    }
  }

  @override
  void dispose() {
    for (final _LineDraft line in _lines) {
      line.dispose();
    }
    _wish.dispose();
    super.dispose();
  }

  List<_LineDraft> get _kept =>
      _lines.where((_LineDraft line) => !line.removed).toList();

  /// Adds [product], or keeps its line when the order already has it;
  /// answers that line, or `null` when the product is new to the order.
  _LineDraft? _take(CatalogProduct product) {
    final String id = product.id.toLowerCase();
    final _LineDraft? present = _lines
        .where((_LineDraft line) => line.productId.toLowerCase() == id)
        .firstOrNull;
    _noneLeft = false;
    if (present == null) {
      _lines.add(_LineDraft.added(product));
    } else {
      present.removed = false;
    }
    return present;
  }

  /// Picks a product from the catalog. One already in the order is not added
  /// twice: its line is kept and brought into view, and the Customer is
  /// told.
  Future<void> _add() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CatalogProduct? product = await GoRouter.of(context)
        .push<CatalogProduct>(AppPaths.customerOrderAdd(widget.order.id));
    if (product == null || !mounted) {
      return;
    }
    _LineDraft? present;
    setState(() => present = _take(product));
    final _LineDraft? line = present;
    if (line == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.orderAddAlreadyIn)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? card = line.card.currentContext;
      if (card != null && card.mounted) {
        Scrollable.ensureVisible(card);
      }
    });
  }

  /// Takes a line out, or keeps it again; a product this edit added is
  /// simply dropped.
  void _toggle(_LineDraft draft) {
    setState(() {
      _noneLeft = false;
      if (draft.line == null) {
        _lines.remove(draft);
        // Its fields leave the tree with this frame; their controllers go
        // after it.
        WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
      } else {
        draft.removed = !draft.removed;
      }
    });
  }

  /// Whether [lines] and [deliveryTimeNote] are what the order holds now —
  /// the order as last loaded, not as the editor found it, since the answer
  /// to an earlier save may have been lost after the server made it.
  bool _changesNothing(List<OrderEditLine> lines, String? deliveryTimeNote) {
    final CustomerOrder order = widget.order;
    if (deliveryTimeNote != order.deliveryTimeNote) {
      return false;
    }
    final Map<String, CustomerOrderLine> open = <String, CustomerOrderLine>{
      for (final CustomerOrderLine line in order.openLines)
        line.productId.toLowerCase(): line,
    };
    if (open.length != lines.length) {
      return false;
    }
    for (final OrderEditLine line in lines) {
      final CustomerOrderLine? now = open[line.productId.toLowerCase()];
      if (now == null ||
          QuantityRules.thousandths(line.quantity) !=
              QuantityRules.thousandths(now.quantity) ||
          line.customerNote != now.customerNote ||
          line.substitutionPolicy != now.substitutionPolicy) {
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    final List<_LineDraft> kept = _kept;
    setState(() => _noneLeft = kept.isEmpty);
    if (kept.isEmpty || kept.length > orderMaxLines) {
      return;
    }
    if (!_form.currentState!.validate()) {
      // The first field to correct may be out of sight: it takes the focus,
      // which brings it into view.
      kept
          .map((_LineDraft line) => line.wrongField)
          .nonNulls
          .firstOrNull
          ?.requestFocus();
      return;
    }
    // The keyboard goes while the edit is sent.
    FocusScope.of(context).unfocus();
    final List<OrderEditLine> lines = <OrderEditLine>[
      for (final _LineDraft line in kept) line.toEdit(),
    ];
    final String wish = trimLikeServer(_wish.text);
    final String? deliveryTimeNote = wish.isEmpty ? null : wish;
    final GoRouter router = GoRouter.of(context);

    // Nothing to change: nothing is sent (`DL-28` (9)).
    if (_changesNothing(lines, deliveryTimeNote)) {
      _backToOrder(router, widget.order.id);
      return;
    }
    // What the server said of an earlier attempt goes with it.
    setState(() {
      for (final _LineDraft line in _lines) {
        line.unavailable = false;
      }
    });
    final CustomerOrder? answer = await ref
        .read(orderEditProvider(widget.order.id).notifier)
        .edit(lines, deliveryTimeNote);
    if (!mounted) {
      return;
    }
    if (answer != null) {
      _backToOrder(router, widget.order.id);
      return;
    }
    // The products the server names as no longer orderable are marked.
    final ApiFailure? failure = ref
        .read(orderEditProvider(widget.order.id))
        .failure;
    if (failure is ApiRefusal && failure.code == 'product_unavailable') {
      final Object? named = failure.error.details['product_ids'];
      final Set<String> ids = <String>{
        if (named is List<Object?>)
          for (final Object? id in named)
            if (id is String) id.toLowerCase(),
      };
      setState(() {
        for (final _LineDraft line in _lines) {
          line.unavailable = ids.contains(line.productId.toLowerCase());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState saving = ref.watch(orderEditProvider(widget.order.id));
    final bool full = _kept.length >= orderMaxLines;
    final TextStyle? warning = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.error);

    return PopScope(
      canPop: !saving.isBusy,
      child: Form(
        key: _form,
        // Every line is built, not only those in view, so the form checks
        // them all and a line can be brought into view.
        child: SingleChildScrollView(
          key: const ValueKey<String>('order-editor'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final _LineDraft draft in _lines)
                KeyedSubtree(
                  key: draft.card,
                  child: Card(
                    key: ValueKey<String>('edit-line-${draft.key}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            draft.name(language),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  decoration: draft.removed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          if (draft.product
                              case final CatalogProduct product) ...<Widget>[
                            Text(
                              l10n.orderAddedLine,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            PriceLine(product: product),
                          ],
                          if (draft.unavailable)
                            Text(
                              l10n.cartLineUnavailable,
                              key: ValueKey<String>(
                                'edit-unavailable-${draft.key}',
                              ),
                              style: warning,
                            ),
                          const SizedBox(height: 8),
                          if (!draft.removed)
                            LineOptionsFields(
                              unit: draft.unit,
                              quantity: draft.quantity,
                              note: draft.note,
                              quantityFocus: draft.quantityFocus,
                              noteFocus: draft.noteFocus,
                              policy: draft.policy,
                              onPolicy: (SubstitutionPolicy policy) =>
                                  setState(() => draft.policy = policy),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              key: ValueKey<String>('edit-remove-${draft.key}'),
                              icon: Icon(
                                draft.removed
                                    ? Icons.undo
                                    : Icons.remove_shopping_cart_outlined,
                              ),
                              label: Text(
                                draft.removed
                                    ? l10n.orderEditKeepLine
                                    : l10n.orderEditRemoveLine,
                              ),
                              onPressed: saving.isBusy
                                  ? null
                                  : () => _toggle(draft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>('edit-add-product'),
                icon: const Icon(Icons.add),
                label: Text(l10n.orderAddProduct),
                onPressed: saving.isBusy || full ? null : _add,
              ),
              if (full)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.orderAddFull(orderMaxLines),
                    key: const ValueKey<String>('edit-full'),
                    style: warning,
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('edit-delivery-wish'),
                controller: _wish,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.orderSectionDeliveryWish,
                  border: const OutlineInputBorder(),
                ),
                validator: (String? text) =>
                    trimLikeServer(text ?? '').runes.length > 160
                    ? l10n.fieldTooLong(160)
                    : null,
              ),
              const SizedBox(height: 16),
              if (_noneLeft)
                Text(
                  l10n.orderEditAtLeastOne,
                  key: const ValueKey<String>('edit-none-left'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                key: const ValueKey<String>('edit-save'),
                onPressed: saving.isBusy ? null : _save,
                child: saving.isBusy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: l10n.orderEditSaving,
                        ),
                      )
                    : Text(l10n.saveButton),
              ),
              FailureMessage(saving.failure),
            ],
          ),
        ),
      ),
    );
  }
}
