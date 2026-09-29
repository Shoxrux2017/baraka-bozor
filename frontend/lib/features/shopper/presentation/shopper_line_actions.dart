import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/shopper_orders_controllers.dart';
import '../domain/price_guard.dart';
import '../domain/shopper_orders.dart';

/// The longest note the server keeps with a question or a line's removal.
const int _noteMax = 300;

/// What the Shopper does with an open line at the market (`docs/09`
/// sections 30 to 34, `DL-70`): buy it, replace it where its policy lets a
/// replacement be proposed, or say it is not to be found. The card watches
/// the line's controller, so a purchase without a sure answer keeps its key
/// while the order is shown, and says so.
class ShopperLineActions extends ConsumerWidget {
  const ShopperLineActions({
    required this.order,
    required this.line,
    super.key,
  });

  final ShopperOrder order;
  final ShopperLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperLineRef lineRef = (orderId: order.id, itemId: line.id);
    final MutationState state = ref.watch(shopperLineActionProvider(lineRef));
    final bool unconfirmed = ref.watch(
      unansweredRequestsProvider(order.id)
          .select((UnansweredRequests r) => r.purchases.containsKey(line.id)),
    );
    final bool busy = state.isBusy;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (unconfirmed)
            Text(
              l10n.purchaseUnconfirmed,
              key: ValueKey<String>('purchase-unconfirmed-${line.id}'),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                key: ValueKey<String>('buy-${line.id}'),
                onPressed: busy
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (BuildContext context) =>
                            PurchaseDialog(order: order, line: line),
                      ),
                child: Text(l10n.lineBuy),
              ),
              if (line.substitutionPolicy !=
                  SubstitutionPolicy.removeIfUnavailable)
                OutlinedButton(
                  key: ValueKey<String>('replace-${line.id}'),
                  onPressed: busy
                      ? null
                      : () => context.push(
                          AppPaths.shopperReplace(order.id, line.id),
                        ),
                  child: Text(l10n.lineReplace),
                ),
              TextButton(
                key: ValueKey<String>('unavailable-${line.id}'),
                onPressed: busy
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (BuildContext context) =>
                            UnavailableDialog(order: order, line: line),
                      ),
                child: Text(l10n.lineUnavailable),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Closes an action's dialog on [answer]. An answer whose order left the
/// Shopper — cancelled with nothing left to buy, or passed to another
/// Shopper meanwhile — takes them back to their list and says why, since
/// they can no longer read the order (`DL-70` (6)).
void closeOnAnswer({
  required NavigatorState dialog,
  required GoRouter router,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required ShopperOrder answer,
}) {
  dialog.pop(true);
  if (answer.assignment == null) {
    router.go(AppPaths.shopper);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          answer.status == OrderStatus.cancelled
              ? l10n.shopperOrderCancelled
              : l10n.shopperOrderGone,
        ),
      ),
    );
  }
}

/// Asks the Shopper to confirm a price the typo guard finds unlikely;
/// `true` when they keep it.
Future<bool> confirmUnusualPrice(
  BuildContext context,
  int price,
  int marketPrice,
) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final AppLanguage language = interfaceLanguage(context);
  final bool? kept = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      scrollable: true,
      title: Text(l10n.typoTitle),
      content: Text(
        l10n.typoExplained(
          MoneyFormat.uzs(price, language),
          MoneyFormat.uzs(marketPrice, language),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('typo-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.typoCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('typo-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.typoConfirm),
        ),
      ],
    ),
  );
  return kept ?? false;
}

/// The text of an optional note as the server keeps it, `null` when blank.
String? optionalNote(String text) {
  final String value = trimLikeServer(text);
  return value.isEmpty ? null : value;
}

String? noteTooLong(AppLocalizations l10n, String text) =>
    trimLikeServer(text).runes.length > _noteMax
    ? l10n.fieldTooLong(_noteMax)
    : null;

/// A price field in sum, digits only, with the groups spaced as typed.
class PriceField extends StatelessWidget {
  const PriceField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.required,
    required this.enabled,
    this.helper,
    super.key,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool enabled;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return TextFormField(
      key: ValueKey<String>(fieldKey),
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
        LengthLimitingTextInputFormatter(14),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: MoneyFormat.currency(interfaceLanguage(context)),
        border: const OutlineInputBorder(),
      ),
      validator: (String? text) {
        final String value = (text ?? '').trim();
        if (value.isEmpty) {
          return required ? l10n.fieldRequired : null;
        }
        return parsePrice(value) == null ? l10n.fieldMarketPrice : null;
      },
    );
  }
}

/// The purchase of one line (`docs/09` section 30): the quantity bought, the
/// price paid per unit — required for an estimate original and for a
/// replacement — and, when a replacement is authorized, whether the
/// replacement or the original was bought. A price the typo guard finds
/// unlikely is confirmed first. When the server answers that the Customer
/// must agree — a price above the bound, or less than they are owed — the
/// dialog offers to ask them (`docs/09` sections 32 and 34). A purchase
/// without a sure answer is shown as it was sent, and sent again as it was.
class PurchaseDialog extends ConsumerStatefulWidget {
  const PurchaseDialog({required this.order, required this.line, super.key});

