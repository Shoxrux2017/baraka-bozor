import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/accessibility/announce.dart';
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
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/keyboard_done_bar.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/application/cart_quantity_queue.dart';
import '../../cart/domain/cart.dart';
import '../../cart/presentation/cart_feedback.dart';
import '../../cart/presentation/cart_paths.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../favorites/application/favorites_controllers.dart';
import '../application/catalog_controllers.dart';
import '../domain/catalog.dart';
import 'more_in_category.dart';
import 'product_bar.dart';
import 'product_photo.dart';
import 'product_sections.dart';
import 'quantity_sheet.dart';

/// One product (drawing 18): its picture, name, approximate price and what an
/// estimate means, its description, the rule for when it is missing and a
/// note to the Shopper, more of its category, and a bottom bar with the
/// stepper and "Ð’ ÐºÐ¾Ñ€Ð·Ð¸Ð½Ñƒ". A product that can no longer be seen shows that
/// it is gone (drawing 18b).
///
/// Opened from a card it is given the card's product ([opening]) and shows it
/// at once while the server's answer is on its way; the photo flies from the
/// card and the page under it fades up (`DL-122`).
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({required this.productId, this.opening, super.key});

  final String productId;

  /// What the card handed over; ignored when it is for another product.
  final ProductOpening? opening;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

/// Where the screen's add stands (`DL-122`).
enum _AddPhase { idle, adding, added }

/// The field whose change the save mark follows (`DL-122`).
enum _SaveField { quantity, policy, note }

class _ProductScreenState extends ConsumerState<ProductScreen> {
  final TextEditingController _note = TextEditingController();
  String _quantity = '1';
  SubstitutionPolicy _policy = SubstitutionPolicy.allowSimilar;
  bool _heartBusy = false;
  _AddPhase _phase = _AddPhase.idle;

  /// Read once so [dispose] can still send a waiting note.
  late final CartQuantityQueue _queue;
  final FocusNode _noteFocus = FocusNode();

  /// The note field, to bring into view when it is too long to send.
  final GlobalKey _noteKey = GlobalKey();

  /// How long the note waits after its last key.
  static const Duration _noteSettle = Duration(seconds: 1);
  Timer? _noteTimer;

  /// Whether the Customer changed the note and it is not sent yet.
  bool _noteDirty = false;

  /// Whether the details last handed to the queue carried a note that was
  /// waiting, which a failed save must put back to waiting.
  bool _carriedNote = false;

  /// Whether a rule the Customer chose has not been answered yet: a cart
  /// answer must not put the old rule back.
  bool _ruleOnItsWay = false;

  /// Counts the changes made in the cart; an answer for a change that a
  /// later one replaced moves nothing.
  int _changes = 0;
  _SaveField? _markField;
  ProductSaveState? _markState;
  Timer? _markTimer;

  /// How long Â«Ð¡Ð¾Ñ…Ñ€Ð°Ð½ÐµÐ½Ð¾Â» stands.
  static const Duration _savedFor = Duration(milliseconds: 1600);

  /// How long "Ð’ ÐºÐ¾Ñ€Ð·Ð¸Ð½Ðµ" stands before the bar offers the cart.
  static const Duration _addedFor = Duration(milliseconds: 1100);
  Timer? _addedTimer;

  /// The quantity the in-cart chip last showed, kept while it folds away.
  String? _chipQuantity;

  /// This product's line in the cart as the screen last took it, which is
  /// what the controls are compared with; `null` while it is not in the cart.
  CartLine? _line;

