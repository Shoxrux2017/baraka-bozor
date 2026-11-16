import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_empty_state.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../../core/widgets/swipe_to_remove.dart';
import '../application/address_removals.dart';
import '../application/addresses_controllers.dart';
import '../application/delivery_address.dart';
import '../domain/addresses.dart';
import 'address_card.dart';
import 'address_removal_flow.dart';

/// What the list is showing.
enum _Face { loading, failed, empty, cards }

/// The Customer's addresses (`docs/09-api-contracts.md` section 13) as the
/// kit draws them (`DL-137`): cards that fold and fade, a full-width add
/// button under them, skeletons while the list has never loaded, a kit block
/// when it could not, and an empty state. A reload that fails while the list
/// is held leaves its cards where they are.
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen>
    with SingleTickerProviderStateMixin {
  /// The cards replacing the skeleton fade in over this.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _fadeOpacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );

  /// The face being drawn.
  _Face? _face;

  /// The card whose «Удалить» is showing, at most one.
  String? _revealed;

  /// How often each card was asked to glow.
  Map<String, int> _glows = const <String, int>{};

  /// A list emptied by a removal is drawn as cards until the last of them has
  /// folded; then the empty state takes over (`DL-137`).
  Timer? _emptyTimer;
  bool _emptyDue = false;

  /// The delivery address last known, so a reload does not take the mark off
  /// the card and pop it back on.
  String? _deliveryId;

  @override
  void dispose() {
    _emptyTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  _Face _faceOf(AsyncValue<List<Address>> shown) {
    if (shown.hasValue) {
      return shown.requireValue.isEmpty ? _Face.empty : _Face.cards;
    }
    return shown.isLoading ? _Face.loading : _Face.failed;
  }

  void _choose(Address address) {
    final String? account = ref.read(customerAccountProvider);
    if (account == null) {
      return;
    }
    unawaited(
      ref
          .read(deliveryAddressChoiceProvider(account).notifier)
          .choose(address.id),
    );
    unawaited(HapticFeedback.lightImpact());
    announce(
      context,
      AppLocalizations.of(context).addressDeliveryChosenSpoken(address.name),
    );
  }

  /// The removal runs on the container, so it outlives this screen.
  void _remove(Address address) {
    if (_revealed != null) {
      setState(() => _revealed = null);
    }
    unawaited(
      removeAddress(
        context,
        container: ProviderScope.containerOf(context),
        address: address,
        offer: ScreenUndoOffer(ScaffoldMessenger.of(context)),
        onRestored: (String id) {
          if (mounted) {
            setState(
              () =>
                  _glows = <String, int>{..._glows, id: (_glows[id] ?? 0) + 1},
            );
          }
        },
      ),
    );
  }

  void _reveal(String id, {required bool open}) {
    final String? next = open ? id : (_revealed == id ? null : _revealed);
    if (next != _revealed) {
      setState(() => _revealed = next);
    }
  }

  void _closeRevealed() {
    if (_revealed != null) {
      setState(() => _revealed = null);
    }
  }

  /// The empty state waits for the last card's fold.
  _Face _heldFace(_Face face) {
    if (face != _Face.empty) {
      _emptyTimer?.cancel();
      _emptyTimer = null;
      _emptyDue = false;
      return face;
    }
    if (_face != _Face.cards || _emptyDue) {
      return face;
    }
    _emptyTimer ??= Timer(
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      () {
        _emptyTimer = null;
        if (mounted) {
          setState(() => _emptyDue = true);
        }
      },
    );
    return _Face.cards;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Address>> shown = ref.watch(shownAddressesProvider);
    final AsyncValue<Address?> delivery = ref.watch(deliveryAddressProvider);
    if (delivery.hasValue) {
      _deliveryId = delivery.requireValue?.id;
    }

    final _Face face = _heldFace(_faceOf(shown));
    if (_face == _Face.loading &&
        face == _Face.cards &&
        !MediaQuery.disableAnimationsOf(context)) {
      _fade
        ..value = 0
        ..forward();
    }
    _face = face;

    final Widget body = switch (face) {
      _Face.loading => const _Skeletons(),
      _Face.failed => KitEmptyState(
        quiet: true,
        icon: Icons.cloud_off,
        title: l10n.addressesFailedTitle,
        text: shown.error is NetworkFailure
            ? l10n.addressesFailedOffline
            : l10n.addressesFailedOther,
        actionLabel: l10n.retryButton,
        actionIcon: Icons.refresh,
        actionKey: const ValueKey<String>('addresses-retry'),
        onAction: () => ref.invalidate(addressesProvider),
      ),
      _Face.empty => KitEmptyState(
        icon: Icons.location_on,
        title: l10n.addressNone,
        text: l10n.addressesEmptyText,
        actionLabel: l10n.addressesAdd,
        actionIcon: Icons.add,
        actionKey: const ValueKey<String>('address-new'),
        onAction: _addNew,
      ),
      _Face.cards => _Cards(
        addresses: shown.requireValue,
        fade: _fadeOpacity,
        deliveryId: _deliveryId,
        onEdit: _edit,
        onChoose: _choose,
        onDelete: _remove,
        revealed: _revealed,
        glows: _glows,
        onReveal: _reveal,
        onCloseRevealed: _closeRevealed,
      ),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: l10n.addressesTitle),
      body: SafeArea(
        bottom: false,
        child: UnderActiveMode(
          child: Column(
            children: <Widget>[
              Expanded(child: body),
              if (face != _Face.empty)
                _Footer(label: l10n.addressesAdd, onPressed: _addNew),
            ],
          ),
        ),
      ),
    );
  }

  void _addNew() => context.push(AppPaths.customerNewAddress);

  void _edit(Address address) =>
      context.push(AppPaths.customerAddress(address.id));
}

