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
import '../../../core/network/idempotency_key.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit/kit_sheet.dart';
import '../application/shopper_orders_controllers.dart';
import '../domain/price_guard.dart';
import '../domain/shopper_orders.dart';
import 'shopper_picture.dart';

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

    final bool large = kitLargeText(context);
    final ButtonStyle compact = ButtonStyle(
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 8),
      ),
    );

    Widget label(String text) =>
        FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));

    final Widget buy = FilledButton.icon(
      key: ValueKey<String>('buy-${line.id}'),
      style: kitFilled(height: 46).merge(compact),
      icon: const Icon(Icons.check, size: 20),
      label: label(l10n.lineBuy),
      onPressed: busy
          ? null
          : () => showPurchaseSheet(context, order: order, line: line),
    );
    final Widget? replace =
        line.substitutionPolicy == SubstitutionPolicy.removeIfUnavailable
        ? null
        : OutlinedButton(
            key: ValueKey<String>('replace-${line.id}'),
            style: kitOutlined(height: 46).merge(compact),
            onPressed: busy
                ? null
                : () =>
                      context.push(AppPaths.shopperReplace(order.id, line.id)),
            child: label(l10n.lineReplace),
          );
    final Widget unavailable = OutlinedButton(
      key: ValueKey<String>('unavailable-${line.id}'),
      style: kitOutlined(
        foreground: KitColors.danger,
        height: 46,
      ).merge(compact),
      onPressed: busy
          ? null
          : () => showUnavailableSheet(context, order: order, line: line),
      child: label(l10n.lineUnavailable),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (unconfirmed) ...<Widget>[
            KitNote(
              key: ValueKey<String>('purchase-unconfirmed-${line.id}'),
              icon: Icons.cloud_off,
              tone: KitTone.grey,
              text: Text(l10n.purchaseUnconfirmed),
            ),
            const SizedBox(height: 10),
          ],
          if (large) ...<Widget>[
            buy,
            if (replace != null) ...<Widget>[
              const SizedBox(height: 8),
              replace,
            ],
            const SizedBox(height: 8),
            unavailable,
          ] else
            Row(
              children: <Widget>[
                Expanded(flex: 11, child: buy),
                if (replace != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Expanded(flex: 10, child: replace),
                ],
                const SizedBox(width: 8),
                Expanded(flex: 10, child: unavailable),
              ],
            ),
        ],
      ),
    );
  }
}

/// Closes an action's sheet on [answer]. An answer whose order left the
/// Shopper — cancelled with nothing left to buy, or passed to another
/// Shopper meanwhile — takes them back to their list and says why, since
/// they can no longer read the order (`DL-70` (6)).
void closeOnAnswer({
  required NavigatorState sheet,
  required GoRouter router,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required ShopperOrder answer,
}) {
  sheet.pop(true);
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

/// Asks the Shopper to confirm a price the typo guard finds unlikely, in a
/// centred modal of the kit; `true` when they keep it.
Future<bool> confirmUnusualPrice(
  BuildContext context,
  int price,
  int marketPrice,
) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final AppLanguage language = interfaceLanguage(context);
  final bool? kept = await showDialog<bool>(
    context: context,
    builder: (BuildContext modal) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: KitColors.warningWash,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 34,
                  color: KitColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                l10n.typoTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: KitColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.typoExplained(
                MoneyFormat.uzs(price, language),
                MoneyFormat.uzs(marketPrice, language),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: KitColors.ink2,
              ),
            ),
            const SizedBox(height: 20),
            KitActionPair(
              secondary: OutlinedButton(
                key: const ValueKey<String>('typo-cancel'),
                style: kitOutlined(),
                onPressed: () => Navigator.of(modal).pop(false),
                child: Text(l10n.typoCancel),
              ),
              primary: FilledButton(
                key: const ValueKey<String>('typo-confirm'),
                style: kitFilled(),
                onPressed: () => Navigator.of(modal).pop(true),
                child: Text(l10n.typoConfirm),
              ),
            ),
          ],
        ),
      ),
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

OutlineInputBorder _fieldBorder(Color? color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: color == null
      ? BorderSide.none
      : BorderSide(color: color, width: 1.5),
);

