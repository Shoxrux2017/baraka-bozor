import 'package:flutter/material.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/orders/estimate_preview.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/presentation/cart_widgets.dart';

/// Asks for an exact quantity of the product [name] in [unit] (drawing 18a,
/// `DL-122`), starting from [current]. It opens typing, offers a few usual
/// quantities and, when the product has a price ([unitPriceUzs]), shows what
/// the quantity would cost. Answers the quantity as the API takes it, or
/// `null` when the sheet is dismissed. «Готово» does nothing while the text is
/// no quantity.
Future<String?> showQuantitySheet(
  BuildContext context, {
  required UnitCode unit,
  required String current,
  required String name,
  int? unitPriceUzs,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext context) => _QuantitySheet(
    unit: unit,
    current: current,
    name: name,
    unitPriceUzs: unitPriceUzs,
  ),
);

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({
    required this.unit,
    required this.current,
    required this.name,
    required this.unitPriceUzs,
  });

  final UnitCode unit;
  final String current;
  final String name;
  final int? unitPriceUzs;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final String text = editableQuantity(widget.unit, widget.current);
    _controller = TextEditingController(text: text)
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length)
      ..addListener(_changed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  /// The text as the API takes it, or `null` while it is no quantity.
  String? get _quantity =>
      QuantityRules.normalize(widget.unit, _controller.text);

  void _pick(String chip) {
    final String text = QuantityRules.display(chip);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _done() {
    final String? quantity = _quantity;
    if (quantity != null) {
      Navigator.of(context).pop(quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final UnitCode unit = widget.unit;
    final String unitLabel = CatalogLabels.unit(l10n, unit);
    final String? quantity = _quantity;
    final bool empty = _controller.text.trim().isEmpty;
    final bool wrong = quantity == null && !empty;
    final List<String> chips = unit.takesFraction
        ? const <String>['0.5', '1', '1.5', '2', '3']
        : const <String>['1', '2', '3', '5', '10'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KitColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.quantitySheetAsk(widget.name, unit.name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _field(l10n, unitLabel, wrong: wrong),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String chip in chips)
                    _Chip(
                      value: chip,
                      selected:
                          quantity != null &&
                          QuantityRules.thousandths(quantity) ==
                              QuantityRules.thousandths(chip),
                      onTap: () => _pick(chip),
                    ),
                ],
              ),
              ..._preview(l10n, quantity, empty: empty, unitLabel: unitLabel),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey<String>('quantity-done'),
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _done,
                child: Text(
                  l10n.quantitySheetDone,
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
    );
  }

  Widget _field(
    AppLocalizations l10n,
    String unitLabel, {
    required bool wrong,
  }) {
    final OutlineInputBorder outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: wrong ? KitColors.danger : KitColors.primary,
        width: 1.5,
      ),
    );
    return Semantics(
      label: '${l10n.cartQuantity}, $unitLabel',
      child: TextFormField(
        key: const ValueKey<String>('line-quantity'),
        controller: _controller,
        autofocus: true,
        keyboardType: quantityKeyboard(widget.unit),
        inputFormatters: quantityInputFormatters(widget.unit),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _done(),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: KitColors.ink,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: KitColors.field,
          constraints: BoxConstraints(
            minHeight: MediaQuery.textScalerOf(context).scale(58),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixText: unitLabel,
          suffixStyle: const TextStyle(fontSize: 15, color: KitColors.muted),
          border: outline,
          enabledBorder: outline,
          focusedBorder: outline,
        ),
      ),
    );
  }

  /// The line under the chips: what the quantity would cost, a request for
  /// one, or what is wrong with the text; nothing for a product without a
  /// price while the text is a quantity.
  List<Widget> _preview(
    AppLocalizations l10n,
    String? quantity, {
    required bool empty,
    required String unitLabel,
  }) {
    final int? price = widget.unitPriceUzs;
    final String text;
    final Color color;
    if (quantity != null) {
      if (price == null) {
        return const <Widget>[];
      }
      final String sum = MoneyFormat.uzs(
        EstimatePreview.lineUzs(price, quantity),
        interfaceLanguage(context),
      );
      final String shown = '${QuantityRules.display(quantity)} $unitLabel';
      text = '${l10n.catalogApproxPrice(sum)} ${l10n.productSumFor(shown)}';
      color = KitColors.ink2;
    } else if (empty) {
      text = l10n.quantitySheetEmpty;
      color = KitColors.muted;
    } else {
      text = widget.unit.takesFraction
          ? l10n.cartQuantityFraction
          : l10n.cartQuantityWhole;
      color = KitColors.danger;
    }
    return <Widget>[
      const SizedBox(height: 12),
      Text(
        text,
        key: const ValueKey<String>('quantity-preview'),
        style: TextStyle(fontSize: 14, height: 1.4, color: color),
      ),
    ];
  }
}

/// One usual quantity; a tap writes it into the field.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: QuantityRules.display(value),
      onTap: onTap,
      child: Material(
        key: ValueKey<String>('quantity-chip-$value'),
        color: selected ? KitColors.primarySoft : KitColors.field,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? const BorderSide(color: KitColors.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 58, minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  QuantityRules.display(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? KitColors.primaryDark : KitColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
