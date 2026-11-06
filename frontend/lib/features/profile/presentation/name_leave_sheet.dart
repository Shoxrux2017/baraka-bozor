import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// What the Customer chose when leaving the name editor with an unsaved name.
enum NameLeaveChoice { save, drop }

/// The sheet «Сохранить новое имя?» (kit drawing `pedit`, `DL-135` (12)):
/// shows the new [name] against the [old] one, or alone when there is none.
/// Completes with the choice, or `null` for a tap outside or a swipe down,
/// which keeps the editor open.
Future<NameLeaveChoice?> showNameLeaveSheet(
  BuildContext context, {
  required String name,
  required String? old,
}) {
  return showModalBottomSheet<NameLeaveChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheet) => _NameLeaveSheet(name: name, old: old),
  );
}

class _NameLeaveSheet extends StatelessWidget {
  const _NameLeaveSheet({required this.name, required this.old});

  final String name;
  final String? old;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? before = old;
    final String body = before != null && before.isNotEmpty
        ? l10n.profileLeaveInstead(name, before)
        : l10n.profileLeaveNew(name);

    return SingleChildScrollView(
      key: const ValueKey<String>('name-leave-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KitColors.fieldEdge,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              l10n.profileLeaveTitle,
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
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: KitColors.ink2,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            key: const ValueKey<String>('name-leave-save'),
            style: FilledButton.styleFrom(
              backgroundColor: KitColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: _buttonText,
            ),
            onPressed: () => Navigator.of(context).pop(NameLeaveChoice.save),
            child: Text(l10n.saveButton),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey<String>('name-leave-drop'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KitColors.ink,
              backgroundColor: Colors.white,
              side: const BorderSide(color: KitColors.outline),
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: _buttonText,
            ),
            onPressed: () => Navigator.of(context).pop(NameLeaveChoice.drop),
            child: Text(l10n.profileLeaveDrop),
          ),
        ],
      ),
    );
  }
}

const TextStyle _buttonText = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
);
