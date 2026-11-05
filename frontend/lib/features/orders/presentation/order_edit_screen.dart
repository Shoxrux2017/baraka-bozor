import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
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
import '../../../core/orders/order_values.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/fold.dart';
import '../../catalog/presentation/quantity_sheet.dart';
import '../application/customer_orders_controllers.dart';
import '../application/order_draft.dart';
import '../application/order_edit_summary.dart';
import '../domain/customer_orders.dart';
import 'line_flash.dart';
import 'order_edit_footer.dart';
import 'order_edit_line.dart';
import 'order_edit_locked.dart';
import 'order_edit_sheets.dart';
import 'order_edit_words.dart';
import 'order_line_sheet.dart';
import 'order_product_picker.dart';

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
  const OrderEditScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends ConsumerState<OrderEditScreen> {
  /// The ✓ «Сохранено» moment, in which the editor cannot be closed.
  final ValueNotifier<bool> _holding = ValueNotifier<bool>(false);

  /// The editor, which knows the changes that × and the system back would
  /// lose.
  final GlobalKey<_EditorState> _editor = GlobalKey<_EditorState>();

  /// The changes of the edit the server refused, as the editor gave them
  /// when the save started or the preview found the order locked: the editor
  /// may be gone before the refusal's reload is in (`DL-132`).
  List<String> _lost = const <String>[];

  /// A preview found the order locked.
  bool _previewLocked = false;

  /// The lock view's words are announced once per refusal.
  bool _announcedLock = false;

  String get orderId => widget.orderId;

  /// The editor hands over the texts of its changes: [locked] when the
  /// summary says the order is locked, otherwise as a save starts.
  void _handOver(List<String> lost, {required bool locked}) {
    _lost = lost;
    _previewLocked = locked;
    _announcedLock = false;
  }

  /// × asks the editor, which asks before losing changes; with no editor
  /// there is nothing to lose.
  void _close() {
    final _EditorState? editor = _editor.currentState;
    if (editor != null) {
      unawaited(editor.close());
    } else {
      backToOrder(GoRouter.of(context), orderId);
    }
  }

  /// Says the lock view's title and how many changes did not save, once it
  /// stands.
  void _announceLock(CustomerOrder order) {
    if (_announcedLock) {
      return;
    }
    _announcedLock = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      announce(
        context,
        l10n.orderEditLockedSpoken(lockedTitle(l10n, order), _lost.length),
      );
    });
  }

  /// An order past editing: what did not save when the Customer lost
  /// changes to the refusal, otherwise only that it can no longer change.
  Widget _lockedOrClosed(CustomerOrder order, bool locked) {
    if (!locked) {
      return _Closed(orderId: order.id);
    }
    _announceLock(order);
    return OrderEditLocked(order: order, lost: _lost);
  }

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
    final MutationState edit = ref.watch(orderEditProvider(orderId));
    final bool saving = edit.isBusy;
    // A save refused because shopping started, or a preview that found the
    // order locked, with the changes the editor handed over.
    final ApiFailure? refusal = edit.failure;
    final bool locked =
        _lost.isNotEmpty &&
        (_previewLocked ||
            (refusal is ApiRefusal && refusal.code == 'order_editing_locked'));
    if (_previewLocked && (order.value?.canEdit ?? false) && !order.isLoading) {
      _previewLocked = false;
    }
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
            onPressed: saving || holding ? null : _close,
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
                // The lock view waits for the order as the server holds it.
                AsyncValue<CustomerOrder>(isLoading: true) when locked =>
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
                  _lockedOrClosed(value, locked),
                AsyncValue<CustomerOrder>(:final CustomerOrder value) =>
                  _Editor(
                    key: _editor,
                    order: value,
                    holding: _holding,
                    onLost: _handOver,
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
          onPressed: () => backToOrder(GoRouter.of(context), orderId),
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
    required this.onLost,
    super.key,
  });

  /// The order as last loaded, which a reload replaces under the draft.
  final CustomerOrder order;

  /// Told when the ✓ «Сохранено» moment starts.
  final ValueNotifier<bool> holding;

  /// Hands the screen the texts of the changes, as a save starts and when a
  /// preview finds the order locked, for the lock view.
  final void Function(List<String> lost, {required bool locked}) onLost;

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

  /// How many times a line was flashed — red after a refused save, green when
  /// it arrived from the picker — and the colour of its last flash.
  final Map<String, int> _flashes = <String, int>{};
  final Map<String, Color> _flashColors = <String, Color>{};

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

  /// The changes the draft makes, as lines of the exit sheet and the lock
  /// view; a quantity still to be set anew is not one of them.
  List<DraftChange> _listed(OrderDraft draft) =>
      draftChanges(draft, widget.order, _wishSeen.isEmpty ? null : _wishSeen);

  List<String> _texts(OrderDraft draft) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    return <String>[
      for (final DraftChange change in _listed(draft))
        changeText(l10n, language, change),
    ];
  }

  /// × and the system back: without changes the editor goes at once; with
  /// them it asks first (`DL-132`).
  Future<void> close() async {
    if (ref.read(orderEditProvider(widget.order.id)).isBusy || _saved) {
      return;
    }
    final GoRouter router = GoRouter.of(context);
    final List<String> texts = _texts(
      ref.read(orderDraftProvider(widget.order.id)),
    );
    if (texts.isEmpty) {
      backToOrder(router, widget.order.id);
      return;
    }
    final bool leave = await showLeaveSheet(context, changes: texts);
    if (leave && mounted) {
      backToOrder(router, widget.order.id);
    }
  }

  /// Opens the picker, which adds to the draft as it stays open; on return
  /// the lines it added arrive in the list (`DL-132`). A picker closed by a
  /// lock leaves this editor gone, and nothing arrives.
  Future<void> _add() async {
    await GoRouter.of(context).push<void>(
      AppPaths.customerOrderAdd(widget.order.id),
      extra: const OrderPickerOpening(),
    );
    if (mounted) {
      _arrive(_draft.settleArrivals());
    }
  }

  /// The lines the picker added come in: the list unfolds them, scrolls to the
  /// first so that it stands a third down the view, and flashes them green; the
  /// first is said with the total through it. The flash and the scroll wait
  /// for the frame that builds the lines.
  void _arrive(List<String> keys) {
    final DraftLine? first = keys.isEmpty ? null : _lineOf(keys.first);
    if (first == null) {
      return;
    }
    _say(_quantityWords(first));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        for (final String key in keys) {
          _flashes[key] = (_flashes[key] ?? 0) + 1;
          _flashColors[key] = KitColors.lineFlash;
        }
      });
      _scrollToThird(first.key);
    });
  }

  /// Scrolls so that the top of the line stands a third down the view, in
  /// 300 ms, at once with reduced motion. The line may still be unfolding, so
  /// its top is used, not the middle of the room it takes up at this moment.
  void _scrollToThird(String key) {
    final BuildContext? card = _card(key).currentContext;
    final RenderObject? line = card?.findRenderObject();
    final ScrollableState? scrollable = card == null
        ? null
        : Scrollable.maybeOf(card);
    if (line == null || scrollable == null) {
      return;
    }
    final ScrollPosition position = scrollable.position;
    final double top = RenderAbstractViewport.of(line)
        .getOffsetToReveal(line, 0)
        .offset;
    // Not held to the extent standing now: the room grows as the line unfolds.
    final double target = math.max(
      position.minScrollExtent,
      top - position.viewportDimension / 3,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(target);
    } else {
      unawaited(
        position.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    }
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
    // The sums may already stand for these lines, as when the picker added
    // them while the editor waited underneath.
    _answered(ref.read(orderEditSummaryProvider(order.id)));
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

  /// The strip's «Убрать»: every marked line goes out, with one light buzz
  /// like every removal.
  void _removeMarked() {
    _draft.removeMarked();
    unawaited(HapticFeedback.lightImpact());
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

    // What the server said of an earlier attempt goes with it. The changes
    // go to the screen now: a refusal's reload may close this editor before
    // the answer is back here.
    _draft.setUnavailable(const <String>{});
    widget.onLost(_texts(draft), locked: false);
    final CustomerOrder? answer = await ref
        .read(orderEditProvider(widget.order.id).notifier)
        .edit(lines, deliveryTimeNote);
    if (!mounted) {
      return;
    }
    if (answer != null) {
      widget.onLost(const <String>[], locked: false);
      _saysSaved(answer, router);
      return;
    }
    final ApiFailure? failure = ref
        .read(orderEditProvider(widget.order.id))
        .failure;
    if (failure is ApiRefusal && failure.code == 'order_editing_locked') {
      return;
    }
    widget.onLost(const <String>[], locked: false);
    if (failure is! ApiRefusal) {
      return;
    }
    if (failure.code == 'product_unavailable') {
      // The products the server names as no longer orderable are marked.
      _draft.setUnavailable(_named(failure.error.details['product_ids']));
      _showMarked();
    } else if (failure.code == 'minimum_order_not_reached') {
      _refusedMinimum(failure);
    }
  }

  /// After a refusal because products are no longer sold: the first marked
  /// line is brought to a third of the view and flashes red, and the words of
  /// the strip are announced (`DL-132`).
  void _showMarked() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final List<DraftLine> marked = ref
        .read(orderDraftProvider(widget.order.id))
        .marked;
    if (marked.isEmpty) {
      return;
    }
    final DraftLine first = marked.first;
    setState(() {
      _flashes[first.key] = (_flashes[first.key] ?? 0) + 1;
      _flashColors[first.key] = KitColors.dangerWash;
    });
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? card = _card(first.key).currentContext;
      if (mounted && card != null) {
        unawaited(
          Scrollable.ensureVisible(
            card,
            alignment: 1 / 3,
            duration: duration,
            curve: Curves.easeInOut,
          ),
        );
      }
    });
    announce(
      context,
      l10n.orderEditNotSaved(
        l10n.orderEditGone(
          marked.map((DraftLine line) => line.name(language)).join(', '),
        ),
      ),
    );
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
          backToOrder(router, widget.order.id, answer);
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
    ref.listen<EditSummary>(orderEditSummaryProvider(widget.order.id), (
      EditSummary? before,
      EditSummary after,
    ) {
      if (after.locked && !(before?.locked ?? false)) {
        // The server says the order is locked: what the Customer set goes
        // to the screen before the order reloads under this editor.
        widget.onLost(
          _texts(ref.read(orderDraftProvider(widget.order.id))),
          locked: true,
        );
      }
      _answered(after);
    });
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
    final List<DraftChange> listed = _listed(draft);
    final List<DraftChange> changes = <DraftChange>[
      ...listed,
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
      // With changes the system back asks first; the save's own pop goes
      // through the router and is not held (`DL-132`).
      canPop: listed.isEmpty && !saving.isBusy && !_saved,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(close());
        }
      },
      child: Form(
        key: _form,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => Column(
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
                      _InfoBox(
                        assigned:
                            widget.order.status == OrderStatus.shoppingAssigned,
                      ),
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
                                flash: _flashes[line.key] ?? 0,
                                color:
                                    _flashColors[line.key] ??
                                    KitColors.dangerWash,
                                child: _Settling(
                                  child: OrderEditLineTile(
                                    draft: line,
                                    adds:
                                        !line.removed &&
                                        line.adds(widget.order),
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
                        onPressed: saving.isBusy || _saved || full
                            ? null
                            : _add,
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
                onRemoveMarked: _removeMarked,
                maxHeight: constraints.maxHeight * 0.45,
              ),
            ],
          ),
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
  const _InfoBox({required this.assigned});

  /// A Shopper is assigned: the box is amber and says to save at once.
  final bool assigned;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: assigned ? KitColors.warningWash : KitColors.primaryWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                assigned ? Icons.schedule : Icons.info_outline,
                size: 18,
                color: assigned ? KitColors.warningDark : KitColors.primaryDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                assigned ? l10n.orderEditInfoAssigned : l10n.orderEditInfo,
                key: const ValueKey<String>('edit-info'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
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
