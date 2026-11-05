import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/rolling_amount.dart';
import '../application/order_draft.dart';
import '../application/order_edit_summary.dart';
import '../domain/customer_orders.dart';

/// What the save button says and whether it can be pressed, in this order of
/// precedence (`DL-132`): busy, the ✓ moment, no line kept, too many lines, a
/// line the server no longer sells, a shortfall to the minimum, nothing
/// changed — while the order is known — else the save.
enum SaveFace {
  saving,
  saved,
  keepOne,
  tooMany,
  removeFirst,
  shortfall,
  noChanges,
  save,
}

/// The face of the save button for what the editor holds now.
SaveFace saveFaceOf({
  required bool saving,
  required bool saved,
  required OrderDraft draft,
  required EditSummary summary,
  required int changes,
  bool orderKnown = true,
}) {
  final List<DraftLine> kept = draft.kept;
  if (saving) {
    return SaveFace.saving;
  }
  if (saved) {
    return SaveFace.saved;
  }
  if (kept.isEmpty) {
    return SaveFace.keepOne;
  }
  if (kept.length > orderMaxLines) {
    return SaveFace.tooMany;
  }
  if (draft.marked.isNotEmpty) {
    return SaveFace.removeFirst;
  }
  if (summary.shortfallUzs > 0) {
    return SaveFace.shortfall;
  }
  // While the order loads again it is not known what it holds, and the edit
  // goes: the server answers a list that changes nothing as it is.
  if (changes == 0 && orderKnown) {
    return SaveFace.noChanges;
  }
  return SaveFace.save;
}

/// "≈" before [amountUzs] while [kind] is an estimate (`DL-132`).
String totalWords(
  AppLocalizations l10n,
  AppLanguage language,
  TotalKind kind,
  int amountUzs,
) {
  final String amount = MoneyFormat.uzs(amountUzs, language);
  return kind == TotalKind.estimate ? l10n.cartLineEstimate(amount) : amount;
}

const TextStyle _muted12 = TextStyle(
  fontSize: 12,
  height: 1.35,
  color: KitColors.muted,
);

/// The sums under the lines of the editor: the goods, delivery, fee and the
/// total, all the server's (`DL-132`, `AGENTS.md` section 5). They roll to a
/// new answer and stay dimmed while a newer one is awaited; when the sums
/// cannot be had they read «—».
class OrderEditTotals extends StatelessWidget {
  const OrderEditTotals({
    required this.keptCount,
    required this.summary,
    super.key,
  });

  final int keptCount;
  final EditSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final OrderEditPreview shown = summary.shown;
    final TotalKind kind = shown.totalKind;
    String sum(int amount) => MoneyFormat.uzs(amount, language);
    String estimate(int amount) => totalWords(l10n, language, kind, amount);

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SumRow(
              label: l10n.cartGoods(keptCount),
              valueKey: 'edit-goods',
              amount: shown.merchandiseSubtotalUzs,
              format: estimate,
              summary: summary,
            ),
            _SumRow(
              label: l10n.cartDelivery,
              valueKey: 'edit-delivery',
              amount: shown.deliveryFeeUzs,
              format: sum,
              summary: summary,
            ),
            _SumRow(
              label: l10n.cartServiceFee,
              valueKey: 'edit-fee',
              amount: shown.serviceFeeUzs,
              format: sum,
              summary: summary,
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: KitColors.line)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _SumRow(
                  label: l10n.cartTotal,
                  valueKey: 'edit-total',
                  amount: shown.totalUzs,
                  format: estimate,
                  summary: summary,
                  bold: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow({
    required this.label,
    required this.valueKey,
    required this.amount,
    required this.format,
    required this.summary,
    this.bold = false,
  });

  final String label;
  final String valueKey;
  final int amount;
  final String Function(int amountUzs) format;
  final EditSummary summary;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final double size = bold ? 16 : 14;
    final FontWeight weight = bold ? FontWeight.w700 : FontWeight.w600;
    final TextStyle valueStyle = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: KitColors.ink,
    );
    final TextStyle labelStyle = TextStyle(
      fontSize: size,
      height: 1.35,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? KitColors.ink : KitColors.ink2,
    );
    final Widget value = summary.failed
        ? Text('—', key: ValueKey<String>(valueKey), style: valueStyle)
        : RollingAmount(
            amountUzs: amount,
            format: format,
            style: valueStyle,
            waiting: summary.waiting,
            textKey: ValueKey<String>(valueKey),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // The amount never breaks inside: it stands beside the label when
          // the label's longest word fits with it, else under the label, at
          // the end.
          final double valueWidth = textWidth(
            context,
            summary.failed ? '—' : format(amount),
            valueStyle,
          );
          final double longestWord = label
              .split(RegExp(r'\s+'))
              .map((String word) => textWidth(context, word, labelStyle))
              .fold<double>(0, math.max);
          if (valueWidth + 12 + longestWord <= constraints.maxWidth) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(child: Text(label, style: labelStyle)),
                const SizedBox(width: 12),
                value,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(label, style: labelStyle),
              Align(alignment: Alignment.centerRight, child: value),
            ],
          );
        },
      ),
    );
  }
}

