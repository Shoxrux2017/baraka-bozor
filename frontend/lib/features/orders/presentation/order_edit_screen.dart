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
/// keep, and nothing when nothing changed; a line taken out is dropped from
/// the list, and at least one must stay, at most [orderMaxLines]. An order the server
/// no longer lets change (`can_edit`) is not edited: after a refusal the
/// order loads again and the editor gives way to saying so.
class OrderEditScreen extends ConsumerWidget {
  const OrderEditScreen({required this.orderId, super.key});

  final String orderId;

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
                  _Editor(key: ValueKey<String>(value.id), order: value),
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

  /// The line as ordered, or `null` for a product this edit adds.
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

  /// What its card and buttons are known by.
  String get key => line?.id ?? 'added-$productId';

  String name(AppLanguage language) =>
      line?.name(language) ?? product!.name(language);

  OrderEditLine toEdit() {
    final String text = trimLikeServer(note.text);
    return OrderEditLine(
      productId: productId,
      quantity: QuantityRules.normalize(unit, quantity.text)!,
      customerNote: text.isEmpty ? null : text,
      substitutionPolicy: policy,
    );
  }

  /// Whether the line stays as it was ordered; an added product never does.
  bool get unchanged {
    final CustomerOrderLine? line = this.line;
    if (line == null || removed) {
      return false;
    }
    final OrderEditLine edit = toEdit();
    return QuantityRules.thousandths(edit.quantity) ==
            QuantityRules.thousandths(line.quantity) &&
        edit.customerNote == line.customerNote &&
        edit.substitutionPolicy == line.substitutionPolicy;
  }

  void dispose() {
    quantity.dispose();
    note.dispose();
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.order, super.key});

  final CustomerOrder order;

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
  void dispose() {
    for (final _LineDraft line in _lines) {
      line.dispose();
    }
    _wish.dispose();
    super.dispose();
  }

  List<_LineDraft> get _kept =>
      _lines.where((_LineDraft line) => !line.removed).toList();

  /// Picks a product from the catalog. One already in the order is not added
  /// twice: its line is kept, and the Customer is told.
  Future<void> _add() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CatalogProduct? product = await GoRouter.of(context)
        .push<CatalogProduct>(AppPaths.customerOrderAdd(widget.order.id));
    if (product == null || !mounted) {
      return;
    }
    final String id = product.id.toLowerCase();
    final _LineDraft? present = _lines
        .where((_LineDraft line) => line.productId.toLowerCase() == id)
        .firstOrNull;
    setState(() {
      _noneLeft = false;
      if (present == null) {
        _lines.add(_LineDraft.added(product));
      } else {
        present.removed = false;
      }
    });
    if (present != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.orderAddAlreadyIn)));
    }
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

  Future<void> _save() async {
    final List<_LineDraft> kept = _kept;
    setState(() {
      _noneLeft = kept.isEmpty;
      for (final _LineDraft line in _lines) {
        line.unavailable = false;
      }
    });
    if (kept.isEmpty ||
        kept.length > orderMaxLines ||
        !_form.currentState!.validate()) {
      return;
    }
    final String wish = trimLikeServer(_wish.text);
    final String? deliveryTimeNote = wish.isEmpty ? null : wish;
    final GoRouter router = GoRouter.of(context);

    // Nothing changed: nothing is sent (`DL-28` (9)).
    if (kept.length == _lines.length &&
        kept.every((_LineDraft line) => line.unchanged) &&
        deliveryTimeNote == widget.order.deliveryTimeNote) {
      _backToOrder(router, widget.order.id);
      return;
    }
    final OrderEditController editing = ref.read(
      orderEditProvider(widget.order.id).notifier,
    );
    final CustomerOrder? answer = await editing.edit(<OrderEditLine>[
      for (final _LineDraft line in kept) line.toEdit(),
    ], deliveryTimeNote);
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
        child: ListView(
          key: const ValueKey<String>('order-editor'),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            for (final _LineDraft draft in _lines)
              Card(
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
    );
  }
}
