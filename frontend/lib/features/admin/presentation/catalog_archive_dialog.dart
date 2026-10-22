import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_dialog.dart';

/// Asks before an archive (`DL-101` (2)): the [subject] in a box, what
/// archiving does in [explanation], and "Cancel" and the red "Archive".
///
/// [archive] runs the archive and answers whether it went through; the window
/// closes itself then. While it runs the window holds — the x, the scrim,
/// Escape and Cancel do nothing — and a refusal shows in it, [state]'s
/// failure, with the confirm button free to try again.
Future<void> showArchiveDialog(
  BuildContext context, {
  required String title,
  required String explanation,
  required Widget subject,
  required ProviderListenable<MutationState> state,
  required Future<bool> Function() archive,
}) {
  return showKitDialog<void>(
    context: context,
    dialogKey: 'archive-dialog',
    title: title,
    builder: (BuildContext dialog) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final MutationState change = ref.watch(state);
        final AppLocalizations l10n = AppLocalizations.of(context);

        Future<void> submit() async {
          if (await archive() && context.mounted) {
            Navigator.of(context).pop();
          }
        }

        return PopScope(
          canPop: !change.isBusy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: KitColors.field,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: subject,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                explanation,
                style: const TextStyle(fontSize: 13, color: KitColors.ink2),
              ),
              FailureMessage(change.failure),
              const SizedBox(height: 20),
              kitDialogButtons(
                context: context,
                busy: change.isBusy,
                confirmKey: const ValueKey<String>('archive-confirm'),
                confirm: l10n.catalogArchive,
                confirmIcon: Icons.archive_outlined,
                destructive: true,
                submit: submit,
              ),
            ],
          ),
        );
      },
    ),
  );
}