/// The footer of the editor: what the server says is lacking or gone, the
/// total with its change and what it was, and the save (`DL-132`).
class OrderEditFooter extends StatelessWidget {
  const OrderEditFooter({
    required this.order,
    required this.draft,
    required this.summary,
    required this.changes,
    required this.saving,
    required this.onSave,
    required this.onAdd,
    required this.onRemoveMarked,
    this.saved = false,
    this.orderKnown = true,
    this.failure,
    super.key,
  });

  final CustomerOrder order;
  final OrderDraft draft;

  /// The sums to show; a failed one says the totals come after saving.
  final EditSummary summary;

  /// What the draft would change in the order; the button counts them.
  final List<DraftChange> changes;
  final bool saving;

  /// The ✓ «Сохранено» moment before the editor leaves.
  final bool saved;

  /// `false` while the order loads again after a save whose answer was lost.
  final bool orderKnown;

  /// The failure of the last save worth a red line over the button.
  final ApiFailure? failure;
  final VoidCallback onSave;
  final VoidCallback onAdd;
  final VoidCallback onRemoveMarked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final OrderEditPreview shown = summary.shown;
    final int? minimum = shown.minimumOrderUzs;
    final List<DraftLine> marked = draft.marked;
    final SaveFace face = saveFaceOf(
      saving: saving,
      saved: saved,
      draft: draft,
      summary: summary,
      changes: changes.length,
      orderKnown: orderKnown,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KitColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (failure != null) ...<Widget>[
              FailureMessage(failure),
              const SizedBox(height: 8),
            ],
            if (summary.shortfallUzs > 0 && minimum != null)
              _Strip(
                stripKey: 'edit-minimum',
                buttonKey: 'edit-minimum-add',
                background: KitColors.warningWash,
                icon: Icons.info_outline,
                iconColor: KitColors.warningDark,
                text: l10n.orderEditMinimum(
                  MoneyFormat.uzs(minimum, language),
                  MoneyFormat.uzs(summary.shortfallUzs, language),
                ),
                button: l10n.orderEditAdd,
                onPressed: saving || saved ? null : onAdd,
              ),
            if (marked.isNotEmpty)
              _Strip(
                stripKey: 'edit-gone',
                buttonKey: 'edit-gone-remove',
                background: KitColors.dangerWash,
                icon: Icons.error,
                iconColor: KitColors.danger,
                text: l10n.orderEditGone(
                  marked
                      .map((DraftLine line) => line.name(language))
                      .join(', '),
                ),
                button: l10n.orderEditRemoveShort,
                onPressed: saving || saved ? null : onRemoveMarked,
              ),
            if (summary.failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  l10n.orderEditRecount,
                  key: const ValueKey<String>('edit-recount'),
                  style: _muted12,
                ),
              )
            else
              _TotalBlock(order: order, summary: summary),
            _SaveButton(
              face: face,
              text: _faceText(l10n, language, face, marked, summary),
              onPressed: face == SaveFace.save ? onSave : null,
            ),
          ],
        ),
      ),
    );
  }

  String _faceText(
    AppLocalizations l10n,
    AppLanguage language,
    SaveFace face,
    List<DraftLine> marked,
    EditSummary summary,
  ) => switch (face) {
    SaveFace.saving => l10n.orderEditSavingBusy,
    SaveFace.saved => l10n.orderEditSaved,
    SaveFace.keepOne => l10n.orderEditKeepOne,
    SaveFace.tooMany => l10n.orderAddFull(orderMaxLines),
    SaveFace.removeFirst =>
      marked.length == 1
          ? l10n.orderEditRemoveFirst(marked.first.name(language))
          : l10n.orderEditRemoveFirstMore(
              marked.first.name(language),
              marked.length - 1,
            ),
    SaveFace.shortfall => l10n.orderEditShortfall(
      MoneyFormat.uzs(summary.shortfallUzs, language),
    ),
    SaveFace.noChanges => l10n.orderEditNoChanges,
    SaveFace.save =>
      changes.isEmpty
          ? l10n.saveButton
          : l10n.orderEditSaveChanges(changes.length),
  };
}

