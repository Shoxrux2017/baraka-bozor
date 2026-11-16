import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/widgets/undo_bar.dart';
import '../application/address_removals.dart';
import '../application/addresses_controllers.dart';
import '../application/delivery_address.dart';
import '../domain/addresses.dart';

/// How long «Вернуть» stays up before the server is told (`DL-137`).
const Duration addressUndoDuration = Duration(seconds: 5);

/// Where the offer to take a removal back is shown (`DL-137`): the screen's
/// own bar, or the sheet's inline one.
abstract interface class UndoOffer {
  /// Shows [text] with «Вернуть», which runs [onUndo]. Completes when the
  /// offer has ended, however it ended.
  Future<void> show({required String text, required VoidCallback onUndo});

  /// Ends the offer now.
  void close();
}

/// The undo bar of the screen's `ScaffoldMessenger`. A bar queued behind the
/// one leaving cannot be closed yet (its controller asserts it is current), so
/// a close asked before it has come in waits until it has (`DL-137`).
final class ScreenUndoOffer implements UndoOffer {
  ScreenUndoOffer(this._messenger);

  final ScaffoldMessengerState _messenger;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _bar;
  bool _visible = false;
  bool _closeWhenVisible = false;

  @override
  Future<void> show({required String text, required VoidCallback onUndo}) {
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> bar =
        showUndoBar(
          _messenger,
          text: text,
          actionLabel: AppLocalizations.of(_messenger.context).undoAction,
          duration: addressUndoDuration,
          onUndo: onUndo,
          onVisible: _becameVisible,
        );
    _bar = bar;
    return bar.closed;
  }

  void _becameVisible() {
    _visible = true;
    if (_closeWhenVisible) {
      _closeWhenVisible = false;
      close();
    }
  }

  /// Ends the bar; one whose messenger is gone has already ended.
  @override
  void close() {
    if (!_messenger.mounted) {
      return;
    }
    if (_visible) {
      _bar?.close();
    } else if (_bar != null) {
      _closeWhenVisible = true;
    }
  }
}

/// The delivery address by the rule of `deliveryAddressProvider`, from the
/// list shown and the stored choice, so a list that is reloading still names
/// it.
Address? _deliveryOf(ProviderContainer container) {
  final List<Address> shown =
      container.read(shownAddressesProvider).value ?? const <Address>[];
  final String? account = container.read(customerAccountProvider);
  final String? chosen = account == null
      ? null
      : container.read(deliveryAddressChoiceProvider(account)).value;
  return shown.where((Address a) => a.id == chosen).firstOrNull ??
      shown.firstOrNull;
}

/// Takes [address] off the lists at once, offers «Вернуть», and tells the
/// server when the offer ends (`DL-137`). There is no question: the card folds,
/// the bar says where delivery goes when the delivery address was removed, and
/// a screen reader hears the same. When the server did not remove it the card
/// comes back and says why. [onRestored] hears the id of an address «Вернуть»
/// brought back.
///
/// The removal belongs to [container], not to the screen: leaving the screen
/// keeps the bar and the removal; only what needs the screen ([context]) is
/// skipped once it is gone.
Future<void> removeAddress(
  BuildContext context, {
  required ProviderContainer container,
  required Address address,
  required UndoOffer offer,
  ValueChanged<String>? onRestored,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final AddressRemovals removals = container.read(
    addressRemovalsProvider.notifier,
  );
  final String? deliveryBefore = _deliveryOf(container)?.id;
  final AddressRemoval removal = AddressRemoval(address);
  removals.hold(removal, closeBar: offer.close);

  // The removal is already hidden, so this names where delivery goes now.
  final String? next = deliveryBefore == address.id
      ? _deliveryOf(container)?.name
      : null;
  final String name = address.name;
  final String text = next == null
      ? l10n.addressRemovedBar(name)
      : l10n.addressRemovedBarDelivery(name, next);
  final String spoken = next == null
      ? l10n.addressRemovedSpoken(name)
      : l10n.addressRemovedSpokenDelivery(name, next);

  final Future<void> closed = offer.show(
    text: text,
    onUndo: () {
      // A removal already sent has nothing to bring back and says nothing.
      if (removals.undo(removal)) {
        onRestored?.call(address.id);
        if (context.mounted) {
          announce(context, l10n.addressRestoredSpoken(name));
        }
      }
    },
  );
  announce(context, spoken);

  // «Вернуть» leaves the removal undone, so its commit sends nothing; any
  // other end of the offer sends it.
  await closed;
  final ApiFailure? failure = await removals.commit(removal);
  if (failure != null && context.mounted) {
    announce(
      context,
      failure is NetworkFailure
          ? l10n.addressNotRemovedSpoken(name)
          : l10n.addressNotRemovedOtherSpoken(name),
    );
  }
}
