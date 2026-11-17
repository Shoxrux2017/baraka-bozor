import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_sheet.dart';

/// Asks whether a new address that was filled in may be left unsaved
/// (`DL-138`). It names the street, or else the words, when there is one.
/// True for «Выйти»; closing the sheet any other way keeps the Customer on
/// the form.
Future<bool> showAddressLeaveSheet(BuildContext context, {String? name}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? leave = await showKitSheet<bool>(
    context,
    title: l10n.addressLeaveTitle,
    sheetKey: 'address-leave-sheet',
    builder: (BuildContext sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            name == null
                ? l10n.addressLeavePlain
                : l10n.addressLeaveNamed(name),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: KitColors.ink2,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const ValueKey<String>('address-leave-stay'),
            style: kitFilled(),
            onPressed: () => Navigator.of(sheet).pop(false),
            child: Text(l10n.addressLeaveStay),
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const ValueKey<String>('address-leave-go'),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: KitColors.danger,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.of(sheet).pop(true),
            child: Text(l10n.addressLeaveGo),
          ),
        ],
      ),
    ),
  );
  return leave ?? false;
}
