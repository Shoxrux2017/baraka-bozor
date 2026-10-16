import 'package:flutter/material.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/presentation/cart_widgets.dart';

/// Asks for an exact quantity of a product in [unit] (drawing 18a), starting
/// from [current]. Answers the quantity as the API takes it, or `null` when
/// the sheet is dismissed. An entry the cart would refuse shows the field's
/// error and keeps the sheet open.
Future<String?> showQuantitySheet(
  BuildContext context, {
  required UnitCode unit,
  required String current,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext context) =>
      _QuantitySheet(unit: unit, current: current),
);

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({required this.unit, required this.current});

  final UnitCode unit;
  final String current;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: editableQuantity(widget.unit, widget.current),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    if (!_form.currentState!.validate()) {
      return;
    }
    Navigator.of(context)
        .pop(QuantityRules.normalize(widget.unit, _controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _form,
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
                  l10n.quantitySheetTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              QuantityField(unit: widget.unit, controller: _controller),
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
}
