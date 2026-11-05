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
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/fold.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/quantity_sheet.dart';
import '../application/customer_orders_controllers.dart';
import '../application/order_draft.dart';
import '../application/order_edit_summary.dart';
import '../domain/customer_orders.dart';
import 'line_flash.dart';
import 'order_edit_footer.dart';
import 'order_edit_line.dart';
import 'order_edit_words.dart';
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
class OrderEditScreen extends ConsumerStatefulWidget {
  const OrderEditScreen({required this.orderId, this.adding, super.key});

  final String orderId;

  /// A product picked before the editor was open, to add at once.
  final CatalogProduct? adding;

  @override
  ConsumerState<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends ConsumerState<OrderEditScreen> {
  /// The ✓ «Сохранено» moment, in which the editor cannot be closed.
  final ValueNotifier<bool> _holding = ValueNotifier<bool>(false);

  String get orderId => widget.orderId;

  @override
  void dispose() {
    _holding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        leading: ValueListenableBuilder<bool>(
          valueListenable: _holding,
          builder: (BuildContext context, bool holding, _) => IconButton(
            key: const ValueKey<String>('edit-close'),
            icon: const Icon(Icons.close, color: KitColors.ink),
            tooltip: l10n.orderEditCloseSpoken,
            onPressed: saving || holding
                ? null
                : () => _backToOrder(GoRouter.of(context), orderId),
          ),
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
                    adding: widget.adding,
                    holding: _holding,
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
/// over it, with the order [saved] for its banner, to it when the editor was
/// opened by its address alone, with no banner (`DL-132`).
void _backToOrder(GoRouter router, String orderId, [CustomerOrder? saved]) {
  if (router.canPop()) {
    router.pop(saved);
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
  const _Editor({
    required this.order,
    required this.holding,
    this.adding,
    super.key,
  });

  /// The order as last loaded, which a reload replaces under the draft.
  final CustomerOrder order;
  final CatalogProduct? adding;

  /// Told when the ✓ «Сохранено» moment starts.
  final ValueNotifier<bool> holding;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _wish = TextEditingController(
    text: widget.order.deliveryTimeNote ?? '',
  );

  /// Each line's row, to bring into view.
  final Map<String, GlobalKey> _cards = <String, GlobalKey>{};

  /// The ✓ «Сохранено» moment: it stands 650 ms, then the editor returns.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _saved = false;

  /// The wish as the server would keep it, to count it among the changes.
  String _wishSeen = '';

  /// What the latest change says, until the preview of its sums answers; a
  /// later change replaces it (`DL-132`).
  String? _waiting;

  OrderDraftController get _draft =>
      ref.read(orderDraftProvider(widget.order.id).notifier);

  @override
  void initState() {
    super.initState();
    _wishSeen = trimLikeServer(_wish.text);
    _wish.addListener(_wishChanged);
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
    _wish.removeListener(_wishChanged);
    _wish.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _wishChanged() {
    final String now = trimLikeServer(_wish.text);
    if (now != _wishSeen) {
      setState(() => _wishSeen = now);
    }
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

  /// Says [words] with the total the lines now come to. A change that
  /// brings the lines back to the order's own needs no preview and is said
  /// at once, with the order's total; any other waits for the next answer of
  /// the sums, and a later change replaces what still waits.
  void _say(String words) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CustomerOrder order = widget.order;
    if (!linesChange(ref.read(orderDraftProvider(order.id)), order)) {
      _waiting = null;
      final OrderEditPreview own = OrderEditPreview.ofOrder(order);
      announce(
        context,
        l10n.orderEditTotalSpoken(
          words,
          totalWords(l10n, language, own.totalKind, own.totalUzs),
        ),
      );
      return;
    }
    _waiting = words;
  }

  /// The words waiting go out once the sums are known; after a failed
  /// preview the change is said alone.
  void _answered(EditSummary summary) {
    final String? words = _waiting;
    if (words == null || summary.waiting) {
      return;
    }
    _waiting = null;
    if (summary.locked) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    announce(
      context,
      summary.failed
          ? words
          : l10n.orderEditTotalSpoken(
              words,
              totalWords(
                l10n,
                interfaceLanguage(context),
                summary.shown.totalKind,
                summary.shown.totalUzs,
              ),
            ),
    );
  }

  DraftLine? _lineOf(String key) {
    for (final DraftLine line
        in ref.read(orderDraftProvider(widget.order.id)).lines) {
      if (line.key == key) {
        return line;
      }
    }
    return null;
  }

  /// «Помидоры, 3 кг».
  String _quantityWords(DraftLine line) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return '${line.name(interfaceLanguage(context))}, '
        '${quantityWords(l10n, line.unit, line.quantity)}';
  }

  /// Says the line's new quantity when [before] differs from it.
  void _sayQuantity(DraftLine before) {
    final DraftLine? now = _lineOf(before.key);
    if (now != null && !now.removed && now.quantity != before.quantity) {
      _say(_quantityWords(now));
    }
  }

  /// One step of the line's quantity.
  void _step(DraftLine line, {required bool up}) {
    _draft.step(line.key, up: up);
    _sayQuantity(line);
  }

  /// Takes a line out, with a light buzz, and says so.
  void _remove(DraftLine line) {
    _draft.remove(line.key);
    unawaited(HapticFeedback.lightImpact());
    _say(
      AppLocalizations.of(context)
          .orderEditRemoved(line.name(interfaceLanguage(context))),
    );
  }

  /// Keeps a line again, and says so.
  void _restore(DraftLine line) {
    _draft.restore(line.key);
    _say(
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
      _sayQuantity(line);
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
    _sayQuantity(line);
  }

  Future<void> _save() async {
    final OrderDraft draft = ref.read(orderDraftProvider(widget.order.id));
    final List<DraftLine> kept = draft.kept;
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

    // What the server said of an earlier attempt goes with it.
    _draft.setUnavailable(const <String>{});
    final CustomerOrder? answer = await ref
        .read(orderEditProvider(widget.order.id).notifier)
        .edit(lines, deliveryTimeNote);
    if (!mounted) {
      return;
    }
    if (answer != null) {
      _saysSaved(answer, router);
      return;
    }
    final ApiFailure? failure = ref
        .read(orderEditProvider(widget.order.id))
        .failure;
    if (failure is! ApiRefusal) {
      return;
    }
    if (failure.code == 'product_unavailable') {
      // The products the server names as no longer orderable are marked.
      _draft.setUnavailable(_named(failure.error.details['product_ids']));
    } else if (failure.code == 'minimum_order_not_reached') {
      _refusedMinimum(failure);
    }
  }

  /// ✓ «Сохранено»: a light buzz, the new total said, and 650 ms later the
  /// editor goes back to the order with the order saved.
  void _saysSaved(CustomerOrder answer, GoRouter router) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() => _saved = true);
    widget.holding.value = true;
    _waiting = null;
    unawaited(HapticFeedback.lightImpact());
    final int? total = answer.totalUzs;
    announce(
      context,
      total == null
          ? l10n.orderEditSaved
          : l10n.orderEditedSpoken(
              totalWords(
                l10n,
                interfaceLanguage(context),
                answer.totalKind,
                total,
              ),
            ),
    );
    _hold
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          _backToOrder(router, widget.order.id, answer);
        }
      })
      ..forward();
  }

  /// A save refused for the minimum: the strip says by how much, from the
  /// refusal's own details, and the words are announced.
  void _refusedMinimum(ApiRefusal failure) {
    final Object? minimum = failure.error.details['minimum_order_uzs'];
    final Object? shortfall = failure.error.details['shortfall_uzs'];
    if (minimum is! int || shortfall is! int) {
      return;
    }
    ref
        .read(orderEditSummaryProvider(widget.order.id).notifier)
        .refusedMinimum(minimumUzs: minimum, shortfallUzs: shortfall);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    announce(
      context,
      l10n.orderEditNotSaved(
        l10n.orderEditMinimum(
          MoneyFormat.uzs(minimum, language),
          MoneyFormat.uzs(shortfall, language),
        ),
      ),
    );
  }

  /// The product ids of a refusal's details, in lower case.
  Set<String> _named(Object? ids) => <String>{
    if (ids is List<Object?>)
      for (final Object? id in ids)
        if (id is String) id.toLowerCase(),
  };

  /// The failure of the last save worth a red line over the button: not a
  /// minimum the strip already says.
  ApiFailure? _lineFailure(ApiFailure? failure) {
    if (failure is ApiRefusal &&
        failure.code == 'minimum_order_not_reached' &&
        failure.error.details['minimum_order_uzs'] is int &&
        failure.error.details['shortfall_uzs'] is int) {
      return null;
    }
    return failure;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState saving = ref.watch(orderEditProvider(widget.order.id));
    final OrderDraft draft = ref.watch(orderDraftProvider(widget.order.id));
    final EditSummary answered = ref.watch(
      orderEditSummaryProvider(widget.order.id),
    );
    ref.listen<EditSummary>(
      orderEditSummaryProvider(widget.order.id),
      (EditSummary? _, EditSummary after) => _answered(after),
    );
    final List<DraftLine> kept = draft.kept;
    final bool full = kept.length >= orderMaxLines;
    // A line without a quantity has no preview: no sums stand for the lines.
    final bool countable =
        kept.isNotEmpty &&
        kept.every((DraftLine line) => line.previewUzs != null);
    final EditSummary summary = countable
        ? answered
        : answered.copyWith(failed: true);
    // A quantity to be set anew is a change to make before saving.
    final List<DraftChange> changes = <DraftChange>[
      ...draftChanges(
        draft,
        widget.order,
        _wishSeen.isEmpty ? null : _wishSeen,
      ),
      for (final DraftLine line in kept)
        if (!line.quantityValid)
          (
            kind: DraftChangeKind.quantity,
            nameUz: line.name(AppLanguage.uz),
            nameRu: line.name(AppLanguage.ru),
            unit: line.unit,
            from: line.line?.quantity,
            to: null,
            rule: null,
          ),
    ];
    final bool orderKnown = !ref
        .watch(customerOrderProvider(widget.order.id))
        .isLoading;
    const TextStyle warning = TextStyle(fontSize: 12, color: KitColors.danger);

    return PopScope(
      canPop: !saving.isBusy && !_saved,
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
                                  busy: saving.isBusy || _saved,
                                  onStep: ({required bool up}) =>
                                      _step(line, up: up),
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
                      onPressed: saving.isBusy || _saved || full ? null : _add,
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
                    OrderEditTotals(keptCount: kept.length, summary: summary),
                  ],
                ),
              ),
            ),
            OrderEditFooter(
              order: widget.order,
              draft: draft,
              summary: summary,
              changes: changes,
              saving: saving.isBusy,
              saved: _saved,
              orderKnown: orderKnown,
              failure: _lineFailure(saving.failure),
              onSave: _save,
              onAdd: _add,
              onRemoveMarked: _draft.removeMarked,
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