/// The cards, in a column that folds them in and out.
class _Cards extends ConsumerWidget {
  const _Cards({
    required this.addresses,
    required this.fade,
    required this.deliveryId,
    required this.onEdit,
    required this.onChoose,
    required this.onDelete,
    required this.revealed,
    required this.glows,
    required this.onReveal,
    required this.onCloseRevealed,
  });

  final List<Address> addresses;
  final Animation<double> fade;
  final String? deliveryId;
  final void Function(Address) onEdit;
  final void Function(Address) onChoose;
  final void Function(Address) onDelete;
  final String? revealed;
  final Map<String, int> glows;
  final void Function(String id, {required bool open}) onReveal;
  final VoidCallback onCloseRevealed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AddressRemovalsState removals = ref.watch(addressRemovalsProvider);
    final ({String id, ApiFailure failure})? notRemoved = removals.notRemoved;
    final AppLocalizations l10n = AppLocalizations.of(context);

    // A scroll that starts closes the open card; one that is not vertical is
    // a card's own swipe.
    return NotificationListener<ScrollStartNotification>(
      onNotification: (ScrollStartNotification start) {
        if (revealed != null && start.metrics.axis == Axis.vertical) {
          onCloseRevealed();
        }
        return false;
      },
      child: ListView(
        key: const ValueKey<String>('addresses-list'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: <Widget>[
          FadeTransition(
            key: const ValueKey<String>('addresses-fade'),
            opacity: fade,
            child: FoldingColumn<Address>(
              items: addresses,
              keyOf: (Address a) => a.id,
              itemBuilder: (BuildContext context, Address address) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TapRegion(
                  enabled: revealed == address.id,
                  onTapOutside: (_) => onCloseRevealed(),
                  child: SwipeToRemove(
                    label: l10n.addressRemove,
                    radius: 16,
                    reveal: true,
                    semanticsAction: false,
                    buttonKey: ValueKey<String>('address-reveal-${address.id}'),
                    removing: removals.hidden.contains(address.id),
                    revealed: revealed == address.id,
                    onRevealChanged: (bool open) =>
                        onReveal(address.id, open: open),
                    onRemove: () => onDelete(address),
                    child: AddressListCard(
                      address: address,
                      spaceAbove: 0,
                      delivery: address.id == deliveryId,
                      onEdit: () => onEdit(address),
                      onChoose: () => onChoose(address),
                      onDelete: () => onDelete(address),
                      onMenuOpened: onCloseRevealed,
                      glow: glows[address.id] ?? 0,
                      notRemoved: notRemoved?.id == address.id
                          ? notRemoved!.failure
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-width add button under the list.
class _Footer extends StatelessWidget {
  const _Footer({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('addresses-footer'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: FilledButton(
        key: const ValueKey<String>('address-new'),
        style: kitFilled(),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.add, size: 22),
            const SizedBox(width: 10),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

/// Three card-shaped placeholders while the list has never loaded; they
/// speak once, as one «Загружаем адреса».
class _Skeletons extends StatelessWidget {
  const _Skeletons();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).addressesLoadingSpoken,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: const <Widget>[
            _SkeletonCard(),
            _SkeletonCard(),
            _SkeletonCard(),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        key: const ValueKey<String>('address-skeleton'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12151D16),
              blurRadius: 14,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SkeletonBar(width: 44, height: 44, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) =>
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SkeletonBar(width: box.maxWidth * 0.42, height: 14),
                            const SizedBox(height: 9),
                            SkeletonBar(width: box.maxWidth * 0.78, height: 12),
                            const SizedBox(height: 9),
                            SkeletonBar(width: box.maxWidth * 0.56, height: 11),
                          ],
                        ),
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