/// «Итого» over the total, the change at the end of it, and what it was.
class _TotalBlock extends StatelessWidget {
  const _TotalBlock({required this.order, required this.summary});

  final CustomerOrder order;
  final EditSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final OrderEditPreview shown = summary.shown;
    final int change = shown.totalChangeUzs;
    String sum(int amount) => MoneyFormat.uzs(amount, language);

    final String was;
    if (change == 0) {
      was = l10n.orderEditFeesIncluded(
        sum(shown.deliveryFeeUzs),
        sum(shown.serviceFeeUzs),
      );
    } else {
      final String before = totalWords(
        l10n,
        language,
        order.totalKind,
        shown.totalBeforeUzs,
      );
      final bool same =
          shown.deliveryFeeUzs == order.deliveryFeeUzs &&
          shown.serviceFeeUzs == order.serviceFeeUzs;
      was = same ? l10n.orderEditWasSame(before) : l10n.orderEditWas(before);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.cartTotal,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KitColors.muted,
                    ),
                  ),
                  RollingAmount(
                    amountUzs: shown.totalUzs,
                    format: (int amount) =>
                        totalWords(l10n, language, shown.totalKind, amount),
                    waiting: summary.waiting,
                    textKey: const ValueKey<String>('edit-footer-total'),
                    style: const TextStyle(
                      fontSize: 19,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: KitColors.ink,
                    ),
                  ),
                ],
              ),
              if (change != 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: change > 0 ? KitColors.chip : KitColors.primaryWash,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      MoneyFormat.signedUzs(change, language),
                      key: const ValueKey<String>('edit-change'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: change > 0
                            ? KitColors.ink
                            : KitColors.primaryDark,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          AnimatedOpacity(
            opacity: summary.waiting ? 0.45 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: Text(
              was,
              key: const ValueKey<String>('edit-was'),
              style: _muted12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A strip over the total: words for what the server says and one button to
/// act on it. At large text the button goes under the words, at the end.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.stripKey,
    required this.buttonKey,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.button,
    required this.onPressed,
  });

  final String stripKey;
  final String buttonKey;
  final Color background;
  final IconData icon;
  final Color iconColor;
  final String text;
  final String button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final Widget words = Text(
      text,
      style: const TextStyle(fontSize: 13, height: 1.35, color: KitColors.ink2),
    );
    final Widget action = TextButton(
      key: ValueKey<String>(buttonKey),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: KitColors.ink2,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      child: Text(button),
    );
    final Widget iconBox = Icon(icon, size: 20, color: iconColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        key: ValueKey<String>(stripKey),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          iconBox,
                          const SizedBox(width: 10),
                          Expanded(child: words),
                        ],
                      ),
                    ),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                )
              : Row(
                  children: <Widget>[
                    iconBox,
                    const SizedBox(width: 10),
                    Expanded(child: words),
                    const SizedBox(width: 10),
                    action,
                  ],
                ),
        ),
      ),
    );
  }
}

/// The save button in the face the editor holds: its colours move over
/// 250 ms, ease-out, and not at all with reduced motion.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.face,
    required this.text,
    required this.onPressed,
  });

  final SaveFace face;
  final String text;
  final VoidCallback? onPressed;

  bool get _grey => switch (face) {
    SaveFace.saving || SaveFace.saved || SaveFace.save => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    final Color background = _grey ? KitColors.buttonOff : KitColors.primary;
    final Color foreground = _grey ? KitColors.muted : Colors.white;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: background),
      duration: duration,
      curve: Curves.easeOut,
      builder: (BuildContext context, Color? fill, _) =>
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: foreground),
            duration: duration,
            curve: Curves.easeOut,
            builder: (BuildContext context, Color? ink, _) => FilledButton(
              key: const ValueKey<String>('edit-save'),
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll<Color?>(fill),
                foregroundColor: WidgetStatePropertyAll<Color?>(ink),
                minimumSize: const WidgetStatePropertyAll<Size>(
                  Size.fromHeight(54),
                ),
                padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                  EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                ),
                shape: WidgetStatePropertyAll<OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                animationDuration: Duration.zero,
              ),
              onPressed: onPressed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (face == SaveFace.saving) ...<Widget>[
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (face == SaveFace.saved) ...<Widget>[
                    const Icon(Icons.check, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
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
