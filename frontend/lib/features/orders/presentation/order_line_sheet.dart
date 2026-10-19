import 'package:flutter/material.dart';

import '../../../core/catalog/catalog_values.dart';
import '../../../core/formatting/server_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/theme/kit_colors.dart';
import '../../cart/presentation/cart_widgets.dart';

/// What the Customer settled in the line's sheet: the quantity as the API
/// takes it, the note (`null` when empty) and the rule.
typedef OrderLineChoice = ({
  String quantity,
  String? note,
  SubstitutionPolicy policy,
});

/// Opens the options of one editor line (drawing 29и): its quantity, note
/// and rule, on copies of the line's values. "Сохранить" checks them and
/// answers the [OrderLineChoice]; closing the sheet any other way answers
/// `null` and changes nothing. With [onRemove] the sheet offers to take the
/// line out of the order, which closes it and calls [onRemove]; [removeKey]
/// is that button's key.
Future<OrderLineChoice?> showOrderLineSheet(
  BuildContext context, {
  required String name,
  required UnitCode unit,
  required String quantity,
  required String? note,
  required SubstitutionPolicy policy,
  required VoidCallback? onRemove,
  Key? removeKey,
}) => showModalBottomSheet<OrderLineChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext sheet) => _OrderLineSheet(
    name: name,
    unit: unit,
    quantity: quantity,
    note: note,
    policy: policy,
    onRemove: onRemove,
    removeKey: removeKey,
  ),
);

class _OrderLineSheet extends StatefulWidget {
  const _OrderLineSheet({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.note,
    required this.policy,
    required this.onRemove,
    required this.removeKey,
  });

  final String name;
  final UnitCode unit;
  final String quantity;
  final String? note;
  final SubstitutionPolicy policy;
  final VoidCallback? onRemove;
  final Key? removeKey;

  @override
  State<_OrderLineSheet> createState() => _OrderLineSheetState();
}

class _OrderLineSheetState extends State<_OrderLineSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _quantity = TextEditingController(
    text: editableQuantity(widget.unit, widget.quantity),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.note ?? '',
  );
  late SubstitutionPolicy _policy = widget.policy;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _done() {
    if (!_form.currentState!.validate()) {
      return;
    }
    final String note = trimLikeServer(_note.text);
    Navigator.of(context).pop<OrderLineChoice>((
      quantity: QuantityRules.normalize(widget.unit, _quantity.text)!,
      note: note.isEmpty ? null : note,
      policy: _policy,
    ));
  }

  void _remove() {
    final VoidCallback remove = widget.onRemove!;
    Navigator.of(context).pop();
    remove();
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
                  widget.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: KitColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LineOptionsFields(
                unit: widget.unit,
                quantity: _quantity,
                note: _note,
                policy: _policy,
                onPolicy: (SubstitutionPolicy policy) =>
                    setState(() => _policy = policy),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey<String>('edit-options-done'),
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
                  l10n.saveButton,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.onRemove != null) ...<Widget>[
                const SizedBox(height: 4),
                TextButton(
                  key: widget.removeKey,
                  style: TextButton.styleFrom(
                    foregroundColor: KitColors.danger,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _remove,
                  child: Text(
                    l10n.orderEditRemoveLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
