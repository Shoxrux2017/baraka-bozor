import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/formatting/address_format.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/addresses.dart';
import 'address_label_chips.dart';

const Cubic _kitCurve = Cubic(0.2, 0.8, 0.2, 1);

/// The pop of the «Доставка сюда» chip: 1 → 1.12 at 35 %, → 0.97 at 70 %,
/// → 1, each leg eased on its own as the drawing's keyframes are (`DL-137`).
final Animatable<double> _popScale = TweenSequence<double>(
  <TweenSequenceItem<double>>[
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 1,
        end: 1.12,
      ).chain(CurveTween(curve: _kitCurve)),
      weight: 35,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 1.12,
        end: 0.97,
      ).chain(CurveTween(curve: _kitCurve)),
      weight: 35,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 0.97,
        end: 1,
      ).chain(CurveTween(curve: _kitCurve)),
      weight: 30,
    ),
  ],
);

const Duration _popDuration = Duration(milliseconds: 340);
const int _glowDelayMs = 200;
const int _glowMs = 1500;

/// The glow's opacity [ms] after it was asked: nothing for 200 ms, then 0 → 1
/// by 15 % of 1500 ms, 1 until 45 %, → 0 at 100 %, each leg `easeOut`.
double _glowOpacity(double ms, {required int delayMs}) {
  final double t = (ms - delayMs) / _glowMs;
  if (t <= 0 || t >= 1) {
    return 0;
  }
  if (t < 0.15) {
    return Curves.easeOut.transform(t / 0.15);
  }
  if (t < 0.45) {
    return 1;
  }
  return 1 - Curves.easeOut.transform((t - 0.45) / 0.55);
}

/// What one menu item asks for.
enum _MenuAction { edit, choose, delete }

/// One address on «Мои адреса» as the drawing has it (`DL-137`): a lead
/// that follows the label, the name, the line with the flat, the landmark, a
/// «Доставка сюда» chip on the delivery address, a «⋯» menu, and a red line
/// when a removal did not go through.
///
/// The face is one stop for a screen reader that carries the menu's actions;
/// the chip pops when the card becomes the delivery address, and the card
/// glows each time [glow] grows (and on its first build when it is above 0).
class AddressListCard extends StatefulWidget {
  const AddressListCard({
    required this.address,
    required this.delivery,
    required this.onEdit,
    required this.onChoose,
    required this.onDelete,
    this.notRemoved,
    this.glow = 0,
    super.key,
  });

  final Address address;

  /// Whether this is the address an order is delivered to.
  final bool delivery;
  final VoidCallback onEdit;

  /// Makes this the delivery address; `null` where that cannot be asked.
  final VoidCallback? onChoose;
  final VoidCallback onDelete;

  /// Why the last removal of this address did not go through, if it did not.
  final ApiFailure? notRemoved;

  /// Grows by one each time the card should glow.
  final int glow;

  @override
  State<AddressListCard> createState() => _AddressListCardState();
}

class _AddressListCardState extends State<AddressListCard>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: _popDuration,
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _glowDelayMs + _glowMs),
  );
  int _glowDelay = _glowDelayMs;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    if (widget.glow > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playGlow());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(AddressListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.delivery && !oldWidget.delivery && !_reduced) {
      _pop.forward(from: 0);
    }
    if (widget.glow > oldWidget.glow) {
      _playGlow();
    }
  }

  /// The glow is no motion: it plays with reduced motion too, only at once.
  void _playGlow() {
    if (!mounted) {
      return;
    }
    _glowDelay = _reduced ? 0 : _glowDelayMs;
    _glow
      ..duration = Duration(milliseconds: _glowDelay + _glowMs)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Address address = widget.address;
    final String id = address.id;
    final String? label = address.label;
    final String? line = label == null
        ? addressApartmentPart(l10n, address.apartment)
        : addressFullLine(
            l10n,
            street: address.street,
            house: address.house,
            apartment: address.apartment,
          );
    final String? landmarkText = address.landmark?.trim();
    final String? landmark = landmarkText == null || landmarkText.isEmpty
        ? null
        : l10n.addressLandmarkLine(landmarkText);
    final ApiFailure? failure = widget.notRemoved;
    final String? failureText = failure == null
        ? null
        : failure is NetworkFailure
        ? l10n.addressNotRemovedOffline
        : l10n.addressNotRemovedOther;
    final VoidCallback? onChoose = widget.delivery ? null : widget.onChoose;

    final String spoken = <String?>[
      address.name,
      if (widget.delivery) l10n.addressDeliveryHereSpoken,
      line,
      landmark,
      failureText,
    ].whereType<String>().join(', ');

    final BorderRadius radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          DecoratedBox(
            key: ValueKey<String>('address-surface-$id'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: radius,
              border: widget.delivery
                  ? Border.all(color: KitColors.primary, width: 1.5)
                  : null,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12151D16),
                  blurRadius: 14,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Semantics(
              container: true,
              button: true,
              excludeSemantics: true,
              label: spoken,
              onTap: widget.onEdit,
              onTapHint: l10n.addressEditHint,
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                CustomSemanticsAction(label: l10n.addressRemove):
                    widget.onDelete,
                CustomSemanticsAction(label: l10n.addressDeliverHere):
                    ?onChoose,
              },
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey<String>('address-card-$id'),
                  onTap: widget.onEdit,
                  borderRadius: radius,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 48, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Lead(address: address, l10n: l10n),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Text(
                            title: address.name,
                            line: line,
                            landmark: landmark,
                            chip: widget.delivery
                                ? _DeliveryChip(
                                    id: id,
                                    text: l10n.addressDeliveryHere,
                                    pop: _pop,
                                  )
                                : null,
                            failure: failureText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 0,
            child: AddressMenuButton(
              address: address,
              keyPrefix: 'address',
              onEdit: widget.onEdit,
              onChoose: onChoose,
              onDelete: widget.onDelete,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (BuildContext context, Widget? child) => Opacity(
                    key: ValueKey<String>('address-glow-$id'),
                    opacity: _glowOpacity(
                      _glow.value *
                          (_glow.duration?.inMilliseconds ?? 1).toDouble(),
                      delayMs: _glowDelay,
                    ),
                    child: child,
                  ),
                  child: const _GlowRings(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's glow: a 2 px ring inside and a 4 px ring outside it.
class _GlowRings extends StatelessWidget {
  const _GlowRings();

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: const Color(0xE63A9E46), width: 2),
            ),
          ),
        ),
        Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x473A9E46), width: 4),
            ),
          ),
        ),
      ],
    );
  }
}

