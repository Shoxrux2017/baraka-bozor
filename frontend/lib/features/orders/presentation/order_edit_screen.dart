import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/localization/order_labels.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/estimate_preview.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/application/card_quantity.dart';
import '../../cart/presentation/cart_line_stepper.dart';
import '../../cart/presentation/cart_line_tile.dart';
import '../../cart/presentation/cart_summary.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/quantity_sheet.dart';
import '../application/customer_orders_controllers.dart';
import '../domain/customer_orders.dart';
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
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
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

/// What the Customer sets on one line: a line already ordered, or a product
/// this edit adds.
final class _LineDraft {
  _LineDraft.ordered(CustomerOrderLine this.line)
    : product = null,
      productId = line.productId,
      unit = line.unit,
      quantity = QuantityRules.normalize(line.unit, line.quantity) ?? '',
      note = line.customerNote,
      policy = line.substitutionPolicy;

  _LineDraft.added(CatalogProduct this.product)
    : line = null,
      productId = product.id,
      unit = product.unitCode,
      quantity = '1',
      note = null,
      policy = SubstitutionPolicy.allowSimilar;

  /// The line as the editor found it, or `null` for a product this edit
  /// adds.
  final CustomerOrderLine? line;

  /// The product this edit adds, at its price now, or `null` for a line
  /// already ordered.
  final CatalogProduct? product;
  final String productId;
  final UnitCode unit;

  /// As the API takes it, or empty when the line's own quantity is one its
  /// unit no longer takes: the Customer sets it anew.
  String quantity;
  String? note;
  SubstitutionPolicy policy;
  bool removed = false;

  /// The server named the product as one the Customer can no longer order.
  bool unavailable = false;

  /// Its row, to bring into view.
  final GlobalKey card = GlobalKey();

  /// What its row and buttons are known by.
  String get key => line?.id ?? 'added-$productId';

  String name(AppLanguage language) =>
      line?.name(language) ?? product!.name(language);

  String? get imageUrl => line?.imageUrl ?? product?.imageUrl;

  /// What one unit costs: the price the order holds for a line already
  /// ordered, the product's price now for one this edit adds.
  int get unitPriceUzs =>
      line?.customerUnitPriceUzs ?? product!.customerUnitPriceUzs;

  /// Whether [quantity] is one the server would take.
  bool get quantityValid => QuantityRules.normalize(unit, quantity) != null;

  /// What the line would cost at its quantity, or `null` while that is not
  /// a quantity (`EstimatePreview`; the server prices the order).
  int? get previewUzs =>
      quantityValid ? EstimatePreview.lineUzs(unitPriceUzs, quantity) : null;

  /// Whether sending this line adds it to [order]: a product picked here, or
  /// a line the order no longer holds — taken out by a save whose answer was
  /// lost — which the server adds anew at the current price (`DL-43`).
  bool adds(CustomerOrder order) {
    final String id = productId.toLowerCase();
    return !order.openLines.any(
      (CustomerOrderLine line) => line.productId.toLowerCase() == id,
    );
  }