  final ShopperOrder order;
  final ShopperLine line;

  @override
  ConsumerState<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends ConsumerState<PurchaseDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  final TextEditingController _price = TextEditingController();
  final TextEditingController _note = TextEditingController();

  /// Whether the authorized replacement, rather than the original, is bought.
  bool _replacement = true;

  /// Whether asking about the price found no price to ask about.
  bool _askNeedsPrice = false;

  ShopperLineRef get _lineRef =>
      (orderId: widget.order.id, itemId: widget.line.id);

  ShopperLineController get _controller =>
      ref.read(shopperLineActionProvider(_lineRef).notifier);

  /// The line's purchase sent without a sure answer, if any.
  UnansweredRequest<PurchaseEntry>? get _unanswered => ref
      .read(unansweredRequestsProvider(widget.order.id))
      .purchases[widget.line.id];

  /// Closes the dialog on [answer], with what the dialog needs read before
  /// the request (`closeOnAnswer`).
  void Function(ShopperOrder answer) _closer() {
    final NavigatorState dialog = Navigator.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return (ShopperOrder answer) => closeOnAnswer(
      dialog: dialog,
      router: router,
      messenger: messenger,
      l10n: l10n,
      answer: answer,
    );
  }

  @override
  void initState() {
    super.initState();
    final ShopperLine line = widget.line;
    final PurchaseEntry? sent = _unanswered?.sent;
    _quantity = TextEditingController(
      text: QuantityRules.display(
        sent?.quantity ?? line.approvedQuantityCap ?? line.quantity,
      ),
    );
    if (sent != null) {
      final int? price = sent.actualMarketPriceUzs;
      _price.text = price == null ? '' : '$price';
      _replacement = sent.productId != line.productId;
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _buysReplacement => widget.line.replacement != null && _replacement;

  /// The market price the typo guard compares with: the line's snapshot for
  /// the original, the replacement's price now for a replacement
  /// (`DL-54` (20)).
  int get _marketPrice => _buysReplacement
      ? widget.line.replacement!.marketPriceUzs
      : widget.line.marketPriceUzs;

  PurchaseEntry _entry() {
    final String price = _price.text.trim();
    return PurchaseEntry(
      quantity: QuantityRules.normalize(widget.line.unit, _quantity.text)!,
      actualMarketPriceUzs: price.isEmpty ? null : parsePrice(price),
      // The product the dialog shows, named whatever the server holds
      // meanwhile (`DL-70` (2)).
      productId: _buysReplacement
          ? widget.line.replacement!.productId
          : widget.line.productId,
    );
  }

  Future<void> _buy() async {
    final PurchaseEntry? sent = _unanswered?.sent;
    final PurchaseEntry entry;
    if (sent != null) {
      entry = sent;
    } else {
      if (!(_form.currentState?.validate() ?? false)) {
        return;
      }
      entry = _entry();
      final int? price = entry.actualMarketPriceUzs;
      if (price != null &&
          looksMistyped(price, _marketPrice) &&
          !await confirmUnusualPrice(context, price, _marketPrice)) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    final void Function(ShopperOrder answer) close = _closer();
    final ShopperOrder? done = await _controller.purchase(entry);
    if (mounted && done != null) {
      close(done);
    }
  }

  Future<void> _askAboutPrice() async {
    // A question about a price needs one, even for a line bought as itself;
    // the field asks for it once rebuilt so.
    if (!_askNeedsPrice) {
      setState(() => _askNeedsPrice = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
    }
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final PurchaseEntry entry = _entry();
    final int? price = entry.actualMarketPriceUzs;
    if (price == null) {
      return;
    }
    final void Function(ShopperOrder answer) close = _closer();
    final ShopperOrder? done = await _controller.askAboutPrice(
      price,
      entry.productId,
      optionalNote(_note.text),
    );
    if (mounted && done != null) {
      close(done);
    }
  }

  Future<void> _askAboutQuantity() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final void Function(ShopperOrder answer) close = _closer();
    final ShopperOrder? done = await _controller.askAboutQuantity(
      _entry().quantity,
      optionalNote(_note.text),
    );
    if (mounted && done != null) {
      close(done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final ShopperLine line = widget.line;
    final ShopperReplacement? replacement = line.replacement;
    final MutationState change = ref.watch(shopperLineActionProvider(_lineRef));
    final bool unanswered =
        ref
            .watch(unansweredRequestsProvider(widget.order.id))
            .purchases[line.id] !=
        null;
    final bool locked = change.isBusy || unanswered;
    String name(String uz, String ru) => language == AppLanguage.ru ? ru : uz;
    final String bought = _buysReplacement
        ? name(replacement!.nameUz, replacement.nameRu)
        : name(line.nameUz, line.nameRu);
    final int? bound = _buysReplacement
        ? replacement!.bound.marketPriceUzs
        : line.bound?.marketPriceUzs;
    final bool priceRequired =
        _buysReplacement || line.priceMode == PriceMode.estimate;
    final bool fraction = line.unit.takesFraction;
    final ApiFailure? failure = change.failure;
    final Object? question =
        failure is ApiRefusal && failure.code == 'customer_approval_required'
        ? failure.error.details['approval_type']
        : null;
    final Object? required = failure is ApiRefusal
        ? failure.error.details['required_quantity']
        : null;

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.purchaseTitle(bought)),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (replacement != null) ...<Widget>[
                  SegmentedButton<bool>(
                    segments: <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(
                          name(replacement.nameUz, replacement.nameRu),
                          key: const ValueKey<String>('buy-replacement'),
                        ),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(
                          name(line.nameUz, line.nameRu),
                          key: const ValueKey<String>('buy-original'),
                        ),
                      ),
                    ],
                    selected: <bool>{_replacement},
                    onSelectionChanged: locked
                        ? null
                        : (Set<bool> chosen) =>
                              setState(() => _replacement = chosen.single),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  l10n.itemMarketPrice(MoneyFormat.uzs(_marketPrice, language)),
                ),
                if (bound != null)
                  Text(
                    l10n.shopperPriceLimit(MoneyFormat.uzs(bound, language)),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('purchase-quantity'),
                  controller: _quantity,
                  enabled: !locked,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: fraction,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(
                      RegExp(fraction ? r'[0-9.,]' : '[0-9]'),
                    ),
                    LengthLimitingTextInputFormatter(fraction ? 8 : 4),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.purchaseQuantity,
                    suffixText: CatalogLabels.unit(l10n, line.unit),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? text) =>
                      QuantityRules.normalize(line.unit, text ?? '') != null
                      ? null
                      : fraction
                      ? l10n.cartQuantityFraction
                      : l10n.cartQuantityWhole,
                ),
                const SizedBox(height: 12),
                PriceField(
                  fieldKey: 'purchase-price',
                  controller: _price,
                  label: l10n.purchasePrice,
                  required: priceRequired || _askNeedsPrice,
                  enabled: !locked,
                  helper: priceRequired ? null : l10n.purchasePriceOptional,
                ),
                if (unanswered)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l10n.purchaseUnconfirmed,
                      key: const ValueKey<String>(
                        'purchase-dialog-unconfirmed',
                      ),
                    ),
                  ),
                if (question == 'price_over_tolerance' ||
                    question == 'reduced_quantity') ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    question == 'price_over_tolerance'
                        ? l10n.purchaseAboveBound
                        : l10n.purchaseBelowQuantity(
                            required is String
                                ? '${QuantityRules.display(required)} '
                                      '${CatalogLabels.unit(l10n, line.unit)}'
                                : '',
                          ),
                    key: const ValueKey<String>('purchase-needs-customer'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const ValueKey<String>('ask-note'),
                    controller: _note,
                    enabled: !change.isBusy,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.askNote,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (String? text) => noteTooLong(l10n, text ?? ''),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton(
                      key: ValueKey<String>(
                        question == 'price_over_tolerance'
                            ? 'ask-price'
                            : 'ask-quantity',
                      ),
                      onPressed: change.isBusy
                          ? null
                          : question == 'price_over_tolerance'
                          ? _askAboutPrice
                          : _askAboutQuantity,
                      child: Text(
                        question == 'price_over_tolerance'
                            ? l10n.askPrice
                            : l10n.askQuantity,
                      ),
                    ),
                  ),
                ] else
                  FailureMessage(failure),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('purchase-cancel'),
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('purchase-save'),
            onPressed: change.isBusy ? null : _buy,
            child: Text(unanswered ? l10n.purchaseAgain : l10n.purchaseSave),
          ),
        ],
      ),
    );
  }
}

