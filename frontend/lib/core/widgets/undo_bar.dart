import 'package:flutter/material.dart';

import '../theme/kit_colors.dart';

/// How long the undo bar stays (`DL-119`). With a screen reader on it does not
/// leave on its own, see [showUndoBar].
const Duration undoBarDuration = Duration(seconds: 4);

/// Shows a floating bar with [text] and an [actionLabel] that runs [onUndo]
/// and closes the bar. It hides the current snack bar first. It leaves after
/// [undoBarDuration]; with a screen reader on it stays until its action, a
/// swipe or the next bar, so the person can reach the action (`DL-119`).
void showUndoBar(
  ScaffoldMessengerState messenger, {
  required String text,
  required String actionLabel,
  required VoidCallback onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: KitColors.undoBar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: undoBarDuration,
        persist: MediaQuery.accessibleNavigationOf(messenger.context),
        content: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () {
                onUndo();
                messenger.hideCurrentSnackBar();
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: KitColors.undoAction,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KitColors.undoAction,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
