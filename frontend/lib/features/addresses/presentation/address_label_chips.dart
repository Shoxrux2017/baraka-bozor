import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// Which name the Customer gives an address: none, one of the two common
/// words, or their own.
enum AddressLabelKind { none, home, work, custom }

/// The kind an existing [label] belongs to: the current language's word for
/// home or work picks its chip, any other text is the Customer's own.
AddressLabelKind addressLabelKindOf(String? label, AppLocalizations l10n) {
  final String text = (label ?? '').trim();
  if (text.isEmpty) {
    return AddressLabelKind.none;
  }
  if (text == l10n.addressLabelHome) {
    return AddressLabelKind.home;
  }
  if (text == l10n.addressLabelWork) {
    return AddressLabelKind.work;
  }
  return AddressLabelKind.custom;
}

/// The chips of "Как назвать адрес" (drawing 22а): Дом, Работа, Своё. Tapping
/// the chosen chip clears the choice.
class AddressLabelChips extends StatelessWidget {
  const AddressLabelChips({
    required this.kind,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final AddressLabelKind kind;
  final bool enabled;
  final ValueChanged<AddressLabelKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _chip(
          'label-home',
          AddressLabelKind.home,
          Icons.home_outlined,
          l10n.addressLabelHome,
        ),
        _chip(
          'label-work',
          AddressLabelKind.work,
          Icons.work_outline,
          l10n.addressLabelWork,
        ),
        _chip(
          'label-custom',
          AddressLabelKind.custom,
          Icons.edit_outlined,
          l10n.addressLabelCustom,
        ),
      ],
    );
  }

  Widget _chip(String key, AddressLabelKind own, IconData icon, String text) {
    final bool selected = kind == own;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? KitColors.primaryWash : KitColors.field,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? KitColors.primary : KitColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey<String>(key),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: enabled
              ? () => onChanged(selected ? AddressLabelKind.none : own)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? KitColors.primaryDark : KitColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? KitColors.primaryDark : KitColors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