/// The confirmation that a line is not to be found, with an optional note
/// kept on the history (`docs/09` section 31). When it was the last line to
/// buy, the order is cancelled, which the explanation says.
class UnavailableDialog extends ConsumerStatefulWidget {
  const UnavailableDialog({required this.order, required this.line, super.key});

  final ShopperOrder order;
  final ShopperLine line;

  @override
  ConsumerState<UnavailableDialog> createState() => _UnavailableDialogState();
}

class _UnavailableDialogState extends ConsumerState<UnavailableDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();

  ShopperLineRef get _lineRef =>
      (orderId: widget.order.id, itemId: widget.line.id);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final NavigatorState dialog = Navigator.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperOrder? done = await ref
        .read(shopperLineActionProvider(_lineRef).notifier)
        .markUnavailable(optionalNote(_note.text));
    if (mounted && done != null) {
      closeOnAnswer(
        dialog: dialog,
        router: router,
        messenger: messenger,
        l10n: l10n,
        answer: done,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(shopperLineActionProvider(_lineRef));
    final String name = interfaceLanguage(context) == AppLanguage.ru
        ? widget.line.nameRu
        : widget.line.nameUz;

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.unavailableTitle(name)),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.unavailableExplained),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey<String>('unavailable-note'),
                  controller: _note,
                  enabled: !change.isBusy,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.actionNote,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? text) => noteTooLong(l10n, text ?? ''),
                ),
                FailureMessage(change.failure),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('unavailable-cancel'),
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('unavailable-confirm'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(l10n.unavailableConfirm),
          ),
        ],
      ),
    );
  }
}