  OrderEditLine toEdit() {
    final String text = trimLikeServer(note ?? '');
    return OrderEditLine(
      productId: productId,
      quantity: QuantityRules.normalize(unit, quantity)!,
      customerNote: text.isEmpty ? null : text,
      substitutionPolicy: policy,
    );
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
      final _LineDraft? present = _take(adding);
      if (present != null) {
        _showPresent(present);
      }
    }
  }

  @override
  void dispose() {
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

  /// Picks a product from the catalog, which marks the products the order
  /// keeps. One already in the order is not added twice: its line is kept and
  /// brought into view, and the Customer is told.
  Future<void> _add() async {
    final Set<String> inOrder = <String>{
      for (final _LineDraft line in _kept) line.productId.toLowerCase(),
    };
    final CatalogProduct? product = await GoRouter.of(context)
        .push<CatalogProduct>(
          AppPaths.customerOrderAdd(widget.order.id),
          extra: inOrder,
        );
    if (product == null || !mounted) {
      return;
    }
    _LineDraft? present;
    setState(() => present = _take(product));
    final _LineDraft? line = present;
    if (line != null) {
      _showPresent(line);
    }
  }

  /// Tells the Customer the product is already in the order, and brings its
  /// line into view, once the line is built.
  void _showPresent(_LineDraft line) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).orderAddAlreadyIn)),
      );
      final BuildContext? card = line.card.currentContext;
      if (card != null) {
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
      } else {
        draft.removed = !draft.removed;
      }
    });
  }

  /// One step of the line's quantity; the minus at the minimum takes the
  /// line out.
  void _step(_LineDraft draft, {required bool up}) {
    final String? quantity = up
        ? CardQuantity.next(draft.unit, draft.quantity)
        : CardQuantity.previous(draft.unit, draft.quantity);
    if (quantity != null) {
      setState(() => draft.quantity = quantity);
    } else if (!up) {
      _toggle(draft);
    }
  }

  /// The line's exact quantity, from the quantity sheet.
  Future<void> _exactQuantity(_LineDraft draft) async {
    final String? quantity = await showQuantitySheet(
      context,
      unit: draft.unit,
      current: draft.quantity,
    );
    if (quantity != null && mounted) {
      setState(() => draft.quantity = quantity);
    }
  }

  /// The line's quantity, note and rule, in their sheet; what it answers is
  /// applied, anything else leaves the line as it was.
  Future<void> _options(_LineDraft draft, AppLanguage language) async {
    final OrderLineChoice? choice = await showOrderLineSheet(
      context,
      name: draft.name(language),
      unit: draft.unit,
      quantity: draft.quantity,
      note: draft.note,
      policy: draft.policy,
      onRemove: () => _toggle(draft),
      removeKey: ValueKey<String>('edit-remove-${draft.key}'),
    );
    if (choice == null || !mounted) {
      return;
    }
    setState(() {
      draft.quantity = choice.quantity;
      draft.note = choice.note;
      draft.policy = choice.policy;
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
      return;
    }
    // A quantity the line's unit no longer takes is set anew before
    // anything goes.
    final _LineDraft? unset = kept
        .where((_LineDraft line) => !line.quantityValid)
        .firstOrNull;
    if (unset != null) {
      final BuildContext? card = unset.card.currentContext;
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
      for (final _LineDraft line in kept) line.toEdit(),
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
    if (known && _changesNothing(lines, deliveryTimeNote)) {
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
    final List<_LineDraft> kept = _kept;
    final bool full = kept.length >= orderMaxLines;
    final int goods = kept.fold<int>(
      0,
      (int sum, _LineDraft line) => sum + (line.previewUzs ?? 0),
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
                    for (final _LineDraft draft in _lines)
                      KeyedSubtree(
                        key: draft.card,
                        child: _EditLine(
                          draft: draft,
                          language: language,
                          adds: !draft.removed && draft.adds(widget.order),
                          busy: saving.isBusy,
                          onOptions: () => _options(draft, language),
                          onToggle: () => _toggle(draft),
                          onStep: ({required bool up}) => _step(draft, up: up),
                          onQuantity: () => _exactQuantity(draft),
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
                              value: l10n.cartLineEstimate(
                                MoneyFormat.uzs(goods, language),
                              ),
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

/// One line of the editor (drawing 29и): picture, name, the price of a unit,
/// the rule and the note when set, and the line's preview with its stepper.
/// A line taken out is greyed and offers to come back.
class _EditLine extends StatelessWidget {
  const _EditLine({
    required this.draft,
    required this.language,
    required this.adds,
    required this.busy,
    required this.onOptions,
    required this.onToggle,
    required this.onStep,
    required this.onQuantity,
  });

  final _LineDraft draft;
  final AppLanguage language;

  /// The line adds a product to the order, rather than keeping one in it.
  final bool adds;
  final bool busy;
  final VoidCallback onOptions;
  final VoidCallback onToggle;
  final void Function({required bool up}) onStep;
  final VoidCallback onQuantity;

  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool removed = draft.removed;
    final String unit = CatalogLabels.unit(l10n, draft.unit);
    final int? preview = draft.previewUzs;
    final String? note = draft.note;
    final Widget image = ProductImage(url: draft.imageUrl, size: 44);

    final Widget picture = SizedBox.square(
      dimension: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KitColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: removed
              ? Opacity(
                  opacity: 0.4,
                  child: ColorFiltered(colorFilter: _grey, child: image),
                )
              : image,
        ),
      ),
    );

    final Widget info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          draft.name(language),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: removed ? KitColors.muted : KitColors.ink,
            decoration: removed ? TextDecoration.lineThrough : null,
          ),
        ),
        if (adds)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: DecoratedBox(
              key: ValueKey<String>('edit-adds-${draft.key}'),
              decoration: BoxDecoration(
                color: KitColors.primaryWash,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  l10n.orderEditNew,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: KitColors.primaryDark,
                  ),
                ),
              ),
            ),
          ),
        if (!removed) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            l10n.cartLineEstimate(
              l10n.catalogPricePerUnit(
                MoneyFormat.uzs(draft.unitPriceUzs, language),
                unit,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
          if (draft.policy != SubstitutionPolicy.allowSimilar)
            CartInfoRow(
              key: ValueKey<String>('line-rule-${draft.key}'),
              icon: draft.policy == SubstitutionPolicy.contactBefore
                  ? Icons.call_outlined
                  : Icons.block,
              text: OrderLabels.substitution(l10n, draft.policy),
              maxLines: 1,
            ),
          if (note != null)
            CartInfoRow(
              key: ValueKey<String>('line-note-${draft.key}'),
              icon: Icons.chat_bubble_outline,
              text: note,
              maxLines: 2,
            ),
        ],
        if (draft.unavailable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.cartLineUnavailable,
              key: ValueKey<String>('edit-unavailable-${draft.key}'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: KitColors.danger,
              ),
            ),
          ),
      ],
    );

    final Widget bottom = removed
        ? Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: ValueKey<String>('edit-remove-${draft.key}'),
              style: TextButton.styleFrom(
                foregroundColor: KitColors.primaryDark,
                minimumSize: const Size(0, 40),
              ),
              onPressed: busy ? null : onToggle,
              child: Text(
                l10n.orderEditKeepLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        : Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: preview == null
                      ? const SizedBox.shrink()
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.cartLineEstimate(
                              MoneyFormat.uzs(preview, language),
                            ),
                            key: ValueKey<String>('edit-sum-${draft.key}'),
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: KitColors.ink,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              CartLineStepper(
                id: draft.key,
                quantityText: draft.quantityValid
                    ? '${QuantityRules.display(draft.quantity)} $unit'
                    : '—',
                busy: busy,
                canStep: draft.quantityValid,
                atMinimum:
                    draft.quantityValid &&
                    CardQuantity.previous(draft.unit, draft.quantity) == null,
                onMinus: () => onStep(up: false),
                onPlus: () => onStep(up: true),
                onQuantity: onQuantity,
              ),
            ],
          );

    return DecoratedBox(
      key: ValueKey<String>('edit-line-${draft.key}'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              key: ValueKey<String>('edit-options-${draft.key}'),
              onTap: removed || busy ? null : onOptions,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  picture,
                  const SizedBox(width: 12),
                  Expanded(child: info),
                ],
              ),
            ),
            const SizedBox(height: 10),
            bottom,
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
