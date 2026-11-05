import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/state/loaded.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/product_image.dart';
import '../../cart/application/card_quantity.dart';
import '../../catalog/application/catalog_controllers.dart';
import '../../catalog/domain/catalog.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../catalog/presentation/category_tile.dart';
import '../../catalog/presentation/search_screen.dart';
import '../application/customer_orders_controllers.dart';
import '../application/order_draft.dart';
import '../domain/customer_orders.dart';
import 'order_edit_words.dart';

/// What the editor hands the picker when it opens it. A picker opened by its
/// address alone has no editor to add to, and its route sends it to the
/// order's editor (`DL-132`).
final class OrderPickerOpening {
  const OrderPickerOpening();
}

/// Adds products to an order's draft (`docs/03` section 11, `DL-52`,
/// `DL-132`): photo tiles for the sections or a search over the whole catalog,
/// and for every product a plus that grows into a stepper in the row. It stays
/// open as products are added; a bar counts what this visit added and «Готово»
/// returns to the editor, which brings the new lines in.
class OrderProductPickerScreen extends ConsumerStatefulWidget {
  const OrderProductPickerScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderProductPickerScreen> createState() =>
      _OrderProductPickerScreenState();
}

class _OrderProductPickerScreenState
    extends ConsumerState<OrderProductPickerScreen> {
  static const OutlineInputBorder _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide.none,
  );

  final TextEditingController _search = TextEditingController();
  Timer? _pause;
  String _query = '';
  CatalogCategory? _category;

  OrderDraftController get _draft =>
      ref.read(orderDraftProvider(widget.orderId).notifier);

  @override
  void dispose() {
    _pause?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onTyped(String text) {
    _pause?.cancel();
    _pause = Timer(SearchScreen.searchPause, () {
      if (mounted) {
        setState(() => _query = ProductListQuery.searchOf(text));
      }
    });
  }

  void _clear() {
    _pause?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  /// The lines this visit added and the order still keeps.
  List<DraftLine> _added(OrderDraft draft) => <DraftLine>[
    for (final DraftLine line in draft.kept)
      if (draft.arriving.contains(line.key)) line,
  ];

  /// Adds [product] to the draft as a line arriving in the editor, with a
  /// light buzz, and says so.
  void _pick(CatalogProduct product) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final DraftLine line = _draft.add(product, arriving: true);
    unawaited(HapticFeedback.lightImpact());
    announce(
      context,
      l10n.orderPickAddedSpoken(
        line.name(language),
        quantityWords(l10n, line.unit, line.quantity),
        _added(ref.read(orderDraftProvider(widget.orderId))).length,
      ),
    );
  }

  /// One step of a line's quantity; the bin at the minimum takes it out.
  void _step(DraftLine line, {required bool up}) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = line.name(interfaceLanguage(context));
    _draft.step(line.key, up: up);
    DraftLine? now;
    for (final DraftLine other
        in ref.read(orderDraftProvider(widget.orderId)).lines) {
      if (other.key == line.key) {
        now = other;
      }
    }
    if (now == null || now.removed) {
      announce(context, l10n.orderEditRemoved(name));
    } else if (now.quantity != line.quantity) {
      announce(
        context,
        '$name, ${quantityWords(l10n, now.unit, now.quantity)}',
      );
    }
  }

  /// The order loaded as no longer editable: there is nothing to add to.
  void _closeOnLock(AsyncValue<CustomerOrder> order) {
    final CustomerOrder? value = order.value;
    if (value == null || value.canEdit || order.isLoading) {
      return;
    }
    final GoRouter router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    }
  }

  void _done() => GoRouter.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OrderDraft draft = ref.watch(orderDraftProvider(widget.orderId));
    ref.listen<AsyncValue<CustomerOrder>>(
      customerOrderProvider(widget.orderId),
      (AsyncValue<CustomerOrder>? _, AsyncValue<CustomerOrder> after) =>
          _closeOnLock(after),
    );
    // A search looks through the whole catalog, as the catalog's does; the
    // section chosen comes back once the search is cleared.
    final CatalogCategory? category = _query.isEmpty ? _category : null;
    final Map<String, DraftLine> inOrder = <String, DraftLine>{
      for (final DraftLine line in draft.kept)
        line.productId.toLowerCase(): line,
    };
    final List<DraftLine> added = _added(draft);
    final bool full = draft.kept.length >= orderMaxLines;

    return PopScope(
      // Back from a section's products returns to the tiles.
      canPop: category == null,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          setState(() => _category = null);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: kitAppBar(title: l10n.orderAddTitle),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ActiveModeBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  key: const ValueKey<String>('pick-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(
                      ProductListQuery.searchMaxLength,
                    ),
                  ],
                  style: const TextStyle(fontSize: 14, color: KitColors.ink),
                  decoration: InputDecoration(
                    hintText: l10n.catalogSearchHint,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: KitColors.muted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: KitColors.muted,
                    ),
                    suffixIcon: _query.isEmpty && _search.text.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey<String>('pick-search-clear'),
                            icon: const Icon(Icons.clear),
                            tooltip: l10n.catalogSearchClear,
                            onPressed: _clear,
                          ),
                    filled: true,
                    fillColor: KitColors.field,
                    border: _fieldBorder,
                    enabledBorder: _fieldBorder,
                    focusedBorder: _fieldBorder,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onTyped,
                ),
              ),
              if (category != null)
                _Crumb(
                  category: category,
                  onBack: () => setState(() => _category = null),
                ),
              Expanded(
                child: _query.isEmpty && category == null
                    ? _PickTiles(
                        onPick: (CatalogCategory picked) =>
                            setState(() => _category = picked),
                      )
                    : ProductList(
                        query: ProductListQuery(
                          categoryId: category?.id,
                          search: _query,
                        ),
                        itemBuilder:
                            (BuildContext context, CatalogProduct product) {
                              final DraftLine? line =
                                  inOrder[product.id.toLowerCase()];
                              return _PickRow(
                                key: ValueKey<String>('pick-row-${product.id}'),
                                product: product,
                                line: line,
                                justAdded:
                                    line != null &&
                                    draft.arriving.contains(line.key),
                                full: full,
                                onAdd: () => _pick(product),
                                onStep: (bool up) => _step(line!, up: up),
                              );
                            },
                      ),
              ),
              if (added.isNotEmpty)
                _PickBar(
                  count: added.length,
                  sumUzs: added.fold<int>(
                    0,
                    (int sum, DraftLine line) => sum + (line.previewUzs ?? 0),
                  ),
                  full: full,
                  onDone: _done,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «‹ Все разделы» and the name of the section open, which stand one over the
/// other at large text.
class _Crumb extends StatelessWidget {
  const _Crumb({required this.category, required this.onBack});

  final CatalogCategory category;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool stacked =
        textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3;
    final Widget back = InkWell(
      key: const ValueKey<String>('pick-all-sections'),
      borderRadius: BorderRadius.circular(12),
      onTap: onBack,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.chevron_left,
                size: 22,
                color: KitColors.primaryDark,
              ),
              Flexible(
                child: Text(
                  l10n.orderPickAllSections,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KitColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final Widget name = Text(
      category.name(interfaceLanguage(context)),
      key: const ValueKey<String>('pick-crumb-name'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: KitColors.ink,
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 20, 6),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[back, name],
            )
          : Row(
              children: <Widget>[
                Flexible(child: back),
                const SizedBox(width: 6),
                Expanded(child: name),
              ],
            ),
    );
  }
}

/// The catalog's sections as photo tiles, in two columns, or one at large
/// text, to choose one to pick from.
class _PickTiles extends ConsumerWidget {
  const _PickTiles({required this.onPick});

  final ValueChanged<CatalogCategory> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Loaded<List<CatalogCategory>>> sections = ref.watch(
      catalogCategoriesProvider,
    );
    // The categories kept from the last load stand when a refresh failed.
    return switch (sections.value?.data) {
      final List<CatalogCategory> categories =>
        categories.isEmpty
            ? Center(child: Text(l10n.catalogNoProducts))
            : _tiles(context, categories),
      null => switch (sections) {
        AsyncError<Loaded<List<CatalogCategory>>>(:final Object error) =>
          Padding(
            padding: const EdgeInsets.all(16),
            child: LoadFailure(
              error: error,
              onRetry: () => ref.invalidate(catalogCategoriesProvider),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    };
  }

  Widget _tiles(BuildContext context, List<CatalogCategory> categories) {
    final int columns = textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3
        ? 1
        : 2;
    return ListView(
      key: const ValueKey<String>('pick-tiles'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      children: <Widget>[
        for (int start = 0; start < categories.length; start += columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < columns; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: start + i < categories.length
                          ? _PickTile(
                              category: categories[start + i],
                              onTap: () => onPick(categories[start + i]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One section: its name at the top start and its picture at the bottom end.
class _PickTile extends StatelessWidget {
  const _PickTile({required this.category, required this.onTap});

  final CatalogCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = category.name(interfaceLanguage(context));
    return Semantics(
      button: true,
      label: l10n.orderPickSection(name),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: KitColors.chip,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('pick-section-${category.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 118),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.bottomEnd,
                    child: CategoryPictureWell(
                      category: category,
                      size: 60,
                      radius: 14,
                      pictureSize: 60,
                      color: category.imageUrl == null
                          ? null
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One product to pick: picture, name, the price and its unit, a tag when it is
/// in the order, and at the end the round plus, which grows into the stepper
/// (124 × 44) once the product is in the order. At large text the stepper
/// takes the row's width under the words. The row picks the product when it is
/// not in the order.
class _PickRow extends StatefulWidget {
  const _PickRow({
    required this.product,
    required this.line,
    required this.justAdded,
    required this.full,
    required this.onAdd,
    required this.onStep,
    super.key,
  });

  final CatalogProduct product;

  /// The order's line for the product, or `null` when it is not in the order.
  final DraftLine? line;

  /// The line was added in this visit.
  final bool justAdded;

  /// The order already holds its most lines.
  final bool full;
  final VoidCallback onAdd;
  final void Function(bool up) onStep;

  @override
  State<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends State<_PickRow>
    with SingleTickerProviderStateMixin {
  static const Cubic _grow = Cubic(0.2, 0.8, 0.2, 1);

  /// The plus growing into the stepper: 260 ms for the width, the contents
  /// fading in over 200 ms after 80 (a 180 ms fade with reduced motion).
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );

  @override
  void didUpdateWidget(_PickRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line == null && widget.line != null) {
      _morph.duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 180 : 280,
      );
      _morph.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  Widget _stepper(DraftLine line, {required bool expanded}) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool atMinimum =
        line.quantityValid &&
        CardQuantity.previous(line.unit, line.quantity) == null;
    final Widget content = Row(
      children: <Widget>[
        _StepButton(
          buttonKey: ValueKey<String>('pick-minus-${widget.product.id}'),
          icon: atMinimum ? Icons.delete_outline : Icons.remove,
          tooltip: atMinimum ? l10n.orderEditRemoveShort : l10n.cartStepMinus,
          onPressed: () => widget.onStep(false),
        ),
        Expanded(
          child: ExcludeSemantics(
            child: Text(
              quantityWords(l10n, line.unit, line.quantity),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        _StepButton(
          buttonKey: ValueKey<String>('pick-plus-${widget.product.id}'),
          icon: Icons.add,
          tooltip: l10n.cartStepPlus,
          onPressed: () => widget.onStep(true),
        ),
      ],
    );
    return AnimatedBuilder(
      animation: _morph,
      builder: (BuildContext context, Widget? _) {
        final bool reduced = MediaQuery.disableAnimationsOf(context);
        final double t = _morph.value;
        final double growth = reduced || expanded
            ? 1
            : _grow.transform(math.min(1, t * 280 / 260));
        final double fade = reduced
            ? Curves.easeOut.transform(t)
            : const Interval(80 / 280, 1).transform(t);
        return SizedBox(
          key: ValueKey<String>('pick-step-${widget.product.id}'),
          width: expanded ? double.infinity : 44 + 80 * growth,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: KitColors.primary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: expanded
                  ? Opacity(opacity: fade, child: content)
                  : OverflowBox(
                      minWidth: 124,
                      maxWidth: 124,
                      child: Opacity(opacity: fade, child: content),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _plus() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = widget.product.name(interfaceLanguage(context));
    return IconButton(
      key: ValueKey<String>('pick-${widget.product.id}'),
      tooltip: l10n.orderPickAdd(name),
      iconSize: 22,
      style: IconButton.styleFrom(
        backgroundColor: KitColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: KitColors.buttonOff,
        disabledForegroundColor: KitColors.muted,
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.add),
      onPressed: widget.full ? null : widget.onAdd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final CatalogProduct product = widget.product;
    final DraftLine? line = widget.line;
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final String unit = CatalogLabels.unit(l10n, product.unitCode);
    final String amount = MoneyFormat.uzs(
      product.customerUnitPriceUzs,
      language,
    );
    final String price = product.priceMode == PriceMode.estimate
        ? l10n.cartLineEstimate(amount)
        : amount;
    final String name = product.name(language);
    final bool tappable = line == null && !widget.full;

    final Widget words = ExcludeSemantics(
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KitColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: ProductImage(url: product.imageUrl, size: 44),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KitColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                // The price wraps at large text instead of shrinking.
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
                Text(
                  l10n.catalogPerUnit(unit),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
                if (line != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DecoratedBox(
                      key: ValueKey<String>('pick-tag-${product.id}'),
                      decoration: BoxDecoration(
                        color: KitColors.primaryWash,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          widget.justAdded
                              ? l10n.orderPickAddedNow
                              : l10n.orderPickAlreadyIn,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: KitColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget body = large && line != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              words,
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 68, top: 8),
                child: _stepper(line, expanded: true),
              ),
            ],
          )
        : Row(
            children: <Widget>[
              Expanded(child: words),
              const SizedBox(width: 12),
              if (line == null) _plus() else _stepper(line, expanded: false),
            ],
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: tappable,
      label: line == null
          ? l10n.orderPickRowSpoken(name, price, unit)
          : l10n.orderPickInOrderSpoken(
              name,
              quantityWords(l10n, line.unit, line.quantity),
            ),
      onTap: tappable ? widget.onAdd : null,
      child: Material(
        color: line == null ? Colors.transparent : KitColors.primaryWash,
        child: InkWell(
          key: ValueKey<String>('product-${product.id}'),
          excludeFromSemantics: true,
          onTap: tappable ? widget.onAdd : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44 button of the stepper: a white icon on its green.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      iconSize: 20,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// What this visit added — how many lines, and what they come to — and
/// «Готово», which returns to the editor. It rises 16 px with a fade in 280 ms
/// (a 200 ms fade with reduced motion). When the order holds its most lines it
/// says so instead of the sum.
class _PickBar extends StatelessWidget {
  const _PickBar({
    required this.count,
    required this.sumUzs,
    required this.full,
    required this.onDone,
  });

  final int count;
  final int sumUzs;
  final bool full;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    // At large text «Готово» goes under the words, at the end.
    final bool stacked =
        textScaleAt(MediaQuery.textScalerOf(context), 15) > 1.3;
    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.orderPickAdded(count),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: KitColors.ink,
          ),
        ),
        Text(
          full
              ? l10n.orderAddFull(orderMaxLines)
              : l10n.cartLineEstimate(MoneyFormat.uzs(sumUzs, language)),
          style: const TextStyle(fontSize: 13, color: KitColors.muted),
        ),
      ],
    );
    final Widget button = FilledButton(
      key: const ValueKey<String>('pick-done'),
      style: FilledButton.styleFrom(
        backgroundColor: KitColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onDone,
      child: Text(
        l10n.doneButton,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: reduced ? 200 : 280),
      curve: reduced ? Curves.easeOut : const Cubic(0.2, 0.8, 0.2, 1),
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : 16 * (1 - t)),
          child: child,
        ),
      ),
      child: DecoratedBox(
        key: const ValueKey<String>('pick-bar'),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: KitColors.line)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    words,
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: button,
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(child: words),
                    const SizedBox(width: 12),
                    button,
                  ],
                ),
        ),
      ),
    );
  }
}