class _Lead extends StatelessWidget {
  const _Lead({required this.address, required this.l10n});

  final Address address;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (addressLabelKindOf(address.label, l10n)) {
      AddressLabelKind.home => Icons.home_outlined,
      AddressLabelKind.work => Icons.work_outline,
      _ => Icons.location_on_outlined,
    };
    return Container(
      key: ValueKey<String>('address-lead-${address.id}'),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: KitColors.primaryWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 24, color: KitColors.primary),
    );
  }
}

class _Text extends StatelessWidget {
  const _Text({
    required this.title,
    required this.line,
    required this.landmark,
    required this.chip,
    required this.failure,
  });

  final String title;
  final String? line;
  final String? landmark;
  final Widget? chip;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            title,
            style: const TextStyle(
              color: KitColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        if (line != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              line!,
              style: const TextStyle(
                color: KitColors.ink2,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        if (landmark != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              landmark!,
              style: const TextStyle(
                color: KitColors.muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        if (chip != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: chip),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              failure!,
              style: const TextStyle(
                color: KitColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({
    required this.id,
    required this.text,
    required this.pop,
  });

  final String id;
  final String text;
  final Animation<double> pop;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pop,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        key: ValueKey<String>('address-chip-$id'),
        scale: pop.isAnimating ? _popScale.evaluate(pop) : 1,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
        decoration: BoxDecoration(
          color: KitColors.primaryWash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check, size: 16, color: KitColors.primaryDark),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: KitColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The «⋯» of an address and its menu: edit, deliver here (when [onChoose] is
/// given), and a red delete (`DL-137`). Keys are `<keyPrefix>-menu-<id>`,
/// `-edit-`, `-choose-` and `-delete-`.
class AddressMenuButton extends StatelessWidget {
  const AddressMenuButton({
    required this.address,
    required this.keyPrefix,
    required this.onEdit,
    required this.onDelete,
    this.onChoose,
    super.key,
  });

  final Address address;
  final String keyPrefix;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onChoose;

  PopupMenuItem<_MenuAction> _item(
    _MenuAction action,
    String name,
    IconData icon,
    String text, {
    Color color = KitColors.ink,
  }) {
    return PopupMenuItem<_MenuAction>(
      key: ValueKey<String>('$keyPrefix-$name-${address.id}'),
      value: action,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(
            child: Text(text, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final VoidCallback? choose = onChoose;
    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<_MenuAction>(
        key: ValueKey<String>('$keyPrefix-menu-${address.id}'),
        tooltip: l10n.addressActionsSpoken(address.name),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, color: KitColors.ink),
        position: PopupMenuPosition.under,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: KitColors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(minWidth: 208),
        onSelected: (_MenuAction action) {
          switch (action) {
            case _MenuAction.edit:
              onEdit();
            case _MenuAction.choose:
              choose?.call();
            case _MenuAction.delete:
              onDelete();
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<_MenuAction>>[
          _item(
            _MenuAction.edit,
            'edit',
            Icons.edit_outlined,
            l10n.addressMenuEdit,
          ),
          if (choose != null)
            _item(
              _MenuAction.choose,
              'choose',
              Icons.where_to_vote_outlined,
              l10n.addressDeliverHere,
            ),
          _item(
            _MenuAction.delete,
            'delete',
            Icons.delete_outline,
            l10n.addressRemove,
            color: KitColors.danger,
          ),
        ],
      ),
    );
  }
}
