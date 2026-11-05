import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/fold.dart';
import '../../cart/presentation/cart_summary.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/quantity_sheet.dart';
import '../application/customer_orders_controllers.dart';
import '../application/order_draft.dart';
import '../domain/customer_orders.dart';
import 'line_flash.dart';
import 'order_edit_line.dart';
import 'order_line_sheet.dart';

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
    final bool saving = ref.watch(orderEditProvider(orderId)).isBusy;
    final int? number = order.value?.orderNumber;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: number == null ? '' : l10n.orderEditKitTitle(number),
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const ValueKey<String>('edit-close'),
          icon: const Icon(Icons.close, color: KitColors.ink),
          tooltip: l10n.orderEditCloseSpoken,
          onPressed: saving
              ? null
              : () => _backToOrder(GoRouter.of(context), orderId),
        ),
      ),
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

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.order, this.adding, super.key});

  /// The order as last loaded, which a reload replaces under the draft.
  final CustomerOrder order;
  final CatalogProduct? adding;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _wish = TextEditingController(
    text: widget.order.deliveryTimeNote ?? '',
  );

  /// Each line's row, to bring into view.
  final Map<String, GlobalKey> _cards = <String, GlobalKey>{};
  bool _noneLeft = false;

  OrderDraftController get _draft =>
      ref.read(orderDraftProvider(widget.order.id).notifier);

  @override
  void initState() {
    super.initState();
    final CatalogProduct? adding = widget.adding;
    if (adding != null) {
      // The draft is changed after the build, not while it runs.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _take(adding);
        }
      });
    }
  }

  @override
  void dispose() {
    _wish.dispose();
    super.dispose();
  }

  GlobalKey _card(String key) => _cards.putIfAbsent(key, GlobalKey.new);

  /// Adds [product] to the draft; one the order already has is not added
  /// twice: its line is kept and brought into view, and the Customer is told.
  void _take(CatalogProduct product) {
    final String id = product.id.toLowerCase();
    final bool present = ref
        .read(orderDraftProvider(widget.order.id))
        .lines
        .any((DraftLine line) => line.productId.toLowerCase() == id);
    final DraftLine line = _draft.add(product);
    _noneLeft = false;
    if (present) {
      _showPresent(line.key);
    }
  }

  /// Picks a product from the catalog, which marks the products the order
  /// keeps.
  Future<void> _add() async {
    final Set<String> inOrder = <String>{
      for (final DraftLine line
          in ref.read(orderDraftProvider(widget.order.id)).kept)
        line.productId.toLowerCase(),
    };
    final CatalogProduct? product = await GoRouter.of(context)
        .push<CatalogProduct>(
          AppPaths.customerOrderAdd(widget.order.id),
          extra: inOrder,
        );
    if (product == null || !mounted) {
      return;
    }
    _take(product);
  }

  /// Tells the Customer the product is already in the order, and brings its
  /// line into view, once the line is built.
  void _showPresent(String key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).orderAddAlreadyIn)),
      );
      final BuildContext? card = _card(key).currentContext;
      if (card != null) {
        Scrollable.ensureVisible(card);
      }
    });
  }

  /// Takes a line out, with a light buzz, and says so.
  void _remove(DraftLine line) {
    _draft.remove(line.key);
    unawaited(HapticFeedback.lightImpact());
    announce(
      context,
      AppLocalizations.of(context)
          .orderEditRemoved(line.name(interfaceLanguage(context))),
    );
  }

  /// Keeps a line again, and says so.
  void _restore(DraftLine line) {
    _draft.restore(line.key);
    announce(
      context,
      AppLocalizations.of(context)
          .orderEditRestored(line.name(interfaceLanguage(context))),
    );
  }

  /// The line's exact quantity, from the quantity sheet.
  Future<void> _exactQuantity(DraftLine line) async {
    final String? quantity = await showQuantitySheet(
      context,
      unit: line.unit,
      current: line.quantity,
      name: line.name(interfaceLanguage(context)),
      unitPriceUzs: line.unitPriceUzs,
    );
    if (quantity != null && mounted) {
      _draft.setQuantity(line.key, quantity);
    }
  }

  /// The line's quantity, note and rule, in their sheet; what it answers is
  /// applied, anything else leaves the line as it was.
  Future<void> _options(DraftLine line, AppLanguage language) async {
    final OrderLineChoice? choice = await showOrderLineSheet(
      context,
      name: line.name(language),
      unit: line.unit,
      quantity: line.quantity,
      note: line.note,
      policy: line.policy,
      onRemove: () => _remove(line),
      removeKey: ValueKey<String>('edit-remove-${line.key}'),
    );
    if (choice == null || !mounted) {
      return;
    }
    _draft.setOptions(line.key, choice);
  }

  Future<void> _save() async {
    final OrderDraft draft = ref.read(orderDraftProvider(widget.order.id));
    final List<DraftLine> kept = draft.kept;
    setState(() => _noneLeft = kept.isEmpty);
    if (kept.isEmpty || kept.length > orderMaxLines) {
      return;
    }
    if (!_form.currentState!.validate()) {
      return;
    }
    // A quantity the line's unit no longer takes is set anew before
    // anything goes.
    final DraftLine? unset = kept
        .where((DraftLine line) => !line.quantityValid)
        .firstOrNull;
    if (unset != null) {
      final BuildContext? card = _card(unset.key).currentContext;
      if (card != null) {
        await Scrollable.ensureVisible(card);
      }
      if (mounted) {
        await _exactQuantity(unset);
      }
      return;
    }
    // The keyboard goes while the edit is sent.
    FocusScope.of(context).unfocus();
    final List<OrderEditLine> lines = <OrderEditLine>[
      for (final DraftLine line in kept) line.toEdit(),
    ];
    final String wish = trimLikeServer(_wish.text);
    final String? deliveryTimeNote = wish.isEmpty ? null : wish;
    final GoRouter router = GoRouter.of(context);

    // Nothing to change: nothing is sent (`DL-28` (9)). While the order
    // loads again it is not yet known what it holds, and the edit goes: the
    // server answers a list that changes nothing as it is (`DL-37` (9)).
    final bool known = !ref
        .read(customerOrderProvider(widget.order.id))
        .isLoading;
    if (known && draftChanges(draft, widget.order, deliveryTimeNote).isEmpty) {
      _backToOrder(router, widget.order.id);
      return;
    }
    // What the server said of an earlier attempt goes with it.
    _draft.setUnavailable(const <String>{});
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
      _draft.setUnavailable(<String>{
        if (named is List<Object?>)
          for (final Object? id in named)
            if (id is String) id.toLowerCase(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState saving = ref.watch(orderEditProvider(widget.order.id));
    final OrderDraft draft = ref.watch(orderDraftProvider(widget.order.id));
    // The warning under the lines goes with the next change of the draft.
    ref.listen<OrderDraft>(orderDraftProvider(widget.order.id), (
      OrderDraft? before,
      OrderDraft after,
    ) {
      if (_noneLeft && before?.version != after.version) {
        setState(() => _noneLeft = false);
      }
    });
    final List<DraftLine> kept = draft.kept;
    final bool full = kept.length >= orderMaxLines;
    // A line without a quantity has no preview: no sum stands for the goods.
    final bool countable = kept.every(
      (DraftLine line) => line.previewUzs != null,
    );
    final int goods = kept.fold<int>(
      0,
      (int sum, DraftLine line) => sum + (line.previewUzs ?? 0),
    );
    const TextStyle warning = TextStyle(fontSize: 12, color: KitColors.danger);

    return PopScope(
      canPop: !saving.isBusy,
      child: Form(
        key: _form,
        child: Column(
          children: <Widget>[
            Expanded(
              // Every line is built, not only those in view, so the form
              // checks them all and a line can be brought into view.
              child: SingleChildScrollView(
                key: const ValueKey<String>('order-editor'),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _InfoBox(),
                    const SizedBox(height: 8),
                    FoldingColumn<DraftLine>(
                      items: <DraftLine>[
                        for (final DraftLine line in draft.lines)
                          if (!draft.arriving.contains(line.key)) line,
                      ],
                      keyOf: (DraftLine line) => line.key,
                      itemBuilder: (BuildContext context, DraftLine line) =>
                          KeyedSubtree(
                            key: _card(line.key),
                            child: LineFlash(
                              flash: 0,
                              child: _Settling(
                                child: OrderEditLineTile(
                                  draft: line,
                                  adds:
                                      !line.removed && line.adds(widget.order),
                                  busy: saving.isBusy,
                                  onStep: ({required bool up}) =>
                                      _draft.step(line.key, up: up),
                                  onQuantity: () => _exactQuantity(line),
                                  onOptions: () => _options(line, language),
                                  onRemove: () => _remove(line),
                                  onRestore: () => _restore(line),
                                ),
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const ValueKey<String>('edit-add-product'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KitColors.primaryDark,
                        side: const BorderSide(
                          color: KitColors.primary,
                          width: 1.5,
                        ),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        l10n.orderAddProduct,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: saving.isBusy || full ? null : _add,
                    ),
                    if (full)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l10n.orderAddFull(orderMaxLines),
                          key: const ValueKey<String>('edit-full'),
                          style: warning,
                        ),
                      ),
                    const SizedBox(height: 20),
                    _WishField(controller: _wish),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: KitColors.line)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SummaryAmountRow(
                              valueKey: 'edit-goods',
                              label: l10n.cartGoods(kept.length),
                              value: countable
                                  ? l10n.cartLineEstimate(
                                      MoneyFormat.uzs(goods, language),
                                    )
                                  : '—',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.orderEditRecount,
                              key: const ValueKey<String>('edit-recount'),
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: KitColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: KitColors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_noneLeft)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.orderEditAtLeastOne,
                          key: const ValueKey<String>('edit-none-left'),
                          style: warning,
                        ),
                      ),
                    if (saving.failure != null) ...<Widget>[
                      FailureMessage(saving.failure),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      key: const ValueKey<String>('edit-save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: KitColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving.isBusy ? null : _save,
                      child: saving.isBusy
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                                semanticsLabel: l10n.orderEditSaving,
                              ),
                            )
                          : Text(
                              l10n.saveButton,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
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
}

/// Lets a line's height move to its new size in 260 ms
/// `Cubic(0.2, 0.8, 0.2, 1)` when it is taken out or brought back; with
/// reduced motion it takes the size at once (`DL-132`).
class _Settling extends StatelessWidget {
  const _Settling({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(0.2, 0.8, 0.2, 1),
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// What the Customer may change, and that the prices of what is already in
/// the order stay.
class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KitColors.primaryWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: KitColors.primaryDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).orderEditInfo,
                key: const ValueKey<String>('edit-info'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: KitColors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The delivery wish: up to 160 characters, counted as the server counts
/// them.
class _WishField extends StatelessWidget {
  const _WishField({required this.controller});

  final TextEditingController controller;

  static const int _max = 160;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    const OutlineInputBorder none = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.checkoutWishLabel,
          style: const TextStyle(fontSize: 12, color: KitColors.muted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const ValueKey<String>('edit-delivery-wish'),
          controller: controller,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: KitColors.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: KitColors.field,
            border: none,
            enabledBorder: none,
            disabledBorder: none,
            focusedBorder: none,
            errorBorder: none,
            focusedErrorBorder: none,
            contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            counter: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (BuildContext context, TextEditingValue value, _) =>
                  Text(
                    '${trimLikeServer(value.text).runes.length} / $_max',
                    style: const TextStyle(
                      fontSize: 11,
                      color: KitColors.muted,
                    ),
                  ),
            ),
          ),
          validator: (String? text) =>
              trimLikeServer(text ?? '').runes.length > _max
              ? l10n.fieldTooLong(_max)
              : null,
        ),
      ],
    );
  }
}