/// The kit's filled field; [warn] outlines it amber, the mark of the value a
/// question to the Customer is about.
InputDecoration _fieldDecoration({
  String? hint,
  String? suffix,
  String? helper,
  bool warn = false,
  bool big = false,
}) {
  final Color? outline = warn ? KitColors.warning : null;

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 15, color: KitColors.muted),
    suffixText: suffix,
    suffixStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: KitColors.muted,
    ),
    helperText: helper,
    helperMaxLines: 4,
    helperStyle: const TextStyle(fontSize: 12, color: KitColors.muted),
    filled: true,
    fillColor: KitColors.field,
    constraints: big ? const BoxConstraints(minHeight: 58) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: _fieldBorder(outline),
    enabledBorder: _fieldBorder(outline),
    disabledBorder: _fieldBorder(outline),
    focusedBorder: _fieldBorder(outline ?? KitColors.primary),
    errorBorder: _fieldBorder(KitColors.danger),
    focusedErrorBorder: _fieldBorder(KitColors.danger),
  );
}

const TextStyle _bigFieldStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);

/// A field under its [label].
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.field});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KitColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

/// Groups the digits of a price by three from the right with spaces as the
/// Shopper types, and keeps the cursor at the end.
class _GroupedDigitsFormatter extends TextInputFormatter {
  const _GroupedDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        grouped.write(' ');
      }
      grouped.write(digits[i]);
    }
    final String text = grouped.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A price field in sum, digits only, with the groups spaced as typed; the
/// kit's field with its [label] above. [warn] outlines it amber.
class PriceField extends StatelessWidget {
  const PriceField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.required,
    required this.enabled,
    this.helper,
    this.warn = false,
    super.key,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool enabled;
  final String? helper;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return _LabeledField(
      label: label,
      field: TextFormField(
        key: ValueKey<String>(fieldKey),
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        style: _bigFieldStyle,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
          LengthLimitingTextInputFormatter(14),
          const _GroupedDigitsFormatter(),
        ],
        decoration: _fieldDecoration(
          suffix: MoneyFormat.currency(interfaceLanguage(context)),
          helper: helper,
          warn: warn,
          big: true,
        ),
        validator: (String? text) {
          final String value = (text ?? '').trim();
          if (value.isEmpty) {
            return required ? l10n.fieldRequired : null;
          }
          return parsePrice(value) == null ? l10n.fieldMarketPrice : null;
        },
      ),
    );
  }
}

