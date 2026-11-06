import 'package:flutter/material.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/cancel_draft.dart';
import 'kit_choice_chip.dart';

/// The reason part of the cancel sheet (`DL-133`): the chips, the button that
/// opens the details, the field with its label and counter, and the tips.
/// It holds no state of its own beyond the tip's entrance; [draft] is the
/// sheet's, and every change goes out through [onChanged]. [locked] is while
/// a send is on its way.
class CancelReasonForm extends StatelessWidget {
  const CancelReasonForm({
    required this.draft,
    required this.request,
    required this.canEdit,
    required this.onChanged,
    required this.onEdit,
    required this.text,
    required this.focus,
    this.locked = false,
    super.key,
  });

  final CancelDraft draft;
  final bool request;

  /// Whether the order can still be edited, which the editor tip needs.
  final bool canEdit;
  final ValueChanged<CancelDraft> onChanged;
  final VoidCallback onEdit;
  final TextEditingController text;
  final FocusNode focus;
  final bool locked;

  /// The tip under the chips: «Заказал не то» offers the editor when the
  /// order allows it, «Нужен другой адрес» explains repeating the order; only
  /// the direct face has them.
  _Tip? _tip(AppLocalizations l10n) {
    if (request) {
      return null;
    }
    switch (draft.chip) {
      case CancelChip.wrongItems:
        return canEdit
            ? _Tip(
                key: const ValueKey<String>('cancel-tip-edit'),
                icon: Icons.edit_note,
                text: l10n.cancelTipEdit,
                buttonText: l10n.cancelTipEditButton,
                onButton: onEdit,
              )
            : null;
      case CancelChip.otherAddress:
        return _Tip(
          key: const ValueKey<String>('cancel-tip-address'),
          icon: Icons.info_outline,
          text: l10n.cancelTipAddress,
        );
      case CancelChip.changedMind:
      case CancelChip.tooSlow:
      case CancelChip.other:
      case null:
        return null;
    }
  }

  void _focusLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  void _tapChip(BuildContext context, AppLocalizations l10n, CancelChip chip) {
    if (locked) {
      return;
    }
    final bool clear = draft.chip == chip;
    onChanged(
      clear
          ? draft.copyWith(clearChip: true)
          : draft.copyWith(
              chip: chip,
              details: draft.details || chip == CancelChip.other,
            ),
    );
    final String label = cancelChipLabel(l10n, chip);
    announce(
      context,
      clear ? l10n.cancelChipSpokenOff(label) : l10n.cancelChipSpokenOn(label),
    );
    if (!clear && chip == CancelChip.other) {
      _focusLater();
    }
  }

  void _openDetails() {
    if (locked) {
      return;
    }
    onChanged(draft.copyWith(details: true));
    _focusLater();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool fieldShown = draft.details || draft.text.isNotEmpty;
    final bool own = draft.chip == null || draft.chip == CancelChip.other;
    final int left =
        cancelReasonLimit -
        composeCancelReason(
          draft,
          (CancelChip chip) => cancelChipLabel(l10n, chip),
        ).runes.length;
    final _Tip? tip = _tip(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            text: request ? l10n.cancelChipsRequest : l10n.cancelChipsDirect,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: KitColors.ink,
            ),
            children: <InlineSpan>[
              TextSpan(
                text:
                    ' ${request ? l10n.cancelChipsForOperator : l10n.cancelChipsOptional}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: KitColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final CancelChip chip in CancelChip.values)
              KitChoiceChip(
                key: ValueKey<String>('cancel-chip-${chip.name}'),
                label: cancelChipLabel(l10n, chip),
                hint: l10n.cancelChipPosition(
                  chip.index + 1,
                  CancelChip.values.length,
                ),
                chosen: draft.chip == chip,
                enabled: !locked,
                onTap: () => _tapChip(context, l10n, chip),
              ),
          ],
        ),
        if (tip != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Rise(key: ValueKey<Key?>(tip.key), child: tip),
          ),
        if (!fieldShown)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                key: const ValueKey<String>('cancel-more'),
                style: TextButton.styleFrom(
                  foregroundColor: KitColors.primaryDark,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: locked ? null : _openDetails,
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  l10n.cancelAddDetails,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        else ...<Widget>[
          const SizedBox(height: 16),
          ExcludeSemantics(
            child: Text(
              own ? l10n.cancelFieldOwn : l10n.cancelFieldDetails,
              key: const ValueKey<String>('cancel-field-label'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: KitColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: request
                ? l10n.cancelFieldRequestSpoken
                : l10n.cancelFieldDirectSpoken,
            child: TextField(
              key: const ValueKey<String>('cancel-reason'),
              controller: text,
              focusNode: focus,
              readOnly: locked,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: KitColors.ink,
              ),
              decoration: InputDecoration(
                hintText: own
                    ? l10n.cancelFieldOwnHint
                    : l10n.cancelFieldDetailsHint,
                hintStyle: const TextStyle(color: KitColors.muted),
                filled: true,
                fillColor: KitColors.field,
                counterText: '',
                constraints: const BoxConstraints(minHeight: 50),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (left < 50)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  left >= 0 ? l10n.cancelLeft(left) : l10n.cancelOver(-left),
                  key: const ValueKey<String>('cancel-counter'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: left < 0 ? KitColors.danger : KitColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// A tip under the chips, with the button that acts on it when it has one;
/// above 1.3 at 13 px, or when the words would be left too narrow beside it,
/// the button goes under the words.
class _Tip extends StatelessWidget {
  const _Tip({
    required this.icon,
    required this.text,
    this.buttonText,
    this.onButton,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? buttonText;
  final VoidCallback? onButton;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final Widget words = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: KitColors.ink2,
        ),
      ),
    );
    final Icon mark = Icon(icon, size: 20, color: KitColors.primaryDark);
    final Widget? button = buttonText == null
        ? null
        : TextButton(
            key: const ValueKey<String>('cancel-tip-edit-button'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: KitColors.primaryDark,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onButton,
            child: Text(
              buttonText!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          );
    final double buttonWidth = buttonText == null
        ? 0
        : textWidth(
                context,
                buttonText!,
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ) +
              24;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        // Inside: 12 + icon 20 + 10 before the words, 10 and the button, 6.
        final bool large =
            textScaleAt(scaler, 13) > 1.3 ||
            box.maxWidth - 12 - 20 - 10 - 10 - buttonWidth - 6 < 120;
        return Container(
          padding: EdgeInsets.fromLTRB(
            12,
            6,
            large || button == null ? 12 : 6,
            6,
          ),
          decoration: BoxDecoration(
            color: KitColors.primaryWash,
            borderRadius: BorderRadius.circular(12),
          ),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: mark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: words),
                      ],
                    ),
                    if (button != null) ...<Widget>[
                      const SizedBox(height: 6),
                      button,
                    ],
                  ],
                )
              : Row(
                  children: <Widget>[
                    mark,
                    const SizedBox(width: 10),
                    Expanded(child: words),
                    if (button != null) ...<Widget>[
                      const SizedBox(width: 10),
                      button,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

/// A tip's entrance: it rises 8 px while it fades in over 260 ms; with
/// reduced motion it only fades.
class _Rise extends StatelessWidget {
  const _Rise({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(0.2, 0.8, 0.2, 1),
      builder: (BuildContext context, double value, Widget? child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : (1 - value) * 8),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