  @override
  void initState() {
    super.initState();
    _queue = ref.read(cartQuantityQueueProvider.notifier);
    _noteFocus.addListener(_onNoteFocus);
    ref.listenManual<AsyncValue<Cart>>(
      currentCartProvider,
      (AsyncValue<Cart>? _, AsyncValue<Cart> next) => _onCart(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _addedTimer?.cancel();
    _markTimer?.cancel();
    _noteTimer?.cancel();
    // Leaving at once still sends the note; a waiting step goes with it. The
    // send waits for the tree to finish unmounting: it changes providers.
    if (_noteDirty && _line != null && _noteFits()) {
      final String productId = widget.productId;
      final CartLineDetails details = _details();
      scheduleMicrotask(() => unawaited(_queue.describe(productId, details)));
    }
    _noteFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  /// A quantity as the stepper holds it: `2.000` is `2`.
  static String _plain(String quantity) =>
      QuantityRules.display(quantity).replaceAll(',', '.');

  /// This product's line in [cart], if it has one.
  CartLine? _lineIn(Cart cart) {
    for (final CartLine candidate in cart.lines) {
      if (candidate.productId == widget.productId) {
        return candidate;
      }
    }
    return null;
  }

  void _onCart(AsyncValue<Cart> cart) {
    // A cart on its way, or one that failed with nothing before it, says
    // nothing about the line.
    if (!cart.hasValue) {
      return;
    }
    final CartLine? line = _lineIn(cart.requireValue);
    final CartLine? before = _line;
    setState(() {
      _line = line;
      if (line == null) {
        if (before != null) {
          // Removed here or elsewhere: a new add again.
          _quantity = '1';
          _policy = SubstitutionPolicy.allowSimilar;
          _note.clear();
          _noteTimer?.cancel();
          _noteDirty = false;
          _ruleOnItsWay = false;
        }
        return;
      }
      // The server's line is shown unless the Customer's own change of it is
      // still on its way or being typed.
      if (!_ruleOnItsWay) {
        _policy = line.substitutionPolicy;
      }
      final String note = line.customerNote ?? '';
      if (!_noteFocus.hasFocus && !_noteDirty && _note.text != note) {
        _note.text = note;
      }
    });
  }

  /// Whether the note is short enough for the server, counted as it counts.
  bool _noteFits() =>
      trimLikeServer(_note.text).runes.length <= cartNoteMaxLength;

  /// The note and rule as the Customer has them now. A note that fits goes
  /// with the rule; one too long does not, and the line keeps its own.
  CartLineDetails _details() {
    final String text = trimLikeServer(_note.text);
    final bool carry = _noteFits();
    if (carry) {
      _noteTimer?.cancel();
      _carriedNote = _noteDirty;
      _noteDirty = false;
    }
    return CartLineDetails(
      customerNote: carry ? (text.isEmpty ? null : text) : _line?.customerNote,
      substitutionPolicy: _policy,
    );
  }

  /// Shows the mark for [field] while [answer] is awaited, then Â«Ð¡Ð¾Ñ…Ñ€Ð°Ð½ÐµÐ½Ð¾Â»;
  /// a failure clears it and says why. An answer of a replaced change moves
  /// nothing.
  void _track(Future<ApiFailure?> answer, _SaveField field) {
    final int mine = ++_changes;
    final bool carried = _carriedNote;
    _carriedNote = false;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    _markTimer?.cancel();
    setState(() {
      _markField = field;
      _markState = ProductSaveState.saving;
    });
    unawaited(
      answer.then((ApiFailure? failure) {
        if (failure != null && carried && _line != null) {
          // The text stays in the field and waits to go again: a cart answer
          // does not overwrite it, and the next change, the field closing or
          // leaving sends it.
          _noteDirty = true;
        }
        if (mine != _changes) {
          return;
        }
        _ruleOnItsWay = false;
        if (failure != null) {
          if (mounted) {
            setState(() => _markState = null);
          }
          showCartFailure(messenger, l10n, failure);
          return;
        }
        if (!mounted) {
          return;
        }
        setState(() => _markState = ProductSaveState.saved);
        _markTimer = Timer(_savedFor, () {
          if (mounted) {
            setState(() => _markState = null);
          }
        });
      }),
    );
  }

  /// A step or an exact quantity of the line in the cart.
  void _step(String quantity, {bool now = false}) {
    _track(
      _queue.want(widget.productId, quantity, now: now),
      _SaveField.quantity,
    );
  }

  void _setPolicy(SubstitutionPolicy policy) {
    if (_line == null) {
      setState(() => _policy = policy);
      return;
    }
    _ruleOnItsWay = true;
    setState(() => _policy = policy);
    _track(_queue.describe(widget.productId, _details()), _SaveField.policy);
  }

  void _onNoteChanged(String _) {
    if (_line == null) {
      return;
    }
    _noteDirty = true;
    _noteTimer?.cancel();
    _noteTimer = Timer(_noteSettle, _sendNote);
  }

  void _onNoteFocus() {
    if (!_noteFocus.hasFocus) {
      _sendNote();
    }
    // The keyboard bar follows the focus.
    if (mounted) {
      setState(() {});
    }
  }

  /// Brings the note into view and focuses it, when it is too long to send.
  void _showNote() {
    final BuildContext? target = _noteKey.currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    }
    _noteFocus.requestFocus();
  }

  void _sendNote() {
    _noteTimer?.cancel();
    if (!_noteDirty || _line == null || !_noteFits()) {
      return;
    }
    _track(_queue.describe(widget.productId, _details()), _SaveField.note);
  }

  Future<void> _askQuantity(CatalogProduct product, String current) async {
    final String? quantity = await showQuantitySheet(
      context,
      unit: product.unitCode,
      current: current,
      name: product.name(interfaceLanguage(context)),
      unitPriceUzs: product.customerUnitPriceUzs,
    );
    if (quantity == null || !mounted || _plain(quantity) == current) {
      return;
    }
    if (_line == null) {
      setState(() => _quantity = quantity);
    } else {
      _step(quantity, now: true);
    }
  }

  /// The card's data, when this page was opened with it for this product.
  ProductOpening? get _opening {
    final ProductOpening? opening = widget.opening;
    return opening != null && opening.product.id == widget.productId
        ? opening
        : null;
  }

  Future<void> _toggleHeart(CatalogProduct product) async {
    if (_heartBusy) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool current = favoriteOf(
      ref.read(favoriteOverridesProvider),
      product,
    );
    setState(() => _heartBusy = true);
    final ApiFailure? failure = await ref
        .read(favoriteOverridesProvider.notifier)
        .change(product.id, current: current);
    if (mounted) {
      setState(() => _heartBusy = false);
    }
    if (failure != null) {
      final String text =
          failure is ApiRefusal && failure.code == 'favorites_full'
          ? l10n.favoritesFull
          : l10n.favoriteFailed;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Adds the product through the quantity queue. The button says so while
  /// the server answers; a taken add shows "Ð’ ÐºÐ¾Ñ€Ð·Ð¸Ð½Ðµ" for a moment, then
  /// offers the cart. A line that appears another way goes straight to the
  /// cart button (`DL-122`).
  Future<void> _add(CatalogProduct product) async {
    if (!_noteFits()) {
      _showNote();
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Kept before the wait: the failure may outlive this page.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String name = product.name(interfaceLanguage(context));
    final String quantity = _quantity;
    final String spoken =
        '${QuantityRules.display(quantity)} '
        '${CatalogLabels.unit(l10n, product.unitCode)}';
    final String note = trimLikeServer(_note.text);

    setState(() => _phase = _AddPhase.adding);
    final ApiFailure? failure = await ref
        .read(cartQuantityQueueProvider.notifier)
        .add(
          NewCartLine(
            productId: product.id,
            quantity: quantity,
            customerNote: note.isEmpty ? null : note,
            substitutionPolicy: _policy,
          ),
        );
    if (failure != null) {
      if (mounted) {
        setState(() => _phase = _AddPhase.idle);
      }
      showCartFailure(messenger, l10n, failure);
      return;
    }
    if (!mounted) {
      return;
    }
    // Read from the cart itself: the screen's own copy is updated a moment
    // later. A line that holds another quantity than the one sent was there
    // before (the add was refused as `cart_item_already_exists`), so it is
    // no add of this screen and the bar goes straight to the cart.
    final Cart? held = ref.read(currentCartProvider).value;
    final CartLine? taken = held == null ? null : _lineIn(held);
    if (taken == null || _plain(taken.quantity) != _plain(quantity)) {
      // Refused, or not shown yet: the cart that follows decides what the
      // bar offers.
      setState(() => _phase = _AddPhase.idle);
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    announce(context, l10n.cartCardAdded(name, spoken));
    setState(() => _phase = _AddPhase.added);
    _addedTimer?.cancel();
    _addedTimer = Timer(_addedFor, () {
      if (mounted) {
        setState(() => _phase = _AddPhase.idle);
      }
    });
  }

  /// The sum under the bar's label: the line's own while the quantity shown
  /// is the line's, else the estimate for the quantity shown.
  int _sum(CatalogProduct product, CartLine? line, String shown) {
    final int? own = line?.estimatedLineTotalUzs;
    if (line != null && own != null && _plain(line.quantity) == shown) {
      return own;
    }
    return EstimatePreview.lineUzs(product.customerUnitPriceUzs, shown);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<CatalogProduct> product = ref.watch(
      catalogProductProvider(widget.productId),
    );
    final ProductOpening? opening = _opening;
    final Object? error = product.hasError && product.value == null
        ? product.error
        : null;
    final ApiFailure? loadFailure = error == null
        ? null
        : error is ApiFailure
        ? error
        : const UnexpectedFailure();
    final bool gone = loadFailure is ApiRefusal && loadFailure.status == 404;
    // The server's product once it has come, else the card's; a product the
    // server says is gone is shown from neither.
    final CatalogProduct? shown =
        product.value ?? (gone ? null : opening?.product);
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final Object? heroTag = opening == null || reduced ? null : opening.heroTag;
    final AsyncValue<Cart> cart = ref.watch(currentCartProvider);
    // The add waits while the cart is on its way: an add to a cart not yet
    // seen could not be told from one already holding the product.
    final bool cartKnown = cart.hasValue || cart.hasError;
    final CartLine? line = _line;
    final Map<String, String> wishes = ref.watch(cartQuantityQueueProvider);
    // What the Customer sets waits for an add's answer, which would
    // overwrite it; nothing waits in the cart.
    final bool locked = line == null && _phase == _AddPhase.adding;
    final String? wished = shownCartQuantity(wishes, widget.productId, line);
    final String shownQuantity = line != null
        ? _plain(wished ?? line.quantity)
        : (wished != null ? _plain(wished) : _quantity);
    final String? lineQuantity = line == null
        ? null
        : '${QuantityRules.display(shownQuantity)} '
              '${CatalogLabels.unit(l10n, line.unit)}';
    // Kept while the chip folds away, so it does not empty as it goes.
    if (lineQuantity != null) {
      _chipQuantity = lineQuantity;
    }
    final ProductBarAction action = line == null
        ? (_phase == _AddPhase.adding
              ? ProductBarAction.adding
              : ProductBarAction.add)
        : (_phase == _AddPhase.added
              ? ProductBarAction.added
              : ProductBarAction.openCart);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: l10n.productTitle,
        actions: <Widget>[
          if (shown != null) _Heart(product: shown, onTap: _toggleHeart),
        ],
      ),
      body: UnderActiveMode(
        child: gone
            ? const _Gone()
            : shown == null
            ? loadFailure == null
                  ? const Center(child: CircularProgressIndicator())
                  : _Retry(
                      failure: loadFailure,
                      onRetry: () => ref.invalidate(
                        catalogProductProvider(widget.productId),
                      ),
                    )
            : Column(
                children: <Widget>[
                  Expanded(
                    child: _Page(
                      product: shown,
                      note: _note,
                      noteFocus: _noteFocus,
                      noteKey: _noteKey,
                      onNoteChanged: _onNoteChanged,
                      saveField: _markField,
                      saveState: _markState,
                      policy: _policy,
                      locked: locked,
                      heroTag: heroTag,
                      fadeUp: opening != null && !reduced,
                      chipQuantity: _chipQuantity,
                      chipShown: line != null,
                      onChipFolded: () => setState(() => _chipQuantity = null),
                      onPolicy: _setPolicy,
                    ),
                  ),
                  if (_noteFocus.hasFocus &&
                      MediaQuery.viewInsetsOf(context).bottom > 0)
                    KeyboardDoneBar(onDone: _noteFocus.unfocus),
                ],
              ),
      ),
      bottomNavigationBar: shown == null
          ? null
          : ProductBar(
              product: shown,
              quantity: shownQuantity,
              sumUzs: _sum(shown, line, shownQuantity),
              onQuantity: line == null
                  ? (String quantity) => setState(() => _quantity = quantity)
                  : _step,
              onQuantityTap: () => _askQuantity(shown, shownQuantity),
              onRemove: line == null || locked
                  ? null
                  : () {
                      _noteTimer?.cancel();
                      _noteDirty = false;
                      unawaited(
                        removeCartLine(
                          context,
                          ref,
                          line: line,
                          quantity: shownQuantity,
                          name: shown.name(interfaceLanguage(context)),
                        ),
                      );
                    },
              locked: locked,
              action: action,
              onAction: switch (action) {
                ProductBarAction.add ||
                ProductBarAction.adding => cartKnown ? () => _add(shown) : null,
                ProductBarAction.added => null,
                ProductBarAction.openCart => () => context.push(CartPaths.cart),
              },
            ),
    );
  }
}

class _Heart extends ConsumerWidget {
  const _Heart({required this.product, required this.onTap});

  final CatalogProduct product;
  final ValueChanged<CatalogProduct> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool favorite = isFavorite(ref, product);
    return IconButton(
      key: const ValueKey<String>('product-heart'),
      tooltip: favorite ? l10n.favoriteRemove : l10n.favoriteAdd,
      color: favorite ? KitColors.danger : KitColors.ink,
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
      onPressed: () => onTap(product),
    );
  }
}

/// The scrolling page; what the Customer sets lives in the screen's state,
/// so it survives the page being built again.
class _Page extends StatelessWidget {
  const _Page({
    required this.product,
    required this.note,
    required this.noteFocus,
    required this.noteKey,
    required this.onNoteChanged,
    required this.saveField,
    required this.saveState,
    required this.policy,
    required this.locked,
    required this.heroTag,
    required this.fadeUp,
    required this.chipQuantity,
    required this.chipShown,
    required this.onChipFolded,
    required this.onPolicy,
  });

  final CatalogProduct product;
  final TextEditingController note;
  final FocusNode noteFocus;
  final GlobalKey noteKey;
  final ValueChanged<String> onNoteChanged;

  /// The field the save mark stands by, and what it says; `null` when none.
  final _SaveField? saveField;
  final ProductSaveState? saveState;
  final SubstitutionPolicy policy;

  /// Whether an add is on its way: the controls wait.
  final bool locked;

  /// The tag the photo flies by, `null` when it does not fly.
  final Object? heroTag;

  /// Whether the page under the photo fades up (opened from a card).
  final bool fadeUp;

  /// The quantity the in-cart chip shows, `null` when there is no chip.
  final String? chipQuantity;

  /// Whether the product has a line in the cart: the chip unfolds.
  final bool chipShown;

  /// Called once the chip has folded away.
  final VoidCallback onChipFolded;
  final ValueChanged<SubstitutionPolicy> onPolicy;

  static const double side = 20;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final String? description = product.description(language);
    final double wellHeight = math.min(
      250,
      MediaQuery.sizeOf(context).width * 0.67,
    );
    Widget? markOf(_SaveField field) => saveState != null && saveField == field
        ? ProductSaveMark(
            key: ValueKey<String>('product-save-mark-${field.name}'),
            state: saveState!,
          )
        : null;
    final Widget? quantityMark = markOf(_SaveField.quantity);
    final Widget well = ProductPhotoWell(
      imageUrl: product.imageUrl,
      radius: 20,
    );

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: side),
            child: SizedBox(
              height: wellHeight,
              child: heroTag == null
                  ? well
                  : Hero(
                      tag: heroTag!,
                      flightShuttleBuilder: productPhotoFlight,
                      child: well,
                    ),
            ),
          ),
          _FadeUp(
            enabled: fadeUp,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 6),
                // First built in the cart it stands still; after an add it
                // folds in, and away when the line goes.
                Fold(
                  shown: chipShown,
                  onFolded: onChipFolded,
                  child: chipQuantity == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(side, 10, side, 0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Flexible(
                                  child: ProductInCartChip(
                                    quantity: chipQuantity!,
                                  ),
                                ),
                                if (quantityMark != null) ...<Widget>[
                                  const SizedBox(width: 10),
                                  Flexible(child: quantityMark),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(side, 10, side, 0),
                  child: Text(
                    product.name(language),
                    key: const ValueKey<String>('product-name'),
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(side, 8, side, 0),
                  child: Semantics(
                    key: const ValueKey<String>('product-price-row'),
                    label: l10n.productPriceSpoken(
                      MoneyFormat.uzs(product.customerUnitPriceUzs, language),
                      product.unitCode.name,
                    ),
                    excludeSemantics: true,
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: <Widget>[
                        Text(
                          l10n.catalogApproxPrice(
                            MoneyFormat.uzs(
                              product.customerUnitPriceUzs,
                              language,
                            ),
                          ),
                          key: const ValueKey<String>('product-price'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: KitColors.ink,
                          ),
                        ),
                        Text(
                          l10n.catalogPerUnit(
                            CatalogLabels.unit(l10n, product.unitCode),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: KitColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (product.priceMode == PriceMode.estimate)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(side, 12, side, 0),
                    child: _EstimatePanel(text: l10n.catalogEstimateExplain),
                  ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(side, 12, side, 0),
                    child: _Description(text: description),
                  ),
                const SizedBox(height: 16),
                const _Rule(),
                _Section(
                  title: l10n.productIfMissing,
                  mark: markOf(_SaveField.policy),
                  child: RadioGroup<SubstitutionPolicy>(
                    groupValue: policy,
                    onChanged: (SubstitutionPolicy? option) {
                      if (option != null && !locked) {
                        onPolicy(option);
                      }
                    },
                    child: Column(
                      key: const ValueKey<String>('line-substitution'),
                      children: <Widget>[
                        for (final SubstitutionPolicy option
                            in SubstitutionPolicy.values)
                          _RuleRow(
                            option: option,
                            label: OrderLabels.substitution(l10n, option),
                            onTap: locked ? null : () => onPolicy(option),
                          ),
                      ],
                    ),
                  ),
                ),
                const _Rule(),
                _Section(
                  title: l10n.cartNote,
                  child: KeyedSubtree(
                    key: noteKey,
                    child: ProductNoteField(
                      controller: note,
                      focusNode: noteFocus,
                      readOnly: locked,
                      onChanged: onNoteChanged,
                      mark: saveField == _SaveField.note ? saveState : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                MoreInCategory(product: product),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The page under the photo comes up from 10 px lower and from nothing in
/// 340 ms after 100 ms, once, when the product was opened from a card
/// (`DL-122`). Not [enabled], it is only its child.
class _FadeUp extends StatefulWidget {
  const _FadeUp({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<_FadeUp> with SingleTickerProviderStateMixin {
  static const Duration delay = Duration(milliseconds: 100);
  static const Duration rise = Duration(milliseconds: 340);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: delay + rise,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      delay.inMilliseconds / (delay + rise).inMilliseconds,
      1,
      curve: const Cubic(0.2, 0.8, 0.2, 1),
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    return FadeTransition(
      key: const ValueKey<String>('product-page-fade'),
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, 10 * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: _Page.side),
    child: Divider(height: 1, thickness: 1, color: KitColors.line),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.mark});

  final String title;
  final Widget child;

  /// The save mark beside the title, when there is one.
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_Page.side, 16, _Page.side, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ),
              ),
              if (mark != null) ...<Widget>[
                const SizedBox(width: 10),
                Flexible(child: mark!),
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EstimatePanel extends StatelessWidget {
  const _EstimatePanel({required this.text});

  final String text;

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
            const Icon(
              Icons.info_outline,
              size: 20,
              color: KitColors.primaryDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
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

/// The description, three lines until the Customer reads on.
class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  static const int foldedLines = 3;
  static const TextStyle style = TextStyle(
    fontSize: 13,
    height: 1.6,
    color: KitColors.ink2,
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = TextPainter(
          // The style the Text below really resolves to, font included.
          text: TextSpan(
            text: widget.text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          maxLines: foldedLines,
          textDirection: direction,
          textScaler: scaler,
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final bool longer = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.text,
              key: const ValueKey<String>('product-description'),
              maxLines: _expanded ? null : foldedLines,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
              style: style,
            ),
            if (longer)
              TextButton(
                key: const ValueKey<String>('product-more'),
                style: TextButton.styleFrom(
                  foregroundColor: KitColors.primaryDark,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? l10n.productReadLess : l10n.productReadMore,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.option,
    required this.label,
    required this.onTap,
  });

  final SubstitutionPolicy option;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('substitution-${option.code}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: <Widget>[
            IgnorePointer(
              child: Radio<SubstitutionPolicy>(
                value: option,
                activeColor: KitColors.primary,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: KitColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drawing 18b: the product is no longer in the catalog (a `404`), which
/// asking again cannot bring back (`DL-28` (12)).
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        key: const ValueKey<String>('product-gone'),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: KitColors.primaryWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.remove_shopping_cart,
                size: 44,
                color: KitColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.productGoneTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.productGoneText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: KitColors.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey<String>('product-gone-action'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KitColors.primaryDark,
                side: const BorderSide(color: KitColors.primary),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.go(AppPaths.customer),
              child: Text(l10n.productGoneAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Something that could not be loaded: the reason and a retry.
class _Retry extends StatelessWidget {
  const _Retry({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FailureMessage(failure),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey<String>('retry-load'),
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
