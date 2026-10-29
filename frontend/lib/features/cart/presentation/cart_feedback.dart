import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/failure_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/undo_bar.dart';
import '../../../core/session/customer_account.dart';
import '../application/cart_quantity_queue.dart';
import '../domain/cart.dart';

/// Says in a snackbar why a cart change did not hold (`DL-119`): nothing for
/// `null`, that the cart stayed as it was when the connection is lost, the
/// failure's own text otherwise.
void showCartFailure(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  ApiFailure? failure,
) {
  if (failure == null || !messenger.mounted) {
    return;
  }
  final String? text = failure is NetworkFailure
      ? l10n.cartNotSaved
      : failureText(l10n, failure);
  if (text == null) {
    return;
  }
  // Cleared, not hidden: a bar that has not drawn its first frame does not
  // hide, and a removal's own undo bar may still be queued behind the current
  // one; none of them may outlive the failure (`DL-119`).
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Takes [line] out of the cart at once and offers to put it back with its
/// note and rule (`DL-119`). [quantity] is what the Customer saw; [name] is
/// the product's name in the interface language. A line no longer sold is
/// only announced, because the server refuses to add it back.
Future<void> removeCartLine(
  BuildContext context,
  WidgetRef ref, {
  required CartLine line,
  required String quantity,
  required String name,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final AppLocalizations l10n = AppLocalizations.of(context);
  final CartQuantityQueue queue = ref.read(cartQuantityQueueProvider.notifier);
  final NewCartLine again = NewCartLine(
    productId: line.productId,
    quantity: quantity,
    customerNote: line.customerNote,
    substitutionPolicy: line.substitutionPolicy,
  );
  final String? account = ref.read(customerAccountProvider);
  final String text = l10n.cartLineRemoved(name);
  final Future<ApiFailure?> removal = queue.remove(line.productId);
  if (line.isAvailable) {
    showUndoBar(
      messenger,
      text: text,
      actionLabel: l10n.undoAction,
      onUndo: () async {
        showCartFailure(
          messenger,
          l10n,
          await queue.restore(again, account: account),
        );
      },
    );
  } else {
    announce(context, text);
  }
  showCartFailure(messenger, l10n, await removal);
}