/// An optional note of up to 300 characters under its [label], with how many
/// it holds.
class KitNoteField extends StatelessWidget {
  const KitNoteField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    super.key,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LabeledField(
          label: label,
          field: TextFormField(
            key: ValueKey<String>(fieldKey),
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, color: KitColors.ink),
            decoration: _fieldDecoration(hint: hint),
            validator: (String? text) => noteTooLong(l10n, text ?? ''),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? _) {
              final int kept = trimLikeServer(controller.text).runes.length;

              return Text(
                '$kept / $_noteMax',
                style: TextStyle(
                  fontSize: 12,
                  color: kept > _noteMax ? KitColors.danger : KitColors.muted,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The head of a sheet: the product's picture, its [name] and a [detail].
class ShopperSheetHeader extends StatelessWidget {
  const ShopperSheetHeader({
    required this.imageUrl,
    required this.name,
    required this.detail,
    super.key,
  });

  final String? imageUrl;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ShopperPicture(url: imageUrl, size: 60),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: KitColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the purchase of [line] in a sheet.
Future<void> showPurchaseSheet(
  BuildContext context, {
  required ShopperOrder order,
  required ShopperLine line,
}) {
  return showKitSheet<void>(
    context,
    title: AppLocalizations.of(context).purchaseSheetTitle,
    sheetKey: 'purchase-sheet',
    builder: (BuildContext sheet) => PurchaseSheet(order: order, line: line),
  );
}

/// Opens the confirmation that [line] is not to be found, in a sheet.
Future<void> showUnavailableSheet(
  BuildContext context, {
  required ShopperOrder order,
  required ShopperLine line,
}) {
  return showKitSheet<void>(
    context,
    title: AppLocalizations.of(context).unavailableSheetTitle,
    sheetKey: 'unavailable-sheet',
    builder: (BuildContext sheet) => UnavailableSheet(order: order, line: line),
  );
}

/// The purchase of one line (`docs/09` section 30): the quantity bought, the
/// price paid per unit — required for an estimate original and for a
/// replacement — and, when a replacement is authorized, whether the
/// replacement or the original was bought. A price the typo guard finds
/// unlikely is confirmed first. When the server answers that the Customer
/// must agree — a price above the bound, or less than they are owed — the
/// sheet asks about exactly the values it refused: changing the quantity or
/// the price returns it to a purchase (`docs/09` sections 32 and 34). A
/// purchase without a sure answer is shown as it was sent, and sent again as
/// it was. A sheet whose request runs cannot be closed.
class PurchaseSheet extends ConsumerStatefulWidget {
  const PurchaseSheet({required this.order, required this.line, super.key});

  final ShopperOrder order;
  final ShopperLine line;

  @override
  ConsumerState<PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends ConsumerState<PurchaseSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  final TextEditingController _price = TextEditingController();
  final TextEditingController _note = TextEditingController();

  /// Whether the authorized replacement, rather than the original, is bought.
  bool _replacement = true;

  /// The texts of the quantity and the price, and the product (the
  /// replacement or the original), as the last purchase was sent; the
  /// question to the Customer holds only while the sheet shows them.
  String? _sentQuantity;
  String? _sentPrice;
  bool? _sentReplacement;

  ShopperLineRef get _lineRef =>
      (orderId: widget.order.id, itemId: widget.line.id);

  ShopperLineController get _controller =>
      ref.read(shopperLineActionProvider(_lineRef).notifier);

  /// The line's purchase sent without a sure answer, if any.
  UnansweredRequest<PurchaseEntry>? get _unanswered => ref
      .read(unansweredRequestsProvider(widget.order.id))
      .purchases[widget.line.id];

  /// Closes the sheet on [answer], with what the sheet needs read before
  /// the request (`closeOnAnswer`).
  void Function(ShopperOrder answer) _closer() {
    final NavigatorState sheet = Navigator.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return (ShopperOrder answer) => closeOnAnswer(
      sheet: sheet,
      router: router,
      messenger: messenger,
      l10n: l10n,
      answer: answer,
    );
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
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
    _quantity.addListener(_changed);
    _price.addListener(_changed);
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

  /// What the Customer is owed, as the decimal string the API gives.
  String get _needed => widget.line.approvedQuantityCap ?? widget.line.quantity;

  PurchaseEntry _entry() {
    final String price = _price.text.trim();
    return PurchaseEntry(
      quantity: QuantityRules.normalize(widget.line.unit, _quantity.text)!,
      actualMarketPriceUzs: price.isEmpty ? null : parsePrice(price),
      // The product the sheet shows, named whatever the server holds
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
    _sentQuantity = _quantity.text;
    _sentPrice = _price.text;
    _sentReplacement = _buysReplacement;
    final void Function(ShopperOrder answer) close = _closer();
    final ShopperOrder? done = await _controller.purchase(entry);
    if (mounted && done != null) {
      close(done);
    }
  }

  Future<void> _askAboutPrice() async {
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

  /// Whether more than the Customer is owed is typed.
  bool get _exceedsNeeded {
    final String? typed = QuantityRules.normalize(
      widget.line.unit,
      _quantity.text,
    );
    return typed != null &&
        QuantityRules.thousandths(typed) > QuantityRules.thousandths(_needed);
  }

  Widget _tab({
    required String tabKey,
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        key: ValueKey<String>(tabKey),
        color: selected ? KitColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? Colors.white : KitColors.ink2,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : KitColors.ink2,
                      ),
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
    final String? boughtImage = _buysReplacement
        ? replacement!.imageUrl
        : line.imageUrl;
    final int? bound = _buysReplacement
        ? replacement!.bound.marketPriceUzs
        : line.bound?.marketPriceUzs;
    final bool priceRequired =
        _buysReplacement || line.priceMode == PriceMode.estimate;
    final bool fraction = line.unit.takesFraction;
    final String unit = CatalogLabels.unit(l10n, line.unit);
    final String needed = '${QuantityRules.display(_needed)} $unit';
    final ApiFailure? failure = change.failure;
    final ApiRefusal? approval =
        failure is ApiRefusal && failure.code == 'customer_approval_required'
        ? failure
        : null;
    final Object? approvalType = approval?.error.details['approval_type'];
    final bool known =
        approvalType == 'price_over_tolerance' ||
        approvalType == 'reduced_quantity';
    // The question holds while the fields read what the refused purchase
    // was sent with.
    final bool asking =
        known &&
        _quantity.text == _sentQuantity &&
        _price.text == _sentPrice &&
        _buysReplacement == _sentReplacement;
    final bool askingPrice = asking && approvalType == 'price_over_tolerance';
    final bool askingQuantity = asking && approvalType == 'reduced_quantity';
    final Object? required = approval?.error.details['required_quantity'];
    final String typed = _sentQuantity == null
        ? ''
        : '${QuantityRules.display(QuantityRules.normalize(line.unit, _sentQuantity!) ?? _sentQuantity!)} $unit';

    final Widget quantityField = _LabeledField(
      label: l10n.purchaseQuantity,
      field: TextFormField(
        key: const ValueKey<String>('purchase-quantity'),
        controller: _quantity,
        enabled: !locked,
        keyboardType: TextInputType.numberWithOptions(decimal: fraction),
        style: _bigFieldStyle,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(
            RegExp(fraction ? r'[0-9.,]' : '[0-9]'),
          ),
          LengthLimitingTextInputFormatter(fraction ? 8 : 4),
        ],
        decoration: _fieldDecoration(
          suffix: unit,
          warn: askingQuantity,
          big: true,
        ),
        validator: (String? text) =>
            QuantityRules.normalize(line.unit, text ?? '') != null
            ? null
            : fraction
            ? l10n.cartQuantityFraction
            : l10n.cartQuantityWhole,
      ),
    );
    final bool sideBySide = asking && !kitLargeText(context);
    final Widget priceField = PriceField(
      fieldKey: 'purchase-price',
      controller: _price,
      label: sideBySide
          ? l10n.purchasePriceShort(unit)
          : l10n.purchasePriceFor(unit),
      required: priceRequired,
      enabled: !locked,
      helper: priceRequired ? null : l10n.purchasePriceOptional,
      warn: askingPrice,
    );

    final String info = bound != null
        ? l10n.purchaseMarketInfo(
            MoneyFormat.uzs(_marketPrice, language),
            MoneyFormat.uzs(bound, language),
            unit,
          )
        : l10n.purchaseMarketOnly(MoneyFormat.uzs(_marketPrice, language));

    return PopScope(
      canPop: !change.isBusy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ShopperSheetHeader(
                imageUrl: boughtImage,
                name: bought,
                detail: l10n.purchaseNeeded(needed),
              ),
              if (replacement != null) ...<Widget>[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: KitColors.field,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _tab(
                            tabKey: 'buy-replacement',
                            label: name(replacement.nameUz, replacement.nameRu),
                            icon: Icons.swap_horiz,
                            selected: _replacement,
                            enabled: !locked,
                            onTap: () => setState(() => _replacement = true),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: _tab(
                            tabKey: 'buy-original',
                            label: name(line.nameUz, line.nameRu),
                            selected: !_replacement,
                            enabled: !locked,
                            onTap: () => setState(() => _replacement = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.purchaseWhich(name(line.nameUz, line.nameRu)),
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
              ],
              const SizedBox(height: 16),
              if (sideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(child: quantityField),
                    const SizedBox(width: 12),
                    Expanded(child: priceField),
                  ],
                )
              else ...<Widget>[
                quantityField,
                if (_exceedsNeeded) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    l10n.purchaseExcess(needed),
                    key: const ValueKey<String>('purchase-excess'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.warningDark,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                priceField,
              ],
              const SizedBox(height: 14),
              KitNote(icon: Icons.verified_outlined, text: Text(info)),
              if (unanswered) ...<Widget>[
                const SizedBox(height: 10),
                KitNote(
                  icon: Icons.cloud_off,
                  tone: KitTone.grey,
                  text: Text(
                    l10n.purchaseUnconfirmed,
                    key: const ValueKey<String>('purchase-dialog-unconfirmed'),
                  ),
                ),
              ],
              if (asking) ...<Widget>[
                const SizedBox(height: 10),
                KitNote(
                  icon: Icons.help_outline,
                  tone: KitTone.amber,
                  text: Text(
                    askingPrice
                        ? l10n.purchaseAboveBound(
                            MoneyFormat.uzs(bound ?? _marketPrice, language),
                          )
                        : l10n.purchaseBelowQuantity(
                            required is String
                                ? '${QuantityRules.display(required)} $unit'
                                : needed,
                            typed,
                          ),
                    key: const ValueKey<String>('purchase-needs-customer'),
                  ),
                ),
                const SizedBox(height: 14),
                KitNoteField(
                  fieldKey: 'ask-note',
                  controller: _note,
                  label: l10n.askNote,
                  hint: l10n.askNotePlaceholder,
                  enabled: !change.isBusy,
                ),
              ] else if (!known) ...<Widget>[FailureMessage(failure)],
              const SizedBox(height: 20),
              if (asking)
                KitActionPair(
                  secondary: OutlinedButton(
                    key: const ValueKey<String>('purchase-cancel'),
                    style: kitOutlined(),
                    onPressed: change.isBusy
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancelButton),
                  ),
                  primary: FilledButton(
                    key: ValueKey<String>(
                      askingPrice ? 'ask-price' : 'ask-quantity',
                    ),
                    style: kitFilled(),
                    onPressed: change.isBusy
                        ? null
                        : askingPrice
                        ? _askAboutPrice
                        : _askAboutQuantity,
                    child: Text(l10n.askCustomer),
                  ),
                )
              else
                FilledButton(
                  key: const ValueKey<String>('purchase-save'),
                  style: kitFilled(),
                  onPressed: change.isBusy ? null : _buy,
                  child: Text(
                    unanswered ? l10n.purchaseAgain : l10n.purchaseSave,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The confirmation that a line is not to be found, with an optional note
/// kept on the history (`docs/09` section 31). When it was the last line to
/// buy, the order is cancelled, which the explanation says.
class UnavailableSheet extends ConsumerStatefulWidget {
  const UnavailableSheet({required this.order, required this.line, super.key});

  final ShopperOrder order;
  final ShopperLine line;

  @override
  ConsumerState<UnavailableSheet> createState() => _UnavailableSheetState();
}

class _UnavailableSheetState extends ConsumerState<UnavailableSheet> {
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
    final NavigatorState sheet = Navigator.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperOrder? done = await ref
        .read(shopperLineActionProvider(_lineRef).notifier)
        .markUnavailable(optionalNote(_note.text));
    if (mounted && done != null) {
      closeOnAnswer(
        sheet: sheet,
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
    final ShopperLine line = widget.line;
    final String name = interfaceLanguage(context) == AppLanguage.ru
        ? line.nameRu
        : line.nameUz;

    return PopScope(
      canPop: !change.isBusy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ShopperSheetHeader(
                imageUrl: line.imageUrl,
                name: name,
                detail:
                    '${QuantityRules.display(line.quantity)} '
                    '${CatalogLabels.unit(l10n, line.unit)}',
              ),
              const SizedBox(height: 16),
              Text(
                l10n.unavailableExplained(name),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: KitColors.ink2,
                ),
              ),
              const SizedBox(height: 16),
              KitNoteField(
                fieldKey: 'unavailable-note',
                controller: _note,
                label: l10n.actionNote,
                hint: l10n.unavailableNotePlaceholder,
                enabled: !change.isBusy,
              ),
              FailureMessage(change.failure),
              const SizedBox(height: 20),
              KitActionPair(
                secondary: OutlinedButton(
                  key: const ValueKey<String>('unavailable-cancel'),
                  style: kitOutlined(),
                  onPressed: change.isBusy
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancelButton),
                ),
                primary: FilledButton(
                  key: const ValueKey<String>('unavailable-confirm'),
                  style: kitFilled(color: KitColors.danger),
                  onPressed: change.isBusy ? null : _submit,
                  child: Text(l10n.unavailableConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
