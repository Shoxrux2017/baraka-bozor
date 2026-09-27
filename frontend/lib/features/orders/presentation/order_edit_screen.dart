import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';

/// The order's editor (`docs/09` section 21, `DL-43`): the lines the
/// Customer still orders, each with its quantity, note and rule and the way
/// to take it out, and the delivery wish. It sends the whole list the order
/// is to keep, and nothing when nothing changed; a line taken out is
/// dropped from the list, and at least one must stay. An order the server
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
              child: switch (order) {
                AsyncValue<CustomerOrder>(:final CustomerOrder value)
                    when !value.canEdit =>
                  _Closed(orderId: value.id),
                AsyncValue<CustomerOrder>(:final CustomerOrder value) =>
                  _Editor(key: ValueKey<String>(value.id), order: value),
                AsyncError<CustomerOrder>(:final Object error) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadFailure(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(customerOrderProvider(orderId)),
                  ),
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
          onPressed: () {
            final GoRouter router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              router.go(AppPaths.customerOrder(orderId));
            }
          },
          child: Text(l10n.orderOpen),
        ),
      ],
    );
  }
}

/// What the Customer sets on one line of the order.
final class _LineDraft {
  _LineDraft(this.line)
    : quantity = TextEditingController(
        text: editableQuantity(line.unit, line.quantity),
      ),
      note = TextEditingController(text: line.customerNote ?? ''),
      policy = line.substitutionPolicy;

  final CustomerOrderLine line;
  final TextEditingController quantity;
  final TextEditingController note;
  SubstitutionPolicy policy;
  bool removed = false;

  OrderEditLine toEdit() {
    final String text = trimLikeServer(note.text);
    return OrderEditLine(
      productId: line.productId,
      quantity: QuantityRules.normalize(line.unit, quantity.text)!,
      customerNote: text.isEmpty ? null : text,
      substitutionPolicy: policy,
    );
  }

  /// Whether the line stays as it was ordered.
  bool get unchanged {
    final OrderEditLine edit = toEdit();
    return !removed &&
        QuantityRules.thousandths(edit.quantity) ==
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
      _LineDraft(line),
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

  Future<void> _save() async {
    final List<_LineDraft> kept = _lines
        .where((_LineDraft line) => !line.removed)
        .toList();
    setState(() => _noneLeft = kept.isEmpty);
    if (kept.isEmpty || !_form.currentState!.validate()) {
      return;
    }
    final String wish = trimLikeServer(_wish.text);
    final String? deliveryTimeNote = wish.isEmpty ? null : wish;
    final NavigatorState navigator = Navigator.of(context);

    // Nothing changed: nothing is sent (`DL-28` (9)).
    if (kept.length == _lines.length &&
        kept.every((_LineDraft line) => line.unchanged) &&
        deliveryTimeNote == widget.order.deliveryTimeNote) {
      navigator.pop();
      return;
    }
    final CustomerOrder? answer = await ref
        .read(orderEditProvider(widget.order.id).notifier)
        .edit(<OrderEditLine>[
          for (final _LineDraft line in kept) line.toEdit(),
        ], deliveryTimeNote);
    if (answer != null && mounted) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState saving = ref.watch(orderEditProvider(widget.order.id));

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
                key: ValueKey<String>('edit-line-${draft.line.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        draft.line.name(language),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              decoration: draft.removed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (!draft.removed)
                        LineOptionsFields(
                          unit: draft.line.unit,
                          quantity: draft.quantity,
                          note: draft.note,
                          policy: draft.policy,
                          onPolicy: (SubstitutionPolicy policy) =>
                              setState(() => draft.policy = policy),
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          key: ValueKey<String>('edit-remove-${draft.line.id}'),
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
                              : () => setState(() {
                                  draft.removed = !draft.removed;
                                  _noneLeft = false;
                                }),
                        ),
                      ),
                    ],
                  ),
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
