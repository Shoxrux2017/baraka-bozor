import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';

/// What the editor lost or would lose, one change to a line: the list box of
/// the exit sheet and the lock view (`DL-132`).
class ChangeList extends StatelessWidget {
  const ChangeList({required this.changes, this.listKey, super.key});

  final List<String> changes;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: listKey,
      decoration: BoxDecoration(
        color: KitColors.page,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String change in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  change,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
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

/// Asks «Выйти без сохранения?» over the editor, listing the [changes] that
/// would be lost (`DL-132`). Answers `true` to leave; «Продолжить изменять»,
/// a tap outside and the system back all answer `false` and keep editing.
Future<bool> showLeaveSheet(
  BuildContext context, {
  required List<String> changes,
}) async {
  final bool? leave = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheet) => _LeaveSheet(changes: changes),
  );
  return leave ?? false;
}

class _LeaveSheet extends StatelessWidget {
  const _LeaveSheet({required this.changes});

  final List<String> changes;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: const ValueKey<String>('edit-leave-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
              l10n.orderEditLeaveTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: KitColors.ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
            child: Text(
              l10n.orderEditLeaveCount(changes.length),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: KitColors.ink2,
              ),
            ),
          ),
          ChangeList(changes: changes),
          const SizedBox(height: 18),
          FilledButton(
            key: const ValueKey<String>('edit-keep-editing'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.orderEditKeepEditing,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey<String>('edit-leave'),
            style: TextButton.styleFrom(
              foregroundColor: KitColors.danger,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.orderEditLeave,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
